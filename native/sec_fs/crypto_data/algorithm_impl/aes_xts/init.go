// Package aes_xts provides AES-XTS encryption for disk encryption.
package aes_xts

import "safe_disk/native/sec_fs/crypto_data"

func init() {
	crypto_data.RegisterFactory(NewFactory())
}
