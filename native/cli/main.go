package main

import (
	"safe_disk/native/cli/cmd"

	// Keep the current CLI-compatible algorithm set until crypto_all deriver
	// factory registration is fixed.
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/none"

	_ "safe_disk/native/sec_fs/sec_transfer/v3"
)

func main() {
	cmd.Execute()
}
