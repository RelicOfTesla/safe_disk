// Package rc4 provides RC4 stream cipher encryption implementation for data.
// This file registers the RC4 algorithm in the global registry.
package rc4

import (
	"safe_disk/native/sec_fs/crypto_data"
)

func init() {
	// Register RC4 as a data cryptor
	factory := NewFactory()
	crypto_data.RegisterFactory(factory)
}
