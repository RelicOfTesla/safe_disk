//go:build windows

package sec_webdav

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"

	"golang.org/x/sys/windows"
)

func mountSessionPlatform(ctx context.Context, session Session) (*MountedSession, error) {
	switch session.AuthMode {
	case AuthModeDigest, AuthModeBasic:
		// supported
	case AuthModeBearer:
		return nil, fmt.Errorf("%w: Windows WebDAV Redirector does not support bearer tokens. Use Digest or Basic authentication.", ErrMountUnsupported)
	default:
		return nil, fmt.Errorf("%w: unsupported authentication mode for Windows mount", ErrMountUnsupported)
	}
	if session.Username == "" || session.Password == "" {
		return nil, fmt.Errorf("%w: credentials are unavailable", ErrMountFailed)
	}
	drive, err := freeWindowsDrive()
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMountFailed, err)
	}

	// Use the full URL directly instead of the WebClient UNC path.
	// The WebClient redirector (\\host@port\DavWWWRoot) requires the
	// WebClient service and specific registry settings. The full URL
	// approach matches what the Explorer "Map Network Drive" wizard uses
	// and is more reliable.
	command := exec.CommandContext(
		ctx,
		"net.exe",
		"use",
		drive,
		session.URL,
		session.Password,
		"/user:"+session.Username,
		"/persistent:no",
	)
	if output, err := command.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	mountPath := drive + "\\"
	if _, err := os.Stat(mountPath); err != nil {
		_ = disconnectWindowsDrive(context.Background(), drive)
		return nil, fmt.Errorf("%w: WebClient did not expose %s: %v", ErrMountFailed, mountPath, err)
	}
	return &MountedSession{
		path: mountPath,
		unmount: func(unmountCtx context.Context) error {
			return disconnectWindowsDrive(unmountCtx, drive)
		},
	}, nil
}

func freeWindowsDrive() (string, error) {
	mask, err := windows.GetLogicalDrives()
	if err != nil {
		return "", err
	}
	// Prefer higher letters so ordinary system volumes keep their usual names.
	for letter := int32('Z'); letter >= int32('D'); letter-- {
		bit := uint32(1) << uint(letter-'A')
		if mask&bit == 0 {
			return string(rune(letter)) + ":", nil
		}
	}
	return "", errors.New("no free drive letter")
}

func disconnectWindowsDrive(ctx context.Context, drive string) error {
	command := exec.CommandContext(ctx, "net.exe", "use", drive, "/delete", "/y")
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}
