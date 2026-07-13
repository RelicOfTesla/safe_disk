//go:build !windows

package sec_fs_test

import (
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

func TestSecureRootCreatesPrivateConfigDirectoriesAndFiles(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	const password = "secure-mode-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath), password,
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
		sec_fs.WithKeyStrengthMs(1),
	); err != nil {
		t.Fatal(err)
	}
	assertPerm(t, rootPath, sec_fs.SecureDirMode)
	assertPerm(t, filepath.Join(rootPath, sec_fs.ConfigFileName), sec_fs.SecureFileMode)

	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	if err := root.MkdirAll("目录/子目录"); err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile("目录/子目录/文件.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	for _, viewPath := range []sec_fs.RelativeViewPath{"目录", "目录/子目录"} {
		storePath, err := root.GetStorePath(viewPath)
		if err != nil {
			t.Fatal(err)
		}
		assertPerm(t, filepath.Join(rootPath, filepath.FromSlash(string(storePath))), sec_fs.SecureDirMode)
	}
	storePath, err := root.GetStorePath("目录/子目录/文件.txt")
	if err != nil {
		t.Fatal(err)
	}
	assertPerm(t, filepath.Join(rootPath, filepath.FromSlash(string(storePath))), sec_fs.SecureFileMode)
}

func TestSecureRootDoesNotChmodExistingRootDirectory(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "existing")
	if err := os.Mkdir(rootPath, 0750); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath), "password",
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
		sec_fs.WithKeyStrengthMs(1),
	); err != nil {
		t.Fatal(err)
	}
	assertPerm(t, rootPath, 0750)
	assertPerm(t, filepath.Join(rootPath, sec_fs.ConfigFileName), sec_fs.SecureFileMode)
}

func assertPerm(t *testing.T, path string, want os.FileMode) {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != want.Perm() {
		t.Fatalf("%s mode = %o, want %o", path, info.Mode().Perm(), want.Perm())
	}
}
