// Package rc4 provides RC4 stream cipher encryption implementation for data.
package rc4

import (
	"crypto/rc4"
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_data/crypt_utils"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// CipherState encapsulates RC4 cipher and its current position.
// This allows tracking the cipher state for sequential operations.
type CipherState struct {
	cipher *rc4.Cipher
	pos    int64
}

// NewCipherState creates a new CipherState with the given key.
func NewCipherState(key []byte) (*CipherState, error) {
	cipher, err := rc4.NewCipher(key)
	if err != nil {
		return nil, err
	}
	return &CipherState{
		cipher: cipher,
		pos:    0,
	}, nil
}

// EncryptAt encrypts data at a specific position.
// If pos equals current position, reuses cipher to avoid recalculating.
// Uses chunked discarding for position mismatch to avoid large allocations.
func (cs *CipherState) EncryptAt(data []byte, pos int64, key []byte) {
	if pos == cs.pos {
		// Reuse cipher - already at correct position
		cs.cipher.XORKeyStream(data, data)
		cs.pos += int64(len(data))
		return
	}

	// Position mismatch - create new cipher and discard to target
	cipher, err := rc4.NewCipher(key)
	if err != nil {
		return
	}

	if pos > 0 {
		// Discard bytes in chunks to reach target position
		discardBuf := make([]byte, crypt_utils.GapFillBufferSize)
		remaining := pos

		for remaining > 0 {
			chunkSize := remaining
			if chunkSize > int64(len(discardBuf)) {
				chunkSize = int64(len(discardBuf))
			}

			cipher.XORKeyStream(discardBuf[:chunkSize], discardBuf[:chunkSize])
			remaining -= chunkSize
		}
	}

	cipher.XORKeyStream(data, data)
}

// DecryptAt decrypts data at a specific position.
// For RC4, decryption is the same as encryption.
func (cs *CipherState) DecryptAt(data []byte, pos int64, key []byte) {
	cs.EncryptAt(data, pos, key)
}

// Reset resets the cipher state to initial state.
func (cs *CipherState) Reset() {
	cs.cipher.Reset()
	cs.pos = 0
}

// GetPos returns the current position.
func (cs *CipherState) GetPos() int64 {
	return cs.pos
}

// Context implements IDataCryptorContext for RC4 encryption.
type Context struct {
	storeFileIo     crypto_data.IFileContext
	key             []byte
	lastReadCipher  *CipherState  // Cached cipher state for read operations
	lastWriteCipher *CipherState  // Cached cipher state for write operations
	pos             int64         // Current file position
	size            int64
}

// NewContext creates a new RC4 encryption context.
func NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) == 0 {
		return nil, io.ErrUnexpectedEOF
	}

	lastReadCipher, err := NewCipherState(key)
	if err != nil {
		return nil, err
	}

	lastWriteCipher, err := NewCipherState(key)
	if err != nil {
		return nil, err
	}

	size, err := storeFileIo.Seek(0, io.SeekEnd)
	if err != nil {
		return nil, err
	}

	_, err = storeFileIo.Seek(0, io.SeekStart)
	if err != nil {
		return nil, err
	}

	return &Context{
		storeFileIo:     storeFileIo,
		key:             key,
		lastReadCipher:  lastReadCipher,
		lastWriteCipher: lastWriteCipher,
		pos:             0,
		size:            size,
	}, nil
}

// Read reads and decrypts data from the underlying storage.
func (c *Context) Read(p []byte) (n int, err error) {
	n, err = c.storeFileIo.Read(p)
	if n > 0 {
		c.decryptAt(p[:n], c.pos)
		c.pos += int64(n)
	}
	return n, err
}

// Write encrypts and writes data to the underlying storage.
// Uses chunked processing to avoid allocating large buffers.
func (c *Context) Write(p []byte) (n int, err error) {
	if err := c.ensure_append_gap(c.pos); err != nil {
		return 0, err
	}

	c.storeFileIo.Seek(c.pos, io.SeekStart)
	n, err = crypt_utils.EncryptAndWriteInChunks(c.storeFileIo, p, c.pos, c.encryptAt)
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

	if newPos < 0 {
		return 0, io.ErrUnexpectedEOF
	}

	_, err := c.storeFileIo.Seek(newPos, io.SeekStart)
	if err != nil {
		return 0, err
	}

	c.pos = newPos
	return c.pos, nil
}

// Close closes the context and releases resources.
func (c *Context) Close() error {
	c.lastReadCipher.Reset()
	c.lastWriteCipher.Reset()
	return c.storeFileIo.Close()
}

// Size returns the current size of the decrypted data.
func (c *Context) Size() int64 {
	return c.size
}

// Truncate changes the size of the decrypted data.
func (c *Context) Truncate(size int64) error {
	if size > c.size {
		if err := c.ensure_append_gap(size); err != nil {
			return err
		}
	} else if size < c.size {
		if truncater, ok := c.storeFileIo.(interface{ Truncate(int64) error }); ok {
			if err := truncater.Truncate(size); err != nil {
				return err
			}
		}
	}

	c.size = size
	if c.pos > size {
		c.pos = size
	}
	return nil
}

// Sync commits the current state to stable storage.
func (c *Context) Sync() error {
	return c.storeFileIo.Sync()
}

// encryptAt encrypts data at a specific position.
// Uses lastWriteCipher for encryption, reusing cipher state when possible.
func (c *Context) encryptAt(data []byte, pos int64) {
	c.lastWriteCipher.EncryptAt(data, pos, c.key)
}

// decryptAt decrypts data at a specific position.
// Uses lastReadCipher for decryption, reusing cipher state when possible.
func (c *Context) decryptAt(data []byte, pos int64) {
	c.lastReadCipher.DecryptAt(data, pos, c.key)
}

// ensure_append_gap fills the gap between current size and target position with encrypted zeros.
// Uses chunked writing to avoid allocating the entire gap size at once.
func (c *Context) ensure_append_gap(targetPos int64) error {
	if targetPos <= c.size {
		return nil
	}

	gapSize := targetPos - c.size

	_, err := c.storeFileIo.Seek(c.size, io.SeekStart)
	if err != nil {
		return err
	}

	// Use chunked filling to avoid large memory allocation
	err = crypt_utils.FillGapWithEncryptFunc(c.storeFileIo, c.size, gapSize, func(data []byte, pos int64) error {
		c.encryptAt(data, pos)
		return nil
	})
	if err != nil {
		return err
	}

	c.size = targetPos
	return nil
}

// ReadAt reads and decrypts data at a specific offset.
func (c *Context) ReadAt(p []byte, off int64) (n int, err error) {
	if readerAt, ok := c.storeFileIo.(io.ReaderAt); ok {
		n, err = readerAt.ReadAt(p, off)
	} else {
		_, err = c.storeFileIo.Seek(off, io.SeekStart)
		if err != nil {
			return 0, err
		}
		n, err = c.storeFileIo.Read(p)
	}

	if n > 0 {
		c.decryptAt(p[:n], off)
	}
	return n, err
}

// WriteAt encrypts and writes data at a specific offset.
// Uses chunked processing to avoid allocating large buffers.
func (c *Context) WriteAt(p []byte, off int64) (n int, err error) {
	if err := c.ensure_append_gap(off); err != nil {
		return 0, err
	}

	if writerAt, ok := c.storeFileIo.(io.WriterAt); ok {
		n, err = crypt_utils.EncryptAndWriteAtInChunks(writerAt, p, off, c.encryptAt)
	} else {
		_, err = c.storeFileIo.Seek(off, io.SeekStart)
		if err != nil {
			return 0, err
		}
		n, err = crypt_utils.EncryptAndWriteInChunks(c.storeFileIo, p, off, c.encryptAt)
	}

	if n > 0 {
		newEnd := off + int64(n)
		if newEnd > c.size {
			c.size = newEnd
		}
	}
	return n, err
}

var _ crypto_data.IDataCryptorContext = (*Context)(nil)
