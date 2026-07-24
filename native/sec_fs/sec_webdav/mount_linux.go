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
	if _, err := exec.LookPath("mount"); err != nil {
		return nil, fmt.Errorf("%w: mount command is unavailable", ErrMountUnsupported)
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

	if err := os.WriteFile(configPath, []byte(config), 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: write mount configuration", ErrMountFailed)
	}
	if err := os.WriteFile(secretsPath, []byte(secrets), 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: write mount credentials", ErrMountFailed)
	}

	// Use pkexec/sudo mount.davfs directly instead of mount -t davfs.
	// mount -t davfs calls setuid mount.davfs which ignores -o conf=... for
	// security; the fallback ~/.davfs2/secrets has no credentials, causing
	// "no entry found".  Calling mount.davfs directly via pkexec/sudo
	// preserves the custom config and secrets.
	mountCmd := selectMountPrivilegeCmd(session.URL, tempDir, configPath)
	command := exec.CommandContext(ctx, mountCmd[0], mountCmd[1:]...)
	if output, err := command.CombinedOutput(); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: davfs mount: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}

	// Post-mount health check: the FUSE daemon may fail shortly after a
	// seemingly successful mount, leaving an unusable directory.
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

// selectMountPrivilegeCmd returns the argument list to run mount.davfs with
// enough privileges to use a custom config. Prefers pkexec (PolicyKit) for
// better desktop integration over sudo.
func selectMountPrivilegeCmd(url, mountPoint, configPath string) []string {
	opts := "conf=" + configPath + ",ro"
	if _, err := exec.LookPath("pkexec"); err == nil {
		return []string{"pkexec", "mount.davfs", url, mountPoint, "-o", opts}
	}
	if _, err := exec.LookPath("sudo"); err == nil {
		return []string{"sudo", "mount.davfs", url, mountPoint, "-o", opts}
	}
	// Fallback: regular mount (setuid mount.davfs may ignore -o conf).
	return []string{"mount", "-t", "davfs", url, mountPoint, "-o", opts}
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
