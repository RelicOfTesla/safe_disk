// Package crypto_all provides automatic registration of all cryptographic algorithms.
// Import this package to automatically register all available algorithms.
//
// Usage:
//
//	import _ "safe_disk/native/sec_fs/crypto_all"
//
// This will automatically register:
// - Data encryption: AES-CTR, AES-XTS, ChaCha20, RC4
// - Name encryption: AES-GCM, RC4, none
// - Key derivation: Argon2id, PBKDF2, scrypt, HKDF
package crypto_all

import (
	// Data encryption algorithms
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_xts"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/chacha20"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"

	// Name encryption algorithms
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/none"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/rc4"

	// Key derivation algorithms
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/hkdf"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/pbkdf2"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/scrypt"
)
