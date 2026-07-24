package sec_transfer_v3

import (
	"fmt"
	"os"
)

// openRegularFile opens a regular file for reading, refusing to follow
// symbolic links. This prevents TOCTOU attacks where an attacker replaces
// a plain file with a symlink to a sensitive path between a stat check
// and the actual open call.
//
// Platform-specific implementations (symlink_guard_unix.go / symlink_guard_windows.go)
// provide the actual O_NOFOLLOW semantics.
func openRegularFile(path string) (*os.File, error) {
	f, err := openRegularFileImpl(path)
	if err != nil {
		return nil, err
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, err
	}
	if !info.Mode().IsRegular() {
		f.Close()
		return nil, fmt.Errorf("not a regular file: %s (mode=%s)", path, info.Mode())
	}
	return f, nil
}

// createRegularFile creates a new regular file, refusing to follow symbolic
// links in the path leading to it and refusing to open an existing symlink.
func createRegularFile(path string, perm os.FileMode) (*os.File, error) {
	f, err := createRegularFileImpl(path, perm)
	if err != nil {
		return nil, err
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, err
	}
	if !info.Mode().IsRegular() {
		f.Close()
		return nil, fmt.Errorf("not a regular file: %s (mode=%s)", path, info.Mode())
	}
	return f, nil
}
