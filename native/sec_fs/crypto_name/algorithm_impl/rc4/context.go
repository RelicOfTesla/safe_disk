// Package rc4 provides RC4 stream cipher encryption implementation for file names.
package rc4

import (
	"crypto/rc4"
	"encoding/base64"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/internal/utils"
)

// Context implements INameCryptorContext for RC4 encryption.
type Context struct {
	key    []byte
	cipher *rc4.Cipher
}

// NewContext creates a new RC4 encryption context for names.
func NewContext(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	// Get key from keyInfo
	key := keyInfo.GetKey()
	if len(key) == 0 {
		return nil, ErrEmptyKey
	}

	ownedKey := append([]byte(nil), key...)
	// Create RC4 cipher
	cipher, err := rc4.NewCipher(ownedKey)
	if err != nil {
		return nil, err
	}

	return &Context{
		key:    ownedKey,
		cipher: cipher,
	}, nil
}

// EncryptName encrypts a file or directory name.
// Returns the encrypted name (RC4 + Base64) or an error.
func (c *Context) EncryptName(name string) (string, error) {
	if name == "" {
		return "", nil
	}

	// Convert name to bytes
	data := []byte(name)

	// Encrypt with RC4
	encrypted := make([]byte, len(data))
	copy(encrypted, data)

	// Reset cipher for each encryption
	cipher, err := rc4.NewCipher(c.key)
	if err != nil {
		return "", err
	}
	cipher.XORKeyStream(encrypted, encrypted)

	// Encode to Base64 (URL-safe to avoid "/" in filename)
	encoded := base64.RawURLEncoding.EncodeToString(encrypted)

	return encoded, nil
}

// DecryptName decrypts an encrypted file or directory name.
// Returns the original name or an error.
func (c *Context) DecryptName(encrypted string) (string, error) {
	if encrypted == "" {
		return "", nil
	}

	// Decode from Base64 (URL-safe)
	data, err := base64.RawURLEncoding.DecodeString(encrypted)
	if err != nil {
		return "", err
	}

	// Decrypt with RC4
	decrypted := make([]byte, len(data))
	copy(decrypted, data)

	// Reset cipher for each decryption
	cipher, err := rc4.NewCipher(c.key)
	if err != nil {
		return "", err
	}
	cipher.XORKeyStream(decrypted, decrypted)

	return string(decrypted), nil
}

func (c *Context) Close() error {
	utils.MemZero(c.key)
	c.key = nil
	c.cipher = nil
	return nil
}

// Compile-time interface verification
var _ crypto_name.INameCryptorContext = (*Context)(nil)
