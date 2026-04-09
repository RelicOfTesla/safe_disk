// Package aes_ctr provides AES-CTR stream cipher encryption.
package aes_ctr

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/subtle"
	"encoding/binary"
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// Context implements IDataCryptorContext for AES-CTR encryption.
type Context struct {
	storeFileIo crypto_data.IFileContext
	block       cipher.Block
	counter     []byte
	stream      []byte
	pos         int64
	size        int64
}

// NewContext creates a new AES-CTR encryption context.
func NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) < 32 {
		return nil, io.ErrUnexpectedEOF
	}

	block, err := aes.NewCipher(key[:32])
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
		storeFileIo: storeFileIo,
		block:       block,
		counter:     make([]byte, aes.BlockSize),
		stream:      make([]byte, aes.BlockSize),
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

// xorKeystream XORs data with keystream at position using standard library cipher.NewCTR.
// For small data (< 1KB), uses xorKeystreamQuick to avoid overhead of creating new CTR instance.
func (c *Context) xorKeystream(data []byte, pos int64) {
	// For small data, use quick method to avoid overhead of creating new cipher.NewCTR instance
	if len(data) < 1024 {
		c.xorKeystreamQuick(data, pos)
		return
	}

	blockSize := int64(aes.BlockSize)
	blockNum := pos / blockSize
	blockOffset := pos % blockSize

	// Create IV with block number (big-endian counter in last 8 bytes)
	iv := make([]byte, aes.BlockSize)
	copy(iv[:8], c.counter[:8])                          // nonce (前 8 字节)
	binary.BigEndian.PutUint64(iv[8:], uint64(blockNum)) // block number (后 8 字节)

	// Create CTR stream using standard library
	stream := cipher.NewCTR(c.block, iv)

	// Discard bytes within block if offset > 0
	if blockOffset > 0 {
		discard := make([]byte, blockOffset)
		stream.XORKeyStream(discard, discard)
	}

	// XOR data using standard library XORKeyStream
	stream.XORKeyStream(data, data)
}

// xorKeystreamQuick XORs data using block-by-block processing.
// This method is kept for small data (< 1KB) where creating a new cipher.NewCTR instance
// has more overhead than direct block processing.
// For large data, cipher.NewCTR with XORKeyStream is more efficient.
func (c *Context) xorKeystreamQuick(data []byte, pos int64) {
	blockSize := int64(aes.BlockSize)
	dataOffset := 0

	for dataOffset < len(data) {
		blockNum := pos / blockSize
		blockOffset := pos % blockSize

		// Generate keystream block with big-endian counter
		// CTR mode uses big-endian counter in the last 8 bytes of IV
		binary.BigEndian.PutUint64(c.counter[8:], uint64(blockNum))
		c.block.Encrypt(c.stream, c.counter)

		// XOR data using standard library
		remaining := blockSize - blockOffset
		toProcess := min(int(remaining), len(data)-dataOffset)

		subtle.XORBytes(data[dataOffset:dataOffset+toProcess], data[dataOffset:dataOffset+toProcess], c.stream[blockOffset:blockOffset+int64(toProcess)])

		dataOffset += toProcess
		pos += int64(toProcess)
	}
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
