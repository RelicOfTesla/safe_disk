//go:build aix || darwin || dragonfly || freebsd || linux || netbsd || openbsd || solaris

package sec_transfer_v3

import (
	"os"

	"golang.org/x/sys/unix"
)

func openRegularFileImpl(path string) (*os.File, error) {
	fd, err := unix.Open(path, unix.O_RDONLY|unix.O_NOFOLLOW, 0)
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(fd), path), nil
}

func createRegularFileImpl(path string, perm os.FileMode) (*os.File, error) {
	flags := unix.O_WRONLY | unix.O_CREAT | unix.O_TRUNC | unix.O_NOFOLLOW | unix.O_EXCL
	fd, err := unix.Open(path, flags, uint32(perm))
	if err != nil {
		return nil, err
	}
	return os.NewFile(uintptr(fd), path), nil
}
