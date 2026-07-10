package sec_fs

import (
	"errors"
	"fmt"
)

// Common errors for the sec_fs package.
var (
	// ErrInvalidPath indicates that the provided path is invalid or malformed.
	ErrInvalidPath = errors.New("invalid path")

	// ErrPathNotFound indicates that the specified path does not exist.
	ErrPathNotFound = errors.New("path not found")

	// ErrFileNotFound indicates that the specified file does not exist.
	ErrFileNotFound = errors.New("file not found")

	// ErrDirectoryNotFound indicates that the specified directory does not exist.
	ErrDirectoryNotFound = errors.New("directory not found")

	// ErrPermissionDenied indicates insufficient permissions for the operation.
	ErrPermissionDenied = errors.New("permission denied")

	// ErrFileAlreadyExists indicates that the file already exists.
	ErrFileAlreadyExists = errors.New("file already exists")

	// ErrDirectoryAlreadyExists indicates that the directory already exists.
	ErrDirectoryAlreadyExists = errors.New("directory already exists")

	// ErrNotAFile indicates that the path is not a file.
	ErrNotAFile = errors.New("not a file")

	// ErrNotADirectory indicates that the path is not a directory.
	ErrNotADirectory = errors.New("not a directory")

	// ErrFileNotOpen indicates that the file is not open.
	ErrFileNotOpen = errors.New("file is not open")

	// ErrFileClosed indicates that the file is already closed.
	ErrFileClosed = errors.New("file is closed")

	// ErrRootClosed indicates that the root is already closed.
	ErrRootClosed = errors.New("root is closed")

	// ErrRootIsNil is returned when operations are called on a nil root.
	ErrRootIsNil = errors.New("root is nil")

	// ErrPathTraversal is returned when a path attempts to escape the root directory.
	// This can happen when the path contains ".." components that would navigate
	// above the root, or when the path is absolute and points outside the root.
	ErrPathTraversal = errors.New("path traversal attempt detected")

	// ErrInvalidPassword indicates that the provided password is invalid.
	ErrInvalidPassword = errors.New("invalid password")

	// ErrPasswordVerifierMissing indicates that the root predates password
	// authentication and cannot safely validate a supplied password.
	ErrPasswordVerifierMissing = errors.New("password verifier missing")

	// ErrInvalidConfig indicates that the configuration is invalid.
	ErrInvalidConfig = errors.New("invalid configuration")

	// ErrEncryptionFailed indicates that encryption operation failed.
	ErrEncryptionFailed = errors.New("encryption failed")

	// ErrDecryptionFailed indicates that decryption operation failed.
	ErrDecryptionFailed = errors.New("decryption failed")

	// ErrKeyDerivationFailed indicates that key derivation failed.
	ErrKeyDerivationFailed = errors.New("key derivation failed")

	// ErrOperationCanceled indicates that the operation was canceled.
	ErrOperationCanceled = errors.New("operation canceled")

	// ErrUnsupportedOperation indicates that the operation is not supported.
	ErrUnsupportedOperation = errors.New("unsupported operation")

	// ErrBufferTooSmall indicates that the provided buffer is too small.
	ErrBufferTooSmall = errors.New("buffer too small")

	// ErrSeekInvalidOffset indicates an invalid seek offset.
	ErrSeekInvalidOffset = errors.New("invalid seek offset")

	// ErrTruncateFailed indicates that truncate operation failed.
	ErrTruncateFailed = errors.New("truncate failed")

	// ErrSyncFailed indicates that sync operation failed.
	ErrSyncFailed = errors.New("sync failed")

	// ErrWalkerClosed indicates that the directory walker is closed.
	ErrWalkerClosed = errors.New("walker is closed")

	// ErrNotConfigFile indicates that the config file is missing or invalid.
	ErrNotConfigFile = errors.New("config file not found or invalid")

	// ErrNotEncrypted indicates that the file or directory is not encrypted.
	ErrNotEncrypted = errors.New("not an encrypted file or directory")
)

// SimplePathError represents an error related to a specific path operation.
type SimplePathError[T ~string] struct {
	Op   string // The operation that caused the error
	Path T      // The path involved in the error
	Err  error  // The underlying error
}

// Error implements the error interface for PathError.
func (e *SimplePathError[T]) Error() string {
	return fmt.Sprintf("%s %s: %v", e.Op, e.Path, e.Err)
}

// Unwrap returns the underlying error for PathError.
func (e *SimplePathError[T]) Unwrap() error {
	return e.Err
}

// newPathError creates a new PathError with the given operation, path, and underlying error.
func newPathError[T ~string](op string, path T, err error) *SimplePathError[T] {
	return &SimplePathError[T]{
		Op:   op,
		Path: path,
		Err:  err,
	}
}
func NewRelativeViewPathError(op string, path RelativeViewPath, err error) *SimplePathError[RelativeViewPath] {
	return newPathError(op, path, err)
}
func NewFullStorePathError(op string, path FullStorePath, err error) *SimplePathError[FullStorePath] {
	return newPathError(op, path, err)
}

type PairPathError struct {
	SimplePathError[RelativeViewPath]
	StorePath FullStorePath
}

func NewPairPathError(op string, path RelativeViewPath, storePath FullStorePath, err error) *PairPathError {
	return &PairPathError{
		SimplePathError: SimplePathError[RelativeViewPath]{
			Op:   op,
			Path: path,
			Err:  err,
		},
		StorePath: storePath,
	}
}

// Error implements the error interface for PairPathError.
func (e *PairPathError) Error() string {
	return fmt.Sprintf("%s %s -> %s: %v", e.Op, e.Path, e.StorePath, e.Err)
}

// Unwrap returns the underlying error for PairPathError.
func (e *PairPathError) Unwrap() error {
	return e.Err
}

// ConfigError represents an error related to configuration.
type ConfigError struct {
	Field   string // The configuration field that caused the error
	Message string // Additional error message
	Err     error  // The underlying error
}

// Error implements the error interface for ConfigError.
func (e *ConfigError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("config error on field %q: %s: %v", e.Field, e.Message, e.Err)
	}
	return fmt.Sprintf("config error on field %q: %s", e.Field, e.Message)
}

// Unwrap returns the underlying error for ConfigError.
func (e *ConfigError) Unwrap() error {
	return e.Err
}

// NewConfigError creates a new ConfigError.
func NewConfigError(field, message string, err error) *ConfigError {
	return &ConfigError{
		Field:   field,
		Message: message,
		Err:     err,
	}
}

// CryptoError represents an error related to cryptographic operations.
type CryptoError struct {
	Operation string // The cryptographic operation that failed
	Message   string // Additional error message
	Err       error  // The underlying error
}

// Error implements the error interface for CryptoError.
func (e *CryptoError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("crypto error during %s: %s: %v", e.Operation, e.Message, e.Err)
	}
	return fmt.Sprintf("crypto error during %s: %s", e.Operation, e.Message)
}

// Unwrap returns the underlying error for CryptoError.
func (e *CryptoError) Unwrap() error {
	return e.Err
}

// NewCryptoError creates a new CryptoError.
func NewCryptoError(operation, message string, err error) *CryptoError {
	return &CryptoError{
		Operation: operation,
		Message:   message,
		Err:       err,
	}
}
