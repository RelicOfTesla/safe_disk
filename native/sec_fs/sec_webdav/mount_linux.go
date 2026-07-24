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
	config := "secrets " + secretsPath + "\nask_auth 0\nuse_locks 0\nif_match_bug 1\n"
	secrets := strings.TrimRight(session.URL, "/") + " " + session.Username + " " + session.Password + "\n"
	if err := os.WriteFile(configPath, []byte(config), 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: write mount configuration", ErrMountFailed)
	}
	if err := os.WriteFile(secretsPath, []byte(secrets), 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: write mount credentials", ErrMountFailed)
	}
	if err := os.Chmod(configPath, 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: protect mount configuration", ErrMountFailed)
	}
	if err := os.Chmod(secretsPath, 0600); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: protect mount credentials", ErrMountFailed)
	}

	command := exec.CommandContext(ctx, "mount", "-t", "davfs", session.URL, tempDir, "-o", "conf="+configPath+",ro")
	if output, err := command.CombinedOutput(); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: davfs mount: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}

	// Post-mount health check: davfs2 can report success from mount(8) but
	// the daemon may fail shortly afterwards, leaving an unusable mount point.
	// Reading the directory confirms the FUSE daemon is responding.
	if entries, readErr := os.ReadDir(tempDir); readErr != nil {
		_ = disconnectMount(context.Background(), tempDir)
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: davfs mount succeeded but directory is unreadable (%v). Check that the WebDAV URL is reachable and authentication is correct", ErrMountFailed, readErr)
	} else {
		// An empty directory may be legitimate, but it also matches the
		// symptom of a silently-failed daemon. We accept it and log the
		// entry count only for diagnostics; the caller can decide.
		_ = entries
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
