// Package pbkdf2 provides PBKDF2 key derivation implementation.
package pbkdf2

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"

	"golang.org/x/crypto/pbkdf2"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Factory ====================

// Factory implements crypto_hkdf.IKeyDeriver for PBKDF2.
type Factory struct {
	name string
}

// NewFactory creates a new PBKDF2 factory.
func NewFactory() *Factory {
	return &Factory{
		name: "pbkdf2",
	}
}

// NewDeriver returns a key deriver instance for this factory.
func (f *Factory) NewDeriver(cfg config.SharedConfig) (crypto_hkdf.IKeyDeriver, error) {
	return NewFactory(), nil
}

// ==================== IKeyDeriver Interface ====================

// LoadKey loads an existing key from configuration.
// Used when opening an existing encrypted root.
//
// Expected cfg to be already prefixed with "key_" by caller.
// This method will further prefix with "pbkdf2_" to read PBKDF2-specific config.
// Final config keys: "key_pbkdf2_salt", "key_pbkdf2_iterations", "key_pbkdf2_key_length".
func (f *Factory) LoadKey(password string, cfg config.SharedConfig) (crypto_hkdf.IKeyInfo, error) {
	// Create algorithm-specific config namespace
	pbkdf2Cfg := cfg.WithGroup("pbkdf2")

	// Read PBKDF2-specific config
	saltHex, err := pbkdf2Cfg.GetStr("salt")
	if err != nil {
		return nil, fmt.Errorf("missing salt in config: %w", err)
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid salt hex: %w", err)
	}

	iterations, err := pbkdf2Cfg.GetInt("iterations")
	if err != nil {
		iterations = 100000 // default
	}

	keyLength, err := pbkdf2Cfg.GetInt("key_length")
	if err != nil {
		keyLength = 32 // default: 256 bits
	}

	// Derive key using PBKDF2
	key := deriveKey(password, salt, iterations, keyLength)

	return &keyInfo{
		key: key,
	}, nil
}

// NewKey creates a new key with the given parameters.
// Used when creating a new encrypted root.
func (f *Factory) NewKey(params *crypto_hkdf.MakeKeyParams, cfg config.SharedConfig) (crypto_hkdf.IKeyInfo, error) {
	if params == nil {
		return nil, fmt.Errorf("params is nil")
	}

	if params.Password == "" {
		return nil, fmt.Errorf("password is empty")
	}

	// Determine key length
	keyLength := params.KeyLength
	if keyLength == 0 {
		keyLength = 32 // default: 256 bits
	}

	// Determine salt and iterations
	var salt []byte
	var iterations int

	if params.StaticSalt {
		// Use static salt and static iterations
		salt = []byte(crypto_hkdf.STATIC_SALT)
		iterations = 100000 // static iterations
	} else {
		// Generate random salt
		saltLength := 32 // 256 bits
		salt = make([]byte, saltLength)
		if _, err := rand.Read(salt); err != nil {
			return nil, fmt.Errorf("failed to generate salt: %w", err)
		}

		// Calculate iterations based on KeyStrengthMs
		iterations = 100000 // default
		if params.KeyStrengthMs > 0 {
			iterations = 200000
		}
	}

	// Derive key using PBKDF2
	key := deriveKey(params.Password, salt, iterations, keyLength)

	// Save PBKDF2-specific config
	if cfg != nil {
		pbkdf2Cfg := cfg.WithGroup("pbkdf2")
		pbkdf2Cfg.SetStr("salt", hex.EncodeToString(salt))
		pbkdf2Cfg.SetInt("iterations", iterations)
		pbkdf2Cfg.SetInt("key_length", keyLength)
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

// deriveKey derives a key using PBKDF2.
func deriveKey(password string, salt []byte, iterations, keyLength int) []byte {
	return pbkdf2.Key([]byte(password), salt, iterations, keyLength, sha256.New)
}

// ==================== KeyInfo Implementation ====================

// keyInfo implements crypto_hkdf.IKeyInfo.
type keyInfo struct {
	key []byte
}

func (k *keyInfo) GetKey() []byte { return k.key }
func (k *keyInfo) Destroy()       { crypto_hkdf.ClearKey(k.key); k.key = nil }

// ==================== Compile-time Interface Verification ====================

var _ crypto_hkdf.IKeyDeriver = (*Factory)(nil)
var _ crypto_hkdf.IDeriverFactory = (*Factory)(nil)
var _ crypto_hkdf.IKeyInfo = (*keyInfo)(nil)
