// Package hkdf provides HKDF (HMAC-based Key Derivation Function) implementation.
// HKDF is used to derive sub-keys from an existing key material.
// Note: HKDF is NOT suitable for password hashing. Use PBKDF2, Argon2, or scrypt for passwords.
package hkdf

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"

	"golang.org/x/crypto/hkdf"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Factory ====================

// Factory implements crypto_hkdf.IKeyDeriver for HKDF.
// Note: HKDF expects the "password" to be the input key material (IKM).
// It's designed for deriving sub-keys from an existing key, not for password hashing.
type Factory struct {
	name string
}

// NewFactory creates a new HKDF factory.
func NewFactory() *Factory {
	return &Factory{
		name: "hkdf",
	}
}

// NewDeriver returns a key deriver instance for this factory.
func (f *Factory) NewDeriver(cfg config.SharedConfig) (crypto_hkdf.IKeyDeriver, error) {
	return NewFactory(), nil
}

// ==================== IKeyDeriver Interface ====================

// LoadKey loads an existing key from configuration.
// For HKDF, this reads the salt and derives a key from the IKM (password parameter).
func (f *Factory) LoadKey(password string, cfg config.SharedConfig) (crypto_hkdf.IKeyInfo, error) {
	// Create algorithm-specific config namespace
	hkdfCfg := cfg.WithGroup("hkdf")

	// Read HKDF-specific config
	saltHex, err := hkdfCfg.GetStr("salt")
	if err != nil {
		return nil, fmt.Errorf("missing salt in config: %w", err)
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid salt hex: %w", err)
	}

	keyLength, err := hkdfCfg.GetInt("key_length")
	if err != nil {
		keyLength = 32 // default: 256 bits
	}

	// Derive key using HKDF
	key, err := f.deriveKey([]byte(password), salt, keyLength)
	if err != nil {
		return nil, err
	}

	return &keyInfo{
		key: key,
	}, nil
}

// NewKey creates a new key with the given parameters.
// For HKDF, the "password" field should contain the input key material (IKM).
func (f *Factory) NewKey(params *crypto_hkdf.MakeKeyParams, cfg config.SharedConfig) (crypto_hkdf.IKeyInfo, error) {
	if params == nil {
		return nil, fmt.Errorf("params is nil")
	}

	if params.Password == "" {
		return nil, fmt.Errorf("input key material (password) is empty")
	}

	// Determine key length
	keyLength := params.KeyLength
	if keyLength == 0 {
		keyLength = 32 // default: 256 bits
	}

	// Determine salt
	var salt []byte

	if params.StaticSalt {
		// Use static salt
		salt = []byte(crypto_hkdf.STATIC_SALT)
	} else {
		salt = make([]byte, 16)
		if _, err := rand.Read(salt); err != nil {
			return nil, fmt.Errorf("failed to generate salt: %w", err)
		}
	}

	// Derive key using HKDF
	key, err := f.deriveKey([]byte(params.Password), salt, keyLength)
	if err != nil {
		return nil, err
	}

	// Save parameters to config
	if cfg != nil {
		hkdfCfg := cfg.WithGroup("hkdf")
		hkdfCfg.SetStr("salt", hex.EncodeToString(salt))
		hkdfCfg.SetInt("key_length", keyLength)
	}

	return &keyInfo{
		key: key,
	}, nil
}

// GetName returns the unique name of this key deriver.
func (f *Factory) GetName() string {
	return f.name
}

// ==================== Helper Functions ====================

// deriveKey derives a key using HKDF-SHA256.
func (f *Factory) deriveKey(ikm, salt []byte, keyLength int) ([]byte, error) {
	// Create HKDF reader
	reader := hkdf.New(sha256.New, ikm, salt, nil)

	// Read derived key
	key := make([]byte, keyLength)
	if _, err := io.ReadFull(reader, key); err != nil {
		return nil, fmt.Errorf("HKDF key derivation failed: %w", err)
	}

	return key, nil
}

// ==================== KeyInfo Implementation ====================

type keyInfo struct {
	key []byte
}

func (k *keyInfo) GetKey() []byte { return k.key }
func (k *keyInfo) Destroy()       { crypto_hkdf.ClearKey(k.key); k.key = nil }

// ==================== Compile-time Interface Verification ====================

var _ crypto_hkdf.IKeyDeriver = (*Factory)(nil)
var _ crypto_hkdf.IDeriverFactory = (*Factory)(nil)
var _ crypto_hkdf.IKeyInfo = (*keyInfo)(nil)
