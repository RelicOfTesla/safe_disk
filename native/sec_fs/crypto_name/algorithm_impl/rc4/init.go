// Package rc4 provides RC4 stream cipher encryption implementation for file names.
// This file registers the RC4 algorithm in the global registry.
package rc4

import (
	"safe_disk/native/sec_fs/crypto_name"
)

func init() {
	// Register RC4 as a name cryptor
	factory := NewFactory()
	crypto_name.RegisterNameFactory(factory)
}
