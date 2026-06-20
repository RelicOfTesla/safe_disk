// Package hkdf provides HKDF key derivation implementation.
package hkdf

import "safe_disk/native/sec_fs/crypto_hkdf"

// init registers the HKDF key deriver factory.
func init() {
	factory := NewFactory()
	crypto_hkdf.RegisterKeyDeriver(factory)
	crypto_hkdf.RegisterDeriverFactory(factory)
}
