// Package crypto_hkdf provides key derivation interfaces and factory registry.
// This package supports multiple key derivation algorithms through a registry mechanism.
package crypto_hkdf

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/internal/utils"
)

// ==================== MakeKeyParams ====================

// MakeKeyParams defines the parameters for creating a new key.
type MakeKeyParams struct {
	// Password is the user-provided password for key derivation.
	Password string

	// KeyStrengthMs is the target key derivation time in milliseconds.
	// Higher values mean stronger security but slower performance.
	// Ignored when StaticSalt is true.
	KeyStrengthMs int

	// StaticSalt indicates whether to use static parameters for deterministic key derivation.
	// When true:
	//   - Salt: uses crypto_hkdf.STATIC_SALT
	//   - Iterations/cost/other params: algorithm-specific static values
	// When false:
	//   - Salt: randomly generated
	//   - Other params: derived from KeyStrengthMs
	StaticSalt bool

	// KeyLength is the target key length in bytes.
	// Common values: 16 (AES-128), 24 (AES-192), 32 (AES-256).
	// If not specified (0), defaults to 32 (AES-256).
	KeyLength int
}

const STATIC_SALT = "SafeDisk"

// ==================== IKeyInfo Interface ====================

// IKeyInfo defines the interface for key information.
// It provides access to the derived cryptographic key.
type IKeyInfo interface {
	// GetKey returns the derived cryptographic key.
	GetKey() []byte
	// Destroy overwrites the owned key bytes and releases the reference.
	Destroy()
}

// ClearKey overwrites a derived key owned by an IKeyInfo implementation.
func ClearKey(key []byte) { utils.MemZero(key) }

// NewKeyInfoCopy creates independently owned key material for a new lifecycle.
func NewKeyInfoCopy(key []byte) IKeyInfo {
	return &keyInfoImpl{key: append([]byte(nil), key...)}
}

// ==================== IKeyDeriver Interface ====================

// IKeyDeriver defines the interface for key derivation operations.
// It supports loading existing keys and creating new keys.
//
// Note: This interface only handles key derivation.
// Password verification (challengeId) should be done by the caller
// using crypto_data package.
type IKeyDeriver interface {
	// LoadKey loads an existing key from configuration.
	// Used when opening an existing encrypted root.
	LoadKey(password string, cfg config.SharedConfig) (IKeyInfo, error)

	// NewKey creates a new key with the given parameters.
	// Used when creating a new encrypted root.
	NewKey(params *MakeKeyParams, cfg config.SharedConfig) (IKeyInfo, error)

	// GetName returns the unique name of this key deriver.
	GetName() string
}

// ==================== IDeriverFactory Interface ====================

// IDeriverFactory defines the interface for creating key derivers.
// It follows the same factory pattern as crypto_data.ICryptoDataFactory
// and crypto_name.ICryptoNameFactory.
type IDeriverFactory interface {
	// NewDeriver creates a new IKeyDeriver instance.
	// cfg provides algorithm-specific configuration.
	NewDeriver(cfg config.SharedConfig) (IKeyDeriver, error)

	// GetName returns the unique name of this deriver factory.
	GetName() string
}

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that implementation types satisfy the interfaces.
var (
	_ IKeyInfo    = (*keyInfoImpl)(nil)
	_ IKeyDeriver = (*keyDeriverImpl)(nil)
)

// ==================== Placeholder Implementation Types ====================
// These are minimal implementations to satisfy compile-time interface verification.
// The actual implementations will be added in algorithm_impl/ directory.

// keyInfoImpl is a placeholder type for IKeyInfo implementation.
type keyInfoImpl struct {
	key []byte
}

func (k *keyInfoImpl) GetKey() []byte { return k.key }
func (k *keyInfoImpl) Destroy()       { ClearKey(k.key); k.key = nil }

// keyDeriverImpl is a placeholder type for IKeyDeriver implementation.
type keyDeriverImpl struct{}

func (d *keyDeriverImpl) LoadKey(password string, cfg config.SharedConfig) (IKeyInfo, error) {
	return nil, nil
}

func (d *keyDeriverImpl) NewKey(params *MakeKeyParams, cfg config.SharedConfig) (IKeyInfo, error) {
	return nil, nil
}

func (d *keyDeriverImpl) GetName() string {
	return ""
}
