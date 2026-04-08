// Package chacha20 provides ChaCha20 stream cipher encryption.
package chacha20

import "safe_disk/native/sec_fs/crypto_data"

func init() {
	crypto_data.RegisterFactory(NewFactory())
}
