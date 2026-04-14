// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains CGO export functions that can be called from C.
//
// To use these exports, compile with CGO enabled:
//
//	go build -buildmode=c-shared -o libffi_sec_fs.so
package main

import (
	"C" // Required for c-shared builds

	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/none"
	_ "safe_disk/native/sec_fs/sec_transfer/v3"
)

// Required for -buildmode=c-shared: dummy main function
func main() {}
