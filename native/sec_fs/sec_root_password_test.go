package sec_fs_test

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestOpenRootQuickAuthenticatesPasswordForEveryKeyDeriver(t *testing.T) {
	for _, deriver := range []string{"Argon2id", "HKDF-SHA-256", "PBKDF2", "scrypt"} {
		t.Run(deriver, func(t *testing.T) {
			rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
			const password = "correct-password"

			cfg, _, err := sec_fs.CreateRootConfigQuick(
				rootPath,
				password,
				sec_fs.WithDeriverFactory(deriver),
				sec_fs.WithDataFactory("AES-CTR"),
				sec_fs.WithNameFactory("AES-256-GCM"),
				sec_fs.WithKeyStrengthMs(1),
			)
			require.NoError(t, err)
			secondCfg, _, err := sec_fs.CreateRootConfigQuick(
				sec_fs.FullStorePath(filepath.Join(t.TempDir(), "second-root")),
				password,
				sec_fs.WithDeriverFactory(deriver),
				sec_fs.WithDataFactory("AES-CTR"),
				sec_fs.WithNameFactory("AES-256-GCM"),
				sec_fs.WithKeyStrengthMs(1),
			)
			require.NoError(t, err)
			group := deriver
			switch deriver {
			case "Argon2id":
				group = "argon2"
			case "HKDF-SHA-256":
				group = "hkdf"
			case "PBKDF2":
				group = "pbkdf2"
			}
			storedDeriver, err := cfg.GetStr("sec_deriver_factory")
			require.NoError(t, err)
			require.Equal(t, deriver, storedDeriver)
			firstSalt, err := cfg.WithGroup(group).GetStr("salt")
			require.NoError(t, err)
			secondSalt, err := secondCfg.WithGroup(group).GetStr("salt")
			require.NoError(t, err)
			require.NotEqual(t, firstSalt, secondSalt, "new roots must use independent salts")

			wrongRoot, err := sec_fs.OpenRootQuick(rootPath, "wrong-password")
			require.Nil(t, wrongRoot)
			require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)

			root, err := sec_fs.OpenRootQuick(rootPath, password)
			require.NoError(t, err)
			require.NoError(t, root.Close())
		})
	}
}

func TestCreateRootConfigQuickUsesExplicitSecureDefaults(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	cfg, _, err := sec_fs.CreateRootConfigQuick(rootPath, "default-password", sec_fs.WithKeyStrengthMs(1))
	require.NoError(t, err)

	dataFactory, err := cfg.GetStr("sec_fs_factory")
	require.NoError(t, err)
	require.Equal(t, sec_fs.DefaultDataFactoryName, dataFactory)
	nameFactory, err := cfg.GetStr("sec_name_factory")
	require.NoError(t, err)
	require.Equal(t, sec_fs.DefaultNameFactoryName, nameFactory)
	deriverFactory, err := cfg.GetStr("sec_deriver_factory")
	require.NoError(t, err)
	require.Equal(t, sec_fs.DefaultDeriverFactoryName, deriverFactory)
}

func TestRootPasswordHintLifecycle(t *testing.T) {
	for _, passwordChangeable := range []bool{false, true} {
		t.Run(map[bool]string{false: "legacy", true: "changeable"}[passwordChangeable], func(t *testing.T) {
			rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
			const password = "correct-password"
			_, _, err := sec_fs.CreateRootConfigQuick(
				rootPath,
				password,
				sec_fs.WithKeyStrengthMs(1),
				sec_fs.WithPasswordChangeable(passwordChangeable),
				sec_fs.WithPasswordHint("stored safely in public metadata"),
			)
			require.NoError(t, err)

			hint, err := sec_fs.ReadRootPasswordHint(rootPath)
			require.NoError(t, err)
			require.Equal(t, "stored safely in public metadata", hint)

			err = sec_fs.UpdateRootPasswordHintQuick(rootPath, "wrong-password", "must not replace")
			require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)
			hint, err = sec_fs.ReadRootPasswordHint(rootPath)
			require.NoError(t, err)
			require.Equal(t, "stored safely in public metadata", hint)

			err = sec_fs.UpdateRootPasswordHintQuick(rootPath, password, strings.Repeat("a", 257))
			require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
			err = sec_fs.UpdateRootPasswordHintQuick(rootPath, password, string([]byte{0xff}))
			require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
			hint, err = sec_fs.ReadRootPasswordHint(rootPath)
			require.NoError(t, err)
			require.Equal(t, "stored safely in public metadata", hint)

			require.NoError(t, sec_fs.UpdateRootPasswordHintQuick(rootPath, password, ""))
			hint, err = sec_fs.ReadRootPasswordHint(rootPath)
			require.NoError(t, err)
			require.Empty(t, hint)

			root, err := sec_fs.OpenRootQuick(rootPath, password)
			require.NoError(t, err)
			require.NoError(t, root.Close())
			wrongRoot, err := sec_fs.OpenRootQuick(rootPath, "wrong-password")
			require.Nil(t, wrongRoot)
			require.ErrorIs(t, err, sec_fs.ErrInvalidPassword)
		})
	}
}

func TestCreateRootPasswordHintValidationAndAbsentDefault(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	_, _, err := sec_fs.CreateRootConfigQuick(rootPath, "password", sec_fs.WithKeyStrengthMs(1))
	require.NoError(t, err)
	hint, err := sec_fs.ReadRootPasswordHint(rootPath)
	require.NoError(t, err)
	require.Empty(t, hint)

	invalidPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "invalid"))
	_, _, err = sec_fs.CreateRootConfigQuick(
		invalidPath,
		"password",
		sec_fs.WithPasswordHint(string([]byte{0xff})),
	)
	require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
	_, statErr := os.Stat(string(invalidPath))
	require.True(t, os.IsNotExist(statErr), "invalid hint must fail before creating a root")
}

func TestOpenRootQuickRejectsRootWithoutPasswordVerifier(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	const password = "correct-password"
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		password,
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
	)
	require.NoError(t, err)

	configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
	raw, err := os.ReadFile(configPath)
	require.NoError(t, err)
	var values map[string]any
	require.NoError(t, json.Unmarshal(raw, &values))
	delete(values, "sec_password_verifier_version")
	delete(values, "sec_password_verifier_challenge")
	delete(values, "sec_password_verifier_tag")
	raw, err = json.Marshal(values)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(configPath, raw, 0600))

	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.Nil(t, root)
	require.True(t, errors.Is(err, sec_fs.ErrPasswordVerifierMissing), "unexpected error: %v", err)
}

func TestOpenRootQuickRejectsCorruptPasswordVerifier(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
	const password = "correct-password"
	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		password,
		sec_fs.WithDeriverFactory("PBKDF2"),
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("None"),
	)
	require.NoError(t, err)

	configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
	raw, err := os.ReadFile(configPath)
	require.NoError(t, err)
	var values map[string]any
	require.NoError(t, json.Unmarshal(raw, &values))
	values["sec_password_verifier_tag"] = "not-base64"
	raw, err = json.Marshal(values)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(configPath, raw, 0600))

	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.Nil(t, root)
	require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
}

func TestOpenRootQuickRejectsMissingOrUnknownFactories(t *testing.T) {
	tests := []struct {
		name  string
		field string
		value any
	}{
		{name: "missing data factory", field: "sec_fs_factory"},
		{name: "unknown data factory", field: "sec_fs_factory", value: "unknown-data"},
		{name: "missing name factory", field: "sec_name_factory"},
		{name: "unknown name factory", field: "sec_name_factory", value: "unknown-name"},
		{name: "missing key deriver", field: "sec_deriver_factory"},
		{name: "unknown key deriver", field: "sec_deriver_factory", value: "unknown-deriver"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "root"))
			_, _, err := sec_fs.CreateRootConfigQuick(
				rootPath,
				"password",
				sec_fs.WithDeriverFactory("PBKDF2"),
				sec_fs.WithDataFactory("AES-CTR"),
				sec_fs.WithNameFactory("None"),
			)
			require.NoError(t, err)

			configPath := filepath.Join(string(rootPath), sec_fs.ConfigFileName)
			raw, err := os.ReadFile(configPath)
			require.NoError(t, err)
			var values map[string]any
			require.NoError(t, json.Unmarshal(raw, &values))
			if tt.value == nil {
				delete(values, tt.field)
			} else {
				values[tt.field] = tt.value
			}
			raw, err = json.Marshal(values)
			require.NoError(t, err)
			require.NoError(t, os.WriteFile(configPath, raw, 0600))

			root, err := sec_fs.OpenRootQuick(rootPath, "password")
			require.Nil(t, root)
			require.ErrorIs(t, err, sec_fs.ErrInvalidConfig)
		})
	}
}
