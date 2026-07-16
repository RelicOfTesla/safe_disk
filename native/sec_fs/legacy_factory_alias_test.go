package sec_fs_test

import (
	"io"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_all"
)

func TestLegacyFactoryAliasesReopenEncryptedRoot(t *testing.T) {
	rootPath := sec_fs.FullStorePath(filepath.Join(t.TempDir(), "legacy-root"))
	const password = "legacy-factory-password"

	_, _, err := sec_fs.CreateRootConfigQuick(
		rootPath,
		password,
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
		sec_fs.WithDeriverFactory("hkdf"),
	)
	if err != nil {
		t.Fatalf("create root with legacy factory names: %v", err)
	}
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	if err != nil {
		t.Fatalf("open newly created legacy root: %v", err)
	}
	file, err := root.OpenFile("旧名称.txt", os.O_CREATE|os.O_RDWR)
	if err != nil {
		t.Fatalf("create encrypted-name file: %v", err)
	}
	if _, err := file.Write([]byte("legacy aliases")); err != nil {
		t.Fatalf("write encrypted-name file: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatalf("close encrypted-name file: %v", err)
	}
	if err := root.Close(); err != nil {
		t.Fatalf("close root: %v", err)
	}

	configBytes, err := os.ReadFile(filepath.Join(string(rootPath), "_cryption.json"))
	if err != nil {
		t.Fatalf("read root config: %v", err)
	}
	for _, legacyName := range []string{"aes-ctr", "aes-gcm-name", "hkdf"} {
		if !containsJSONValue(configBytes, legacyName) {
			t.Fatalf("config no longer preserves legacy name %q: %s", legacyName, configBytes)
		}
	}

	reopened, err := sec_fs.OpenRootQuick(rootPath, password)
	if err != nil {
		t.Fatalf("reopen root with legacy factory names: %v", err)
	}
	defer reopened.Close()
	readFile, err := reopened.Open("旧名称.txt")
	if err != nil {
		t.Fatalf("open encrypted-name file after reopen: %v", err)
	}
	defer readFile.Close()
	data, err := io.ReadAll(readFile)
	if err != nil {
		t.Fatalf("read encrypted-name file after reopen: %v", err)
	}
	if string(data) != "legacy aliases" {
		t.Fatalf("reopened data = %q, want %q", data, "legacy aliases")
	}
}

func containsJSONValue(data []byte, value string) bool {
	quoted := []byte(`"` + value + `"`)
	for index := 0; index+len(quoted) <= len(data); index++ {
		if string(data[index:index+len(quoted)]) == string(quoted) {
			return true
		}
	}
	return false
}
