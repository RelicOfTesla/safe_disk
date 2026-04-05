// Package crypto_name provides cryptographic name processing interfaces and factory registry.
// This package supports multiple encryption algorithms through a registry mechanism.
package crypto_name

// ==================== IKeyInfo Interface ====================

// IKeyInfo provides key information for encryption/decryption operations.
// Note: This interface is also defined in crypto_data package.
// In future refactoring, this will be unified in crypto_key package.
type IKeyInfo interface {
	// GetKey returns the encryption key.
	GetKey() []byte

	// GetSalt returns the salt used for key derivation.
	GetSalt() []byte

	// GetInitConfig returns the initialization configuration.
	// The returned value is implementation-specific and may be nil.
	GetInitConfig() any
}

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
	NewContext(keyInfo IKeyInfo) (INameCryptorContext, error)

	// GetName returns the unique name of this cryptor factory.
	GetName() string
}

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that implementation types satisfy the interfaces.
var (
	_ IKeyInfo            = (*keyInfoImpl)(nil)
	_ INameCryptorContext = (*nameCryptorContextImpl)(nil)
	_ ICryptoNameFactory  = (*cryptoNameFactoryImpl)(nil)
)

// ==================== Placeholder Implementation Types ====================
// These are minimal implementations to satisfy compile-time interface verification.
// The actual implementations will be added in future tasks.

// keyInfoImpl is a placeholder type for IKeyInfo implementation.
type keyInfoImpl struct{}

func (k *keyInfoImpl) GetKey() []byte     { return nil }
func (k *keyInfoImpl) GetSalt() []byte    { return nil }
func (k *keyInfoImpl) GetInitConfig() any { return nil }

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

func (f *cryptoNameFactoryImpl) NewContext(keyInfo IKeyInfo) (INameCryptorContext, error) {
	return nil, nil
}
func (f *cryptoNameFactoryImpl) GetName() string { return "" }
