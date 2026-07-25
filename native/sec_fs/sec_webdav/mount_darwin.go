//go:build darwin

package sec_webdav

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func mountSessionPlatform(ctx context.Context, session Session) (*MountedSession, error) {
	switch session.AuthMode {
	case AuthModeDigest, AuthModeBasic:
		// supported by mount_webdav via the keychain
	case AuthModeBearer:
		return nil, fmt.Errorf("%w: macOS mount_webdav does not support bearer tokens. Use Digest or Basic authentication.", ErrMountUnsupported)
	default:
		return nil, fmt.Errorf("%w: unsupported authentication mode for macOS mount", ErrMountUnsupported)
	}
	if _, err := exec.LookPath("mount_webdav"); err != nil {
		return nil, fmt.Errorf("%w: mount_webdav is unavailable", ErrMountUnsupported)
	}
	if _, err := exec.LookPath("security"); err != nil {
		return nil, fmt.Errorf("%w: security(1) is required for keychain-based WebDAV authentication", ErrMountUnsupported)
	}
	if session.Username == "" || session.Password == "" {
		return nil, fmt.Errorf("%w: credentials are unavailable", ErrMountFailed)
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

	// macOS mount_webdav reads credentials from the keychain. Create a
	// temporary keychain entry so mount_webdav can authenticate without
	// an interactive prompt. The entry is deleted on unmount.
	keychainLabel := "safe-disk-webdav-" + session.ID
	host := extractURLHost(session.URL)

	// -A allows any application to access this entry without prompting.
	// This is acceptable because the entry is short-lived and scoped to
	// this session.
	secAdd := exec.CommandContext(ctx, "security", "add-internet-password",
		"-a", session.Username,
		"-s", host,
		"-w", session.Password,
		"-l", keychainLabel,
		"-r", "webdav ",
		"-D", "WebDAV password",
		"-A",
		"-U",
	)
	if output, err := secAdd.CombinedOutput(); err != nil {
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: keychain credential store (%s)", ErrMountFailed, sanitizeMountOutput(string(output)))
	}

	deleteKeychain := func() {
		delCmd := exec.Command("security", "delete-internet-password", "-l", keychainLabel)
		_ = delCmd.Run()
	}

	// -S suppresses the Finder sidebar entry.
	mountCmd := exec.CommandContext(ctx, "mount_webdav", "-S", session.URL, tempDir)
	if output, err := mountCmd.CombinedOutput(); err != nil {
		deleteKeychain()
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: mount_webdav: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}

	// Verify the mount is readable. Retry because the mount daemon may
	// still be initializing.
	var readErr error
	for attempt := 0; attempt < 5; attempt++ {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				deleteKeychain()
				_ = disconnectDarwinMount(context.Background(), tempDir)
				cleanupWorkspace()
				return nil, fmt.Errorf("%w: mount interrupted during verification", ErrMountFailed)
			case <-time.After(time.Duration(attempt*100) * time.Millisecond):
			}
		}
		_, readErr = os.ReadDir(tempDir)
		if readErr == nil {
			break
		}
	}
	if readErr != nil {
		deleteKeychain()
		_ = disconnectDarwinMount(context.Background(), tempDir)
		cleanupWorkspace()
		return nil, fmt.Errorf("%w: mount succeeded but directory is unreadable (%v)", ErrMountFailed, readErr)
	}

	return &MountedSession{
		path: tempDir,
		unmount: func(unmountCtx context.Context) error {
			if umountErr := disconnectDarwinMount(unmountCtx, tempDir); umountErr != nil {
				return umountErr
			}
			deleteKeychain()
			cleanupWorkspace()
			return nil
		},
	}, nil
}

// disconnectDarwinMount unmounts a WebDAV filesystem. Tries umount first,
// then diskutil unmount force as a fallback.
func disconnectDarwinMount(ctx context.Context, mountPoint string) error {
	cmd := exec.CommandContext(ctx, "umount", mountPoint)
	output, err := cmd.CombinedOutput()
	if err == nil {
		return nil
	}
	// Try diskutil force unmount as fallback.
	forceCmd := exec.CommandContext(ctx, "diskutil", "unmount", "force", mountPoint)
	if forceErr := forceCmd.Run(); forceErr != nil {
		return fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}

// extractURLHost returns the host[:port] portion of a URL, stripping
// scheme, path, query, and fragment.
func extractURLHost(rawURL string) string {
	s := rawURL
	s = strings.TrimPrefix(s, "https://")
	s = strings.TrimPrefix(s, "http://")
	if idx := strings.IndexAny(s, "/?#"); idx >= 0 {
		s = s[:idx]
	}
	return s
}
