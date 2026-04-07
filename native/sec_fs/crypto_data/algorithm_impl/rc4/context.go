// Package rc4 provides RC4 stream cipher encryption implementation for data.
package rc4

import (
	"crypto/rc4"
	"io"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// Context implements IDataCryptorContext for RC4 encryption.
type Context struct {
	mu          sync.RWMutex
	storeFileIo crypto_data.IReadWriterSeeker
	key         []byte
	cipher      *rc4.Cipher
	pos         int64
	size        int64
}

// NewContext creates a new RC4 encryption context.
func NewContext(storeFileIo crypto_data.IReadWriterSeeker, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	// Get key from keyInfo
	key := keyInfo.GetKey()
	if len(key) == 0 {
		return nil, io.ErrUnexpectedEOF
	}

	// Create RC4 cipher
	cipher, err := rc4.NewCipher(key)
	if err != nil {
		return nil, err
	}

	// Get file size
	size, err := storeFileIo.Seek(0, io.SeekEnd)
	if err != nil {
		return nil, err
	}

	// Reset position to 0
	_, err = storeFileIo.Seek(0, io.SeekStart)
	if err != nil {
		return nil, err
	}

	return &Context{
		storeFileIo: storeFileIo,
		key:         key,
		cipher:      cipher,
		pos:         0,
		size:        size,
	}, nil
}

// Read reads and decrypts data from the underlying storage.
func (c *Context) Read(p []byte) (n int, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Read encrypted data from underlying storage
	n, err = c.storeFileIo.Read(p)
	if n > 0 {
		// Decrypt data in-place
		c.decryptAt(p[:n], c.pos)
		c.pos += int64(n)
	}

	return n, err
}

// Write encrypts and writes data to the underlying storage.
func (c *Context) Write(p []byte) (n int, err error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Make a copy of data to encrypt
	encrypted := make([]byte, len(p))
	copy(encrypted, p)

	// Encrypt data
	c.encryptAt(encrypted, c.pos)

	// Write encrypted data to underlying storage
	n, err = c.storeFileIo.Write(encrypted)
	if n > 0 {
		c.pos += int64(n)
		if c.pos > c.size {
			c.size = c.pos
		}
	}

	return n, err
}

// Seek sets the position for the next Read or Write.
func (c *Context) Seek(offset int64, whence int) (int64, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Calculate new position
	var newPos int64
	switch whence {
	case io.SeekStart:
		newPos = offset
	case io.SeekCurrent:
		newPos = c.pos + offset
	case io.SeekEnd:
		newPos = c.size + offset
	default:
		return 0, io.ErrUnexpectedEOF
	}

	// Validate position
	if newPos < 0 {
		return 0, io.ErrUnexpectedEOF
	}

	// Seek in underlying storage
	_, err := c.storeFileIo.Seek(newPos, io.SeekStart)
	if err != nil {
		return 0, err
	}

	c.pos = newPos
	return c.pos, nil
}

// Close closes the context and releases resources.
func (c *Context) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Reset cipher
	c.cipher.Reset()

	return c.storeFileIo.Close()
}

// Size returns the current size of the decrypted data.
func (c *Context) Size() int64 {
	c.mu.RLock()
	defer c.mu.RUnlock()

	return c.size
}

// Truncate changes the size of the decrypted data.
func (c *Context) Truncate(size int64) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Truncate underlying storage
	// Note: This is a simplified implementation
	// Real implementation would need to handle encrypted data properly
	c.size = size

	return nil
}

// Sync commits the current state to stable storage.
func (c *Context) Sync() error {
	c.mu.RLock()
	defer c.mu.RUnlock()

	// Sync underlying storage if it supports Sync
	if syncer, ok := c.storeFileIo.(interface{ Sync() error }); ok {
		return syncer.Sync()
	}

	return nil
}

// ==================== RC4 Encryption Helpers ====================

// encryptAt encrypts data at a specific position.
func (c *Context) encryptAt(data []byte, pos int64) {
	// Create a new cipher for this position
	cipher, err := rc4.NewCipher(c.key)
	if err != nil {
		return
	}

	// Generate keystream up to the position
	// Note: This is inefficient for large files
	// A better implementation would use RC4-variant with seek support
	if pos > 0 {
		discard := make([]byte, pos)
		cipher.XORKeyStream(discard, discard)
	}

	// Encrypt data
	cipher.XORKeyStream(data, data)
}

// decryptAt decrypts data at a specific position.
func (c *Context) decryptAt(data []byte, pos int64) {
	// RC4 encryption and decryption are the same operation (XOR)
	c.encryptAt(data, pos)
}

// Compile-time interface verification
var _ crypto_data.IDataCryptorContext = (*Context)(nil)
