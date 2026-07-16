package sec_fs_test

import (
	"errors"
	"testing"

	"safe_disk/native/sec_fs"
)

func TestCopyEntryAcrossEncryptedRootsHonorsConflictPolicy(t *testing.T) {
	source := openCopyTestRoot(t, "source-password")
	destination := openCopyTestRoot(t, "destination-password")

	writeRootFile(t, source, "资料/子目录/中文.txt", "source-content")
	writeRootFile(t, destination, "资料/子目录/中文.txt", "old-content")
	writeRootFile(t, destination, "资料/保留.txt", "keep-content")

	err := sec_fs.CopyEntry(source, "资料", destination, "资料", false)
	if !errors.Is(err, sec_fs.ErrFileAlreadyExists) {
		t.Fatalf("copy collision error = %v, want ErrFileAlreadyExists", err)
	}
	if got := readRootFile(t, destination, "资料/子目录/中文.txt"); got != "old-content" {
		t.Fatalf("destination changed without overwrite: %q", got)
	}

	if err := sec_fs.CopyEntry(source, "资料", destination, "资料", true); err != nil {
		t.Fatal(err)
	}
	if got := readRootFile(t, destination, "资料/子目录/中文.txt"); got != "source-content" {
		t.Fatalf("copied content = %q", got)
	}
	if got := readRootFile(t, destination, "资料/保留.txt"); got != "keep-content" {
		t.Fatalf("directory merge removed destination-only file: %q", got)
	}
}

func TestCopyEntryRejectsSelfAndDescendantTargets(t *testing.T) {
	root := openCopyTestRoot(t, "copy-path-password")
	writeRootFile(t, root, "目录/文件.txt", "content")

	if err := sec_fs.CopyEntry(root, "目录/文件.txt", root, "目录/文件.txt", true); !errors.Is(err, sec_fs.ErrFileAlreadyExists) {
		t.Fatalf("same-file copy error = %v, want ErrFileAlreadyExists", err)
	}
	if err := sec_fs.CopyEntry(root, "目录", root, "目录/副本", true); err == nil {
		t.Fatal("copying a directory into itself succeeded")
	}
	for _, destination := range []sec_fs.RelativeViewPath{"../outside", "/absolute"} {
		if err := sec_fs.CopyEntry(root, "目录/文件.txt", root, destination, false); !errors.Is(err, sec_fs.ErrPathTraversal) {
			t.Fatalf("copy destination %q error = %v, want ErrPathTraversal", destination, err)
		}
	}
	if got := readRootFile(t, root, "目录/文件.txt"); got != "content" {
		t.Fatalf("source changed after rejected copies: %q", got)
	}
}

func openCopyTestRoot(t *testing.T, password string) sec_fs.ISecRoot {
	t.Helper()
	rootPath := t.TempDir()
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		password,
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("AES-256-GCM"),
		sec_fs.WithKeyStrengthMs(1),
	); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = root.Close() })
	return root
}
