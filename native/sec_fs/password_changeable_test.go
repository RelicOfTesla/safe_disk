package sec_fs_test

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestPasswordChangeableRootPreservesContentAndEncryptedNames(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	const oldPassword = "old-password"
	const newPassword = "new-password"
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		oldPassword,
		sec_fs.WithDataFactory("AES-XTS"),
		sec_fs.WithNameFactory("AES-256-GCM"),
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithKeyStrengthMs(1),
		sec_fs.WithPasswordChangeable(true),
	)
	require.NoError(t, err)

	root, err := sec_fs.OpenRootQuick(rootPath, oldPassword)
	require.NoError(t, err)
	require.NoError(t, root.MkdirAll("私密目录"))
	file, err := root.OpenFile("私密目录/笔记.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	require.NoError(t, err)
	_, err = file.Write([]byte("change-password keeps this content"))
	require.NoError(t, err)
	require.NoError(t, file.Close())
	require.NoError(t, root.Close())

	require.NoError(t, sec_fs.ChangeRootPasswordQuick(rootPath, oldPassword, newPassword))

	oldRoot, err := sec_fs.OpenRootQuick(rootPath, oldPassword)
	require.Nil(t, oldRoot)
	require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)

	newRoot, err := sec_fs.OpenRootQuick(rootPath, newPassword)
	require.NoError(t, err)
	defer newRoot.Close()
	opened, err := newRoot.Open("私密目录/笔记.txt")
	require.NoError(t, err)
	defer opened.Close()
	content, err := io.ReadAll(opened)
	require.NoError(t, err)
	require.Equal(t, "change-password keeps this content", string(content))

	entries, err := newRoot.ReadDir("私密目录")
	require.NoError(t, err)
	require.Len(t, entries, 1)
	require.Equal(t, "笔记.txt", entries[0].Name())

	diskEntries, err := os.ReadDir(filepath.Join(string(rootPath)))
	require.NoError(t, err)
	for _, entry := range diskEntries {
		require.NotEqual(t, "私密目录", entry.Name())
	}
}

func TestPasswordChangeableRootRejectsWrongOldPasswordWithoutMutation(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		"old-password",
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithKeyStrengthMs(1),
		sec_fs.WithPasswordChangeable(true),
	)
	require.NoError(t, err)

	err = sec_fs.ChangeRootPasswordQuick(rootPath, "wrong-password", "new-password")
	require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)

	root, err := sec_fs.OpenRootQuick(rootPath, "old-password")
	require.NoError(t, err)
	require.NoError(t, root.Close())
	newRoot, err := sec_fs.OpenRootQuick(rootPath, "new-password")
	require.Nil(t, newRoot)
	require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)
}

func TestLegacyRootRejectsPasswordChange(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		"password",
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithKeyStrengthMs(1),
	)
	require.NoError(t, err)

	err = sec_fs.ChangeRootPasswordQuick(rootPath, "password", "new-password")
	require.True(t, errors.Is(err, sec_fs.ErrPasswordChangeUnsupported), "unexpected error: %v", err)
}

func TestPasswordChangeableRootFailsClosedForCorruptEnvelope(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		"password",
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithKeyStrengthMs(1),
		sec_fs.WithPasswordChangeable(true),
	)
	require.NoError(t, err)

	configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
	raw, err := os.ReadFile(configPath)
	require.NoError(t, err)
	var values map[string]any
	require.NoError(t, json.Unmarshal(raw, &values))
	values["sec_key_envelope_ciphertext"] = "not-base64"
	raw, err = json.Marshal(values)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(configPath, raw, 0o600))

	root, err := sec_fs.OpenRootQuick(rootPath, "password")
	require.Nil(t, root)
	require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
}

func TestPasswordChangeableRootKeepsOldPasswordWhenStagingCannotStart(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		"old-password",
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithKeyStrengthMs(1),
		sec_fs.WithPasswordChangeable(true),
	)
	require.NoError(t, err)

	require.NoError(t, os.Chmod(string(rootPath), 0o500))
	err = sec_fs.ChangeRootPasswordQuick(rootPath, "old-password", "new-password")
	require.Error(t, err)
	require.NoError(t, os.Chmod(string(rootPath), 0o700))

	root, err := sec_fs.OpenRootQuick(rootPath, "old-password")
	require.NoError(t, err)
	require.NoError(t, root.Close())
	newRoot, err := sec_fs.OpenRootQuick(rootPath, "new-password")
	require.Nil(t, newRoot)
	require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)
}

func TestPasswordChangePreservesStoredKDFParameters(t *testing.T) {
	tests := []struct {
		name    string
		deriver string
		prefix  string
	}{
		{name: "argon2id", deriver: "Argon2id", prefix: "argon2_"},
		{name: "scrypt", deriver: "scrypt", prefix: "scrypt_"},
		{name: "pbkdf2", deriver: "PBKDF2", prefix: "pbkdf2_"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
			_, _, err := sec_fs.CreateRootConfigQuick(
				rootPath,
				"old-password",
				sec_fs.WithDataFactory("AES-CTR"),
				sec_fs.WithNameFactory("None"),
				sec_fs.WithDeriverFactory(tt.deriver),
				sec_fs.WithKeyStrengthMs(1),
				sec_fs.WithPasswordChangeable(true),
			)
			require.NoError(t, err)

			configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
			before := readJSONConfig(t, configPath)
			require.NoError(t, sec_fs.ChangeRootPasswordQuick(rootPath, "old-password", "new-password"))
			after := readJSONConfig(t, configPath)

			for key, beforeValue := range before {
				if len(key) >= len(tt.prefix) && key[:len(tt.prefix)] == tt.prefix && key != tt.prefix+"salt" {
					require.Equal(t, beforeValue, after[key], "KDF parameter %s changed", key)
				}
			}
			require.NotEqual(t, before[tt.prefix+"salt"], after[tt.prefix+"salt"])

			oldRoot, err := sec_fs.OpenRootQuick(rootPath, "old-password")
			require.Nil(t, oldRoot)
			require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)
			newRoot, err := sec_fs.OpenRootQuick(rootPath, "new-password")
			require.NoError(t, err)
			require.NoError(t, newRoot.Close())
		})
	}
}

func TestPasswordChangeFailsClosedWhenStoredKDFParametersAreMissing(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		"old-password",
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
		sec_fs.WithDeriverFactory("Argon2id"),
		sec_fs.WithKeyStrengthMs(1),
		sec_fs.WithPasswordChangeable(true),
	)
	require.NoError(t, err)

	configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
	values := readJSONConfig(t, configPath)
	delete(values, "argon2_memory")
	corrupt, err := json.Marshal(values)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(configPath, corrupt, 0o600))

	err = sec_fs.ChangeRootPasswordQuick(rootPath, "old-password", "new-password")
	require.Error(t, err)
	unchanged, err := os.ReadFile(configPath)
	require.NoError(t, err)
	require.Equal(t, corrupt, unchanged)
}

func readJSONConfig(t *testing.T, path string) map[string]any {
	t.Helper()
	raw, err := os.ReadFile(path)
	require.NoError(t, err)
	values := map[string]any{}
	require.NoError(t, json.Unmarshal(raw, &values))
	return values
}
