package sec_fs_test

import (
	"errors"
	"os"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

func TestRenameDoesNotReplaceExistingEncryptedEntry(t *testing.T) {
	rootPath := t.TempDir()
	const password = "rename-no-replace-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		password,
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
		sec_fs.WithKeyStrengthMs(1),
	); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	writeRootFile(t, root, "原文件.txt", "source")
	writeRootFile(t, root, "已存在.txt", "target")

	err = root.Rename("原文件.txt", "已存在.txt")
	if !errors.Is(err, sec_fs.ErrFileAlreadyExists) {
		t.Fatalf("rename collision error = %v, want ErrFileAlreadyExists", err)
	}
	if got := readRootFile(t, root, "原文件.txt"); got != "source" {
		t.Fatalf("source changed after collision: %q", got)
	}
	if got := readRootFile(t, root, "已存在.txt"); got != "target" {
		t.Fatalf("target changed after collision: %q", got)
	}

	if err := root.Rename("原文件.txt", "新文件.txt"); err != nil {
		t.Fatal(err)
	}
	if root.FileExists("原文件.txt") || !root.FileExists("新文件.txt") {
		t.Fatal("file rename did not update the encrypted view paths")
	}

	if err := root.MkdirAll("旧目录/子目录"); err != nil {
		t.Fatal(err)
	}
	if err := root.Rename("旧目录", "新目录"); err != nil {
		t.Fatal(err)
	}
	if _, err := root.Stat("新目录/子目录"); err != nil {
		t.Fatalf("renamed directory contents are unavailable: %v", err)
	}
}

func writeRootFile(t *testing.T, root sec_fs.ISecRoot, path, content string) {
	t.Helper()
	file, err := root.OpenFile(
		sec_fs.RelativeViewPath(path),
		os.O_CREATE|os.O_WRONLY|os.O_TRUNC,
	)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := file.Write([]byte(content)); err != nil {
		file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
}

func readRootFile(t *testing.T, root sec_fs.ISecRoot, path string) string {
	t.Helper()
	file, err := root.OpenFile(sec_fs.RelativeViewPath(path), os.O_RDONLY)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	buffer := make([]byte, 64)
	n, err := file.Read(buffer)
	if err != nil && n == 0 {
		t.Fatal(err)
	}
	return string(buffer[:n])
}
