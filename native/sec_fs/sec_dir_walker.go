// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains the secDirWalker implementation with streaming directory reading.
package sec_fs

import (
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/sec_fs/crypto_name"
)

// ==================== secDirWalker Implementation ====================

// secDirWalker implements IDirWalker interface.
// It iterates over directory entries in a secure root with streaming support.
type secDirWalker struct {
	rootPath     FullStorePath
	relativePath RelativeViewPath
	fullPath     string
	options      *WalkOptions

	// Streaming fields
	dirFile     *os.File        // Opened directory file handle
	rawEntries  []fs.DirEntry   // Current batch of raw directory entries
	rawIndex    int             // Current index in rawEntries
	batchSize   int             // Number of entries to read per batch
	initialized bool
	closed      bool
	mu          sync.RWMutex

	// nameCryptor provides name decryption for file and directory names.
	nameCryptor crypto_name.INameCryptorContext
	// ignoreMatcher provides ignore logic for file names.
	ignoreMatcher IIgnoreMatcher
}

// Default batch size for streaming directory reading.
const defaultBatchSize = 100

// newSecDirWalker creates a new secDirWalker instance.
// This is an internal factory function used by WalkDir.
func newSecDirWalker(rootPath FullStorePath, relativePath RelativeViewPath, nameCryptor crypto_name.INameCryptorContext, ignoreMatcher IIgnoreMatcher, opts ...WalkOption) *secDirWalker {
	// Build full path
	fullPath := filepath.Join(string(rootPath), string(relativePath))

	// Apply default options
	options := &WalkOptions{}
	for _, opt := range opts {
		opt(options)
	}

	return &secDirWalker{
		rootPath:      rootPath,
		relativePath:  relativePath,
		fullPath:      fullPath,
		options:       options,
		nameCryptor:   nameCryptor,
		ignoreMatcher: ignoreMatcher,
		batchSize:     defaultBatchSize,
	}
}


// Next returns the next directory entry.
// It implements streaming reading by loading entries in batches.
func (w *secDirWalker) Next() (IDirEntry, error) {
	if w == nil {
		return &secDirEntry{}, ErrWalkerClosed
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return &secDirEntry{}, ErrWalkerClosed
	}

	// Initialize on first call
	if !w.initialized {
		if err := w.init(); err != nil {
			return &secDirEntry{}, err
		}
	}

	// Try to get next valid entry
	for {
		// Check if we need to load more entries
		if w.rawIndex >= len(w.rawEntries) {
			// Try to load next batch
			if err := w.loadNextBatch(); err != nil {
				return &secDirEntry{}, err
			}
			// If no more entries after loading
			if len(w.rawEntries) == 0 {
				return &secDirEntry{}, ErrNoMoreEntries
			}
		}

		// Process current entry
		entry := w.rawEntries[w.rawIndex]
		w.rawIndex++

		// Convert to DirEntry with decryption and filtering
		dirEntry, skip, err := w.processEntry(entry)
		if err != nil {
			continue // Skip entries with errors
		}
		if skip {
			continue // Skip filtered entries
		}

		return dirEntry, nil
	}
}

// init opens the directory file for streaming reading.
func (w *secDirWalker) init() error {
	w.initialized = true
	w.batchSize = defaultBatchSize

	// Open the directory file
	dirFile, err := os.Open(w.fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrDirectoryNotFound
		}
		return NewPathError("opendir", w.fullPath, err)
	}

	w.dirFile = dirFile
	w.rawEntries = make([]fs.DirEntry, 0, w.batchSize)
	w.rawIndex = 0

	return nil
}

// loadNextBatch reads the next batch of directory entries from the directory file.
func (w *secDirWalker) loadNextBatch() error {
	// Read next batch from directory file
	entries, err := w.dirFile.ReadDir(w.batchSize)
	if err != nil {
		// EOF is expected when no more entries
		if err.Error() == "EOF" {
			w.rawEntries = nil
			return ErrNoMoreEntries
		}
		return NewPathError("readdir", w.fullPath, err)
	}

	// No more entries
	if len(entries) == 0 {
		w.rawEntries = nil
		return ErrNoMoreEntries
	}

	w.rawEntries = entries
	w.rawIndex = 0

	return nil
}

// processEntry converts a raw directory entry to DirEntry with decryption and filtering.
func (w *secDirWalker) processEntry(entry fs.DirEntry) (IDirEntry, bool, error) {
	name := entry.Name()

	// Decrypt name if nameCryptor is available
	if w.nameCryptor != nil {
		decryptedName, err := w.nameCryptor.DecryptName(name)
		if err != nil {
			return &secDirEntry{}, true, nil // Skip files that cannot be decrypted
		}
		name = decryptedName
	}

	// Skip hidden files if not included
	if !w.options.IncludeHidden && len(name) > 0 && name[0] == '.' {
		return &secDirEntry{}, true, nil
	}

	isDir := entry.IsDir()

	// Check ignore matcher
	if w.ignoreMatcher != nil && w.ignoreMatcher.ShouldIgnore(name, isDir) {
		return &secDirEntry{}, true, nil
	}

	// Apply skip filters
	if w.options.SkipFiles && !isDir {
		return &secDirEntry{}, true, nil
	}
	if w.options.SkipDirs && isDir {
		return &secDirEntry{}, true, nil
	}

	// Get file info
	info, err := entry.Info()
	if err != nil {
		return &secDirEntry{}, true, nil
	}

	dirEntry := &secDirEntry{
		name:         name,
		isDir:        isDir,
		size:         info.Size(),
		modTime:      info.ModTime().UnixNano(),
		mode:         info.Mode(),
		relativeViewPath: RelativeViewPath(filepath.Join(string(w.relativePath), name)),
	}

	return dirEntry, false, nil
}

// Close closes the directory walker and releases resources.
func (w *secDirWalker) Close() error {
	if w == nil {
		return nil
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	w.closed = true
	w.rawEntries = nil

	// Close the directory file
	if w.dirFile != nil {
		err := w.dirFile.Close()
		w.dirFile = nil
		return err
	}

	return nil
}

// NextBatch returns the next batch of directory entries.
func (w *secDirWalker) NextBatch(batchSize int) ([]IDirEntry, error) {
	if w == nil {
		return nil, ErrWalkerClosed
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return nil, ErrWalkerClosed
	}

	// Initialize on first call
	if !w.initialized {
		if err := w.init(); err != nil {
			return nil, err
		}
	}

	// Handle invalid batch size
	if batchSize <= 0 {
		return []IDirEntry{}, nil
	}

	// Collect entries
	batch := make([]IDirEntry, 0, batchSize)
	for len(batch) < batchSize {
		// Check if we need to load more entries
		if w.rawIndex >= len(w.rawEntries) {
			// Try to load next batch
			if err := w.loadNextBatch(); err != nil {
				if len(batch) == 0 {
					return nil, err
				}
				break // Return what we have
			}
			// If no more entries after loading
			if len(w.rawEntries) == 0 {
				break
			}
		}

		// Process current entry
		entry := w.rawEntries[w.rawIndex]
		w.rawIndex++

		// Convert to DirEntry with decryption and filtering
		dirEntry, skip, err := w.processEntry(entry)
		if err != nil {
			continue // Skip entries with errors
		}
		if skip {
			continue // Skip filtered entries
		}

		batch = append(batch, dirEntry)
	}

	if len(batch) == 0 {
		return nil, ErrNoMoreEntries
	}

	return batch, nil
}

// HasNext returns true if there are more entries to read.
func (w *secDirWalker) HasNext() bool {
	if w == nil || w.closed {
		return false
	}

	w.mu.RLock()
	defer w.mu.RUnlock()

	// If not initialized, assume there are entries
	if !w.initialized {
		return true
	}

	// Check if we have entries in current batch or can load more
	return w.rawIndex < len(w.rawEntries)
}

// Reset resets the walker to the beginning of the directory.
func (w *secDirWalker) Reset() error {
	if w == nil {
		return ErrWalkerClosed
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return ErrWalkerClosed
	}

	// Reset indices
	w.rawIndex = 0
	w.rawEntries = nil

	// Seek to beginning of directory
	if w.dirFile != nil {
		_, err := w.dirFile.Seek(0, 0)
		if err != nil {
			return NewPathError("seekdir", w.fullPath, err)
		}
	}

	return nil
}
