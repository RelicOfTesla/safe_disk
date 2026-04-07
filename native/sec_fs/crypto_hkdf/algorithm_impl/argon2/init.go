// Package argon2 provides Argon2id key derivation implementation.
package argon2

import "safe_disk/native/sec_fs/crypto_hkdf"

// init registers the Argon2id key deriver.
func init() {
	factory := NewFactory()
	crypto_hkdf.RegisterKeyDeriver(factory)
}
