// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains the secRootImpl implementation that manages the secure root directory.
package sec_fs

import (
	"time"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)
// secRootImpl implements ISecRoot interface.
// It manages the root directory for encrypted file storage.
type secRootImpl struct {
	// factory is the cryptographic data factory used to create cryptor contexts.
	factory crypto_data.ICryptoDataFactory
	// rootPath is the full storage path of the root directory.
	rootPath FullStorePath
	// keyInfo provides key information for encryption/decryption.
	keyInfo crypto_hkdf.IKeyInfo
	// cfg provides algorithm-specific configuration.
	cfg config.SharedConfig
	// closed indicates whether the root has been closed.
	closed bool
	// mu protects the closed field from concurrent access.
	mu sync.RWMutex
	// nameCryptor provides name encryption/decryption for file and directory names.
	nameCryptor crypto_name.INameCryptorContext
	// ignoreMatcher provides ignore logic for file names.
	ignoreMatcher IIgnoreMatcher
}
// ==================== ISecRoot Interface Methods ====================
// OpenFile opens a file at the given relative view path with the specified mode.

// Open opens the named file. Implements fs.FS interface.
// This method provides read-only access to files in the secure root.
func (r *secRootImpl) Open(name string) (fs.File, error) {
	if r == nil {
		return nil, ErrRootIsNil
	}

	r.mu.RLock()
	defer r.mu.RUnlock()

	if r.closed {
		return nil, ErrRootClosed
	}

	// Convert name to RelativeViewPath
	path := RelativeViewPath(name)

	// Open file in read-only mode
	file, err := r.OpenFile(path, os.O_RDONLY)
	if err != nil {
		return nil, err
	}

	return file, nil
}

// It creates a cryptographic context for the file and returns an ISecFile interface.
func (r *secRootImpl) OpenFile(path RelativeViewPath, mode int) (ISecFile, error) {
	if r == nil {
		return nil, ErrRootClosed
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return nil, ErrRootClosed
	}
	// Build the full storage path
	fullPath := filepath.Join(string(r.rootPath), string(path))
	// Ensure parent directory exists for write operations
	if mode&os.O_WRONLY != 0 || mode&os.O_RDWR != 0 || mode&os.O_CREATE != 0 {
		parentDir := filepath.Dir(fullPath)
		if err := os.MkdirAll(parentDir, 0755); err != nil {
			return nil, NewPathError("mkdir", parentDir, err)
		}
	}
	// Open or create the underlying file
	file, err := os.OpenFile(fullPath, mode, 0644)
	if err != nil {
		return nil, NewPathError("open", fullPath, err)
	}
	// Create a cryptographic context for the file
	cryptorContext, err := r.factory.NewContext(&fileContext{File: file}, r.keyInfo, r.cfg)
	if err != nil {
		file.Close()
		return nil, NewCryptoError("new_context", "failed to create cryptor context", err)
	}
	// Create and return the secFileImpl
	secFile := &secFileImpl{
		impl:             cryptorContext,
		relativeViewPath: path,
		
	}
	return secFile, nil
}
// Close closes the root and releases all resources.
// After calling Close, all operations on the root will return ErrRootClosed.
func (r *secRootImpl) Close() error {
	if r == nil {
		return nil
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.closed {
		return nil
	}
	r.closed = true
	return nil
}
// DeleteFile deletes a file at the given relative view path.
// It returns an error if the file does not exist or cannot be deleted.
func (r *secRootImpl) DeleteFile(path RelativeViewPath) error {
	if r == nil {
		return ErrRootClosed
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return ErrRootClosed
	}
	fullPath := filepath.Join(string(r.rootPath), string(path))
	err := os.Remove(fullPath)
	if err != nil {
		return NewPathError("remove", fullPath, err)
	}
	return nil
}
// FileExists checks if a file exists at the given relative view path.
func (r *secRootImpl) FileExists(path RelativeViewPath) bool {
	if r == nil {
		return false
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return false
	}
	fullPath := filepath.Join(string(r.rootPath), string(path))
	_, err := os.Stat(fullPath)
	return err == nil
}
// MkdirAll creates a directory named path, along with any necessary parents.
func (r *secRootImpl) MkdirAll(path RelativeViewPath) error {
	if r == nil {
		return ErrRootClosed
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return ErrRootClosed
	}
	fullPath := filepath.Join(string(r.rootPath), string(path))
	return os.MkdirAll(fullPath, 0755)
}
// WalkDir returns a directory walker for the given path.
func (r *secRootImpl) WalkDir(path RelativeViewPath, opts ...WalkOption) (IDirWalker, error) {
	if r == nil {
		return nil, ErrRootClosed
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return nil, ErrRootClosed
	}

	// Create walker using factory function
	walker := newSecDirWalker(r.rootPath, path, r.nameCryptor, r.ignoreMatcher, opts...)

	if err := walker.init(); err != nil {
		return nil, err
	}
	return walker, nil
}
// GetRootPath returns the root path of the secure storage.

// ReadDir reads the named directory and returns a list of directory entries.
// Implements fs.ReadDirFS interface.
func (r *secRootImpl) ReadDir(name string) ([]fs.DirEntry, error) {
	if r == nil {
		return nil, ErrRootIsNil
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return nil, ErrRootClosed
	}

	// Create walker using factory function
	walker := newSecDirWalker(r.rootPath, RelativeViewPath(name), r.nameCryptor, r.ignoreMatcher)

	if err := walker.init(); err != nil {
		return nil, err
	}
	defer walker.Close()

	// Read all entries
	var entries []fs.DirEntry
	for {
		entry, err := walker.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		// Create fs.DirEntry adapter
		entries = append(entries, &dirEntryAdapter{
			name:    entry.Name,
			isDir:   entry.IsDir,
			size:    entry.Size,
			modTime: time.Unix(0, entry.ModTime),
			mode:    entry.Mode,
		})
	}

	return entries, nil
}

// dirEntryAdapter implements fs.DirEntry interface
type dirEntryAdapter struct {
	name    string
	isDir   bool
	size    int64
	modTime time.Time
	mode    os.FileMode
}

func (d *dirEntryAdapter) Name() string      { return d.name }
func (d *dirEntryAdapter) IsDir() bool       { return d.isDir }
func (d *dirEntryAdapter) Type() fs.FileMode { return d.mode.Type() }
func (d *dirEntryAdapter) Info() (fs.FileInfo, error) {
	return &fileInfoAdapter{
		name:    d.name,
		size:    d.size,
		modTime: d.modTime,
		mode:    d.mode,
	}, nil
}

// fileInfoAdapter implements fs.FileInfo interface
type fileInfoAdapter struct {
	name    string
	size    int64
	modTime time.Time
	mode    os.FileMode
}

func (f *fileInfoAdapter) Name() string       { return f.name }
func (f *fileInfoAdapter) Size() int64        { return f.size }
func (f *fileInfoAdapter) Mode() fs.FileMode  { return f.mode }
func (f *fileInfoAdapter) ModTime() time.Time { return f.modTime }
func (f *fileInfoAdapter) IsDir() bool        { return f.mode.IsDir() }
func (f *fileInfoAdapter) Sys() interface{}   { return nil }
func (r *secRootImpl) GetRootPath() FullStorePath {
	if r == nil {
		return ""
	}
	return r.rootPath
}
// GetConfig returns the shared configuration.
func (r *secRootImpl) GetConfig() config.SharedConfig {
	if r == nil {
		return nil
	}
	return r.cfg
}
