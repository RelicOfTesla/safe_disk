package sec_fs_test

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestPlainFSDeleteDirectoryTree(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(filepath.Join(rootPath, "nested", "child"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rootPath, "nested", "child", "note.txt"), []byte("data"), 0600); err != nil {
		t.Fatal(err)
	}

	root, err := sec_fs.NewPlainFS(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	if err := root.DeleteDirectoryTree("nested"); err != nil {
		t.Fatalf("DeleteDirectoryTree: %v", err)
	}
	if _, err := os.Stat(filepath.Join(rootPath, "nested")); !os.IsNotExist(err) {
		t.Fatalf("nested directory remains after delete: %v", err)
	}
	if err := root.DeleteDirectoryTree(""); !errors.Is(err, sec_fs.ErrInvalidPath) {
		t.Fatalf("empty path error = %v, want ErrInvalidPath", err)
	}
	if err := root.DeleteDirectoryTree("../outside"); !errors.Is(err, sec_fs.ErrPathTraversal) {
		t.Fatalf("traversal error = %v, want ErrPathTraversal", err)
	}
}

func TestPlainFSDeleteDirectoryTreeRejectsSymlink(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	outsidePath := filepath.Join(tmp, "outside")
	if err := os.MkdirAll(filepath.Join(rootPath, "nested"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(outsidePath, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outsidePath, filepath.Join(rootPath, "nested", "outside-link")); err != nil {
		t.Skipf("symbolic links unavailable: %v", err)
	}

	root, err := sec_fs.NewPlainFS(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	if err := root.DeleteDirectoryTree("nested"); err == nil {
		t.Fatal("DeleteDirectoryTree accepted a symbolic link")
	}
	if _, err := os.Lstat(filepath.Join(rootPath, "nested", "outside-link")); err != nil {
		t.Fatalf("rejected tree was modified: %v", err)
	}
	if _, err := os.Stat(outsidePath); err != nil {
		t.Fatalf("outside target was modified: %v", err)
	}
}

func TestEncryptedRootDeleteDirectoryTree(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	root, err := createPathSecurityRoot(rootPath, "AES-256-GCM")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	if err := root.MkdirAll("目录/子目录"); err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile("目录/子目录/记录.txt", os.O_CREATE|os.O_WRONLY)
	if err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}

	if err := root.DeleteDirectoryTree("目录"); err != nil {
		t.Fatalf("DeleteDirectoryTree: %v", err)
	}
	if root.FileExists("目录/子目录/记录.txt") {
		t.Fatal("encrypted directory content remains after delete")
	}
	if err := root.DeleteDirectoryTree("."); !errors.Is(err, sec_fs.ErrInvalidPath) {
		t.Fatalf("root path error = %v, want ErrInvalidPath", err)
	}
}
