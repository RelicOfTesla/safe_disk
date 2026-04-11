// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains the secRootImpl implementation that manages the secure root directory.
package sec_fs

import (
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/sec_utils"
)

// secRootImpl implements ISecRoot interface.
// It manages the root directory for encrypted file storage.
type secRootImpl struct {
	// fileDataFactory is the cryptographic data factory used to create cryptor contexts.
	fileDataFactory crypto_data.ICryptoDataFactory
	// rootPathInfo is the full storage path of the root directory.
	rootPathInfo sec_utils.PathInfo
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

// viewPathToStorePathCheck converts a view path (plain text) to a store path (encrypted).
// Each path component is encrypted separately using nameCryptor.
// If nameCryptor is nil, the path is returned as-is (no encryption).
// If allowUnsafe is false, it validates that the resulting path is within the root directory.
// Returns the encrypted store path, the full storage path, and an error if validation fails.
func viewPathToStorePathCheck(rootInfo sec_utils.PathInfo, viewPath RelativeViewPath, nameCryptor crypto_name.INameCryptorContext, allowUnsafe bool) (RelativeStorePath, FullStorePath, error) {
	// Convert view path to store path (encrypt file names)
	storePath, err := ViewPathToStorePath(viewPath, nameCryptor)
	if err != nil {
		return "", "", err
	}

	// Build the full storage path
	fullPathInfo := rootInfo.Join(string(storePath))
	fullPath := FullStorePath(fullPathInfo.Encode())

	// Validate the full path is within the root directory (unless allowUnsafe is true)
	if !allowUnsafe {
		if !rootInfo.ContainsPathInfo(fullPathInfo) {
			return "", "", NewPairPathError("validate", viewPath, fullPath, ErrPathTraversal)
		}
	}

	return storePath, fullPath, nil
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

	// Convert view path to store path (encrypt file names) and validate
	_, fullPath, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return nil, err
	}

	// Ensure parent directory exists for write operations
	if mode&os.O_WRONLY != 0 || mode&os.O_RDWR != 0 || mode&os.O_CREATE != 0 {
		parentDir := filepath.Dir(string(fullPath))
		if err := os.MkdirAll(parentDir, 0755); err != nil {
			return nil, NewFullStorePathError("mkdir", FullStorePath(parentDir), err)
		}
	}

	// Open or create the underlying file
	file, err := os.OpenFile(string(fullPath), mode, 0644)
	if err != nil {
		return nil, NewPairPathError("open", path, fullPath, err)
	}

	// Create a cryptographic context for the file
	cryptorContext, err := r.fileDataFactory.NewContext(&fileContext{File: file}, r.keyInfo, r.cfg)
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

	// Convert view path to store path (encrypt file names) and validate
	_, fullPath, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return err
	}

	err = os.Remove(string(fullPath))
	if err != nil {
		return NewPairPathError("remove", path, fullPath, err)
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

	// Convert view path to store path (encrypt file names) and validate
	_, fullPath, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return false
	}

	_, err = os.Stat(string(fullPath))
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

	// Convert view path to store path (encrypt file names) and validate
	_, fullPath, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return err
	}

	return os.MkdirAll(string(fullPath), 0755)
}

// Rename renames a file or directory from oldPath to newPath.
// Both paths are relative view paths (plain text, will be encrypted).
// This operation is atomic at the file system level.
func (r *secRootImpl) Rename(oldPath RelativeViewPath, newPath RelativeViewPath) error {
	if r == nil {
		return ErrRootClosed
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	if r.closed {
		return ErrRootClosed
	}

	// Convert view paths to store paths (encrypt file names) and validate
	_, oldFullPath, err := viewPathToStorePathCheck(r.rootPathInfo, oldPath, r.nameCryptor, false)
	if err != nil {
		return err
	}

	_, newFullPath, err := viewPathToStorePathCheck(r.rootPathInfo, newPath, r.nameCryptor, false)
	if err != nil {
		return err
	}

	err = os.Rename(string(oldFullPath), string(newFullPath))
	if err != nil {
		return NewPairPathError("rename", oldPath, oldFullPath, err)
	}
	return nil
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

	// Convert view path to store path (encrypt file names) and validate
	_, _, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return nil, err
	}

	// Create walker using factory function
	walker := newSecDirWalker(r.rootPathInfo, path, r.nameCryptor, r.ignoreMatcher, opts...)

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

	// Convert name to RelativeViewPath
	path := RelativeViewPath(name)

	// Convert view path to store path (encrypt file names) and validate
	_, _, err := viewPathToStorePathCheck(r.rootPathInfo, path, r.nameCryptor, false)
	if err != nil {
		return nil, err
	}

	// Create walker using factory function
	walker := newSecDirWalker(r.rootPathInfo, path, r.nameCryptor, r.ignoreMatcher)

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
		// IDirEntry already implements fs.DirEntry, so we can directly append
		entries = append(entries, entry)
	}

	return entries, nil
}

func (r *secRootImpl) GetRootPath() FullStorePath {
	if r == nil {
		return ""
	}
	return FullStorePath(r.rootPathInfo.Encode())
}

// GetConfig returns the shared configuration.
func (r *secRootImpl) GetConfig() config.SharedConfig {
	if r == nil {
		return nil
	}
	return r.cfg
}
