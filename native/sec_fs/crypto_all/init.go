// Package crypto_all provides automatic registration of all cryptographic algorithms.
// Import this package to automatically register all available algorithms.
//
// Usage:
//
//	import _ "safe_disk/native/sec_fs/crypto_all"
//
// This will automatically register:
// - Data encryption: RC4, AES-GCM
// - Name encryption: RC4, AES-GCM
// - Key derivation: PBKDF2
package crypto_all

import (
	// Data encryption algorithms
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"

	// Name encryption algorithms
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/rc4"

	// Key derivation algorithms
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/scrypt"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/hkdf"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/pbkdf2"
)
