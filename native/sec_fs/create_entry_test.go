package sec_fs_test

import (
	"errors"
	"os"
	"testing"

	"safe_disk/native/sec_fs"
)

func TestCreateEntriesEncryptsNamesAndRejectsCollisions(t *testing.T) {
	root := openCopyTestRoot(t, "create-entry-password")
	if err := sec_fs.CreateDirectory(root, "新目录"); err != nil {
		t.Fatal(err)
	}
	if err := sec_fs.CreateEmptyFile(root, "新目录/空文件.txt"); err != nil {
		t.Fatal(err)
	}
	info, err := root.Stat("新目录/空文件.txt")
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() != 0 {
		t.Fatalf("new file size = %d, want 0", info.Size())
	}

	for _, create := range []func() error{
		func() error { return sec_fs.CreateDirectory(root, "新目录") },
		func() error { return sec_fs.CreateEmptyFile(root, "新目录/空文件.txt") },
	} {
		if err := create(); !errors.Is(err, sec_fs.ErrFileAlreadyExists) && !os.IsExist(err) {
			t.Fatalf("collision error = %v, want existing target error", err)
		}
	}

	entries, err := os.ReadDir(string(root.GetRootPath()))
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if entry.Name() == "新目录" {
			t.Fatal("directory name was stored as plaintext")
		}
	}
}
