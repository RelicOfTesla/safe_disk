// Package crypto_key_test provides generic tests for key derivation algorithms.
package crypto_hkdf_test

import (
	"testing"

	_ "safe_disk/native/sec_fs/crypto_all" // Import to register all algorithms
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Test: List Registered Algorithms ====================

func TestListKeyDerivers(t *testing.T) {
	names := crypto_hkdf.ListKeyDerivers()
	
	if len(names) == 0 {
		t.Error("No key derivers registered. Import crypto_all to register algorithms.")
	}
	
	t.Logf("Registered key derivers: %v", names)
}

// ==================== Test All Algorithms ====================

func TestAllKeyDerivers(t *testing.T) {
	names := crypto_hkdf.ListKeyDerivers()
	
	if len(names) == 0 {
		t.Fatal("No key derivers registered. Import crypto_all to register algorithms.")
	}
	
	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			runKeyDeriverTests(t, name)
		})
	}
}

// ==================== Generic Test Runner ====================

// runKeyDeriverTests runs all tests for a specific key deriver.
func runKeyDeriverTests(t *testing.T, name string) {
	factory := crypto_hkdf.GetKeyDeriver(name)
	if factory == nil {
		t.Fatalf("Key deriver '%s' not found", name)
	}
	
	t.Run("NewKey_Success", func(t *testing.T) {
		testNewKeySuccess(t, factory)
	})
	
	t.Run("NewKey_EmptyPassword", func(t *testing.T) {
		testNewKeyEmptyPassword(t, factory)
	})
	
	t.Run("LoadKey_CorrectPassword", func(t *testing.T) {
		testLoadKeyCorrectPassword(t, factory)
	})
	
	t.Run("StaticSalt_Deterministic", func(t *testing.T) {
		testStaticSaltDeterministic(t, factory)
	})
}

// ==================== Test Cases ====================

// testNewKeySuccess tests that NewKey creates a valid key.
func testNewKeySuccess(t *testing.T, factory crypto_hkdf.IKeyDeriver) {
	mockCfg := NewMockConfig()
	params := &crypto_hkdf.MakeKeyParams{
		Password:      "test_password",
		KeyStrengthMs: 100,
	}
	
	keyInfo, err := factory.NewKey(params, mockCfg)
	if err != nil {
		t.Fatalf("NewKey failed: %v", err)
	}
	
	if keyInfo == nil {
		t.Fatal("NewKey returned nil keyInfo")
	}
	
	key := keyInfo.GetKey()
	if len(key) == 0 {
		t.Error("NewKey returned empty key")
	}
	
	t.Logf("NewKey success: key length=%d", len(key))
}

// testNewKeyEmptyPassword tests that NewKey fails with empty password.
func testNewKeyEmptyPassword(t *testing.T, factory crypto_hkdf.IKeyDeriver) {
	mockCfg := NewMockConfig()
	params := &crypto_hkdf.MakeKeyParams{
		Password: "",
	}
	
	_, err := factory.NewKey(params, mockCfg)
	if err == nil {
		t.Error("NewKey should fail with empty password")
	}
}

// testLoadKeyCorrectPassword tests that LoadKey works with correct password.
func testLoadKeyCorrectPassword(t *testing.T, factory crypto_hkdf.IKeyDeriver) {
	password := "correct_password"
	
	// First, create a new key
	mockCfg := NewMockConfig()
	params := &crypto_hkdf.MakeKeyParams{
		Password: password,
	}
	
	newKeyInfo, err := factory.NewKey(params, mockCfg)
	if err != nil {
		t.Fatalf("NewKey failed: %v", err)
	}
	
	// Then, load the key with correct password
	loadedKeyInfo, err := factory.LoadKey(password, mockCfg)
	if err != nil {
		t.Fatalf("LoadKey failed with correct password: %v", err)
	}
	
	// Verify keys match
	newKey := newKeyInfo.GetKey()
	loadedKey := loadedKeyInfo.GetKey()
	
	if !equalBytes(newKey, loadedKey) {
		t.Error("Keys don't match: newKey and loadedKey should be identical")
	}
	
	t.Logf("LoadKey success with correct password: key length=%d", len(loadedKey))
}

// ==================== Helper Functions ====================

func equalBytes(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// testStaticSaltDeterministic tests that NewKey produces identical outputs
// when StaticSalt is true.
func testStaticSaltDeterministic(t *testing.T, factory crypto_hkdf.IKeyDeriver) {
	password := "test_password_deterministic"
	
	// Create two separate configs
	mockCfg1 := NewMockConfig()
	mockCfg2 := NewMockConfig()
	
	// Use StaticSalt = true
	params := &crypto_hkdf.MakeKeyParams{
		Password:   password,
		StaticSalt: true,
		KeyLength:  32,
	}
	
	// Call NewKey twice with the same parameters
	keyInfo1, err := factory.NewKey(params, mockCfg1)
	if err != nil {
		t.Fatalf("First NewKey failed: %v", err)
	}
	
	keyInfo2, err := factory.NewKey(params, mockCfg2)
	if err != nil {
		t.Fatalf("Second NewKey failed: %v", err)
	}
	
	// Verify keys are identical
	key1 := keyInfo1.GetKey()
	key2 := keyInfo2.GetKey()
	
	if !equalBytes(key1, key2) {
		t.Errorf("Keys should be identical with StaticSalt=true\nKey1: %x\nKey2: %x", key1, key2)
	}
	
	t.Logf("StaticSalt test passed: key length=%d", len(key1))
}
