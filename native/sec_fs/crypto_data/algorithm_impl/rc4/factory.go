// Package rc4 provides RC4 stream cipher encryption implementation for data.
package rc4

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// Factory implements ICryptoDataFactory for RC4.
type Factory struct {
	name string
}

// NewFactory creates a new RC4 factory.
func NewFactory() *Factory {
	return &Factory{
		name: "rc4",
	}
}

// NewContext creates a new IDataCryptorContext for encrypting/decrypting data.
func (f *Factory) NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_data.IDataCryptorContext, error) {
	return NewContext(storeFileIo, keyInfo, cfg)
}

// GetName returns the unique name of this cryptor factory.
func (f *Factory) GetName() string {
	return f.name
}

// GetCapabilities returns the capabilities of this cryptor.
func (f *Factory) GetCapabilities() crypto_data.CryptorCapabilities {
	return crypto_data.CryptorCapabilities{
		Mode:                   crypto_data.CryptModeNormal,
		StreamingComplexity:    crypto_data.O1,  // RC4 supports streaming efficiently
		RandomAccessComplexity: crypto_data.ON, // O(N): must generate keystream from position 0 to target
		ModificationComplexity: crypto_data.ON, // O(N): must regenerate keystream after modification point
		RandomDeleteComplexity: crypto_data.O1, // O(1): truncate directly without re-encryption
		MemoryOverhead:         crypto_data.O1, // O(1): fixed-size buffer (64KB) for chunked processing
		MaxFileSize:            0,              // Unlimited
		RecommendedChunkSize:   0,
		RequireMinKeyLength:   1, // RC4 supports variable key length (1-256 bytes)
	}
}

func (f *Factory) GetRequireMinKeyLength() int {
	return 1 // RC4 supports variable key length (1-256 bytes)
}

// Compile-time interface verification
var _ crypto_data.ICryptoDataFactory = (*Factory)(nil)
