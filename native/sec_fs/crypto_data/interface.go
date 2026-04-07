// Package crypto_data provides cryptographic data processing interfaces and factory registry.
// This package supports multiple encryption algorithms through a registry mechanism.
package crypto_data

import (
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== IReadWriterSeeker Interface ====================

// IReadWriterSeeker combines io.Reader, io.Writer, io.Seeker, and io.Closer interfaces.
// It represents a file-like object that supports reading, writing, seeking, and closing.
type IBaseReadWriterSeeker interface {
	io.Reader
	io.Writer
	io.Seeker
	io.Closer
}

type IFileContext interface {
	IBaseReadWriterSeeker

	// Size returns the current size of the decrypted data.
	Size() int64

	// Truncate changes the size of the decrypted data.
	Truncate(size int64) error

	// Sync commits the current state to stable storage.
	Sync() error
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

// ==================== Complexity Constants ====================

type ComplexityScore int8
// Complexity constants for CryptorCapabilities.
// Lower values indicate better performance.
const (
	// O1 indicates constant time complexity - best performance.
	O1 ComplexityScore = 1
	
	// OLogN indicates logarithmic time complexity - good performance.
	OLogN ComplexityScore = 2
	
	// OSqrtN indicates square root time complexity - moderate performance.
	OSqrtN ComplexityScore = 3
	
	// ON indicates linear time complexity - acceptable for small data.
	ON ComplexityScore = 4
	
	// ONLogN indicates linearithmic time complexity - slower.
	ONLogN ComplexityScore = 5
	
	// ON2 indicates quadratic time complexity - slow, avoid for large data.
	ON2 ComplexityScore = 6
	
	// Unsupported indicates the operation is not implemented.
	Unsupported ComplexityScore = 127
)

// ==================== CryptorCapabilities Structure ====================

// CryptorCapabilities describes the capabilities of a cryptor implementation.
// All algorithms must implement all operations, but with different performance characteristics.
type CryptorCapabilities struct {
	// Mode indicates the encryption mode supported by this cryptor.
	Mode CryptMode

	// StreamingComplexity indicates the complexity of streaming encryption/decryption.
	// O1 = constant time per byte (best for streaming)
	// ON = linear time (must process entire file)
	StreamingComplexity ComplexityScore

	// RandomAccessComplexity indicates the complexity of random access (Seek + Read/Write).
	// O1 = can seek and read/write at any position efficiently
	// ON = must decrypt/encrypt from start to position
	RandomAccessComplexity ComplexityScore

	// ModificationComplexity indicates the complexity of modifying existing data.
	// O1 = can modify in place without re-encryption
	// ON = must re-encrypt entire file
	ModificationComplexity ComplexityScore

	// RandomDeleteComplexity indicates the complexity of deleting data at arbitrary positions.
	// O1 = can delete without re-encryption
	// ON = must re-encrypt entire file
	RandomDeleteComplexity ComplexityScore

	// MaxFileSize indicates the maximum file size supported by this cryptor.
	// A value of 0 means unlimited.
	MaxFileSize int64

	// RecommendedChunkSize indicates the recommended chunk size for chunked mode.
	// A value of 0 means no specific recommendation.
	RecommendedChunkSize int
}

// ==================== IDataCryptorContext Interface ====================

type IBaseDataCryptorContext interface {
	IFileContext
	// some method
}

type IFullDataCryptorContext interface {
	IBaseDataCryptorContext
	io.WriterAt
	io.ReaderAt
}

type IDataCryptorContext = IFullDataCryptorContext

// ==================== ICryptoDataFactory Interface ====================

// ICryptoDataFactory defines the interface for creating cryptographic contexts.
// Different encryption algorithms implement this interface to provide their
// specific encryption/decryption capabilities.
type ICryptoDataFactory interface {
	// NewContext creates a new IDataCryptorContext for encrypting/decrypting data.
	// storeFileIo is the underlying storage file I/O interface.
	// keyInfo provides the key information for encryption/decryption.
	// cfg provides algorithm-specific configuration.
	NewContext(storeFileIo IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (IDataCryptorContext, error)

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
func (c *dataCryptorContextImpl) ReadAt(p []byte, off int64) (n int, err error) {
	return 0, nil
}
func (c *dataCryptorContextImpl) WriteAt(p []byte, off int64) (n int, err error) {
	return 0, nil
}

// cryptoDataFactoryImpl is a placeholder type for ICryptoDataFactory implementation.
type cryptoDataFactoryImpl struct{}

func (f *cryptoDataFactoryImpl) NewContext(storeFileIo IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (IDataCryptorContext, error) {
	return nil, nil
}
func (f *cryptoDataFactoryImpl) GetName() string            { return "" }
func (f *cryptoDataFactoryImpl) GetCapabilities() CryptorCapabilities {
	return CryptorCapabilities{}
}
