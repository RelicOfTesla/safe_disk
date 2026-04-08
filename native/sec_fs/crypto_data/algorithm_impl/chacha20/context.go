// Package chacha20 provides ChaCha20 stream cipher encryption.
package chacha20

import (
	"io"

	"golang.org/x/crypto/chacha20"
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// Context implements IDataCryptorContext for ChaCha20 encryption.
type Context struct {
	storeFileIo crypto_data.IFileContext
	key         []byte
	nonce       []byte
	pos         int64
	size        int64
}

// NewContext creates a new ChaCha20 encryption context.
func NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) < 32 {
		return nil, io.ErrUnexpectedEOF
	}

	// Use zero nonce for simplicity (in production, should derive from keyInfo or config)
	nonce := make([]byte, 12)

	size, err := storeFileIo.Seek(0, io.SeekEnd)
	if err != nil {
		return nil, err
	}

	_, err = storeFileIo.Seek(0, io.SeekStart)
	if err != nil {
		return nil, err
	}

	return &Context{
		storeFileIo: storeFileIo,
		key:         key[:32],
		nonce:       nonce,
		pos:         0,
		size:        size,
	}, nil
}

// Read reads and decrypts data.
func (c *Context) Read(p []byte) (n int, err error) {
	n, err = c.storeFileIo.Read(p)
	if n > 0 {
		c.xorKeystream(p[:n], c.pos)
		c.pos += int64(n)
	}
	return n, err
}

// Write encrypts and writes data.
func (c *Context) Write(p []byte) (n int, err error) {
	if err := c.ensure_append_gap(c.pos); err != nil {
		return 0, err
	}

	encrypted := make([]byte, len(p))
	copy(encrypted, p)
	c.xorKeystream(encrypted, c.pos)

	c.storeFileIo.Seek(c.pos, io.SeekStart)
	n, err = c.storeFileIo.Write(encrypted)
	if n > 0 {
		c.pos += int64(n)
		if c.pos > c.size {
			c.size = c.pos
		}
	}
	return n, err
}

// Seek sets position.
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

// Close closes context.
func (c *Context) Close() error {
	return c.storeFileIo.Close()
}

// Size returns size.
func (c *Context) Size() int64 {
	return c.size
}

// Truncate changes size.
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

// Sync syncs.
func (c *Context) Sync() error {
	return c.storeFileIo.Sync()
}

// xorKeystream XORs data with keystream at position.
func (c *Context) xorKeystream(data []byte, pos int64) {
	cipher, err := chacha20.NewUnauthenticatedCipher(c.key, c.nonce)
	if err != nil {
		return
	}

	// ChaCha20 has 64-byte blocks
	blockSize := int64(64)
	blockNum := pos / blockSize
	blockOffset := pos % blockSize

	// Set counter to block number
	cipher.SetCounter(uint32(blockNum))

	// Discard bytes within block
	if blockOffset > 0 {
		discard := make([]byte, blockOffset)
		cipher.XORKeyStream(discard, discard)
	}

	// XOR data
	cipher.XORKeyStream(data, data)
}

// ensure_append_gap fills gap with encrypted zeros.
func (c *Context) ensure_append_gap(targetPos int64) error {
	if targetPos <= c.size {
		return nil
	}

	gapSize := targetPos - c.size
	gapZeros := make([]byte, gapSize)
	c.xorKeystream(gapZeros, c.size)

	_, err := c.storeFileIo.Seek(c.size, io.SeekStart)
	if err != nil {
		return err
	}

	_, err = c.storeFileIo.Write(gapZeros)
	if err != nil {
		return err
	}

	c.size = targetPos
	return nil
}

// ReadAt reads at offset.
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
		c.xorKeystream(p[:n], off)
	}
	return n, err
}

// WriteAt writes at offset.
func (c *Context) WriteAt(p []byte, off int64) (n int, err error) {
	if err := c.ensure_append_gap(off); err != nil {
		return 0, err
	}

	encrypted := make([]byte, len(p))
	copy(encrypted, p)
	c.xorKeystream(encrypted, off)

	if writerAt, ok := c.storeFileIo.(io.WriterAt); ok {
		n, err = writerAt.WriteAt(encrypted, off)
	} else {
		_, err = c.storeFileIo.Seek(off, io.SeekStart)
		if err != nil {
			return 0, err
		}
		n, err = c.storeFileIo.Write(encrypted)
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
