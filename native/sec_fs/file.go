package sec_fs

import (
	"io"
	"io/fs"
	"time"

	"github.com/safedisk/native/sec_fs/crypto"
	"github.com/safedisk/native/errors"
)

// secFileImpl represents an open encrypted file.
// It provides stdio-like operations for reading and writing.
// Uses IIncrementalCryptor for actual encryption/decryption operations
// instead of storing decrypted data in memory.
type secFileImpl struct {
	handle *secFileHandle
	root   *secRootImpl
	closed bool
	impl   crypto.ICryptorMaker // CryptImpl from registry (private)
}

// Read reads up to len(p) bytes into p. It satisfies the io.Reader interface.
// Returns the number of bytes read and any error encountered.
func (f *secFileImpl) Read(p []byte) (n int, err error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if f.handle.mode == "w" {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter,
			"file not open for reading")
	}

	if len(p) == 0 {
		return 0, nil
	}

	// Determine how much to read
	remaining := f.handle.size - f.handle.offset
	if remaining <= 0 {
		return 0, io.EOF
	}

	toRead := int64(len(p))
	if toRead > remaining {
		toRead = remaining
	}

	// Read using incremental decryptor if available
	if f.handle.isIncremental && f.handle.incDecryptor != nil {
		data, err := f.readIncremental(int(toRead))
		if err != nil {
			return 0, err
		}
		n = copy(p, data)
		if n < len(data) {
			// Didn't read all the data, need to adjust offset back
			f.handle.offset -= int64(len(data) - n)
		}
		return n, nil
	}

	// Fallback: use one-shot decryption (for non-incremental files)
	if f.handle.decryptor != nil {
		data, err := f.handle.decryptor.DecryptToData()
		if err != nil {
			return 0, err
		}
		defer crypto.MemZero(data)

		// Extract the needed portion
		start := f.handle.offset
		end := start + toRead
		if end > int64(len(data)) {
			end = int64(len(data))
		}

		n = copy(p, data[start:end])
		f.handle.offset += int64(n)

		if f.handle.offset >= f.handle.size {
			return n, io.EOF
		}
		return n, nil
	}

	return 0, errors.NewWithMessage(errors.ErrOperationFailed,
		"no decryptor available for reading")
}

// ReadSize reads up to size bytes from the file and returns an allocated buffer.
// This is a convenience method for when you want the buffer allocated for you.
// For io.Reader compatibility, prefer the Read(p []byte) method.
// If size <= 0, reads all remaining data.
func (f *secFileImpl) ReadSize(size int) ([]byte, int, error) {
	if f.closed {
		return nil, 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if f.handle.mode == "w" {
		return nil, 0, errors.NewWithMessage(errors.ErrInvalidParameter,
			"file not open for reading")
	}

	// Determine how much to read
	toRead := size
	if toRead <= 0 || toRead > int(f.handle.size-f.handle.offset) {
		toRead = int(f.handle.size - f.handle.offset)
	}

	if toRead <= 0 {
		return []byte{}, 0, nil
	}

	// Read using incremental decryptor if available
	if f.handle.isIncremental && f.handle.incDecryptor != nil {
		data, err := f.readIncremental(toRead)
		if err != nil {
			return nil, 0, err
		}
		return data, len(data), nil
	}

	// Fallback: use one-shot decryption (for non-incremental files)
	if f.handle.decryptor != nil {
		data, err := f.handle.decryptor.DecryptToData()
		if err != nil {
			return nil, 0, err
		}
		defer crypto.MemZero(data)

		// Extract the needed portion
		start := f.handle.offset
		end := start + int64(toRead)
		if end > int64(len(data)) {
			end = int64(len(data))
		}

		result := make([]byte, end-start)
		copy(result, data[start:end])
		f.handle.offset = end

		return result, len(result), nil
	}

	return nil, 0, errors.NewWithMessage(errors.ErrOperationFailed,
		"no decryptor available for reading")
}

// readIncremental reads data using the incremental decryptor
func (f *secFileImpl) readIncremental(size int) ([]byte, error) {
	blockSize := f.handle.blockSize
	if blockSize <= 0 {
		blockSize = crypto.DefaultChunkSize
	}

	// Calculate which blocks we need
	startOffset := f.handle.offset
	endOffset := startOffset + int64(size)
	if endOffset > f.handle.size {
		endOffset = f.handle.size
	}

	startBlock := int(startOffset / int64(blockSize))
	endBlock := int((endOffset - 1) / int64(blockSize))

	if startBlock < 0 {
		startBlock = 0
	}

	// Read all needed blocks
	var allData []byte
	for i := startBlock; i <= endBlock; i++ {
		blockData, err := f.handle.incDecryptor.GetBlock(i)
		if err != nil {
			return nil, err
		}
		allData = append(allData, blockData...)
	}

	// Calculate the exact range within the blocks
	startInBlocks := startOffset % int64(blockSize)
	endInBlocks := startInBlocks + int64(size)

	if endInBlocks > int64(len(allData)) {
		endInBlocks = int64(len(allData))
	}

	// Extract the needed data
	result := make([]byte, endInBlocks-startInBlocks)
	copy(result, allData[startInBlocks:endInBlocks])

	// Update offset
	f.handle.offset += int64(len(result))

	// Clear sensitive data
	crypto.MemZero(allData)

	return result, nil
}

// ReadAll reads all remaining data from the file.
// This is a convenience method; for standard usage, prefer io.ReadAll(f).
func (f *secFileImpl) ReadAll() ([]byte, error) {
	if f.closed {
		return nil, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	data, _, err := f.ReadSize(-1)
	return data, err
}

// Write writes data to the file.
// Returns the number of bytes written.
func (f *secFileImpl) Write(data []byte) (int, error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if f.handle.mode == "r" {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter,
			"file not open for writing")
	}

	if len(data) == 0 {
		return 0, nil
	}

	// For incremental mode, initialize encryptor if needed
	if f.handle.incEncryptor != nil {
		// Check if encryptor needs initialization
		if init, ok := f.handle.incEncryptor.(interface{ InitForWrite(string) error }); ok {
			if f.handle.incEncryptor.GetBlockCount() == 0 {
				// For append mode, we need to load existing data first
				if f.handle.mode == "a" && f.handle.size > 0 && f.handle.decryptor != nil {
					// Load existing data from non-incremental file
					existingData, err := f.handle.decryptor.DecryptToData()
					if err != nil {
						return 0, err
					}
					// Initialize encryptor
					if err := init.InitForWrite(f.handle.path); err != nil {
						crypto.MemZero(existingData)
						return 0, err
					}
					// Add existing data as blocks
					blockSize := f.handle.blockSize
					if blockSize <= 0 {
						blockSize = crypto.DefaultChunkSize
					}
					for offset := 0; offset < len(existingData); offset += blockSize {
						end := offset + blockSize
						if end > len(existingData) {
							end = len(existingData)
						}
						block := make([]byte, end-offset)
						copy(block, existingData[offset:end])
						if err := f.handle.incEncryptor.AddBlock(f.handle.incEncryptor.GetBlockCount(), block); err != nil {
							crypto.MemZero(existingData)
							return 0, err
						}
					}
					crypto.MemZero(existingData)
				} else {
					// Initialize encryptor for new file
					if err := init.InitForWrite(f.handle.path); err != nil {
						return 0, err
					}
				}
			}
		}
		return f.writeIncremental(data)
	}

	return 0, errors.NewWithMessage(errors.ErrOperationFailed,
		"no encryptor available for writing")
}

// writeIncremental writes data using the incremental encryptor
func (f *secFileImpl) writeIncremental(data []byte) (int, error) {
	blockSize := f.handle.blockSize
	if blockSize <= 0 {
		blockSize = crypto.DefaultChunkSize
	}

	// Calculate which block we're writing to
	offset := f.handle.offset
	blockIndex := int(offset / int64(blockSize))
	offsetInBlock := offset % int64(blockSize)

	// If we're writing in the middle of a block, we need to read-modify-write
	if offsetInBlock > 0 || len(data) < blockSize {
		return f.writePartialBlock(blockIndex, offsetInBlock, data)
	}

	// If we're writing full blocks, use AddBlock/ModifyBlock
	written := 0
	for len(data) >= blockSize {
		blockData := make([]byte, blockSize)
		copy(blockData, data[:blockSize])

		var err error
		if blockIndex < f.handle.incEncryptor.GetBlockCount() {
			err = f.handle.incEncryptor.ModifyBlock(blockIndex, blockData)
		} else {
			err = f.handle.incEncryptor.AddBlock(blockIndex, blockData)
		}

		if err != nil {
			return written, err
		}

		written += blockSize
		data = data[blockSize:]
		blockIndex++
		f.handle.offset += int64(blockSize)
	}

	// Handle remaining data (less than a block)
	if len(data) > 0 {
		n, err := f.writePartialBlock(blockIndex, 0, data)
		written += n
		return written, err
	}

	f.handle.modified = true
	return written, nil
}

// writePartialBlock handles writing data that doesn't align with block boundaries
func (f *secFileImpl) writePartialBlock(blockIndex int, offsetInBlock int64, data []byte) (int, error) {
	blockSize := f.handle.blockSize
	if blockSize <= 0 {
		blockSize = crypto.DefaultChunkSize
	}

	// For new files or appending at the end, just add the actual data
	// Don't pad to block size - this preserves the actual file size
	if blockIndex >= f.handle.incEncryptor.GetBlockCount() && offsetInBlock == 0 {
		// This is a new block at the end - just add the actual data
		actualData := make([]byte, len(data))
		copy(actualData, data)

		err := f.handle.incEncryptor.AddBlock(blockIndex, actualData)
		if err != nil {
			return 0, err
		}

		f.handle.offset += int64(len(data))
		if f.handle.offset > f.handle.size {
			f.handle.size = f.handle.offset
		}
		f.handle.modified = true
		return len(data), nil
	}

	// For modifying existing blocks or writing in the middle, we need read-modify-write
	var existingBlock []byte
	var err error

	if blockIndex < f.handle.incEncryptor.GetBlockCount() {
		existingBlock, err = f.handle.incEncryptor.GetBlock(blockIndex)
		if err != nil {
			return 0, err
		}
	} else {
		// New block
		existingBlock = make([]byte, offsetInBlock)
	}

	// Calculate how much we can write
	availableInBlock := int64(blockSize) - offsetInBlock
	if availableInBlock < 0 {
		availableInBlock = 0
	}
	toWrite := int64(len(data))
	if toWrite > availableInBlock {
		toWrite = availableInBlock
	}

	// Extend the block if needed
	newLen := offsetInBlock + toWrite
	if int64(len(existingBlock)) < newLen {
		newBlock := make([]byte, newLen)
		copy(newBlock, existingBlock)
		existingBlock = newBlock
	}

	// Modify the block
	copy(existingBlock[offsetInBlock:offsetInBlock+toWrite], data[:toWrite])

	// Write the block back
	if blockIndex < f.handle.incEncryptor.GetBlockCount() {
		err = f.handle.incEncryptor.ModifyBlock(blockIndex, existingBlock)
	} else {
		err = f.handle.incEncryptor.AddBlock(blockIndex, existingBlock)
	}

	if err != nil {
		return 0, err
	}

	// Update offset
	f.handle.offset += toWrite
	if f.handle.offset > f.handle.size {
		f.handle.size = f.handle.offset
	}
	f.handle.modified = true

	// Clear sensitive data
	crypto.MemZero(existingBlock)

	return int(toWrite), nil
}

// WriteString writes a string to the file.
func (f *secFileImpl) WriteString(s string) (int, error) {
	return f.Write([]byte(s))
}

// Seek sets the file position.
// Returns the new position.
//
// Whence:
//   - SeekSet (0): offset from start
//   - SeekCur (1): offset from current position
//   - SeekEnd (2): offset from end
func (f *secFileImpl) Seek(offset int64, whence int) (int64, error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	var newPos int64
	switch whence {
	case SeekSet:
		newPos = offset
	case SeekCur:
		newPos = f.handle.offset + offset
	case SeekEnd:
		newPos = f.handle.size + offset
	default:
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter,
			"invalid whence value")
	}

	// Clamp to valid range
	if newPos < 0 {
		newPos = 0
	}
	if newPos > f.handle.size {
		newPos = f.handle.size
	}

	f.handle.offset = newPos
	return newPos, nil
}

// Tell returns the current file position.
func (f *secFileImpl) Tell() (int64, error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}
	return f.handle.offset, nil
}

// Rewind resets the position to the start of the file.
func (f *secFileImpl) Rewind() error {
	_, err := f.Seek(0, SeekSet)
	return err
}

// Truncate truncates the file to the specified size.
func (f *secFileImpl) Truncate(size int64) error {
	if f.closed {
		return errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if f.handle.mode == "r" {
		return errors.NewWithMessage(errors.ErrInvalidParameter,
			"file not open for writing")
	}

	if size < 0 {
		size = 0
	}

	// For incremental mode, we need to handle block deletion/addition
	if f.handle.isIncremental && f.handle.incEncryptor != nil {
		blockSize := int64(f.handle.blockSize)
		if blockSize <= 0 {
			blockSize = crypto.DefaultChunkSize
		}

		currentBlocks := f.handle.incEncryptor.GetBlockCount()
		targetBlocks := int((size + blockSize - 1) / blockSize)

		// Delete extra blocks
		for i := currentBlocks - 1; i >= targetBlocks; i-- {
			if err := f.handle.incEncryptor.DeleteBlock(i); err != nil {
				return err
			}
		}
	}

	f.handle.size = size
	f.handle.modified = true

	return nil
}

// Stat returns file information. It satisfies the fs.File interface.
func (f *secFileImpl) Stat() (fs.FileInfo, error) {
	if f.closed {
		return nil, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	return &secFileInfo{
		name:     f.handle.path,
		size:     f.handle.size,
		mode:     0, // Regular file
		modTime:  time.Now(), // We don't track modification time currently
		isDir:    false,
	}, nil
}

// StatDetail returns detailed file status (extended version of Stat).
func (f *secFileImpl) StatDetail() (*SecFileStat, error) {
	if f.closed {
		return nil, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	return &SecFileStat{
		Size:     f.handle.size,
		Position: f.handle.offset,
	}, nil
}

// Sync flushes changes to the encrypted file.
func (f *secFileImpl) Sync() error {
	if f.closed {
		return errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if !f.handle.modified {
		return nil
	}

	return f.flush()
}

// flush writes the data to disk.
func (f *secFileImpl) flush() error {
	if f.handle.incEncryptor != nil {
		return f.handle.incEncryptor.Flush()
	}
	return nil
}

// Close closes the file and writes changes if modified.
func (f *secFileImpl) Close() error {
	if f.closed {
		return nil
	}

	f.closed = true

	// If modified, flush changes
	if f.handle.modified && f.handle.mode != "r" {
		if err := f.flush(); err != nil {
			return err
		}
	}

	// Close decryptor if it has a Close method
	if f.handle.incDecryptor != nil {
		if closer, ok := f.handle.incDecryptor.(interface{ Close() error }); ok {
			closer.Close()
		}
	}

	// Close encryptor if it has a Close method
	if f.handle.incEncryptor != nil {
		if closer, ok := f.handle.incEncryptor.(interface{ Close() error }); ok {
			closer.Close()
		}
	}

	return nil
}

// ==================== Status Methods ====================

// IsClosed returns true if the file is closed.
func (f *secFileImpl) IsClosed() bool {
	return f.closed
}

// Size returns the file size.
func (f *secFileImpl) Size() int64 {
	return f.handle.size
}

// Mode returns the open mode.
func (f *secFileImpl) Mode() string {
	return f.handle.mode
}

// Path returns the file path.
func (f *secFileImpl) Path() string {
	return f.handle.path
}

// ==================== Convenience Methods ====================

// ReadAt reads data at a specific offset without changing the file position.
func (f *secFileImpl) ReadAt(offset int64, size int) ([]byte, error) {
	if _, err := f.Seek(offset, SeekSet); err != nil {
		return nil, err
	}
	data, _, err := f.ReadSize(size)
	return data, err
}

// WriteAt writes data at a specific offset.
func (f *secFileImpl) WriteAt(offset int64, data []byte) (int, error) {
	if _, err := f.Seek(offset, SeekSet); err != nil {
		return 0, err
	}
	return f.Write(data)
}

// Append appends data to the end of the file.
func (f *secFileImpl) Append(data []byte) (int, error) {
	if _, err := f.Seek(0, SeekEnd); err != nil {
		return 0, err
	}
	return f.Write(data)
}

// AppendString appends a string to the end of the file.
func (f *secFileImpl) AppendString(s string) (int, error) {
	return f.Append([]byte(s))
}

// ==================== StatInfo ====================

// StatInfo returns detailed file information from the root context.
func (f *secFileImpl) StatInfo() (*SecFileInfo, error) {
	if f.root == nil {
		return nil, errors.NewWithMessage(errors.ErrOperationFailed,
			"no root context available")
	}

	// Get relative path
	relPath, err := f.root.RelPath(f.handle.path)
	if err != nil {
		return nil, err
	}

	return f.root.StatFile(relPath)
}
