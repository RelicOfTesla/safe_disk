// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains the secDirWalker implementation with streaming directory reading.
package sec_fs

import (
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/sec_utils"
)

// ==================== secDirWalker Implementation ====================

// secDirWalker implements IDirWalker interface.
// It iterates over directory entries in a secure root with streaming support.

// dirStackItem represents a directory in the traversal stack.
type dirStackItem struct {
	relativePath RelativeViewPath
	depth        int
}
type secDirWalker struct {
	rootPathInfo sec_utils.PathInfo
	relativePath RelativeViewPath
	options      *WalkOptions

	// Streaming fields
	dirFile     *os.File      // Opened directory file handle
	rawEntries  []fs.DirEntry // Current batch of raw directory entries
	rawIndex    int           // Current index in rawEntries
	batchSize   int           // Number of entries to read per batch
	initialized bool
	closed      bool
	mu          sync.RWMutex

	// nameCryptor provides name decryption for file and directory names.
	nameCryptor crypto_name.INameCryptorContext
	// ignoreMatcher provides ignore logic for file names.
	ignoreMatcher IIgnoreMatcher

	// Recursive traversal fields
	dirStack     []dirStackItem // Stack of directories to traverse
	currentDepth int            // Current recursion depth
}

// Default batch size for streaming directory reading.
const defaultBatchSize = 100

// DefaultWalkerMaxPendingDirectories bounds memory used by recursive
// traversal. Callers may reduce it but cannot disable the hard ceiling.
const DefaultWalkerMaxPendingDirectories = 1024

const maximumWalkerPendingDirectories = 4096

// newSecDirWalker creates a new secDirWalker instance.
// This is an internal factory function used by WalkDir.
func newSecDirWalker(rootPathInfo sec_utils.PathInfo, relativePath RelativeViewPath, nameCryptor crypto_name.INameCryptorContext, ignoreMatcher IIgnoreMatcher, opts ...WalkOption) *secDirWalker {
	// Apply default options
	options := &WalkOptions{}
	for _, opt := range opts {
		opt(options)
	}

	return &secDirWalker{
		rootPathInfo:  rootPathInfo,
		relativePath:  relativePath,
		options:       options,
		nameCryptor:   nameCryptor,
		ignoreMatcher: ignoreMatcher,
		batchSize:     defaultBatchSize,
	}
}

// viewPathToStorePath converts a view path (plain text) to a store path (encrypted).
// Each path component is encrypted separately using nameCryptor.
// If nameCryptor is nil, the path is returned as-is (no encryption).
// It also validates that the resulting path is within the root directory.
func (w *secDirWalker) viewPathToStorePath(viewPath RelativeViewPath) (RelativeStorePath, FullStorePath, error) {
	storePath, fullPath, err := viewPathToStorePathCheck(w.rootPathInfo, viewPath, w.nameCryptor, false)
	return storePath, fullPath, err
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
				return &secDirEntry{}, io.EOF
			}
		}

		// Process current entry
		entry := w.rawEntries[w.rawIndex]
		w.rawIndex++

		// Convert to DirEntry with decryption and filtering
		dirEntry, skip, err := w.processEntry(entry)
		if err != nil {
			return &secDirEntry{}, err
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

	// Convert relativePath (view path, plain text) to store path (encrypted)
	_, fullPath, err := w.viewPathToStorePath(w.relativePath)
	if err != nil {
		return NewPairPathError("encrypt_path", w.relativePath, fullPath, err)
	}

	// Open the directory file
	dirFile, err := os.Open(string(fullPath))
	if err != nil {
		if os.IsNotExist(err) {
			return ErrDirectoryNotFound
		}
		return NewPairPathError("opendir", w.relativePath, fullPath, err)
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
		if err.Error() == "EOF" || errors.Is(err, io.EOF) {
			return w.loadNextDirectory()
		}
		return NewRelativeViewPathError("readdir", w.relativePath, err)
	}

	// No more entries
	if len(entries) == 0 {
		return w.loadNextDirectory()
	}

	w.rawEntries = entries
	w.rawIndex = 0

	return nil
}

// loadNextDirectory loads the next directory from the stack for recursive traversal.
// Returns io.EOF if there are no more directories to traverse.
func (w *secDirWalker) loadNextDirectory() error {
	for w.options.Recursive && len(w.dirStack) > 0 {
		item := w.dirStack[len(w.dirStack)-1]
		w.dirStack = w.dirStack[:len(w.dirStack)-1]

		if w.dirFile != nil {
			currentDir := w.dirFile
			w.dirFile = nil
			if err := currentDir.Close(); err != nil {
				return NewRelativeViewPathError("closedir", w.relativePath, err)
			}
		}

		_, fullPath, err := w.viewPathToStorePath(item.relativePath)
		if err != nil {
			return err
		}
		dirFile, err := os.Open(string(fullPath))
		if err != nil {
			if os.IsNotExist(err) {
				return ErrDirectoryNotFound
			}
			return NewPairPathError("opendir", item.relativePath, fullPath, err)
		}

		w.relativePath = item.relativePath
		w.dirFile = dirFile
		w.currentDepth = item.depth
		w.rawEntries = nil
		w.rawIndex = 0

		entries, err := w.dirFile.ReadDir(w.batchSize)
		if errors.Is(err, io.EOF) && len(entries) == 0 {
			continue
		}
		if err != nil && !errors.Is(err, io.EOF) {
			return NewRelativeViewPathError("readdir", w.relativePath, err)
		}
		if len(entries) == 0 {
			continue
		}
		w.rawEntries = entries
		return nil
	}

	w.rawEntries = nil
	return io.EOF
}

// processEntry converts a raw directory entry to DirEntry with decryption and filtering.
func (w *secDirWalker) processEntry(entry fs.DirEntry) (IDirEntry, bool, error) {
	name := entry.Name()
	isDir := entry.IsDir()

	// Check ignore matcher BEFORE name decryption (using encrypted name)
	if w.ignoreMatcher != nil && w.ignoreMatcher.ShouldIgnore1(name, isDir) {
		return &secDirEntry{}, true, nil
	}

	// Decrypt name if nameCryptor is available
	if w.nameCryptor != nil {
		decryptedName, err := w.nameCryptor.DecryptName(name)
		if err != nil {
			return &secDirEntry{}, false, NewRelativeViewPathError(
				"decrypt_entry_name", w.relativePath, err,
			)
		}
		name = decryptedName
	}

	// Skip hidden files if not included
	if !w.options.IncludeHidden && len(name) > 0 && name[0] == '.' {
		return &secDirEntry{}, true, nil
	}

	// Check ignore matcher AFTER name decryption (using decrypted name)
	if w.ignoreMatcher != nil && w.ignoreMatcher.ShouldIgnore2(name, isDir) {
		return &secDirEntry{}, true, nil
	}

	// For directories with recursive traversal, push to stack BEFORE SkipDirs check
	if isDir && w.options.Recursive {
		// Check max depth (0 = unlimited)
		if w.options.MaxDepth == 0 || w.currentDepth < w.options.MaxDepth {
			if len(w.dirStack) >= w.maxPendingDirectories() {
				return &secDirEntry{}, false, fmt.Errorf(
					"%w: limit=%d",
					ErrWalkerWorkLimit,
					w.maxPendingDirectories(),
				)
			}
			subDirPath := RelativeViewPath(filepath.Join(string(w.relativePath), name))
			w.dirStack = append(w.dirStack, dirStackItem{
				relativePath: subDirPath,
				depth:        w.currentDepth + 1,
			})
		}
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
		return &secDirEntry{}, false, NewRelativeViewPathError(
			"entry_info", w.relativePath, err,
		)
	}

	dirEntry := &secDirEntry{
		viewName:         name,
		isDir:            isDir,
		size:             info.Size(),
		modTime:          info.ModTime().UnixNano(),
		mode:             info.Mode(),
		relativeViewPath: RelativeViewPath(filepath.Join(string(w.relativePath), name)),
	}

	return dirEntry, false, nil
}

func (w *secDirWalker) maxPendingDirectories() int {
	limit := w.options.MaxPendingDirectories
	if limit < 1 {
		return DefaultWalkerMaxPendingDirectories
	}
	if limit > maximumWalkerPendingDirectories {
		return maximumWalkerPendingDirectories
	}
	return limit
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
	w.dirStack = nil

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
				if errors.Is(err, io.EOF) {
					break
				}
				return nil, err
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
			return nil, err
		}
		if skip {
			continue // Skip filtered entries
		}

		batch = append(batch, dirEntry)
	}

	if len(batch) == 0 {
		return nil, io.EOF
	}

	return batch, nil
}

// HasNext returns true if there are more entries to read.
func (w *secDirWalker) HasNext() bool {
	if w == nil || w.closed {
		return false
	}

	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return false
	}

	// Historical behavior: an uninitialized walker is treated as potentially
	// having entries. Next() remains responsible for initialization and EOF.
	if !w.initialized {
		return true
	}

	// If we have entries in current batch, return true
	if w.rawIndex < len(w.rawEntries) {
		return true
	}

	// Try to load next batch to check if there are more entries
	// This is needed because init() doesn't load the first batch
	err := w.loadNextBatch()
	if err != nil {
		return false
	}

	// Check if we got any entries
	return len(w.rawEntries) > 0
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
			return NewRelativeViewPathError("seekdir", w.relativePath, err)
		}
	}

	return nil
}
