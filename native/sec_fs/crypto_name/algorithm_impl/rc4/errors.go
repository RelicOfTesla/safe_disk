// Package rc4 provides RC4 stream cipher encryption implementation for file names.
package rc4

import "errors"

// Errors for RC4 name encryption
var (
	// ErrEmptyKey indicates that the key is empty.
	ErrEmptyKey = errors.New("key is empty")
)
