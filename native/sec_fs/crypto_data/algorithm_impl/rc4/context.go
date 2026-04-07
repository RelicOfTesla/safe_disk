// Package rc4 provides RC4 stream cipher encryption implementation for data.
package rc4

import (
	"crypto/rc4"
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// Context implements IDataCryptorContext for RC4 encryption.
type Context struct {
	storeFileIo crypto_data.IFileContext
	key         []byte
	cipher      *rc4.Cipher
	pos         int64
	size        int64
}

// NewContext creates a new RC4 encryption context.
func NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
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
	// Check if we're writing beyond current file size
	if c.pos > c.size {
		// Fill the gap with encrypted zeros
		gapSize := c.pos - c.size
		gapZeros := make([]byte, gapSize)
		// Encrypt zeros for the gap
		c.encryptAt(gapZeros, c.size)

		// Seek to the old end position
		c.storeFileIo.Seek(c.size, io.SeekStart)

		// Write encrypted zeros for the gap
		_, err = c.storeFileIo.Write(gapZeros)
		if err != nil {
			return 0, err
		}

		// Update size to reflect the gap fill
		c.size = c.pos
	}

	// Make a copy of data to encrypt
	encrypted := make([]byte, len(p))
	copy(encrypted, p)

	// Ensure underlying storage position is at c.pos
	c.storeFileIo.Seek(c.pos, io.SeekStart)

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
	// Reset cipher
	c.cipher.Reset()

	return c.storeFileIo.Close()
}

// Size returns the current size of the decrypted data.
func (c *Context) Size() int64 {
	return c.size
}

// Truncate changes the size of the decrypted data.
func (c *Context) Truncate(size int64) error {
	// Handle shrink: truncate underlying storage
	if size < c.size {
		if truncater, ok := c.storeFileIo.(interface{ Truncate(int64) error }); ok {
			if err := truncater.Truncate(size); err != nil {
				return err
			}
		}
		c.size = size
		return nil
	}

	// Handle expand: extend underlying storage with zeros
	if size > c.size {
		// Save current position
		oldPos := c.pos

		// Seek to end of current data
		c.storeFileIo.Seek(c.size, io.SeekStart)

		// Write zeros to extend the file
		zeros := make([]byte, size-c.size)
		c.encryptAt(zeros, c.size)
		c.storeFileIo.Write(zeros)

		// Restore position
		c.pos = oldPos
		c.size = size
	}

	return nil
}

// Sync commits the current state to stable storage.
func (c *Context) Sync() error {
	return c.storeFileIo.Sync()
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

// ==================== ReadAt/WriteAt Methods ====================

// ReadAt reads and decrypts data at a specific offset.
// It implements io.ReaderAt for random access support.
func (c *Context) ReadAt(p []byte, off int64) (n int, err error) {
	// Save current position
	oldPos := c.pos

	// Seek to the specified offset
	_, err = c.Seek(off, io.SeekStart)
	if err != nil {
		return 0, err
	}

	// Read data
	n, err = c.storeFileIo.Read(p)
	if n > 0 {
		// Decrypt data
		c.decryptAt(p[:n], off)
	}

	// Restore position (both c.pos and underlying storage)
	c.pos = oldPos
	c.storeFileIo.Seek(oldPos, io.SeekStart)

	return n, err
}

// WriteAt encrypts and writes data at a specific offset.
// It implements io.WriterAt for random access support.
func (c *Context) WriteAt(p []byte, off int64) (n int, err error) {
	// Check if we're writing beyond current file size
	if off > c.size {
		// Fill the gap with encrypted zeros
		gapSize := off - c.size
		gapZeros := make([]byte, gapSize)
		// Encrypt zeros for the gap
		c.encryptAt(gapZeros, c.size)
		
		// Write encrypted zeros for the gap at the old end position
		if writerAt, ok := c.storeFileIo.(io.WriterAt); ok {
			_, err = writerAt.WriteAt(gapZeros, c.size)
		} else {
			_, err = c.storeFileIo.Seek(c.size, io.SeekStart)
			if err != nil {
				return 0, err
			}
			_, err = c.storeFileIo.Write(gapZeros)
		}
		if err != nil {
			return 0, err
		}
		c.size = off
	}

	// Make a copy of data to encrypt
	encrypted := make([]byte, len(p))
	copy(encrypted, p)

	// Encrypt data at the specified offset
	c.encryptAt(encrypted, off)

	// Write encrypted data at the specified offset
	if writerAt, ok := c.storeFileIo.(io.WriterAt); ok {
		n, err = writerAt.WriteAt(encrypted, off)
	} else {
		// Fallback: seek and write
		_, err = c.storeFileIo.Seek(off, io.SeekStart)
		if err != nil {
			return 0, err
		}
		n, err = c.storeFileIo.Write(encrypted)
	}

	if n > 0 {
		// Update size if necessary
		newEnd := off + int64(n)
		if newEnd > c.size {
			c.size = newEnd
		}
	}

	return n, err
}

// Compile-time interface verification
var _ crypto_data.IDataCryptorContext = (*Context)(nil)
