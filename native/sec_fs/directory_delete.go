package sec_fs

import (
	"io/fs"
	"os"
	"path/filepath"
)

// deleteDirectoryTree removes an already resolved non-root directory. It
// refuses symbolic links anywhere in the tree before deletion.
func deleteDirectoryTree(path RelativeViewPath, fullPath FullStorePath) error {
	if path.IsEmpty() || path == "." {
		return NewPairPathError("remove_tree", path, fullPath, ErrInvalidPath)
	}

	info, err := os.Lstat(string(fullPath))
	if err != nil {
		return NewPairPathError("lstat", path, fullPath, err)
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.IsDir() {
		return NewPairPathError("remove_tree", path, fullPath, ErrNotADirectory)
	}

	err = filepath.WalkDir(string(fullPath), func(_ string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return ErrUnsupportedOperation
		}
		return nil
	})
	if err != nil {
		return NewPairPathError("verify_remove_tree", path, fullPath, err)
	}
	if err := os.RemoveAll(string(fullPath)); err != nil {
		return NewPairPathError("remove_tree", path, fullPath, err)
	}
	return nil
}
