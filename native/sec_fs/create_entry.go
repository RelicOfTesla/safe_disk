package sec_fs

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

// CreateEmptyFile creates a new zero-length logical file without replacing an
// existing file or directory.
func CreateEmptyFile(root ISecRoot, path RelativeViewPath) error {
	if root == nil {
		return ErrRootIsNil
	}
	file, err := root.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL)
	if err != nil {
		if errors.Is(err, os.ErrExist) {
			err = ErrFileAlreadyExists
		}
		return fmt.Errorf("create empty file %q: %w", path, err)
	}
	if err := file.Close(); err != nil {
		_ = root.DeleteFile(path)
		return fmt.Errorf("close empty file %q: %w", path, err)
	}
	return nil
}

// CreateDirectory creates exactly one logical directory. Its parent must
// already exist, and an existing target is never accepted.
func CreateDirectory(root ISecRoot, path RelativeViewPath) error {
	if root == nil {
		return ErrRootIsNil
	}
	storePath, err := root.GetStorePath(path)
	if err != nil {
		return fmt.Errorf("resolve directory %q: %w", path, err)
	}
	if storePath == "" {
		return fmt.Errorf("create root directory is not supported")
	}
	fullPath := filepath.Join(
		string(root.GetRootPath()),
		filepath.FromSlash(string(storePath)),
	)
	if err := os.Mkdir(fullPath, SecureDirMode); err != nil {
		if os.IsExist(err) {
			err = ErrFileAlreadyExists
		}
		return NewPairPathError("mkdir", path, FullStorePath(fullPath), err)
	}
	return nil
}
