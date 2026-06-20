// Package argon2 provides Argon2id key derivation implementation.
// Argon2id is the recommended variant for password hashing and key derivation.
package argon2

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"

	"golang.org/x/crypto/argon2"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Factory ====================

// Factory implements crypto_hkdf.IKeyDeriver for Argon2id.
type Factory struct {
	name string
}

// NewFactory creates a new Argon2id factory.
func NewFactory() *Factory {
	return &Factory{
		name: "argon2id",
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
	argon2Cfg := cfg.WithGroup("argon2")

	// Read Argon2-specific config
	saltHex, err := argon2Cfg.GetStr("salt")
	if err != nil {
		return nil, fmt.Errorf("missing salt in config: %w", err)
	}

	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid salt hex: %w", err)
	}

	time, err := argon2Cfg.GetInt("time")
	if err != nil {
		time = 3 // default iterations
	}

	memory, err := argon2Cfg.GetInt("memory")
	if err != nil {
		memory = 64 * 1024 // default: 64 MB
	}

	threads, err := argon2Cfg.GetInt("threads")
	if err != nil {
		threads = 4 // default parallelism
	}

	keyLength, err := argon2Cfg.GetInt("key_length")
	if err != nil {
		keyLength = 32 // default: 256 bits
	}

	// Derive key using Argon2id
	key := argon2.IDKey([]byte(password), salt, uint32(time), uint32(memory), uint8(threads), uint32(keyLength))

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
	var time uint32
	var memory uint32
	var threads uint8

	if params.StaticSalt {
		// Use static salt and static parameters
		salt = []byte(crypto_hkdf.STATIC_SALT)
		time = 3           // static iterations
		memory = 64 * 1024 // static memory: 64 MB
		threads = 4        // static parallelism
	} else {
		// Generate random salt
		saltLength := 16
		salt = make([]byte, saltLength)
		if _, err := rand.Read(salt); err != nil {
			return nil, fmt.Errorf("failed to generate salt: %w", err)
		}

		// Calculate parameters based on KeyStrengthMs
		time = 3
		memory = 64 * 1024 // 64 MB
		threads = 4

		if params.KeyStrengthMs > 0 {
			time = uint32(params.KeyStrengthMs / 100)
			if time < 1 {
				time = 1
			}
			if time > 10 {
				time = 10
			}

			memory = uint32(64*1024 + params.KeyStrengthMs*64)
			if memory > 256*1024 {
				memory = 256 * 1024
			}
		}
	}

	// Derive key using Argon2id
	key := argon2.IDKey([]byte(params.Password), salt, time, memory, threads, uint32(keyLength))

	// Save parameters to config
	if cfg != nil {
		argon2Cfg := cfg.WithGroup("argon2")
		argon2Cfg.SetStr("salt", hex.EncodeToString(salt))
		argon2Cfg.SetInt("time", int(time))
		argon2Cfg.SetInt("memory", int(memory))
		argon2Cfg.SetInt("threads", int(threads))
		argon2Cfg.SetInt("key_length", keyLength)
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
