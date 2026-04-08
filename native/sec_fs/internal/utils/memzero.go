// Package utils provides common utility functions for the sec_fs package.
package utils

import (
	"runtime"
	"unsafe"
)

// MemZero clears sensitive data from memory securely.
// This function overwrites the byte slice with zeros to prevent
// sensitive data (like encryption keys) from remaining in memory.
func MemZero(b []byte) {
	if b == nil || len(b) == 0 {
		return
	}

	// Overwrite with zeros
	for i := range b {
		b[i] = 0
	}

	// Prevent compiler optimization from removing the zeroing
	runtime.KeepAlive(unsafe.Pointer(&b[0]))
}

// MemZeroMultiple clears multiple byte slices from memory.
func MemZeroMultiple(slices ...[]byte) {
	for _, s := range slices {
		MemZero(s)
	}
}
