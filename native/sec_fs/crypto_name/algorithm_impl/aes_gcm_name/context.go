// Package aes_gcm_name provides AES-256-GCM encryption implementation for names.
package aes_gcm_name

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"io"

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
// This method will further group with cfg.WithGroup("aes-gcm-name") to read algorithm-specific config.
// Current implementation only uses IKeyInfo, but config is available for future extensions.
func NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) != 32 {
		return nil, sec_fs.NewCryptoError("new_context", "AES-256 requires 32-byte key", nil)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, sec_fs.NewCryptoError("new_context", "failed to create AES cipher", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, sec_fs.NewCryptoError("new_context", "failed to create GCM", err)
	}

	return &Context{
		key: key,
		gcm: gcm,
	}, nil
}

// EncryptName encrypts a file or directory name.
// Returns the encrypted name (base64 encoded) or an error.
func (c *Context) EncryptName(name string) (string, error) {
	if name == "" {
		return "", nil
	}

	plaintext := []byte(name)

	// Generate random IV
	iv := make([]byte, c.gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return "", sec_fs.NewCryptoError("encrypt_name", "failed to generate IV", err)
	}

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
