// Package aes_gcm_name provides AES-256-GCM encryption implementation for names.
package aes_gcm_name

import (
	"safe_disk/native/sec_fs/crypto_name"
)

// Factory implements ICryptoNameFactory for AES-256-GCM.
type Factory struct {
	name string
}

// NewFactory creates a new AES-256-GCM name cryptor factory.
func NewFactory() *Factory {
	return &Factory{
		name: "aes-gcm-name",
	}
}

// NewContext creates a new INameCryptorContext for encrypting/decrypting names.
func (f *Factory) NewContext(keyInfo crypto_name.IKeyInfo) (crypto_name.INameCryptorContext, error) {
	return NewContext(keyInfo)
}

// GetName returns the unique name of this cryptor factory.
func (f *Factory) GetName() string {
	return f.name
}

// Compile-time interface verification
var _ crypto_name.ICryptoNameFactory = (*Factory)(nil)
