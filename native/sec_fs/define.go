// Package sec_fs provides a secure file system implementation with encryption support.
// This package is designed to be independently usable without FFI dependencies.
package sec_fs

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"time"

	"safe_disk/native/config"
)

// ==================== Core Interfaces ====================

// ISecFile defines the interface for a secure file with encryption support.
// It combines standard file operations with encryption capabilities.
type ISecFile interface {
	io.Reader
	io.Writer
	io.Seeker
	fs.File // includes Close() error and Stat() (FileInfo, error)

	// Size returns the current size of the file.
	Size() int64

	// Truncate changes the size of the file.
	Truncate(size int64) error
}

// ISecFilePlus extends ISecFile with additional metadata and utility methods.
type ISecFilePlus interface {
	ISecFile

	// Mode returns the file mode (permissions).
	Mode() os.FileMode

	// RelativeViewPath returns the relative path from the user's perspective.
	RelativeViewPath() RelativeViewPath

	// FullStorePath returns the full path from the storage perspective.
	FullStorePath() FullStorePath

	// IsClosed returns true if the file has been closed.
	IsClosed() bool

	// Sync commits the current contents of the file to stable storage.
	Sync() error
}

// ISecRoot defines the interface for a secure root directory.
type ISecRoot interface {
	// Open opens the named file. Implements fs.FS interface.
	// When implementing fs.FS, Open returns a file that can be used for reading.
	fs.FS
	fs.ReadDirFS

	// OpenFile opens a file at the given relative view path with the specified mode.
	OpenFile(path RelativeViewPath, mode int) (ISecFile, error)

	// Close closes the root and releases any associated resources.
	Close() error

	// DeleteFile deletes the file at the given relative view path.
	DeleteFile(path RelativeViewPath) error

	// FileExists returns true if a file exists at the given relative view path.
	FileExists(path RelativeViewPath) bool

	// MkdirAll creates a directory named path, along with any necessary parents.
	MkdirAll(path RelativeViewPath) error

	// WalkDir returns a directory walker for the given path.
	WalkDir(path RelativeViewPath, opts ...WalkOption) (IDirWalker, error)

	// Rename renames a file or directory from oldPath to newPath.
	// Both paths are relative view paths (encrypted names).
	// This operation handles encrypted file names internally.
	Rename(oldPath RelativeViewPath, newPath RelativeViewPath) error

	// GetRootPath returns the full store path of the root directory.
	GetRootPath() FullStorePath

	// GetConfig returns the current configuration.
	GetConfig() config.SharedConfig
}

// IDirWalker defines the interface for iterating over directory entries.
type IDirWalker interface {
	// Next returns the next directory entry.
	// Returns ErrNoMoreEntries when there are no more entries.
	Next() (IDirEntry, error)

	// NextBatch returns the next batch of directory entries.
	NextBatch(batchSize int) ([]IDirEntry, error)

	// HasNext returns true if there are more entries to read.
	HasNext() bool

	// Close closes the walker and releases any associated resources.
	Close() error
}

// DirEntry represents a directory entry (file or subdirectory).
type IDirEntry interface {
	fs.DirEntry

	// RelativePath is the relative view path from the root.
	GetRelativeViewPath() RelativeViewPath
	GetRelativeStorePath() RelativeStorePath

	// StoreName returns the encrypted file name as stored on disk.
	// This is the encrypted version of the file name, useful for debugging
	// and low-level operations.
	StoreName() string
}

// WalkOption is a functional option for configuring directory walking.
type WalkOption func(*WalkOptions)

// secDirEntry implements IDirEntry interface
type secDirEntry struct {
	name              string
	isDir             bool
	size              int64
	modTime           int64
	mode              os.FileMode
	relativeViewPath  RelativeViewPath
	relativeStorePath RelativeStorePath
}

// fs.DirEntry interface methods
func (e *secDirEntry) Name() string      { return e.name }
func (e *secDirEntry) IsDir() bool       { return e.isDir }
func (e *secDirEntry) Type() fs.FileMode { return e.mode.Type() }
func (e *secDirEntry) Info() (fs.FileInfo, error) {
	return &secFileInfo{
		name:    e.name,
		size:    e.size,
		modTime: time.Unix(0, e.modTime),
		mode:    e.mode,
	}, nil
}

// IDirEntry interface methods
func (e *secDirEntry) GetRelativeViewPath() RelativeViewPath  { return e.relativeViewPath }
func (e *secDirEntry) GetRelativeStorePath() RelativeStorePath { return e.relativeStorePath }

// StoreName returns the encrypted file name as stored on disk.
// Extracts the base name from the relative store path.
func (e *secDirEntry) StoreName() string {
	if e.relativeStorePath == "" {
		return ""
	}
	return filepath.Base(string(e.relativeStorePath))
}

// secFileInfo implements fs.FileInfo interface
type secFileInfo struct {
	name    string
	size    int64
	modTime time.Time
	mode    os.FileMode
}

func (f *secFileInfo) Name() string       { return f.name }
func (f *secFileInfo) Size() int64        { return f.size }
func (f *secFileInfo) Mode() fs.FileMode  { return f.mode }
func (f *secFileInfo) ModTime() time.Time { return f.modTime }
func (f *secFileInfo) IsDir() bool        { return f.mode.IsDir() }
func (f *secFileInfo) Sys() interface{}   { return nil }

// Compile-time interface verification
var _ IDirEntry = (*secDirEntry)(nil)
var _ fs.FileInfo = (*secFileInfo)(nil)


type WalkOptions struct {
	// Recursive indicates whether to walk subdirectories recursively.
	Recursive bool

	// MaxDepth limits the recursion depth (0 = unlimited).
	MaxDepth int

	// SkipFiles indicates whether to skip regular files.
	SkipFiles bool

	// SkipDirs indicates whether to skip directories.
	SkipDirs bool

	// IncludeHidden indicates whether to include hidden files/directories.
	IncludeHidden bool
}

// WithRecursive returns a WalkOption that enables recursive directory walking.
func WithRecursive() WalkOption {
	return func(opts *WalkOptions) {
		opts.Recursive = true
	}
}

// WithMaxDepth returns a WalkOption that sets the maximum recursion depth.
func WithMaxDepth(depth int) WalkOption {
	return func(opts *WalkOptions) {
		opts.MaxDepth = depth
	}
}

// WithSkipFiles returns a WalkOption that skips regular files.
func WithSkipFiles() WalkOption {
	return func(opts *WalkOptions) {
		opts.SkipFiles = true
	}
}

// WithSkipDirs returns a WalkOption that skips directories.
func WithSkipDirs() WalkOption {
	return func(opts *WalkOptions) {
		opts.SkipDirs = true
	}
}

// WithIncludeHidden returns a WalkOption that includes hidden files/directories.
func WithIncludeHidden() WalkOption {
	return func(opts *WalkOptions) {
		opts.IncludeHidden = true
	}
}

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that the implementation types satisfy the interfaces.
// The actual implementation types will be defined in separate files.
var (
	_ ISecFile     = (*secFileImpl)(nil)
	_ ISecFilePlus = (*secFileImpl)(nil)
	_ ISecRoot     = (*secRootImpl)(nil)
	_ IDirWalker   = (*secDirWalker)(nil)
)

// ==================== Ignore Matcher Interface ====================

// IIgnoreMatcher defines the interface for matching file names to ignore.
// This allows flexible ignore patterns (e.g., gitignore-style patterns).
type IIgnoreMatcher interface {
	// ShouldIgnore1 returns true if the file/directory should be ignored BEFORE name decryption.
	// Parameters:
	//   - encryptedName: the encrypted file or directory name (store name)
	//   - isDir: true if this is a directory
	// Returns: true if the entry should be ignored
	//
	// This is called before name decryption, allowing filtering based on encrypted name patterns.
	// Use this to skip files with specific encrypted name formats (e.g., config files with special prefixes).
	ShouldIgnore1(encryptedName string, isDir bool) bool

	// ShouldIgnore2 returns true if the file/directory should be ignored AFTER name decryption.
	// Parameters:
	//   - decryptedName: the decrypted file or directory name (view name)
	//   - isDir: true if this is a directory
	// Returns: true if the entry should be ignored
	//
	// This is called after name decryption, allowing filtering based on decrypted name patterns.
	// Use this to skip files with specific patterns (e.g., hidden files, temporary files).
	ShouldIgnore2(decryptedName string, isDir bool) bool
}

// ==================== WalkOptions Ignore Support ====================

// Compile-time interface verification
var _ fs.FS = (ISecRoot)(nil)
