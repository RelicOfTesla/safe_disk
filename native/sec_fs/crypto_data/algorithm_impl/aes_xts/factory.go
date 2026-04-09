// Package aes_xts provides AES-XTS encryption for disk encryption.
package aes_xts

import (
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// NewFactory creates a new AES-XTS factory.
func NewFactory() crypto_data.ICryptoDataFactory {
	return &factory{}
}

type factory struct{}

func (f *factory) GetName() string {
	return "aes-xts"
}

func (f *factory) GetCapabilities() crypto_data.CryptorCapabilities {
	return crypto_data.CryptorCapabilities{
		Mode:                   crypto_data.CryptModeNormal,
		StreamingComplexity:    crypto_data.O1,
		RandomAccessComplexity: crypto_data.O1,
		ModificationComplexity: crypto_data.O1,
		RandomDeleteComplexity: crypto_data.O1,
		MemoryOverhead:         crypto_data.O1, // AES-XTS uses constant memory for block-based operations
		RequireMinKeyLength:   64,             // AES-XTS requires two 256-bit keys
	}
}

func (f *factory) GetRequireMinKeyLength() int {
	return 64 // AES-XTS requires two 256-bit keys
}

func (f *factory) NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_data.IDataCryptorContext, error) {
	return NewContext(storeFileIo, keyInfo, cfg)
}
