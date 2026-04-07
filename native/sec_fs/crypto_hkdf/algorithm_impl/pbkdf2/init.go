// Package pbkdf2 provides PBKDF2 key derivation implementation.
// This file registers the PBKDF2 algorithm in the global registry.
package pbkdf2

import (
	"safe_disk/native/sec_fs/crypto_hkdf"
)

func init() {
	// Register PBKDF2 as the default key deriver
	factory := NewFactory()
	crypto_hkdf.RegisterKeyDeriver(factory)
}
