// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains the secFileImpl implementation that delegates operations to IDataCryptorContext.
package sec_fs

import (
	"io/fs"
	"os"
	"sync"
	"time"

	"safe_disk/native/sec_fs/crypto_data"
)

// ==================== fileContext Implementation ====================

// fileContext wraps *os.File to implement crypto_data.IFileContext.
// This wrapper adds the Size() method that *os.File is missing.
type fileContext struct {
	*os.File
}

// Size returns the current size of the file.
func (f *fileContext) Size() int64 {
	if f.File == nil {
		return 0
	}
	info, err := f.File.Stat()
	if err != nil {
		return 0
	}
	return info.Size()
}

// ==================== secFileImpl Implementation ====================


// Compile-time interface verification
var _ crypto_data.IFileContext = (*fileContext)(nil)
var _ crypto_data.IFullFileContext = (*fileContext)(nil)
var _ crypto_data.IFullFileContext = (*secFileImpl)(nil)
// secFileImpl implements ISecFile and ISecFilePlus interfaces.
// It delegates file operations to an IDataCryptorContext instance.
type secFileImpl struct {
	// impl is the cryptographic context that handles actual file operations.
	// This field is private and all operations are delegated to it.
	impl crypto_data.IDataCryptorContext

	// relativeViewPath is the relative path from the user's perspective.
	relativeViewPath RelativeViewPath

	// fullStorePath is the full path from the storage perspective.
	fullStorePath FullStorePath

	// mode is the file mode (permissions).
	mode os.FileMode

	// closed indicates whether the file has been closed.
	closed bool

	// mu protects the closed field from concurrent access.
	mu sync.RWMutex
}

// ==================== ISecFile Interface Methods ====================

// Read reads up to len(p) bytes from the file into p.
// It returns the number of bytes read and any error encountered.
func (f *secFileImpl) Read(p []byte) (n int, err error) {
	if f == nil || f.impl == nil {
		return 0, ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return 0, ErrFileClosed
	}

	return f.impl.Read(p)
}

// Write writes len(p) bytes from p to the file.
// It returns the number of bytes written and any error encountered.
func (f *secFileImpl) Write(p []byte) (n int, err error) {
	if f == nil || f.impl == nil {
		return 0, ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return 0, ErrFileClosed
	}

	return f.impl.Write(p)
}

// Seek sets the offset for the next Read or Write on file to offset,
// interpreted according to whence: 0 means relative to the origin of the file,
// 1 means relative to the current offset, and 2 means relative to the end.
func (f *secFileImpl) Seek(offset int64, whence int) (int64, error) {
	if f == nil || f.impl == nil {
		return 0, ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return 0, ErrFileClosed
	}

	return f.impl.Seek(offset, whence)
}

// Close closes the file, rendering it unusable for I/O.
func (f *secFileImpl) Close() error {
	if f == nil || f.impl == nil {
		return ErrFileNotOpen
	}

	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return ErrFileClosed
	}

	err := f.impl.Close()
	f.closed = true

	return err
}

// Size returns the current size of the decrypted data.
func (f *secFileImpl) Size() int64 {
	if f == nil || f.impl == nil {
		return 0
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return 0
	}

	return f.impl.Size()
}

// Truncate changes the size of the file.
func (f *secFileImpl) Truncate(size int64) error {
	if f == nil || f.impl == nil {
		return ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return ErrFileClosed
	}

	return f.impl.Truncate(size)
}

// Stat returns the FileInfo structure describing file.
func (f *secFileImpl) Stat() (fs.FileInfo, error) {
	if f == nil || f.impl == nil {
		return nil, ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return nil, ErrFileClosed
	}

	// Create a FileInfo with current file information
	info := &fileInfoImpl{
		name: f.relativeViewPath.String(),
		size: f.impl.Size(),
		mode: f.mode,
	}

	return info, nil
}

// ==================== ISecFilePlus Interface Methods ====================

// Mode returns the file mode (permissions).
func (f *secFileImpl) Mode() os.FileMode {
	if f == nil {
		return 0
	}
	return f.mode
}

// RelativeViewPath returns the relative path from the user's perspective.
func (f *secFileImpl) RelativeViewPath() RelativeViewPath {
	if f == nil {
		return ""
	}
	return f.relativeViewPath
}

// FullStorePath returns the full path from the storage perspective.
func (f *secFileImpl) FullStorePath() FullStorePath {
	if f == nil {
		return ""
	}
	return f.fullStorePath
}

// IsClosed returns true if the file has been closed.
func (f *secFileImpl) IsClosed() bool {
	if f == nil {
		return true
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	return f.closed
}

// Sync commits the current contents of the file to stable storage.
func (f *secFileImpl) Sync() error {
	if f == nil || f.impl == nil {
		return ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return ErrFileClosed
	}

	return f.impl.Sync()
}

// ==================== fileInfoImpl Implementation ====================

// fileInfoImpl implements fs.FileInfo interface.
type fileInfoImpl struct {
	name string
	size int64
	mode os.FileMode
}

func (fi *fileInfoImpl) Name() string       { return fi.name }
func (fi *fileInfoImpl) Size() int64        { return fi.size }
func (fi *fileInfoImpl) Mode() fs.FileMode  { return fi.mode }
func (fi *fileInfoImpl) ModTime() time.Time { return time.Time{} }
func (fi *fileInfoImpl) IsDir() bool        { return fi.mode.IsDir() }
func (fi *fileInfoImpl) Sys() any           { return nil }

// ReadAt reads len(p) bytes from the file starting at byte offset off.
// It returns the number of bytes read and any error encountered.
func (f *secFileImpl) ReadAt(p []byte, off int64) (n int, err error) {
	if f == nil || f.impl == nil {
		return 0, ErrFileNotOpen
	}

	f.mu.RLock()
	defer f.mu.RUnlock()

	if f.closed {
		return 0, ErrFileClosed
	}

	return f.impl.ReadAt(p, off)
}

// WriteAt writes len(p) bytes to the file starting at byte offset off.
// It returns the number of bytes written and any error encountered.
func (f *secFileImpl) WriteAt(p []byte, off int64) (n int, err error) {
	if f == nil || f.impl == nil {
		return 0, ErrFileNotOpen
	}

	f.mu.Lock()
	defer f.mu.Unlock()

	if f.closed {
		return 0, ErrFileClosed
	}

	return f.impl.WriteAt(p, off)
}
