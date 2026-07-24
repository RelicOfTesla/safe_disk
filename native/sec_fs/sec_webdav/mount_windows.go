//go:build windows

package sec_webdav

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"golang.org/x/sys/windows"
)

func mountSessionPlatform(ctx context.Context, session Session) (*MountedSession, error) {
	if session.AuthMode != AuthModeDigest {
		return nil, fmt.Errorf("%w: Windows WebDAV Redirector cannot use bearer sessions", ErrMountUnsupported)
	}
	if session.Username == "" || session.Password == "" {
		return nil, fmt.Errorf("%w: Digest credentials are unavailable", ErrMountFailed)
	}
	drive, err := freeWindowsDrive()
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMountFailed, err)
	}
	uncPath, err := windowsWebDAVUNC(session.URL)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMountFailed, err)
	}
	command := exec.CommandContext(
		ctx,
		"net.exe",
		"use",
		drive,
		uncPath,
		"/user:"+session.Username,
		"*",
		"/persistent:no",
	)
	command.Stdin = strings.NewReader(session.Password + "\r\n")
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

func windowsWebDAVUNC(rawURL string) (string, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Scheme != "http" && parsed.Scheme != "https" || parsed.Hostname() == "" {
		return "", errors.New("WebDAV URL must be an HTTP/HTTPS loopback URL")
	}
	if parsed.Hostname() != "127.0.0.1" && parsed.Hostname() != "localhost" {
		return "", errors.New("WebDAV URL is not loopback")
	}
	port := parsed.Port()
	if port == "" {
		port = strconv.Itoa(80)
	}
	path := strings.Trim(parsed.EscapedPath(), "/")
	path = strings.ReplaceAll(path, "/", "\\")
	if path == "" {
		return `\\` + parsed.Hostname() + "@" + port + `\DavWWWRoot`, nil
	}
	return `\\` + parsed.Hostname() + "@" + port + `\DavWWWRoot\` + path, nil
}

func disconnectWindowsDrive(ctx context.Context, drive string) error {
	command := exec.CommandContext(ctx, "net.exe", "use", drive, "/delete", "/y")
	if output, err := command.CombinedOutput(); err != nil {
		return fmt.Errorf("%w: %s", ErrMountFailed, sanitizeMountOutput(string(output)))
	}
	return nil
}
