// Package crypto_data provides cryptographic data processing interfaces and factory registry.
// This package supports multiple encryption algorithms through a registry mechanism.
package crypto_data

import (
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_key"
)

// ==================== IReadWriterSeeker Interface ====================

// IReadWriterSeeker combines io.Reader, io.Writer, io.Seeker, and io.Closer interfaces.
// It represents a file-like object that supports reading, writing, seeking, and closing.
type IReadWriterSeeker interface {
	io.Reader
	io.Writer
	io.Seeker
	io.Closer
}

// ==================== CryptMode Type ====================

// CryptMode defines the encryption mode for the cryptor.
type CryptMode int

const (
	// CryptModeNormal indicates normal encryption mode (default).
	// Suitable for small to medium files with full encryption.
	CryptModeNormal CryptMode = iota

	// CryptModeChunked indicates chunk-based encryption mode.
	// Suitable for large files, encrypts data in chunks for better performance.
	CryptModeChunked

	// CryptModeIncremental indicates incremental encryption mode.
	// Suitable for files that are frequently modified, supports partial updates.
	CryptModeIncremental
)

// String returns the string representation of CryptMode.
func (m CryptMode) String() string {
	switch m {
	case CryptModeNormal:
		return "Normal"
	case CryptModeChunked:
		return "Chunked"
	case CryptModeIncremental:
		return "Incremental"
	default:
		return "Unknown"
	}
}

// ==================== CryptorCapabilities Structure ====================

// CryptorCapabilities describes the capabilities of a cryptor implementation.
type CryptorCapabilities struct {
	// Mode indicates the encryption mode supported by this cryptor.
	Mode CryptMode

	// SupportsStreaming indicates whether the cryptor supports streaming encryption.
	// If true, data can be encrypted/decrypted in a streaming fashion without
	// loading the entire file into memory.
	SupportsStreaming bool

	// SupportsRandomAccess indicates whether the cryptor supports random access
	// to encrypted data. If true, Seek operations can be performed efficiently.
	SupportsRandomAccess bool

	// SupportsModification indicates whether the cryptor supports in-place
	// modification of encrypted data without full re-encryption.
	SupportsModification bool

	// MaxFileSize indicates the maximum file size supported by this cryptor.
	// A value of 0 means unlimited.
	MaxFileSize int64

	// RecommendedChunkSize indicates the recommended chunk size for chunked mode.
	// A value of 0 means no specific recommendation.
	RecommendedChunkSize int
}

// ==================== IDataCryptorContext Interface ====================

// IDataCryptorContext defines the interface for a cryptographic context that
// provides encrypted read/write operations on underlying storage.
type IDataCryptorContext interface {
	IReadWriterSeeker

	// Size returns the current size of the decrypted data.
	Size() int64

	// Truncate changes the size of the decrypted data.
	Truncate(size int64) error

	// Sync commits the current state to stable storage.
	Sync() error
}

// ==================== ICryptoDataFactory Interface ====================

// ICryptoDataFactory defines the interface for creating cryptographic contexts.
// Different encryption algorithms implement this interface to provide their
// specific encryption/decryption capabilities.
type ICryptoDataFactory interface {
	// NewContext creates a new IDataCryptorContext for encrypting/decrypting data.
	// storeFileIo is the underlying storage file I/O interface.
	// keyInfo provides the key information for encryption/decryption.
	// cfg provides algorithm-specific configuration.
	NewContext(storeFileIo IReadWriterSeeker, keyInfo crypto_key.IKeyInfo, cfg config.SharedConfig) (IDataCryptorContext, error)

	// GetName returns the unique name of this cryptor factory.
	GetName() string

	// GetCapabilities returns the capabilities of this cryptor.
	GetCapabilities() CryptorCapabilities
}

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that implementation types satisfy the interfaces.
var (
	_ IDataCryptorContext = (*dataCryptorContextImpl)(nil)
	_ ICryptoDataFactory  = (*cryptoDataFactoryImpl)(nil)
)

// ==================== Placeholder Implementation Types ====================
// These are minimal implementations to satisfy compile-time interface verification.
// The actual implementations will be added in algorithm_impl/ directory.

// dataCryptorContextImpl is a placeholder type for IDataCryptorContext implementation.
type dataCryptorContextImpl struct{}

func (c *dataCryptorContextImpl) Read(p []byte) (n int, err error)  { return 0, nil }
func (c *dataCryptorContextImpl) Write(p []byte) (n int, err error) { return 0, nil }
func (c *dataCryptorContextImpl) Seek(offset int64, whence int) (int64, error) {
	return 0, nil
}
func (c *dataCryptorContextImpl) Close() error          { return nil }
func (c *dataCryptorContextImpl) Size() int64           { return 0 }
func (c *dataCryptorContextImpl) Truncate(size int64) error { return nil }
func (c *dataCryptorContextImpl) Sync() error           { return nil }

// cryptoDataFactoryImpl is a placeholder type for ICryptoDataFactory implementation.
type cryptoDataFactoryImpl struct{}

func (f *cryptoDataFactoryImpl) NewContext(storeFileIo IReadWriterSeeker, keyInfo crypto_key.IKeyInfo, cfg config.SharedConfig) (IDataCryptorContext, error) {
	return nil, nil
}
func (f *cryptoDataFactoryImpl) GetName() string            { return "" }
func (f *cryptoDataFactoryImpl) GetCapabilities() CryptorCapabilities {
	return CryptorCapabilities{}
}
