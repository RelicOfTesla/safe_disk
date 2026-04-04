package sec_fs

import (
	"github.com/safedisk/native/crypto"
	"github.com/safedisk/native/errors"
	"github.com/safedisk/native/service"
)

// SecFile represents an open encrypted file.
// It provides stdio-like operations for reading and writing.
type SecFile struct {
	handle    *secFileHandle
	cryptoSvc *service.CryptoService
	root      *SecRoot
	closed    bool
}

// Read reads up to size bytes from the file.
// Returns the data and number of bytes read.
// If size <= 0, reads all remaining data.
func (f *SecFile) Read(size int) ([]byte, int, error) {
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

	// Read from buffer
	var data []byte
	if toRead > 0 && f.handle.offset < int64(len(f.handle.data)) {
		end := f.handle.offset + int64(toRead)
		if end > int64(len(f.handle.data)) {
			end = int64(len(f.handle.data))
		}
		data = make([]byte, end-f.handle.offset)
		copy(data, f.handle.data[f.handle.offset:end])
		f.handle.offset = end
	} else {
		data = []byte{}
	}

	return data, len(data), nil
}

// ReadAll reads all remaining data from the file.
func (f *SecFile) ReadAll() ([]byte, error) {
	if f.closed {
		return nil, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	data, _, err := f.Read(-1)
	return data, err
}

// Write writes data to the file.
// Returns the number of bytes written.
func (f *SecFile) Write(data []byte) (int, error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if f.handle.mode == "r" {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter,
			"file not open for writing")
	}

	// Write to buffer at current offset
	endOffset := f.handle.offset + int64(len(data))
	if endOffset > int64(len(f.handle.data)) {
		// Extend buffer
		newData := make([]byte, endOffset)
		copy(newData, f.handle.data)
		f.handle.data = newData
	}
	copy(f.handle.data[f.handle.offset:], data)
	f.handle.offset = endOffset
	f.handle.size = int64(len(f.handle.data))
	f.handle.modified = true

	return len(data), nil
}

// WriteString writes a string to the file.
func (f *SecFile) WriteString(s string) (int, error) {
	return f.Write([]byte(s))
}

// Seek sets the file position.
// Returns the new position.
//
// Whence:
//   - SeekSet (0): offset from start
//   - SeekCur (1): offset from current position
//   - SeekEnd (2): offset from end
func (f *SecFile) Seek(offset int64, whence int) (int64, error) {
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
func (f *SecFile) Tell() (int64, error) {
	if f.closed {
		return 0, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}
	return f.handle.offset, nil
}

// Rewind resets the position to the start of the file.
func (f *SecFile) Rewind() error {
	_, err := f.Seek(0, SeekSet)
	return err
}

// Truncate truncates the file to the specified size.
func (f *SecFile) Truncate(size int64) error {
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

	if size > int64(len(f.handle.data)) {
		// Extend
		newData := make([]byte, size)
		copy(newData, f.handle.data)
		f.handle.data = newData
	} else {
		// Shrink
		f.handle.data = f.handle.data[:size]
	}

	f.handle.size = size
	f.handle.modified = true

	return nil
}

// Stat returns basic file status.
func (f *SecFile) Stat() (*SecFileStat, error) {
	if f.closed {
		return nil, errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	return &SecFileStat{
		Size:     f.handle.size,
		Position: f.handle.offset,
	}, nil
}

// Sync flushes changes to the encrypted file.
// For in-memory files, this encrypts and writes to disk.
func (f *SecFile) Sync() error {
	if f.closed {
		return errors.NewWithMessage(errors.ErrInvalidParameter, "file is closed")
	}

	if !f.handle.modified {
		return nil
	}

	return f.flush()
}

// flush writes the data to disk.
func (f *SecFile) flush() error {
	if f.handle.data == nil {
		return nil
	}

	source := crypto.NewCryptSourceFromData(f.handle.data)
	encryptor := f.handle.maker.NewEncryptor(source)
	if err := encryptor.EncryptToFile(f.handle.path); err != nil {
		return err
	}

	f.handle.modified = false
	return nil
}

// Close closes the file and writes changes if modified.
func (f *SecFile) Close() error {
	if f.closed {
		return nil
	}

	f.closed = true

	// If modified, encrypt and save
	if f.handle.modified && f.handle.mode != "r" {
		if err := f.flush(); err != nil {
			return err
		}
	}

	// Clear sensitive data
	if f.handle.data != nil {
		f.cryptoSvc.MemZero(f.handle.data)
		f.handle.data = nil
	}

	return nil
}

// ==================== Status Methods ====================

// IsClosed returns true if the file is closed.
func (f *SecFile) IsClosed() bool {
	return f.closed
}

// Size returns the file size.
func (f *SecFile) Size() int64 {
	return f.handle.size
}

// Mode returns the open mode.
func (f *SecFile) Mode() string {
	return f.handle.mode
}

// Path returns the file path.
func (f *SecFile) Path() string {
	return f.handle.path
}

// ==================== Convenience Methods ====================

// ReadAt reads data at a specific offset.
func (f *SecFile) ReadAt(offset int64, size int) ([]byte, error) {
	if _, err := f.Seek(offset, SeekSet); err != nil {
		return nil, err
	}
	data, _, err := f.Read(size)
	return data, err
}

// WriteAt writes data at a specific offset.
func (f *SecFile) WriteAt(offset int64, data []byte) (int, error) {
	if _, err := f.Seek(offset, SeekSet); err != nil {
		return 0, err
	}
	return f.Write(data)
}

// Append appends data to the end of the file.
func (f *SecFile) Append(data []byte) (int, error) {
	if _, err := f.Seek(0, SeekEnd); err != nil {
		return 0, err
	}
	return f.Write(data)
}

// AppendString appends a string to the end of the file.
func (f *SecFile) AppendString(s string) (int, error) {
	return f.Append([]byte(s))
}

// ==================== StatInfo ====================

// StatInfo returns detailed file information from the root context.
func (f *SecFile) StatInfo() (*SecFileInfo, error) {
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
