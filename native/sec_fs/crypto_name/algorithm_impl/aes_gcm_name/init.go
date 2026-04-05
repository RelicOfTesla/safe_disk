// Package aes_gcm_name provides AES-256-GCM encryption implementation for names.
// This file registers the AES-GCM name cryptor in the global registry.
package aes_gcm_name

import (
	"safe_disk/native/sec_fs/crypto_name"
)

func init() {
	// Register AES-GCM as the default name cryptor
	factory := NewFactory()
	crypto_name.RegisterNameFactory(factory)
}
