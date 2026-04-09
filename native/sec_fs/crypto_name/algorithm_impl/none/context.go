// Package none provides a no-op name encryption implementation.
// This package implements INameCryptorContext without any encryption,
// simply returning the original names unchanged.
package none

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)

// Context implements INameCryptorContext without encryption.
type Context struct{}

// NewContext creates a new no-op encryption context for names.
// This implementation ignores keyInfo and cfg as no encryption is performed.
func NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	return &Context{}, nil
}

// EncryptName returns the name unchanged.
func (c *Context) EncryptName(name string) (string, error) {
	return name, nil
}

// DecryptName returns the encrypted name unchanged.
func (c *Context) DecryptName(encrypted string) (string, error) {
	return encrypted, nil
}

// Compile-time interface verification
var _ crypto_name.INameCryptorContext = (*Context)(nil)
