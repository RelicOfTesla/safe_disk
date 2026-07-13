package sec_fs

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path"
	"strings"
)

// CopyEntry copies one logical file or directory between secure roots. File
// content is read and written through ISecRoot, so roots may use different
// encryption configurations. Existing directories are merged only when
// overwrite is true; existing files are replaced with an atomic rename.
func CopyEntry(srcRoot ISecRoot, src RelativeViewPath, dstRoot ISecRoot, dst RelativeViewPath, overwrite bool) error {
	if srcRoot == nil || dstRoot == nil {
		return ErrRootIsNil
	}
	var err error
	src, err = cleanCopyPath(src)
	if err != nil {
		return err
	}
	dst, err = cleanCopyPath(dst)
	if err != nil {
		return err
	}
	if src == "" || dst == "" {
		return fmt.Errorf("copy root directory is not supported")
	}

	sameRoot := srcRoot.GetRootPath() == dstRoot.GetRootPath()
	if sameRoot && src == dst {
		return copyDestinationExists(dst)
	}
	if sameRoot && isPathWithin(dst, src) {
		return fmt.Errorf("copy destination %q is inside source %q", dst, src)
	}

	info, err := srcRoot.Stat(src)
	if err != nil {
		return fmt.Errorf("stat copy source %q: %w", src, err)
	}
	if info.IsDir() {
		return copyDirectoryEntry(srcRoot, src, dstRoot, dst, overwrite)
	}
	return copyFileEntry(srcRoot, src, dstRoot, dst, overwrite)
}

func copyDirectoryEntry(srcRoot ISecRoot, src RelativeViewPath, dstRoot ISecRoot, dst RelativeViewPath, overwrite bool) error {
	dstExists := dstRoot.FileExists(dst)
	if dstExists {
		info, err := dstRoot.Stat(dst)
		if err != nil {
			return fmt.Errorf("stat copy destination %q: %w", dst, err)
		}
		if !info.IsDir() {
			return fmt.Errorf("copy directory destination %q is a file", dst)
		}
		if !overwrite {
			return copyDestinationExists(dst)
		}
	} else if err := dstRoot.MkdirAll(dst); err != nil {
		return fmt.Errorf("create copy destination %q: %w", dst, err)
	}

	entries, err := srcRoot.ReadDir(string(src))
	if err != nil {
		return fmt.Errorf("read copy source %q: %w", src, err)
	}
	for _, entry := range entries {
		srcChild := RelativeViewPath(path.Join(string(src), entry.Name()))
		dstChild := RelativeViewPath(path.Join(string(dst), entry.Name()))
		if entry.IsDir() {
			if err := copyDirectoryEntry(srcRoot, srcChild, dstRoot, dstChild, overwrite); err != nil {
				return err
			}
			continue
		}
		if err := copyFileEntry(srcRoot, srcChild, dstRoot, dstChild, overwrite); err != nil {
			return err
		}
	}
	return nil
}

func copyFileEntry(srcRoot ISecRoot, src RelativeViewPath, dstRoot ISecRoot, dst RelativeViewPath, overwrite bool) error {
	dstExists := dstRoot.FileExists(dst)
	if dstExists {
		info, err := dstRoot.Stat(dst)
		if err != nil {
			return fmt.Errorf("stat copy destination %q: %w", dst, err)
		}
		if info.IsDir() {
			return fmt.Errorf("copy file destination %q is a directory", dst)
		}
		if !overwrite {
			return copyDestinationExists(dst)
		}
	}

	source, err := srcRoot.OpenFile(src, os.O_RDONLY)
	if err != nil {
		return fmt.Errorf("open copy source %q: %w", src, err)
	}
	defer source.Close()

	parent := path.Dir(string(dst))
	if parent != "." && parent != "" {
		if err := dstRoot.MkdirAll(RelativeViewPath(parent)); err != nil {
			return fmt.Errorf("create copy parent %q: %w", parent, err)
		}
	}
	temp, err := uniqueCopyPath(dstRoot, dst, ".copying")
	if err != nil {
		return err
	}
	target, err := dstRoot.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_EXCL|os.O_TRUNC)
	if err != nil {
		return fmt.Errorf("create copy temporary file %q: %w", temp, err)
	}
	_, copyErr := io.Copy(target, source)
	closeErr := target.Close()
	if copyErr != nil || closeErr != nil {
		_ = dstRoot.DeleteFile(temp)
		if copyErr != nil {
			return fmt.Errorf("copy %q to %q: %w", src, dst, copyErr)
		}
		return fmt.Errorf("close copy destination %q: %w", dst, closeErr)
	}

	if !dstExists {
		if err := dstRoot.Rename(temp, dst); err != nil {
			_ = dstRoot.DeleteFile(temp)
			return fmt.Errorf("commit copy destination %q: %w", dst, err)
		}
		return nil
	}

	backup, err := uniqueCopyPath(dstRoot, dst, ".replaced")
	if err != nil {
		_ = dstRoot.DeleteFile(temp)
		return err
	}
	if err := dstRoot.Rename(dst, backup); err != nil {
		_ = dstRoot.DeleteFile(temp)
		return fmt.Errorf("backup copy destination %q: %w", dst, err)
	}
	if err := dstRoot.Rename(temp, dst); err != nil {
		_ = dstRoot.Rename(backup, dst)
		_ = dstRoot.DeleteFile(temp)
		return fmt.Errorf("commit replacement copy %q: %w", dst, err)
	}
	if err := dstRoot.DeleteFile(backup); err != nil {
		return fmt.Errorf("remove replaced copy destination %q: %w", backup, err)
	}
	return nil
}

func cleanCopyPath(value RelativeViewPath) (RelativeViewPath, error) {
	normalized := strings.ReplaceAll(string(value), "\\", "/")
	if strings.HasPrefix(normalized, "/") {
		return "", NewRelativeViewPathError("copy_validate", value, ErrPathTraversal)
	}
	cleaned := path.Clean(normalized)
	if cleaned == ".." || strings.HasPrefix(cleaned, "../") {
		return "", NewRelativeViewPathError("copy_validate", value, ErrPathTraversal)
	}
	if cleaned == "." {
		return "", nil
	}
	return RelativeViewPath(cleaned), nil
}

func isPathWithin(candidate RelativeViewPath, parent RelativeViewPath) bool {
	return strings.HasPrefix(string(candidate), string(parent)+"/")
}

func copyDestinationExists(dst RelativeViewPath) error {
	return fmt.Errorf("copy destination %q: %w", dst, ErrFileAlreadyExists)
}

func uniqueCopyPath(root ISecRoot, dst RelativeViewPath, suffix string) (RelativeViewPath, error) {
	parent := path.Dir(string(dst))
	for attempt := 0; attempt < 8; attempt++ {
		var random [8]byte
		if _, err := rand.Read(random[:]); err != nil {
			return "", fmt.Errorf("generate copy temporary name: %w", err)
		}
		name := ".safe_disk" + suffix + "." + hex.EncodeToString(random[:])
		candidate := RelativeViewPath(name)
		if parent != "." && parent != "" {
			candidate = RelativeViewPath(path.Join(parent, name))
		}
		if !root.FileExists(candidate) {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("allocate copy temporary path for %q", dst)
}
