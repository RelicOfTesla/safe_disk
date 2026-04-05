// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains CGO export functions that can be called from C.
//
// To use these exports, compile with CGO enabled:
//   go build -buildmode=c-shared -o libffi_sec_fs.so
package main

import (
	"C"  // Required for c-shared builds
)

// Required for -buildmode=c-shared: dummy main function
func main() {}
