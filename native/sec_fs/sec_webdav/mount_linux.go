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
	if session.AuthMode != AuthModeDigest {
		return nil, fmt.Errorf("%w: bearer credentials are not accepted by davfs", ErrMountUnsupported)
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
	config := "secrets " + secretsPath + "\nask_auth 0\nuse_locks 0\n"
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
		return nil, fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return &MountedSession{
		path: tempDir,
		unmount: func(unmountCtx context.Context) error {
			command := exec.CommandContext(unmountCtx, "umount", tempDir)
			if output, err := command.CombinedOutput(); err != nil {
				return fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
			}
			cleanupWorkspace()
			return nil
		},
	}, nil
}
