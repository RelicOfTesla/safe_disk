package sec_fs

import (
	"io"
	"io/fs"
	"os"
)

type ISecReadWriter interface{
	io.ReadWriteCloser
	io.Seeker
	// TODO: more
}
type ISecFile interface{
	// Read reads up to size bytes from the file.
	// Returns the data and number of bytes read.
	// If size <= 0, reads all remaining data.
	Read(size int) ([]byte, int, error)
	
	// ReadAll reads all remaining data from the file.
	ReadAll() ([]byte, error)
	
	// Write writes data to the file.
	// Returns the number of bytes written.
	Write(data []byte) (int, error)
	
	// WriteString writes a string to the file.
	WriteString(s string) (int, error)
	
	// Seek sets the file position.
	Seek(offset int64, whence int) (int64, error)
	
	// Tell returns the current file position.
	Tell() (int64, error)
	
	// Rewind resets the position to the start of the file.
	Rewind() error
	
	// Truncate truncates the file to the specified size.
	Truncate(size int64) error
	
	// Sync flushes changes to the encrypted file.
	Sync() error
	
	// Close closes the file and writes changes if modified.
	Close() error
	
	// IsClosed returns true if the file is closed.
	IsClosed() bool
	
	// Size returns the file size.
	Size() int64
	
	// Mode returns the open mode.
	Mode() string
	
	// Path returns the file path.
	Path() string
	
	// ReadAt reads data at a specific offset.
	ReadAt(offset int64, size int) ([]byte, error)
	
	// WriteAt writes data at a specific offset.
	WriteAt(offset int64, data []byte) (int, error)
	
	// Append appends data to the end of the file.
	Append(data []byte) (int, error)
	
	// AppendString appends a string to the end of the file.
	AppendString(s string) (int, error)
	
	// Stat returns basic file status.
	Stat() (*SecFileStat, error)
}


//TODO:
//var _ ISecFile = (*SecFile)(nil)

type IDirWalker interface{
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

type IFileInfo interface{
	fs.FileInfo
}
type IDirEntry interface{
	fs.DirEntry
}

//TODO:
//var _ IDirWalker = (*SecDirWalker)(nil)

type ISecRoot interface{
	// Close closes the root and releases resources.
	Close() error
	
	// ChangePass changes the password for the encrypted root.
	ChangePass(newPass string) error
	
	// GetInfo returns information about the root.
	GetInfo() (*SecRootInfo, error)
	
	// GetSessionID returns the session ID (0 for direct mode).
	GetSessionID() int64
	
	// GetRootPath returns the root directory path.
	GetRootPath() string
	
	// OpenFile opens an encrypted file for reading or writing.
	OpenFile(path string, mode string) (ISecFile, error)
	
	// ReadFile reads a file from the encrypted root.
	ReadFile(path string) ([]byte, error)
	
	// WriteFile writes data to a file in the encrypted root.
	WriteFile(path string, data []byte) error
	
	// DeleteFile deletes a file from the encrypted root.
	DeleteFile(path string) error
	
	// StatFile returns file information.
	StatFile(path string) (*SecFileInfo, error)
	
	// FileExists checks if a file exists.
	FileExists(path string) bool
	
	// MkdirAll creates a directory and all parent directories.
	MkdirAll(path string) error
	
	// ReadDir reads a directory and returns entries.
	ReadDir(path string) ([]os.DirEntry, error)
	
	// WalkDir creates a directory walker.
	WalkDir(path string, opt *WalkOpt) (IDirWalker, error)
}
//TODO:
//var _ ISecRoot = (*SecDirWalker)(nil)
