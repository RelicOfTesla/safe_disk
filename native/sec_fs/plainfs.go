// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains PlainFS - a plain (non-encrypted) file system wrapper that implements ISecRoot.
// PlainFS is used for converting between plain directories and encrypted directories.
package sec_fs

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/config"
)

// PlainFS is a plain (non-encrypted) file system wrapper.
// It implements ISecRoot interface but performs no encryption/decryption.
// Use PlainFS for:
//   - Initialize encryption: PlainFS (source) -> SecFS (destination)
//   - Final decryption: SecFS (source) -> PlainFS (destination)
type PlainFS struct {
	rootPath string
	closed   bool
	mu       sync.RWMutex
}

// NewPlainFS creates a new PlainFS instance for the given root path.
// The root path must be an absolute path to an existing directory.
// PlainFS implements ISecRoot but performs no encryption/decryption.
func NewPlainFS(rootPath string) (ISecRoot, error) {
	// Validate path
	absPath, err := filepath.Abs(rootPath)
	if err != nil {
		return nil, NewFullStorePathError("abs", FullStorePath(rootPath), err)
	}

	// Check if directory exists
	info, err := os.Stat(absPath)
	if err != nil {
		return nil, NewFullStorePathError("stat", FullStorePath(absPath), err)
	}
	if !info.IsDir() {
		return nil, NewFullStorePathError("not_dir", FullStorePath(absPath), os.ErrNotExist)
	}

	return &PlainFS{
		rootPath: absPath,
		closed:   false,
	}, nil
}

// ==================== fs.FS Interface ====================

// Open opens the named file. Implements fs.FS interface.
func (p *PlainFS) Open(name string) (fs.File, error) {
	if p == nil {
		return nil, ErrRootIsNil
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return nil, ErrRootClosed
	}

	// Use OpenFile with read-only mode
	return p.OpenFile(RelativeViewPath(name), os.O_RDONLY)
}

// ==================== fs.ReadDirFS Interface ====================

// ReadDir reads the named directory and returns a list of directory entries.
// Implements fs.ReadDirFS interface.
func (p *PlainFS) ReadDir(name string) ([]fs.DirEntry, error) {
	if p == nil {
		return nil, ErrRootIsNil
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return nil, ErrRootClosed
	}

	fullPath := filepath.Join(p.rootPath, name)
	entries, err := os.ReadDir(fullPath)
	if err != nil {
		return nil, err
	}

	// Convert to our wrapper type
	result := make([]fs.DirEntry, len(entries))
	for i, entry := range entries {
		result[i] = &plainDirEntry{
			DirEntry:     entry,
			relativePath: RelativeViewPath(filepath.Join(name, entry.Name())),
		}
	}

	return result, nil
}

// ==================== ISecRoot Interface ====================

// OpenFile opens a file at the given relative view path with the specified mode.
func (p *PlainFS) OpenFile(path RelativeViewPath, mode int) (ISecFile, error) {
	if p == nil {
		return nil, ErrRootIsNil
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return nil, ErrRootClosed
	}

	// Build full path
	fullPath := filepath.Join(p.rootPath, string(path))

	// Ensure parent directory exists for write operations
	if mode&os.O_WRONLY != 0 || mode&os.O_RDWR != 0 || mode&os.O_CREATE != 0 {
		parentDir := filepath.Dir(fullPath)
		if err := os.MkdirAll(parentDir, 0755); err != nil {
			return nil, NewFullStorePathError("mkdir", FullStorePath(parentDir), err)
		}
	}

	// Open or create the file
	file, err := os.OpenFile(fullPath, mode, 0644)
	if err != nil {
		return nil, NewPairPathError("open", path, FullStorePath(fullPath), err)
	}

	// Return wrapped file
	return &plainFile{
		File:          file,
		relativePath:  path,
		fullStorePath: FullStorePath(fullPath),
	}, nil
}

// Close closes the root and releases all resources.
func (p *PlainFS) Close() error {
	if p == nil {
		return nil
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed {
		return nil
	}

	p.closed = true
	return nil
}

// DeleteFile deletes a file at the given relative view path.
func (p *PlainFS) DeleteFile(path RelativeViewPath) error {
	if p == nil {
		return ErrRootClosed
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return ErrRootClosed
	}

	fullPath := filepath.Join(p.rootPath, string(path))
	err := os.Remove(fullPath)
	if err != nil {
		return NewPairPathError("remove", path, FullStorePath(fullPath), err)
	}
	return nil
}

// FileExists checks if a file exists at the given relative view path.
func (p *PlainFS) FileExists(path RelativeViewPath) bool {
	if p == nil {
		return false
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return false
	}

	fullPath := filepath.Join(p.rootPath, string(path))
	_, err := os.Stat(fullPath)
	return err == nil
}

// MkdirAll creates a directory named path, along with any necessary parents.
func (p *PlainFS) MkdirAll(path RelativeViewPath) error {
	if p == nil {
		return ErrRootClosed
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return ErrRootClosed
	}

	fullPath := filepath.Join(p.rootPath, string(path))
	return os.MkdirAll(fullPath, 0755)
}

// Rename renames a file or directory from oldPath to newPath.
// This operation is atomic at the file system level.
func (p *PlainFS) Rename(oldPath RelativeViewPath, newPath RelativeViewPath) error {
	if p == nil {
		return ErrRootClosed
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return ErrRootClosed
	}

	oldFullPath := filepath.Join(p.rootPath, string(oldPath))
	newFullPath := filepath.Join(p.rootPath, string(newPath))

	err := os.Rename(oldFullPath, newFullPath)
	if err != nil {
		return NewPairPathError("rename", oldPath, FullStorePath(oldFullPath), err)
	}
	return nil
}

// WalkDir returns a directory walker for the given path.
func (p *PlainFS) WalkDir(path RelativeViewPath, opts ...WalkOption) (IDirWalker, error) {
	if p == nil {
		return nil, ErrRootClosed
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return nil, ErrRootClosed
	}

	// Create walker for plain directory
	walker := newPlainDirWalker(p.rootPath, path, opts...)
	if err := walker.init(); err != nil {
		return nil, err
	}
	return walker, nil
}

// GetRootPath returns the root path of the plain storage.
func (p *PlainFS) GetRootPath() FullStorePath {
	if p == nil {
		return ""
	}
	return FullStorePath(p.rootPath)
}

// GetConfig returns nil for PlainFS as it has no encryption config.
func (p *PlainFS) GetConfig() config.SharedConfig {
	return nil
}

// Stat returns a FileInfo describing the named file.
func (p *PlainFS) Stat(path RelativeViewPath) (fs.FileInfo, error) {
	if p == nil {
		return nil, ErrRootIsNil
	}

	p.mu.RLock()
	defer p.mu.RUnlock()

	if p.closed {
		return nil, ErrRootClosed
	}

	fullPath := filepath.Join(p.rootPath, string(path))
	return os.Stat(fullPath)
}

// ==================== plainFile - ISecFile implementation ====================

// plainFile implements ISecFile for plain files (no encryption).
type plainFile struct {
	*os.File
	relativePath  RelativeViewPath
	fullStorePath FullStorePath
}

// Size returns the current size of the file.
func (f *plainFile) Size() int64 {
	info, err := f.File.Stat()
	if err != nil {
		return 0
	}
	return info.Size()
}

// Truncate changes the size of the file.
func (f *plainFile) Truncate(size int64) error {
	return f.File.Truncate(size)
}

// Mode returns the file mode (permissions).
func (f *plainFile) Mode() os.FileMode {
	info, err := f.File.Stat()
	if err != nil {
		return 0
	}
	return info.Mode()
}

// RelativeViewPath returns the relative path from the user's perspective.
func (f *plainFile) RelativeViewPath() RelativeViewPath {
	return f.relativePath
}

// FullStorePath returns the full path from the storage perspective.
func (f *plainFile) FullStorePath() FullStorePath {
	return f.fullStorePath
}

// IsClosed returns true if the file has been closed.
func (f *plainFile) IsClosed() bool {
	return f.File == nil
}

// Sync commits the current contents of the file to stable storage.
func (f *plainFile) Sync() error {
	return f.File.Sync()
}

// ==================== plainDirEntry - IDirEntry implementation ====================

// plainDirEntry implements IDirEntry for plain directory entries.
type plainDirEntry struct {
	fs.DirEntry
	relativePath RelativeViewPath
}

// GetRelativeViewPath returns the relative view path.
func (e *plainDirEntry) GetRelativeViewPath() RelativeViewPath {
	return e.relativePath
}

// GetRelativeStorePath returns the same as GetRelativeViewPath for plain files.
func (e *plainDirEntry) GetRelativeStorePath() RelativeStorePath {
	return RelativeStorePath(e.relativePath)
}

// StoreName returns the plain file name (no encryption).
func (e *plainDirEntry) StoreName() string {
	return e.Name()
}

// ==================== plainDirWalker - IDirWalker implementation ====================

// plainDirWalker implements IDirWalker for plain directories.
type plainDirWalker struct {
	rootPath      string
	startPath     RelativeViewPath
	entries       []IDirEntry
	index         int
	options       WalkOptions
	recursive     bool
	maxDepth      int
	currentDepth  int
}

// newPlainDirWalker creates a new plain directory walker.
func newPlainDirWalker(rootPath string, startPath RelativeViewPath, opts ...WalkOption) *plainDirWalker {
	options := WalkOptions{
		Recursive: true,
		MaxDepth:  0,
	}
	for _, opt := range opts {
		opt(&options)
	}

	return &plainDirWalker{
		rootPath:  rootPath,
		startPath: startPath,
		options:   options,
		recursive: options.Recursive,
		maxDepth:  options.MaxDepth,
	}
}

// init initializes the walker by collecting all entries.
func (w *plainDirWalker) init() error {
	startFullPath := filepath.Join(w.rootPath, string(w.startPath))
	return w.walkDir(startFullPath, string(w.startPath), 0)
}

// walkDir recursively walks the directory and collects entries.
func (w *plainDirWalker) walkDir(fullPath, relativePath string, depth int) error {
	entries, err := os.ReadDir(fullPath)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		relPath := filepath.Join(relativePath, entry.Name())
		idirEntry := &plainDirEntry{
			DirEntry:     entry,
			relativePath: RelativeViewPath(relPath),
		}

		// Skip files if configured
		if w.options.SkipFiles && !entry.IsDir() {
			continue
		}

		// Skip directories if configured
		if w.options.SkipDirs && entry.IsDir() {
			continue
		}

		w.entries = append(w.entries, idirEntry)

		// Recurse into subdirectories
		if entry.IsDir() && w.recursive {
			// Check max depth
			if w.maxDepth > 0 && depth >= w.maxDepth {
				continue
			}

			childFullPath := filepath.Join(fullPath, entry.Name())
			if err := w.walkDir(childFullPath, relPath, depth+1); err != nil {
				return err
			}
		}
	}

	return nil
}

// Next returns the next directory entry.
func (w *plainDirWalker) Next() (IDirEntry, error) {
	if w.index >= len(w.entries) {
		return nil, io.EOF
	}

	entry := w.entries[w.index]
	w.index++
	return entry, nil
}

// NextBatch returns the next batch of directory entries.
func (w *plainDirWalker) NextBatch(batchSize int) ([]IDirEntry, error) {
	if w.index >= len(w.entries) {
		return nil, io.EOF
	}

	end := w.index + batchSize
	if end > len(w.entries) {
		end = len(w.entries)
	}

	batch := w.entries[w.index:end]
	w.index = end
	return batch, nil
}

// HasNext returns true if there are more entries to read.
func (w *plainDirWalker) HasNext() bool {
	return w.index < len(w.entries)
}

// Close closes the walker and releases any associated resources.
func (w *plainDirWalker) Close() error {
	w.entries = nil
	return nil
}

// ==================== Compile-time Interface Verification ====================

var _ ISecRoot = (*PlainFS)(nil)
var _ ISecFile = (*plainFile)(nil)
var _ IDirEntry = (*plainDirEntry)(nil)
var _ IDirWalker = (*plainDirWalker)(nil)
