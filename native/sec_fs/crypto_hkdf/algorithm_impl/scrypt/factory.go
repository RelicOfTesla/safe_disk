// Package scrypt provides scrypt key derivation implementation.
// scrypt is a memory-hard password-based key derivation function.
package scrypt

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"

	"golang.org/x/crypto/scrypt"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Factory ====================

// Factory implements crypto_hkdf.IKeyDeriver for scrypt.
type Factory struct {
	name string
}

// NewFactory creates a new scrypt factory.
func NewFactory() *Factory {
	return &Factory{
		name: "scrypt",
	}
}

// NewDeriver returns a key deriver instance for this factory.
func (f *Factory) NewDeriver(cfg config.SharedConfig) (crypto_hkdf.IKeyDeriver, error) {
	return NewFactory(), nil
}

// ==================== IKeyDeriver Interface ====================

// LoadKey loads an existing key from configuration.
func (f *Factory) LoadKey(password string, cfg config.SharedConfig) (crypto_hkdf.IKeyInfo, error) {
	// Create algorithm-specific config namespace
	scryptCfg := cfg.WithGroup("scrypt")

	// Read scrypt-specific config
	saltHex, err := scryptCfg.GetStr("salt")
	if err != nil {
		return nil, fmt.Errorf("missing salt in config: %w", err)
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid salt hex: %w", err)
	}

	N, err := scryptCfg.GetInt("n")
	if err != nil {
		N = 32768 // default CPU/memory cost
	}

	r, err := scryptCfg.GetInt("r")
	if err != nil {
		r = 8 // default block size
	}

	p, err := scryptCfg.GetInt("p")
	if err != nil {
		p = 1 // default parallelization
	}

	keyLength, err := scryptCfg.GetInt("key_length")
	if err != nil {
		keyLength = 32 // default: 256 bits
	}

	// Derive key using scrypt
	key, err := scrypt.Key([]byte(password), salt, N, r, p, keyLength)
	if err != nil {
		return nil, fmt.Errorf("scrypt key derivation failed: %w", err)
	}

	return &keyInfo{
		key: key,
	}, nil
}

// NewKey creates a new key with the given parameters.
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

	// Determine salt and parameters
	var salt []byte
	var N int
	var r int
	var p int

	if params.StaticSalt {
		// Use static salt and static parameters
		salt = []byte(crypto_hkdf.STATIC_SALT)
		N = 32768 // static CPU/memory cost
		r = 8     // static block size
		p = 1     // static parallelization
	} else {
		// Generate random salt
		saltLength := 16
		salt = make([]byte, saltLength)
		if _, err := rand.Read(salt); err != nil {
			return nil, fmt.Errorf("failed to generate salt: %w", err)
		}

		// Calculate parameters based on KeyStrengthMs
		N = 32768
		r = 8
		p = 1

		if params.KeyStrengthMs > 0 {
			N = 16384
			if params.KeyStrengthMs > 100 {
				N = 32768
			}
			if params.KeyStrengthMs > 500 {
				N = 65536
			}
			if params.KeyStrengthMs > 1000 {
				N = 131072
			}
		}
	}

	// Derive key using scrypt
	key, err := scrypt.Key([]byte(params.Password), salt, N, r, p, keyLength)
	if err != nil {
		return nil, fmt.Errorf("scrypt key derivation failed: %w", err)
	}

	// Save parameters to config
	if cfg != nil {
		scryptCfg := cfg.WithGroup("scrypt")
		scryptCfg.SetStr("salt", hex.EncodeToString(salt))
		scryptCfg.SetInt("n", N)
		scryptCfg.SetInt("r", r)
		scryptCfg.SetInt("p", p)
		scryptCfg.SetInt("key_length", keyLength)
	}

	return &keyInfo{
		key: key,
	}, nil
}

// GetName returns the unique name of this key deriver.
func (f *Factory) GetName() string {
	return f.name
}

// ==================== KeyInfo Implementation ====================

type keyInfo struct {
	key []byte
}

func (k *keyInfo) GetKey() []byte { return k.key }

// ==================== Compile-time Interface Verification ====================

var _ crypto_hkdf.IKeyDeriver = (*Factory)(nil)
var _ crypto_hkdf.IDeriverFactory = (*Factory)(nil)
var _ crypto_hkdf.IKeyInfo = (*keyInfo)(nil)
