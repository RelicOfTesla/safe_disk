// Package sec_fs provides a secure file system implementation with encryption support.
// This package is designed to be independently usable without FFI dependencies.
package sec_fs

import (
	"io"
	"io/fs"
	"os"
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
}

// IDirWalker defines the interface for iterating over directory entries.
type IDirWalker interface {
	// Next returns the next directory entry.
	// Returns ErrNoMoreEntries when there are no more entries.
	Next() (DirEntry, error)
	
	// NextBatch returns the next batch of directory entries.
	NextBatch(batchSize int) ([]DirEntry, error)
	
	// HasNext returns true if there are more entries to read.
	HasNext() bool
	
	// Close closes the walker and releases any associated resources.
	Close() error
}

// ISecRootInfo provides information about a secure root.
type ISecRootInfo interface {
	// GetRootPath returns the full store path of the root directory.
	GetRootPath() FullStorePath
	
	// GetConfig returns the current configuration as JSON.
	GetConfig() string
	
	// IsOpen returns true if the root is currently open.
	IsOpen() bool
}

// ==================== Helper Types ====================

// DirEntry represents a directory entry (file or subdirectory).
type DirEntry struct {
	// Name is the base name of the file or directory.
	Name string
	
	// IsDir reports whether the entry is a directory.
	IsDir bool
	
	// Size is the size in bytes for files; 0 for directories.
	Size int64
	
	// ModTime is the modification time.
	ModTime int64 // Unix timestamp in nanoseconds
	
	// Mode is the file mode (permissions).
	Mode os.FileMode
	
	// RelativePath is the relative view path from the root.
	RelativePath RelativeViewPath
}

// WalkOption is a functional option for configuring directory walking.
type WalkOption func(*WalkOptions)

// WalkOptions holds configuration options for directory walking.
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

// ==================== Compile-time Interface Verification ====================

// These declarations ensure that the implementation types satisfy the interfaces.
// The actual implementation types will be defined in separate files.
var (
	_ ISecFile     = (*secFileImpl)(nil)
	_ ISecFilePlus = (*secFileImpl)(nil)
	_ ISecRoot     = (*secRootImpl)(nil)
	_ IDirWalker   = (*secDirWalker)(nil)
)

// ==================== Path Types ====================

// RelativeViewPath represents a relative path from the user's perspective within RootDir.
// This is the path that users interact with when navigating the encrypted file system.
// Example: "documents/report.pdf"
type RelativeViewPath string

// FullViewPath represents a complete absolute path from the user's perspective.
// This includes the full path to a file or directory within the view layer.
// Example: "/data/safe_disk_root/documents/report.pdf"
type FullViewPath string

// RelativeStorePath represents a relative path from the storage perspective.
// This path reflects the actual stored file name, which may be encrypted or in plain text.
// Example: "a1b2c3d4e5f6..." (encrypted file name)
type RelativeStorePath string

// FullStorePath represents a complete absolute path from the storage perspective.
// This is the actual path on disk where the encrypted or unencrypted data is stored.
// Example: "/data/safe_disk_root/a1b2c3d4e5f6..."
type FullStorePath string

// String returns the string representation of RelativeViewPath.
func (p RelativeViewPath) String() string {
	return string(p)
}

// String returns the string representation of FullViewPath.
func (p FullViewPath) String() string {
	return string(p)
}

// String returns the string representation of RelativeStorePath.
func (p RelativeStorePath) String() string {
	return string(p)
}

// String returns the string representation of FullStorePath.
func (p FullStorePath) String() string {
	return string(p)
}

// IsEmpty returns true if the RelativeViewPath is empty.
func (p RelativeViewPath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the FullViewPath is empty.
func (p FullViewPath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the RelativeStorePath is empty.
func (p RelativeStorePath) IsEmpty() bool {
	return string(p) == ""
}

// IsEmpty returns true if the FullStorePath is empty.
func (p FullStorePath) IsEmpty() bool {
	return string(p) == ""
}
