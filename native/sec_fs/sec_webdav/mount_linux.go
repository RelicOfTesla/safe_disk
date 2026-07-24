//go:build linux

package sec_webdav

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func mountSessionPlatform(ctx context.Context, session Session) (*MountedSession, error) {
	switch session.AuthMode {
	case AuthModeDigest, AuthModeBasic:
		// supported
	case AuthModeBearer:
		return nil, fmt.Errorf("%w: bearer tokens are not accepted by davfs. Use Digest or Basic authentication.", ErrMountUnsupported)
	default:
		return nil, fmt.Errorf("%w: unsupported authentication mode for davfs mount", ErrMountUnsupported)
	}
	if _, err := exec.LookPath("mount.davfs"); err != nil {
		return nil, fmt.Errorf("%w: mount.davfs is unavailable", ErrMountUnsupported)
	}
	cacheDir, err := os.UserCacheDir()
	if err != nil {
		return nil, fmt.Errorf("%w: locate user cache", ErrMountFailed)
	}
	workspaceRoot := filepath.Join(cacheDir, "safe_disk", "webdav-mounts")
	if err := os.MkdirAll(workspaceRoot, 0700); err != nil {
		return nil, fmt.Errorf("%w: create mount workspace", ErrMountFailed)
	}
	tempDir, err := os.MkdirTemp(workspaceRoot, "session-")
	if err != nil {
		return nil, fmt.Errorf("%w: create mount workspace", ErrMountFailed)
	}
	cleanupWorkspace := func() {
		_ = os.RemoveAll(tempDir)
	}

	configPath := filepath.Join(tempDir, "davfs2.conf")
	secretsPath := filepath.Join(tempDir, "secrets")

	config := "secrets " + secretsPath + "\n"
	config += "ask_auth 0\n"
	config += "use_locks 0\n"
	config += "if_match_bug 1\n"

	secrets := strings.TrimRight(session.URL, "/") + " " + session.Username + " " + session.Password + "\n"

	if err := tryMountDavfs(ctx, session.URL, tempDir, configPath, secretsPath, config, secrets); err != nil {
		cleanupWorkspace()
		return nil, err
	}

	if _, readErr := os.ReadDir(tempDir); readErr != nil {
		_ = disconnectMount(context.Background(), tempDir)
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: davfs mount succeeded but directory is unreadable (%v)", ErrMountFailed, readErr)
	}

	return &MountedSession{
		path: tempDir,
		unmount: func(unmountCtx context.Context) error {
			if umountErr := disconnectMount(unmountCtx, tempDir); umountErr != nil {
				return umountErr
			}
			cleanupWorkspace()
			return nil
		},
	}, nil
}

// tryMountDavfs attempts to mount via pkexec, sudo, or direct setuid call.
// When using pkexec/sudo, it creates a helper script that writes root-owned
// config/secrets files (required by davfs2's security check) and then mounts.
func tryMountDavfs(ctx context.Context, url, mountPoint, configPath, secretsPath, config, secrets string) error {
	if _, err := exec.LookPath("pkexec"); err == nil {
		return mountDavfsViaElevated(ctx, "pkexec", url, mountPoint, configPath, secretsPath, config, secrets)
	}
	if _, err := exec.LookPath("sudo"); err == nil {
		return mountDavfsViaElevated(ctx, "sudo", url, mountPoint, configPath, secretsPath, config, secrets)
	}

	// Direct setuid call: write files as user and hope mount.davfs accepts them.
	if err := os.WriteFile(configPath, []byte(config), 0600); err != nil {
		return fmt.Errorf("%w: write mount configuration", ErrMountFailed)
	}
	if err := os.WriteFile(secretsPath, []byte(secrets), 0600); err != nil {
		return fmt.Errorf("%w: write mount credentials", ErrMountFailed)
	}
	cmd := exec.CommandContext(ctx, "mount.davfs", url, mountPoint, "-o", "conf="+configPath+",ro")
	if output, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("%w: davfs mount: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}

// mountDavfsViaElevated creates a shell script that writes root-owned config
// and secrets files (required by davfs2 when running as root), then calls
// mount.davfs. The script is run via pkexec or sudo in a single elevation.
func mountDavfsViaElevated(ctx context.Context, cmd string, url, mountPoint, configPath, secretsPath, config, secrets string) error {
	// Build a self-contained shell script. Using quoted heredoc delimiters
	// prevents variable expansion in the config/secrets content.
	script := fmt.Sprintf(`#!/bin/sh
set -e
cat > '%s' << 'DAVFS2CONF_EOF'
%s
DAVFS2CONF_EOF
cat > '%s' << 'DAVFS2SECRETS_EOF'
%s
DAVFS2SECRETS_EOF
chmod 600 '%s' '%s'
exec mount.davfs %s '%s' -o 'conf=%s,ro'
`, configPath, config, secretsPath, secrets, configPath, secretsPath, url, mountPoint, configPath)

	scriptPath := filepath.Join(filepath.Dir(mountPoint), "davfs_mount.sh")
	if err := os.WriteFile(scriptPath, []byte(script), 0700); err != nil {
		return fmt.Errorf("%w: write mount script", ErrMountFailed)
	}
	defer os.Remove(scriptPath)

	command := exec.CommandContext(ctx, cmd, scriptPath)
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("%w: davfs mount: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}

// disconnectMount unmounts a davfs2 filesystem. If a normal unmount fails,
// it attempts a lazy unmount as a fallback for stuck or unresponsive mounts.
func disconnectMount(ctx context.Context, mountPoint string) error {
	command := exec.CommandContext(ctx, "umount", mountPoint)
	output, err := command.CombinedOutput()
	if err == nil {
		return nil
	}
	// Try lazy unmount as fallback.
	lazyCmd := exec.CommandContext(ctx, "umount", "-l", mountPoint)
	if lazyErr := lazyCmd.Run(); lazyErr != nil {
		return fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}
