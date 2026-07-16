// Package aes_gcm_name_test provides tests for AES-256-GCM name encryption.
package aes_gcm_name_test

import (
	"bytes"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

// mockKeyInfo is a mock implementation of IKeyInfo for testing.
type mockKeyInfo struct {
	key []byte
}

func (m *mockKeyInfo) GetKey() []byte {
	return m.key
}

func (m *mockKeyInfo) Destroy() {
	clear(m.key)
	m.key = nil
}

func TestContextCloseDoesNotDestroySourceKey(t *testing.T) {
	keyBytes := []byte("0123456789abcdef0123456789abcdef")
	want := append([]byte(nil), keyBytes...)
	context, err := aes_gcm_name.NewContext(&mockKeyInfo{key: keyBytes}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if err := context.Close(); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(keyBytes, want) {
		t.Fatal("closing name context modified keyInfo-owned bytes")
	}
}

func (m *mockKeyInfo) GetSalt() []byte {
	return nil
}

func TestAESGCMNameFactory(t *testing.T) {
	// Get factory from registry
	factory := crypto_name.GetNameFactory("AES-256-GCM")
	if factory == nil {
		t.Fatal("AES-256-GCM factory not registered")
	}

	// Verify factory name
	if factory.GetName() != "AES-256-GCM" {
		t.Errorf("Expected factory name 'AES-256-GCM', got '%s'", factory.GetName())
	}
}

func TestNameEncryptDecrypt(t *testing.T) {
	factory := aes_gcm_name.NewFactory()

	// Create a 32-byte key
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}

	keyInfo := &mockKeyInfo{key: key}

	// Create config
	cfg := config.NewMemoryConfig()

	// Create context
	ctx, err := factory.NewContext(keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer func() {
		// Close context (clear sensitive data)
		if closer, ok := ctx.(interface{ Close() error }); ok {
			closer.Close()
		}
	}()

	// Test names
	testNames := []string{
		"test.txt",
		"document.pdf",
		"my photo.jpg",
		"重要文件.docx",
		"folder/subfolder/file.txt",
	}

	for _, name := range testNames {
		// Encrypt
		encrypted, err := ctx.EncryptName(name)
		if err != nil {
			t.Errorf("Failed to encrypt name '%s': %v", name, err)
			continue
		}

		// Verify encrypted name is different from original
		if encrypted == name {
			t.Errorf("Encrypted name should be different from original for '%s'", name)
			continue
		}

		// Decrypt
		decrypted, err := ctx.DecryptName(encrypted)
		if err != nil {
			t.Errorf("Failed to decrypt name '%s': %v", encrypted, err)
			continue
		}

		// Verify
		if decrypted != name {
			t.Errorf("Decrypted name doesn't match original")
			t.Errorf("Original: '%s'", name)
			t.Errorf("Decrypted: '%s'", decrypted)
		}
	}
}

func TestEncryptEmptyName(t *testing.T) {
	factory := aes_gcm_name.NewFactory()

	key := make([]byte, 32)
	keyInfo := &mockKeyInfo{key: key}

	// Create config
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer func() {
		// Close context (clear sensitive data)
		if closer, ok := ctx.(interface{ Close() error }); ok {
			closer.Close()
		}
	}()

	// Encrypt empty name
	encrypted, err := ctx.EncryptName("")
	if err != nil {
		t.Errorf("Failed to encrypt empty name: %v", err)
	}

	if encrypted != "" {
		t.Errorf("Encrypted empty name should be empty, got '%s'", encrypted)
	}

	// Decrypt empty name
	decrypted, err := ctx.DecryptName("")
	if err != nil {
		t.Errorf("Failed to decrypt empty name: %v", err)
	}

	if decrypted != "" {
		t.Errorf("Decrypted empty name should be empty, got '%s'", decrypted)
	}
}
