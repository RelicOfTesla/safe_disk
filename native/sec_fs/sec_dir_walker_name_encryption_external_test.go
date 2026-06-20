package sec_fs_test

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

func TestSecDirWalker_EncryptedDirectoryNames(t *testing.T) {
	rootPath := t.TempDir()
	password := "walker-name-encryption-password"
	_, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		password,
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
		sec_fs.WithDeriverFactory("argon2id"),
	)
	require.NoError(t, err)
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	require.NoError(t, err)
	defer root.Close()

	err = root.MkdirAll("目录/子目录")
	require.NoError(t, err)
	file, err := root.OpenFile("目录/子目录/文件.txt", os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	require.NoError(t, err)
	_, err = file.Write([]byte("walker encrypted names"))
	require.NoError(t, err)
	require.NoError(t, file.Close())

	walker, err := root.WalkDir("", sec_fs.WithRecursive())
	require.NoError(t, err)
	defer walker.Close()

	seen := map[string]bool{}
	for {
		entry, err := walker.Next()
		if errors.Is(err, io.EOF) {
			break
		}
		require.NoError(t, err)
		seen[string(entry.GetRelativeViewPath())] = true
	}
	assert.True(t, seen["目录"], "walker should expose decrypted directory name")
	assert.True(t, seen["目录/子目录"], "walker should expose decrypted nested directory name")
	assert.True(t, seen["目录/子目录/文件.txt"], "walker should expose decrypted file name")
	assert.False(t, containsDiskEntryName(t, rootPath, "目录"), "plain directory name must not exist on disk")
	assert.False(t, containsDiskEntryName(t, rootPath, "文件.txt"), "plain file name must not exist on disk")
}

func containsDiskEntryName(t *testing.T, rootPath string, name string) bool {
	t.Helper()
	found := false
	err := filepath.WalkDir(rootPath, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.Name() == name {
			found = true
		}
		return nil
	})
	require.NoError(t, err)
	return found
}
