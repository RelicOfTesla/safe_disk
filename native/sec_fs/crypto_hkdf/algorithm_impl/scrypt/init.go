// Package scrypt provides scrypt key derivation implementation.
package scrypt

import "safe_disk/native/sec_fs/crypto_hkdf"

// init registers the scrypt key deriver.
func init() {
	factory := NewFactory()
	crypto_hkdf.RegisterKeyDeriver(factory)
}
