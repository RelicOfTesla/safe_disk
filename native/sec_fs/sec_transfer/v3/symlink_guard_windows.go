//go:build windows

package sec_transfer_v3

import (
	"fmt"
	"os"

	"golang.org/x/sys/windows"
)

func openRegularFileImpl(path string) (*os.File, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	// FILE_FLAG_OPEN_REPARSE_POINT alone does not prevent following
	// symlinks; we open without that flag so reparse points are
	// resolved.  On Windows the OS-level guard against TOCTOU is
	// weaker than unix O_NOFOLLOW, so we still rely on the
	// post-open IsRegular check in the shared wrapper.
	fd, err := windows.CreateFile(
		p,
		windows.GENERIC_READ,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE,
		nil,
		windows.OPEN_EXISTING,
		windows.FILE_ATTRIBUTE_NORMAL,
		0,
	)
	if err != nil {
		return nil, fmt.Errorf("openRegularFile %s: %w", path, err)
	}
	return os.NewFile(uintptr(fd), path), nil
}

func createRegularFileImpl(path string, perm os.FileMode) (*os.File, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}
	security := (*windows.SecurityAttributes)(nil)
	fd, err := windows.CreateFile(
		p,
		windows.GENERIC_WRITE,
		0,
		security,
		windows.CREATE_NEW,
		windows.FILE_ATTRIBUTE_NORMAL,
		0,
	)
	if err != nil {
		return nil, fmt.Errorf("createRegularFile %s: %w", path, err)
	}
	return os.NewFile(uintptr(fd), path), nil
}
