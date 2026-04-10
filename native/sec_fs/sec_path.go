// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains path types and path encryption/decryption functions.
package sec_fs

import (
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/sec_utils"
)

// ==================== Path Types ====================

// RelativeViewPath represents a relative path from the user's perspective within RootDir.
// This is the path that users interact with when navigating the encrypted file system.
// Example: "documents/report.pdf"
type RelativeViewPath string

// FullViewPath represents a complete absolute path from the user's perspective.
// This includes the full path to a file or directory within the view layer.
// Example: "/data/safe_disk_root/documents/report.pdf"
type FullViewPath string

// RelativeStorePath represents a relative path from the storage perspective.
// This path reflects the actual stored file name, which may be encrypted or in plain text.
// Example: "a1b2c3d4e5f6..." (encrypted file name)
type RelativeStorePath string

// FullStorePath represents a complete absolute path from the storage perspective.
// This is the actual path on disk where the encrypted or unencrypted data is stored.
// Example: "/data/safe_disk_root/a1b2c3d4e5f6..."
type FullStorePath string

// String returns the string representation of RelativeViewPath.
func (p RelativeViewPath) String() string {
	return string(p)
}

// String returns the string representation of FullViewPath.
func (p FullViewPath) String() string {
	return string(p)
}

// String returns the string representation of RelativeStorePath.
func (p RelativeStorePath) String() string {
	return string(p)
}

// String returns the string representation of FullStorePath.
func (p FullStorePath) String() string {
	return string(p)
}

// IsEmpty returns true if the RelativeViewPath is empty.
func (p RelativeViewPath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the FullViewPath is empty.
func (p FullViewPath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the RelativeStorePath is empty.
func (p RelativeStorePath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the FullStorePath is empty.
func (p FullStorePath) IsEmpty() bool {
	return string(p) == ""
}

// ==================== Path Encryption/Decryption ====================

// ViewPathToStorePath converts a view path (plain text) to a store path (encrypted).
// Each path component is encrypted separately using the provided nameCryptor.
// Special components (empty, ".", "..") are preserved without encryption.
//
// This function handles:
//   - Unix (/) and Windows (\) path separators
//   - Any URI prefix (scheme://, scheme:///, scheme:/)
//   - UNC paths (\\server\share\path)
//   - Windows drive letters (C:\, d:\)
//
// Parameters:
//   - viewPath: The view path to convert (plain text)
//   - nameCryptor: The name encryptor to use. If nil, the path is returned unchanged.
//
// Returns:
//   - The encrypted store path
//   - An error if encryption fails
func ViewPathToStorePath(viewPath RelativeViewPath, nameCryptor crypto_name.INameCryptorContext) (RelativeStorePath, error) {
	if nameCryptor == nil {
		// No encryption configured, return path as-is
		return RelativeStorePath(viewPath), nil
	}

	// Parse path using ParsePathInfo (cleans the path automatically)
	info, err := sec_utils.ParsePathInfo(string(viewPath))
	if err != nil {
		return "", err
	}

	encryptedParts := make([]string, 0, len(info.Parts()))
	for _, part := range info.Parts() {
		// Skip empty parts, current directory, and parent directory
		if part == "" || part == "." || part == ".." {
			encryptedParts = append(encryptedParts, part)
			continue
		}

		// Encrypt the path component
		encrypted, err := nameCryptor.EncryptName(part)
		if err != nil {
			return "", NewPathCryptoError("name_encrypt", "failed to encrypt path component: "+part, err)
		}
		encryptedParts = append(encryptedParts, encrypted)
	}

	// Create new PathInfo with encrypted parts and encode
	result := info.ReplaceParts(encryptedParts).Encode()
	return RelativeStorePath(result), nil
}

// StorePathToViewPath converts a store path (encrypted) to a view path (plain text).
// Each path component is decrypted separately using the provided nameCryptor.
// Special components (empty, ".", "..") are preserved without decryption.
//
// This function handles:
//   - Unix (/) and Windows (\) path separators
//   - Any URI prefix (scheme://, scheme:///, scheme:/)
//   - UNC paths (\\server\share\path)
//   - Windows drive letters (C:\, d:\)
//
// Parameters:
//   - storePath: The store path to convert (encrypted)
//   - nameCryptor: The name decryptor to use. If nil, the path is returned unchanged.
//
// Returns:
//   - The decrypted view path
//   - An error if decryption fails
func StorePathToViewPath(storePath RelativeStorePath, nameCryptor crypto_name.INameCryptorContext) (RelativeViewPath, error) {
	if nameCryptor == nil {
		// No encryption configured, return path as-is
		return RelativeViewPath(storePath), nil
	}

	// Parse path using ParsePathInfo (cleans the path automatically)
	info, err := sec_utils.ParsePathInfo(string(storePath))
	if err != nil {
		return "", err
	}

	decryptedParts := make([]string, 0, len(info.Parts()))
	for _, part := range info.Parts() {
		// Skip empty parts, current directory, and parent directory
		if part == "" || part == "." || part == ".." {
			decryptedParts = append(decryptedParts, part)
			continue
		}

		// Decrypt the path component
		decrypted, err := nameCryptor.DecryptName(part)
		if err != nil {
			return "", NewPathCryptoError("name_decrypt", "failed to decrypt path component: "+part, err)
		}
		decryptedParts = append(decryptedParts, decrypted)
	}

	// Create new PathInfo with decrypted parts and encode
	result := info.ReplaceParts(decryptedParts).Encode()
	return RelativeViewPath(result), nil
}

// ==================== Path Crypto Error ====================

// PathCryptoError represents an error during path encryption/decryption.
type PathCryptoError struct {
	Operation string
	Message   string
	Cause     error
}

// Error implements the error interface.
func (e *PathCryptoError) Error() string {
	if e.Cause != nil {
		return e.Operation + ": " + e.Message + ": " + e.Cause.Error()
	}
	return e.Operation + ": " + e.Message
}

// Unwrap returns the underlying cause of the error.
func (e *PathCryptoError) Unwrap() error {
	return e.Cause
}

// NewPathCryptoError creates a new PathCryptoError.
func NewPathCryptoError(operation, message string, err error) *PathCryptoError {
	return &PathCryptoError{
		Operation: operation,
		Message:   message,
		Cause:     err,
	}
}
