package sec_fs_test

import (
	"io"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestCloneRootShallowOwnsIndependentSensitiveState(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	password := "clone-close-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		password,
		sec_fs.WithNameFactory("aes-gcm-name"),
	); err != nil {
		t.Fatal(err)
	}
	original, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	file, err := original.OpenFile("payload.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := file.Write([]byte("clone remains usable")); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}

	cloned, err := sec_fs.CloneRootShallow(original)
	if err != nil {
		t.Fatal(err)
	}
	if err := original.Close(); err != nil {
		t.Fatal(err)
	}
	clonedFile, err := cloned.OpenFile("payload.txt", os.O_RDONLY)
	if err != nil {
		t.Fatalf("clone stopped working after original close: %v", err)
	}
	data, err := io.ReadAll(clonedFile)
	_ = clonedFile.Close()
	if err != nil || string(data) != "clone remains usable" {
		t.Fatalf("clone read=%q err=%v", data, err)
	}
	if err := cloned.Close(); err != nil {
		t.Fatal(err)
	}
}
