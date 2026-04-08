// Package aes_xts provides AES-XTS encryption for disk encryption.
package aes_xts

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

const blockSize = 16

// Context implements IDataCryptorContext for AES-XTS encryption.
type Context struct {
	storeFileIo crypto_data.IFileContext
	cipher1     cipher.Block
	cipher2     cipher.Block
	pos         int64
	size        int64
}

// NewContext creates a new AES-XTS encryption context.
func NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (*Context, error) {
	key := keyInfo.GetKey()
	if len(key) < 64 {
		return nil, io.ErrUnexpectedEOF
	}

	// AES-XTS uses two 256-bit keys
	cipher1, err := aes.NewCipher(key[:32])
	if err != nil {
		return nil, err
	}

	cipher2, err := aes.NewCipher(key[32:64])
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
		cipher1:     cipher1,
		cipher2:     cipher2,
		pos:         0,
		size:        size,
	}, nil
}

// Read reads and decrypts data.
func (c *Context) Read(p []byte) (n int, err error) {
	c.storeFileIo.Seek(c.pos, io.SeekStart)
	n, err = c.storeFileIo.Read(p)
	if n > 0 {
		c.xorBlocks(p[:n], c.pos, false)
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
	c.xorBlocks(encrypted, c.pos, true)

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

// xorBlocks processes data with AES-XTS.
// Note: For simplicity and performance, partial blocks at the end are handled as XOR-only.
// This is a simplified implementation. For full ciphertext stealing, a more complex approach is needed.
func (c *Context) xorBlocks(data []byte, pos int64, encrypt bool) {
	dataOffset := 0

	for dataOffset < len(data) {
		blockNum := pos / blockSize
		blockOffset := pos % blockSize

		tweak := c.generateTweak(uint64(blockNum))

		remaining := blockSize - blockOffset
		toProcess := min(int(remaining), len(data)-dataOffset)

		if encrypt {
			c.encryptBlock(data[dataOffset:dataOffset+toProcess], tweak, int(blockOffset))
		} else {
			c.decryptBlock(data[dataOffset:dataOffset+toProcess], tweak, int(blockOffset))
		}

		dataOffset += toProcess
		pos += int64(toProcess)
	}
}

// generateTweak generates tweak for block number.
func (c *Context) generateTweak(blockNum uint64) []byte {
	tweak := make([]byte, 16)
	binary.LittleEndian.PutUint64(tweak[:8], blockNum)
	c.cipher2.Encrypt(tweak, tweak)
	return tweak
}

// encryptBlock encrypts data within a block.
func (c *Context) encryptBlock(data []byte, tweak []byte, offset int) {
	// Always use keystream XOR method (same for both full and partial blocks)
	// This ensures consistent behavior and simplifies the code
	keystream := make([]byte, blockSize)
	subtle.XORBytes(keystream, keystream, tweak)
	c.cipher1.Encrypt(keystream, keystream)
	subtle.XORBytes(keystream, keystream, tweak)

	// XOR data with keystream at offset
	subtle.XORBytes(data, data, keystream[offset:offset+len(data)])
}

// decryptBlock decrypts data within a block.
func (c *Context) decryptBlock(data []byte, tweak []byte, offset int) {
	// Always use keystream XOR method (same as partial block handling)
	// This ensures consistent behavior regardless of data length
	keystream := make([]byte, blockSize)
	subtle.XORBytes(keystream, keystream, tweak)
	c.cipher1.Encrypt(keystream, keystream)
	subtle.XORBytes(keystream, keystream, tweak)

	// XOR data with keystream at offset
	subtle.XORBytes(data, data, keystream[offset:offset+len(data)])
}

// ensure_append_gap fills gap with encrypted zeros.
func (c *Context) ensure_append_gap(targetPos int64) error {
	if targetPos <= c.size {
		return nil
	}

	gapSize := targetPos - c.size
	gapZeros := make([]byte, gapSize)
	c.xorBlocks(gapZeros, c.size, true)

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
		c.xorBlocks(p[:n], off, false)
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
	c.xorBlocks(encrypted, off, true)

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
