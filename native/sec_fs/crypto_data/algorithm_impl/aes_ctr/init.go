// Package aes_ctr provides AES-CTR stream cipher encryption.
package aes_ctr

import "safe_disk/native/sec_fs/crypto_data"

func init() {
	crypto_data.RegisterFactory(NewFactory())
}
