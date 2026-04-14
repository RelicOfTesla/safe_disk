// Package random_access_adapter provides a caching layer for encryption contexts
// that don't support efficient random access (like RC4 stream cipher).
package random_access_adapter

import (
	"io"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

const DefaultBlockSize = 4096

type Adapter struct {
	ctx         crypto_data.IDataCryptorContext
	blockSize   int
	cache       map[int64][]byte
	dirtyBlocks map[int64]bool
	pos         int64
	size        int64
}

func NewAdapter(ctx crypto_data.IDataCryptorContext, blockSize int) *Adapter {
	if blockSize <= 0 {
		blockSize = DefaultBlockSize
	}
	size, _ := ctx.Seek(0, io.SeekEnd)
	ctx.Seek(0, io.SeekStart)

	return &Adapter{
		ctx:         ctx,
		blockSize:   blockSize,
		cache:       make(map[int64][]byte),
		dirtyBlocks: make(map[int64]bool),
		pos:         0,
		size:        size,
	}
}

func (a *Adapter) blockIndex(pos int64) int64  { return pos / int64(a.blockSize) }
func (a *Adapter) blockOffset(pos int64) int   { return int(pos % int64(a.blockSize)) }
func (a *Adapter) getBlock(blockIdx int64) ([]byte, error) { return a.getBlockInternal(blockIdx) }

func (a *Adapter) getBlockInternal(blockIdx int64) ([]byte, error) {
	if data, ok := a.cache[blockIdx]; ok {
		return data, nil
	}

	blockStart := blockIdx * int64(a.blockSize)
	blockEnd := blockStart + int64(a.blockSize)
	if blockEnd > a.size {
		blockEnd = a.size
	}

	blockSize := int(blockEnd - blockStart)
	if blockSize <= 0 {
		data := make([]byte, a.blockSize)
		a.cache[blockIdx] = data
		return data, nil
	}

	_, err := a.ctx.Seek(blockStart, io.SeekStart)
	if err != nil {
		return nil, err
	}

	data := make([]byte, a.blockSize)
	n, err := io.ReadFull(a.ctx, data[:blockSize])
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return nil, err
	}

	for i := n; i < a.blockSize; i++ {
		data[i] = 0
	}

	a.cache[blockIdx] = data
	return data, nil
}

func (a *Adapter) Read(p []byte) (n int, err error) {
	if a.pos >= a.size {
		return 0, io.EOF
	}

	remaining := a.size - a.pos
	toRead := int64(len(p))
	if toRead > remaining {
		toRead = remaining
	}

	for n < int(toRead) {
		blockIdx := a.blockIndex(a.pos + int64(n))
		offset := a.blockOffset(a.pos + int64(n))

		block, err := a.getBlockInternal(blockIdx)
		if err != nil {
			return n, err
		}

		copied := 0
		for i := offset; i < len(block) && n+copied < int(toRead); i++ {
			p[n+copied] = block[i]
			copied++
		}
		n += copied
		if copied == 0 {
			break
		}
	}

	a.pos += int64(n)
	return n, nil
}

func (a *Adapter) Write(p []byte) (n int, err error) {
	for n < len(p) {
		blockIdx := a.blockIndex(a.pos + int64(n))
		offset := a.blockOffset(a.pos + int64(n))

		block, err := a.getBlockInternal(blockIdx)
		if err != nil {
			return n, err
		}

		copied := 0
		for i := offset; i < len(block) && n+copied < len(p); i++ {
			block[i] = p[n+copied]
			copied++
		}
		n += copied
		a.dirtyBlocks[blockIdx] = true
	}

	a.pos += int64(n)
	if a.pos > a.size {
		a.size = a.pos
	}
	return n, nil
}

func (a *Adapter) Seek(offset int64, whence int) (int64, error) {
	var newPos int64
	switch whence {
	case io.SeekStart:
		newPos = offset
	case io.SeekCurrent:
		newPos = a.pos + offset
	case io.SeekEnd:
		newPos = a.size + offset
	default:
		return 0, io.ErrUnexpectedEOF
	}
	if newPos < 0 {
		return 0, io.ErrUnexpectedEOF
	}
	a.pos = newPos
	return a.pos, nil
}

func (a *Adapter) Close() error {
	for blockIdx := range a.dirtyBlocks {
		if err := a.flushBlock(blockIdx); err != nil {
			return err
		}
	}
	return a.ctx.Close()
}

func (a *Adapter) flushBlock(blockIdx int64) error {
	block, ok := a.cache[blockIdx]
	if !ok {
		return nil
	}

	blockStart := blockIdx * int64(a.blockSize)
	blockEnd := blockStart + int64(a.blockSize)
	if blockEnd > a.size {
		blockEnd = a.size
	}

	blockSize := int(blockEnd - blockStart)
	if blockSize <= 0 {
		return nil
	}

	_, err := a.ctx.Seek(blockStart, io.SeekStart)
	if err != nil {
		return err
	}
	_, err = a.ctx.Write(block[:blockSize])
	return err
}

func (a *Adapter) ReadAt(p []byte, off int64) (n int, err error) {
	oldPos := a.pos
	a.pos = off
	n, err = a.Read(p)
	a.pos = oldPos
	if n < len(p) {
		return n, io.EOF
	}
	return n, err
}

func (a *Adapter) WriteAt(p []byte, off int64) (n int, err error) {
	oldPos := a.pos
	a.pos = off
	n, err = a.Write(p)
	a.pos = oldPos
	return n, err
}

func (a *Adapter) Size() int64 { return a.size }

func (a *Adapter) Truncate(size int64) error {
	if size < a.size {
		newLastBlock := a.blockIndex(size)
		for blockIdx := range a.cache {
			if blockIdx > newLastBlock {
				delete(a.cache, blockIdx)
				delete(a.dirtyBlocks, blockIdx)
			}
		}
		if block, ok := a.cache[newLastBlock]; ok {
			offset := a.blockOffset(size)
			for i := offset; i < len(block); i++ {
				block[i] = 0
			}
			a.dirtyBlocks[newLastBlock] = true
		}
	} else if size > a.size {
		oldLastBlock := a.blockIndex(a.size)
		if block, ok := a.cache[oldLastBlock]; ok {
			offset := a.blockOffset(a.size)
			for i := offset; i < len(block); i++ {
				block[i] = 0
			}
			a.dirtyBlocks[oldLastBlock] = true
		}
	}
	a.size = size
	return nil
}

func (a *Adapter) Sync() error {
	for blockIdx := range a.dirtyBlocks {
		if err := a.flushBlock(blockIdx); err != nil {
			return err
		}
	}
	a.dirtyBlocks = make(map[int64]bool)
	return a.ctx.Sync()
}

type Factory struct {
	underlying crypto_data.ICryptoDataFactory
	blockSize  int
}

func NewFactory(underlying crypto_data.ICryptoDataFactory, blockSize int) *Factory {
	return &Factory{underlying: underlying, blockSize: blockSize}
}

func (f *Factory) NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_data.IDataCryptorContext, error) {
	ctx, err := f.underlying.NewContext(storeFileIo, keyInfo, cfg)
	if err != nil {
		return nil, err
	}
	return NewAdapter(ctx, f.blockSize), nil
}

func (f *Factory) GetName() string { return f.underlying.GetName() + "+random-access" }

func (f *Factory) GetCapabilities() crypto_data.CryptorCapabilities {
	caps := f.underlying.GetCapabilities()
	caps.RandomAccessComplexity = crypto_data.O1
	caps.ModificationComplexity = crypto_data.O1
	return caps
}

func (f *Factory) GetRequireMinKeyLength() int {
	return f.underlying.GetRequireMinKeyLength()
}

var _ crypto_data.IDataCryptorContext = (*Adapter)(nil)
var _ crypto_data.ICryptoDataFactory = (*Factory)(nil)
