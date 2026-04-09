// Package none provides a no-op name encryption factory.
package none

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)

// Factory implements ICryptoNameFactory for no-op encryption.
type Factory struct{}

// NewFactory creates a new no-op encryption factory.
func NewFactory() *Factory {
	return &Factory{}
}

// NewContext creates a new no-op encryption context.
func (f *Factory) NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_name.INameCryptorContext, error) {
	return NewContext(keyInfo, cfg)
}

// GetName returns the factory name.
func (f *Factory) GetName() string {
	return "none"
}

// Compile-time interface verification
var _ crypto_name.ICryptoNameFactory = (*Factory)(nil)
