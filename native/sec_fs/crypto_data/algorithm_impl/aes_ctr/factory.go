// Package aes_ctr provides AES-CTR stream cipher encryption.
package aes_ctr

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// NewFactory creates a new AES-CTR factory.
func NewFactory() crypto_data.ICryptoDataFactory {
	return &factory{}
}

type factory struct{}

func (f *factory) GetName() string {
	return "aes-ctr"
}

func (f *factory) GetCapabilities() crypto_data.CryptorCapabilities {
	return crypto_data.CryptorCapabilities{
		Mode:                   crypto_data.CryptModeNormal,
		StreamingComplexity:    crypto_data.O1,
		RandomAccessComplexity: crypto_data.O1,
		ModificationComplexity: crypto_data.O1,
		RandomDeleteComplexity: crypto_data.O1,
		MemoryOverhead:         crypto_data.O1, // AES-CTR uses constant memory for random access
		RequireMinKeyLength:   32,             // AES-256 requires 256-bit key
	}
}

func (f *factory) GetRequireMinKeyLength() int {
	return 32 // AES-256 requires 256-bit key
}

func (f *factory) NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_data.IDataCryptorContext, error) {
	return NewContext(storeFileIo, keyInfo, cfg)
}
