// Package rc4 provides RC4 stream cipher encryption implementation for file names.
package rc4

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)

// Factory implements ICryptoNameFactory for RC4.
type Factory struct {
	name string
}

// NewFactory creates a new RC4 factory for name encryption.
func NewFactory() *Factory {
	return &Factory{
		name: "RC4",
	}
}

// NewContext creates a new INameCryptorContext for encrypting/decrypting names.
func (f *Factory) NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_name.INameCryptorContext, error) {
	return NewContext(keyInfo, cfg)
}

// GetName returns the unique name of this cryptor factory.
func (f *Factory) GetName() string {
	return f.name
}

// Compile-time interface verification
var _ crypto_name.ICryptoNameFactory = (*Factory)(nil)
