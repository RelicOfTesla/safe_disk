// Package aes_gcm_name provides AES-256-GCM encryption implementation for names.
package aes_gcm_name

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"encoding/base64"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/internal/utils"
)

// Context implements INameCryptorContext for AES-256-GCM.
type Context struct {
	key []byte
	gcm cipher.AEAD
}

// NewContext creates a new AES-256-GCM context for name encryption.
//
// Expected cfg to be already grouped by caller with cfg.WithGroup("name").
// This method will further group with cfg.WithGroup("AES-256-GCM") to read algorithm-specific config.
// Current implementation only uses IKeyInfo, but config is available for future extensions.
func NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) < 32 {
		return nil, sec_fs.NewCryptoError("new_context", "AES-256 requires at least 32-byte key", nil)
	}

	// Use first 32 bytes for AES-256-GCM
	// Note: If different algorithms need to share the same key, consider using HKDF to derive subkeys
	var aesKey []byte
	if len(key) == 32 {
		aesKey = append([]byte(nil), key...)
	} else {
		// Derive 32-byte key using HKDF-like approach
		// Use SHA-256 to derive the key
		hash := sha256.Sum256(key)
		aesKey = hash[:]
	}

	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return nil, sec_fs.NewCryptoError("new_context", "failed to create AES cipher", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, sec_fs.NewCryptoError("new_context", "failed to create GCM", err)
	}

	return &Context{
		key: aesKey,
		gcm: gcm,
	}, nil
}

// EncryptName encrypts a file or directory name.
// Returns the encrypted name (base64 encoded) or an error.
//
// For filename encryption, we use deterministic IV derived from the filename itself,
// so that the same filename always produces the same encrypted result.
// This is necessary for file path consistency.
// Security analysis: While deterministic IV is generally less secure than random IV,
// for filename encryption, the security impact is limited because:
// 1. Filenames are typically low-entropy and predictable anyway
// 2. The same filename encrypted by different users with different keys will produce different results
// 3. The main security goal is to hide the filename structure, not provide semantic security
func (c *Context) EncryptName(name string) (string, error) {
	if name == "" {
		return "", nil
	}

	plaintext := []byte(name)

	// Derive deterministic IV from filename using SHA-256
	// Use first 12 bytes (GCM nonce size) of the hash as IV
	hash := sha256.Sum256(append(c.key, plaintext...))
	iv := hash[:c.gcm.NonceSize()]

	// Encrypt: IV + ciphertext + tag
	ciphertext := c.gcm.Seal(iv, iv, plaintext, nil)

	// Encode to base64 for safe filename
	encoded := base64.RawURLEncoding.EncodeToString(ciphertext)

	return encoded, nil
}

// DecryptName decrypts an encrypted file or directory name.
// Returns the original name or an error.
func (c *Context) DecryptName(encrypted string) (string, error) {
	if encrypted == "" {
		return "", nil
	}

	// Decode from base64
	ciphertext, err := base64.RawURLEncoding.DecodeString(encrypted)
	if err != nil {
		return "", sec_fs.NewCryptoError("decrypt_name", "failed to decode base64", err)
	}

	if len(ciphertext) < 28 { // IV(12) + Tag(16) minimum
		return "", sec_fs.NewCryptoError("decrypt_name", "encrypted name too short", nil)
	}

	ivSize := c.gcm.NonceSize()
	if len(ciphertext) < ivSize {
		return "", sec_fs.NewCryptoError("decrypt_name", "encrypted name shorter than IV size", nil)
	}

	// Extract IV and ciphertext
	iv := ciphertext[:ivSize]
	ciphertextWithTag := ciphertext[ivSize:]

	// Decrypt
	plaintext, err := c.gcm.Open(nil, iv, ciphertextWithTag, nil)
	if err != nil {
		return "", sec_fs.NewCryptoError("decrypt_name", "authentication failed: wrong key or corrupted data", err)
	}

	return string(plaintext), nil
}

// Close clears sensitive data from memory.
func (c *Context) Close() error {
	utils.MemZero(c.key)
	c.key = nil
	c.gcm = nil
	return nil
}

// Compile-time interface verification
var _ crypto_name.INameCryptorContext = (*Context)(nil)
