// Package crypto_name provides cryptographic name processing interfaces and factory registry.
// This package supports multiple encryption algorithms through a registry mechanism.
package crypto_name

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_key"
)

// ==================== INameCryptorContext Interface ====================

// INameCryptorContext defines the interface for a cryptographic context that
// provides encryption/decryption operations for file and directory names.
type INameCryptorContext interface {
	// EncryptName encrypts a file or directory name.
	// Returns the encrypted name or an error.
	EncryptName(name string) (string, error)

	// DecryptName decrypts an encrypted file or directory name.
	// Returns the original name or an error.
	DecryptName(encrypted string) (string, error)
}

// ==================== ICryptoNameFactory Interface ====================

// ICryptoNameFactory defines the interface for creating name cryptographic contexts.
// Different encryption algorithms implement this interface to provide their
// specific name encryption/decryption capabilities.
type ICryptoNameFactory interface {
	// NewContext creates a new INameCryptorContext for encrypting/decrypting names.
	// keyInfo provides the key information for encryption/decryption.
	// cfg provides algorithm-specific configuration.
	NewContext(keyInfo crypto_key.IKeyInfo, cfg config.SharedConfig) (INameCryptorContext, error)

	// GetName returns the unique name of this cryptor factory.
	GetName() string
}

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that implementation types satisfy the interfaces.
var (
	_ INameCryptorContext = (*nameCryptorContextImpl)(nil)
	_ ICryptoNameFactory  = (*cryptoNameFactoryImpl)(nil)
)

// ==================== Placeholder Implementation Types ====================
// These are minimal implementations to satisfy compile-time interface verification.
// The actual implementations will be added in algorithm_impl/ directory.

// nameCryptorContextImpl is a placeholder type for INameCryptorContext implementation.
type nameCryptorContextImpl struct{}

func (c *nameCryptorContextImpl) EncryptName(name string) (string, error) {
	return "", nil
}
func (c *nameCryptorContextImpl) DecryptName(encrypted string) (string, error) {
	return "", nil
}

// cryptoNameFactoryImpl is a placeholder type for ICryptoNameFactory implementation.
type cryptoNameFactoryImpl struct{}

func (f *cryptoNameFactoryImpl) NewContext(keyInfo crypto_key.IKeyInfo, cfg config.SharedConfig) (INameCryptorContext, error) {
	return nil, nil
}
func (f *cryptoNameFactoryImpl) GetName() string { return "" }
