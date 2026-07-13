package sec_fs_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

func TestOpenFileStatReportsDecryptedSizeAndStoreMetadata(t *testing.T) {
	rootPath := t.TempDir()
	const password = "file-stat-password"
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

	const viewPath = sec_fs.RelativeViewPath("目录/文件.txt")
	if err := root.MkdirAll("目录"); err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile(viewPath, os.O_CREATE|os.O_RDWR|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	payload := []byte("decrypted-size")
	if _, err := file.Write(payload); err != nil {
		t.Fatal(err)
	}

	storePath, err := root.GetStorePath(viewPath)
	if err != nil {
		t.Fatal(err)
	}
	fullStorePath := filepath.Join(rootPath, filepath.FromSlash(string(storePath)))
	wantTime := time.Unix(1_700_000_000, 0)
	if err := os.Chmod(fullStorePath, 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(fullStorePath, wantTime, wantTime); err != nil {
		t.Fatal(err)
	}
	storeInfo, err := os.Stat(fullStorePath)
	if err != nil {
		t.Fatal(err)
	}

	info, err := file.Stat()
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() != int64(len(payload)) {
		t.Fatalf("view size = %d, want %d", info.Size(), len(payload))
	}
	if info.Mode() != storeInfo.Mode() {
		t.Fatalf("mode = %v, want store mode %v", info.Mode(), storeInfo.Mode())
	}
	if !info.ModTime().Equal(storeInfo.ModTime()) {
		t.Fatalf("mtime = %s, want store mtime %s", info.ModTime(), storeInfo.ModTime())
	}
	if plus, ok := file.(sec_fs.ISecFilePlus); !ok || plus.Mode() != storeInfo.Mode() {
		t.Fatalf("ISecFilePlus.Mode did not report current store mode")
	}
}

func TestOpenFileStatSurvivesStoreRename(t *testing.T) {
	rootPath := t.TempDir()
	const password = "file-stat-rename-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath), password,
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
	file, err := root.OpenFile("before.txt", os.O_CREATE|os.O_RDWR|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if _, err := file.Write([]byte("content")); err != nil {
		t.Fatal(err)
	}
	if err := root.Rename("before.txt", "after.txt"); err != nil {
		t.Fatal(err)
	}
	info, err := file.Stat()
	if err != nil {
		t.Fatalf("stat on renamed open file failed: %v", err)
	}
	if info.Size() != int64(len("content")) {
		t.Fatalf("renamed open file size = %d", info.Size())
	}
}
