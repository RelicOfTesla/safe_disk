package sec_fs_test

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestRootOperationsRejectPathsOutsideRoot(t *testing.T) {
	for _, nameFactory := range []string{"none", "aes-gcm-name"} {
		t.Run(nameFactory, func(t *testing.T) {
			tmp := t.TempDir()
			rootPath := filepath.Join(tmp, "root")
			root, err := createPathSecurityRoot(rootPath, nameFactory)
			if err != nil {
				t.Fatal(err)
			}
			defer root.Close()

			outsideFile := filepath.Join(tmp, "outside.txt")
			outsideDir := filepath.Join(tmp, "outside-dir")
			paths := []sec_fs.RelativeViewPath{
				"../outside.txt",
				"nested/../../outside.txt",
				sec_fs.RelativeViewPath(outsideFile),
			}
			for _, path := range paths {
				t.Run("open_"+filepath.Base(string(path)), func(t *testing.T) {
					file, err := root.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
					if file != nil {
						_ = file.Close()
					}
					assertPathTraversal(t, err)
				})
			}

			assertPathTraversal(t, root.MkdirAll("../outside-dir"))
			assertPathTraversal(t, root.DeleteFile("../outside.txt"))
			if root.FileExists("../outside.txt") {
				t.Fatal("FileExists accepted a path outside root")
			}
			_, err = root.GetStorePath("../outside.txt")
			assertPathTraversal(t, err)
			_, err = root.Stat("../outside.txt")
			assertPathTraversal(t, err)
			_, err = root.ReadDir("../outside-dir")
			assertPathTraversal(t, err)
			walker, err := root.WalkDir("../outside-dir")
			if walker != nil {
				_ = walker.Close()
			}
			assertPathTraversal(t, err)

			inside, err := root.OpenFile("inside.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
			if err != nil {
				t.Fatal(err)
			}
			if err := inside.Close(); err != nil {
				t.Fatal(err)
			}
			assertPathTraversal(t, root.Rename("inside.txt", "../outside.txt"))
			insideStorePath, err := root.GetStorePath("inside.txt")
			if err != nil {
				t.Fatal(err)
			}
			assertPathTraversal(t, root.RenameByStorePath(insideStorePath, "../outside-store.txt"))

			for _, path := range []string{outsideFile, outsideDir, filepath.Join(tmp, "outside-store.txt")} {
				if _, err := os.Stat(path); !os.IsNotExist(err) {
					t.Fatalf("operation escaped root and created %s", path)
				}
			}
		})
	}
}

func TestPlainFSOperationsRejectPathsOutsideRoot(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "plain-root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.NewPlainFS(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	file, err := root.OpenFile("../plain-escape.txt", os.O_CREATE|os.O_WRONLY)
	if file != nil {
		_ = file.Close()
	}
	assertPathTraversal(t, err)
	assertPathTraversal(t, root.MkdirAll("../plain-escape-dir"))
	assertPathTraversal(t, root.DeleteFile("../plain-escape.txt"))
	if root.FileExists("../plain-escape.txt") {
		t.Fatal("PlainFS FileExists accepted a path outside root")
	}
	_, err = root.GetStorePath("../plain-escape.txt")
	assertPathTraversal(t, err)
	_, err = root.Stat("../plain-escape.txt")
	assertPathTraversal(t, err)
	_, err = root.ReadDir("../plain-escape-dir")
	assertPathTraversal(t, err)
	walker, err := root.WalkDir("../plain-escape-dir")
	if walker != nil {
		_ = walker.Close()
	}
	assertPathTraversal(t, err)

	inside, err := root.OpenFile("inside.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	if err := inside.Close(); err != nil {
		t.Fatal(err)
	}
	assertPathTraversal(t, root.Rename("inside.txt", "../plain-rename.txt"))
	assertPathTraversal(t, root.RenameByStorePath("inside.txt", "../plain-store-rename.txt"))

	for _, name := range []string{"plain-escape.txt", "plain-escape-dir", "plain-rename.txt", "plain-store-rename.txt"} {
		if _, err := os.Stat(filepath.Join(tmp, name)); !os.IsNotExist(err) {
			t.Fatalf("PlainFS operation escaped root and created %s", name)
		}
	}
}

func TestRootOperationsAllowNormalizedPathsInsideRoot(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	root, err := createPathSecurityRoot(rootPath, "aes-gcm-name")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	file, err := root.OpenFile("a/../inside.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatalf("normalized in-root path was rejected: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if _, err := root.Stat("inside.txt"); err != nil {
		t.Fatalf("normalized file is not accessible: %v", err)
	}
}

func createPathSecurityRoot(rootPath, nameFactory string) (sec_fs.ISecRoot, error) {
	_, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		"path-security-password",
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory(nameFactory),
		sec_fs.WithKeyStrengthMs(1),
	)
	if err != nil {
		return nil, err
	}
	return sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "path-security-password")
}

func assertPathTraversal(t *testing.T, err error) {
	t.Helper()
	if !errors.Is(err, sec_fs.ErrPathTraversal) {
		t.Fatalf("expected ErrPathTraversal, got %v", err)
	}
}
