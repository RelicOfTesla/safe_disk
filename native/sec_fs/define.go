package sec_fs

import (
	"io"
	"io/fs"
	"os"

	"github.com/safedisk/native/sec_fs/crypto"
)

// ==================== Path Types ====================
// Path types provide type safety for different path representations.
// All path parameters should use these types instead of plain string.

// RelativeViewPath is a relative path from user's perspective (relative to RootDir).
// Example: "documents/report.pdf"
type RelativeViewPath string

// FullViewPath is an absolute path from user's perspective.
// Example: "/data/safe_disk_root/documents/report.pdf"
type FullViewPath string

// RelativeStorePath is a relative path from storage perspective (encrypted or plaintext).
// Example: "a1b2c3d4e5f6..."
type RelativeStorePath string

// FullStorePath is an absolute path from storage perspective.
// Example: "/data/safe_disk_root/a1b2c3d4e5f6..."
type FullStorePath string

// ==================== Core Interfaces ====================

// ISecReadWriter combines basic I/O interfaces.
type ISecReadWriter interface {
	io.ReadWriteCloser
	io.Seeker
}

// ISecFile is the core interface for encrypted file operations.
// It satisfies io.Reader, io.Writer, io.Seeker, and fs.File interfaces.
//
// Usage:
//
//	f, err := root.OpenFile("document.txt", "r")
//	if err != nil { log.Fatal(err) }
//	defer f.Close()
//
//	// Read all content
//	data, err := io.ReadAll(f)
//
//	// Or use ReadSize for convenience (returns allocated buffer)
//	data, n, err := f.ReadSize(1024)
type ISecFile interface {
	io.Reader       // Read(p []byte) (n int, err error)
	io.Writer       // Write(p []byte) (n int, err error)
	io.Seeker       // Seek(offset int64, whence int) (int64, error)
	fs.File         // Stat() (FileInfo, error) + Close() error

	// Size returns the decrypted file size in bytes.
	Size() int64

	// Truncate truncates the file to the specified size.
	Truncate(size int64) error

	// ===== Convenience Methods (from original ISecFile) =====

	// ReadSize reads up to size bytes and returns an allocated buffer.
	// If size <= 0, reads all remaining data.
	// This is a convenience method; prefer Read(p []byte) for io.Reader compatibility.
	ReadSize(size int) (data []byte, n int, err error)

	// ReadAll reads all remaining data from the file.
	// This is a convenience method; prefer io.ReadAll(f) for standard usage.
	ReadAll() ([]byte, error)

	// WriteString writes a string to the file.
	WriteString(s string) (int, error)

	// Tell returns the current file position.
	Tell() (int64, error)

	// Rewind resets the position to the start of the file.
	Rewind() error

	// Sync flushes changes to the encrypted file.
	Sync() error

	// IsClosed returns true if the file is closed.
	IsClosed() bool

	// Mode returns the open mode ("r", "w", or "a").
	Mode() string

	// Path returns the file path.
	Path() string

	// ReadAt reads data at a specific offset without changing the file position.
	ReadAt(offset int64, size int) ([]byte, error)

	// WriteAt writes data at a specific offset without changing the file position.
	WriteAt(offset int64, data []byte) (int, error)

	// Append appends data to the end of the file.
	Append(data []byte) (int, error)

	// AppendString appends a string to the end of the file.
	AppendString(s string) (int, error)

	// StatDetail returns detailed file status including position.
	// This provides more information than the standard Stat() method.
	StatDetail() (*SecFileStat, error)
}

// ISecFilePlus extends ISecFile with additional metadata methods.
// It provides path information in both view and store perspectives.
type ISecFilePlus interface {
	ISecFile

	// FileMode returns the file mode (permissions).
	FileMode() os.FileMode

	// RelativeViewPath returns the path relative to the root directory (user perspective).
	RelativeViewPath() RelativeViewPath

	// FullStorePath returns the absolute storage path (storage perspective).
	FullStorePath() FullStorePath
}

// IDirWalker provides directory traversal for encrypted file systems.
// It iterates over directory entries without decrypting file contents.
//
// Usage:
//
//	walker, err := root.WalkDir("documents", nil)
//	if err != nil { log.Fatal(err) }
//	defer walker.Close()
//
//	for walker.HasNext() {
//		entry, err := walker.Next()
//		if err != nil { log.Fatal(err) }
//		fmt.Println(entry.Name)
//	}
type IDirWalker interface {
	// Next returns the next directory entry.
	// Returns nil, nil when there are no more entries.
	Next() (*SecDirEntry, error)

	// NextBatch returns the next batch of entries.
	// If batchSize <= 0, returns all remaining entries.
	NextBatch(batchSize int) ([]*SecDirEntry, error)

	// HasNext returns true if there are more entries.
	HasNext() bool

	// Close closes the walker and releases resources.
	Close() error

	// Reset resets the walker to the beginning.
	Reset() error

	// Count returns the total number of entries.
	Count() int

	// Remaining returns the number of remaining entries.
	Remaining() int

	// IsClosed returns true if the walker is closed.
	IsClosed() bool

	// Path returns the directory path being walked.
	Path() string

	// WalkAll returns all entries.
	WalkAll() ([]*SecDirEntry, error)

	// CollectFiles returns all file entries.
	CollectFiles() ([]*SecDirEntry, error)

	// CollectDirs returns all directory entries.
	CollectDirs() ([]*SecDirEntry, error)

	// Stats returns walker statistics.
	Stats() map[string]interface{}
}

// IFileInfo is an alias for fs.FileInfo.
type IFileInfo interface {
	fs.FileInfo
}

// IDirEntry is an alias for fs.DirEntry.
type IDirEntry interface {
	fs.DirEntry
}

// ISecRoot is the interface for managing an encrypted root directory.
// It provides file operations, directory traversal, and configuration management.
//
// Usage:
//
//	root, err := OpenRoot("/path/to/vault", "password", nil)
//	if err != nil { log.Fatal(err) }
//	defer root.Close()
//
//	// File operations
//	f, err := root.OpenFile("secret.txt", "r")
//	data, err := root.ReadFile("secret.txt")
//
//	// Directory traversal
//	walker, err := root.WalkDir("documents", nil)
type ISecRoot interface {
	// Close closes the root and releases resources.
	// For session-based roots, this also closes the session.
	Close() error

	// ChangePass changes the password for the encrypted root.
	// This only works if the root was created with mutable=true.
	ChangePass(newPass string) error

	// GetInfo returns information about the root.
	GetInfo() (*SecRootInfo, error)

	// GetSessionID returns the session ID (0 for direct mode).
	GetSessionID() int64

	// GetRootPath returns the root directory path.
	GetRootPath() FullStorePath

	// ==================== File Operations ====================

	// OpenFile opens an encrypted file for reading or writing.
	// Mode: "r" (read), "w" (write), "a" (append).
	OpenFile(path RelativeViewPath, mode string) (ISecFile, error)

	// ReadFile reads an entire file at once.
	ReadFile(path RelativeViewPath) ([]byte, error)

	// WriteFile writes an entire file at once.
	// Creates parent directories if needed.
	WriteFile(path RelativeViewPath, data []byte) error

	// DeleteFile deletes a file.
	DeleteFile(path RelativeViewPath) error

	// StatFile returns detailed file information.
	StatFile(path RelativeViewPath) (*SecFileInfo, error)

	// FileExists checks if a file exists.
	FileExists(path RelativeViewPath) bool

	// ==================== Directory Operations ====================

	// MkdirAll creates a directory and all parent directories.
	MkdirAll(path RelativeViewPath) error

	// ReadDir reads a directory and returns entries.
	// The entries are NOT decrypted; they represent the encrypted file system view.
	ReadDir(path RelativeViewPath) ([]os.DirEntry, error)

	// WalkDir creates a directory walker for traversing entries.
	WalkDir(path RelativeViewPath, opt *WalkOpt) (IDirWalker, error)

	// ==================== Advanced Operations ====================

	// GetCryptorMaker returns the cryptor maker for custom operations.
	// Advanced users can use this to create custom encryptors/decryptors.
	GetCryptorMaker() crypto.ICryptorMaker
}

// ==================== Compile-time Interface Verification ====================
// These assertions ensure that our implementations satisfy the interfaces.
// If a type doesn't implement an interface, the compiler will fail.

var (
	_ ISecFile    = (*secFileImpl)(nil)
	_ IDirWalker  = (*secDirWalker)(nil)
	_ ISecRoot    = (*secRootImpl)(nil)
)
