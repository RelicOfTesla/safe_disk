// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains FFI interface implementations that delegate to sec_fs.
package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"unsafe"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

// ==================== Response Helper Functions ====================

// successResponse creates a success JSON response.
func successResponse(data interface{}) string {
	return SuccessWithData(data)
}

// ==================== Utility Operations ====================

func ClearSecureMemory_FFI(data []byte) string {
	memZero(data)
	return Success()
}

func memZero(data []byte) {
	if len(data) == 0 {
		return
	}
	for i := range data {
		data[i] = 0
	}
	runtime.KeepAlive(unsafe.Pointer(&data[0]))
}

// ==================== Transfer V3 Operations ====================

func TransferV3ListUnfinished_FFI(rootID int64) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	markers, err := manager.ListUnfinishedOperations(context.Background(), entry.RootPath)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(map[string]interface{}{"markers": markers, "count": len(markers)})
}

func TransferV3CleanUnfinished_FFI(rootID int64, opID string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	if err := manager.CleanUnfinishedImportExport(context.Background(), entry.RootPath, opID); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3RecoverConvert_FFI(rootPath string) string {
	manager := sec_transfer.GetDefaultTransferV3()
	result, err := manager.RecoverConvert(context.Background(), rootPath)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(result)
}

func TransferV3ConvertRoot_FFI(rootPath string, password string, kind string) string {
	return transferV3ConvertRoot(rootPath, password, kind, nil)
}

func transferV3ConvertRoot(rootPath string, password string, kind string, callback sec_transfer.V3ProgressCallback) string {
	manager := sec_transfer.GetDefaultTransferV3()
	convertKind := sec_transfer.ConvertKind(kind)
	if convertKind == "" {
		convertKind = sec_transfer.ConvertKindEncrypt
	}
	if err := manager.ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind:      convertKind,
		RootPath:  rootPath,
		Password:  password,
		Overwrite: true,
	}, callback); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3ImportFile_FFI(rootID int64, srcPath string, destPath string) string {
	return transferV3ImportFileWithPolicy(context.Background(), rootID, srcPath, destPath, false, nil)
}

func transferV3ImportFile(ctx context.Context, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	return transferV3ImportFileWithPolicy(ctx, rootID, srcPath, destPath, false, callback)
}

func transferV3ImportFileWithPolicy(ctx context.Context, rootID int64, srcPath string, destPath string, overwrite bool, callback sec_transfer.V3ProgressCallback) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	if err := manager.ImportFile(ctx, sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(srcPath),
		DestRoot:  entry.Root,
		Dest:      sec_fs.RelativeViewPath(destPath),
		Overwrite: overwrite,
	}, callback); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3ImportDirectory_FFI(rootID int64, srcPath string, destPath string) string {
	return transferV3ImportDirectoryWithPolicy(context.Background(), rootID, srcPath, destPath, false, nil)
}

func transferV3ImportDirectory(ctx context.Context, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	return transferV3ImportDirectoryWithPolicy(ctx, rootID, srcPath, destPath, false, callback)
}

func transferV3ImportDirectoryWithPolicy(ctx context.Context, rootID int64, srcPath string, destPath string, overwrite bool, callback sec_transfer.V3ProgressCallback) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	if err := manager.ImportDirectory(ctx, sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(srcPath),
		DestRoot:  entry.Root,
		Dest:      sec_fs.RelativeViewPath(destPath),
		Overwrite: overwrite,
	}, callback); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3ExportFile_FFI(rootID int64, srcPath string, destPath string) string {
	return transferV3ExportFile(context.Background(), rootID, srcPath, destPath, nil)
}

func transferV3ExportFile(ctx context.Context, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	if err := manager.ExportFile(ctx, sec_transfer.ExportFileRequest{
		SourceRoot: entry.Root,
		Source:     sec_fs.RelativeViewPath(srcPath),
		Dest:       sec_fs.FullStorePath(destPath),
		Overwrite:  true,
	}, callback); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3ExportDirectory_FFI(rootID int64, srcPath string, destPath string) string {
	return transferV3ExportDirectory(context.Background(), rootID, srcPath, destPath, nil)
}

func transferV3ExportDirectory(ctx context.Context, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	manager := sec_transfer.GetDefaultTransferV3()
	if err := manager.ExportDirectory(ctx, sec_transfer.ExportDirectoryRequest{
		SourceRoot: entry.Root,
		Source:     sec_fs.RelativeViewPath(srcPath),
		Dest:       sec_fs.FullStorePath(destPath),
		Overwrite:  true,
	}, callback); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func TransferV3ImportFileWithOperation_FFI(operationID string, rootID int64, srcPath string, destPath string, overwrite bool, callback sec_transfer.V3ProgressCallback) string {
	return runtimeOperations.run(operationID, func(ctx context.Context) string {
		return transferV3ImportFileWithPolicy(ctx, rootID, srcPath, destPath, overwrite, callback)
	})
}

func TransferV3ImportDirectoryWithOperation_FFI(operationID string, rootID int64, srcPath string, destPath string, overwrite bool, callback sec_transfer.V3ProgressCallback) string {
	return runtimeOperations.run(operationID, func(ctx context.Context) string {
		return transferV3ImportDirectoryWithPolicy(ctx, rootID, srcPath, destPath, overwrite, callback)
	})
}

func TransferV3ExportFileWithOperation_FFI(operationID string, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	return runtimeOperations.run(operationID, func(ctx context.Context) string {
		return transferV3ExportFile(ctx, rootID, srcPath, destPath, callback)
	})
}

func TransferV3ExportDirectoryWithOperation_FFI(operationID string, rootID int64, srcPath string, destPath string, callback sec_transfer.V3ProgressCallback) string {
	return runtimeOperations.run(operationID, func(ctx context.Context) string {
		return transferV3ExportDirectory(ctx, rootID, srcPath, destPath, callback)
	})
}

func TransferV3Cancel_FFI(operationID string) string {
	return SuccessWithData(map[string]bool{"active": runtimeOperations.cancel(operationID)})
}

// errorResponse creates an error JSON response.
func errorResponse(err error) string {
	return ErrorResponse(err.Error())
}

// errorResponseStr creates an error JSON response from a string.
func errorResponseStr(msg string) string {
	return ErrorResponse(msg)
}

// ==================== Data Structures for Responses ====================

// RootOpenResult represents the result of OpenRoot_FFI.
type RootOpenResult struct {
	RootID int64 `json:"root_id"`
}

// FileOpenResult represents the result of OpenFile_FFI.
type FileOpenResult struct {
	FileID int64 `json:"file_id"`
}

// ReadResult represents the result of ReadFile_FFI.
type ReadResult struct {
	Data []byte `json:"data"`
	Size int    `json:"size"`
}

// SeekResult represents the result of SeekFile_FFI.
type SeekResult struct {
	Position int64 `json:"position"`
}

// FileInfoResult represents the result of file info queries.
type FileInfoResult struct {
	Size int64 `json:"size"`
}

// DirEntryResult represents a directory entry for ReadDir_FFI.
type DirEntryResult struct {
	Name    string `json:"name"`
	IsDir   bool   `json:"is_dir"`
	Size    int64  `json:"size"`
	ModTime int64  `json:"mod_time"` // Unix seconds.
	Mode    uint32 `json:"mode"`
	Path    string `json:"path"`
}

// ReadDirResult represents the result of ReadDir_FFI.
type ReadDirResult struct {
	Entries []DirEntryResult `json:"entries"`
	Count   int              `json:"count"`
}

// ==================== Config Helper Functions ====================

// parseOpenOptions parses a JSON string into OpenOption slice.
// If the JSON string is empty, returns an empty slice.
//
// Supported options:
//   - configFileName: custom config file name (string)
//   - ignoreMatcher: ignore matcher configuration
func parseOpenOptions(optionsJSON string) []sec_fs.OpenOption {
	if optionsJSON == "" {
		return nil
	}

	// Parse JSON into a map
	var optsMap map[string]interface{}
	if err := json.Unmarshal([]byte(optionsJSON), &optsMap); err != nil {
		// If parsing fails, return empty options
		return nil
	}

	var options []sec_fs.OpenOption
	configFileName := sec_fs.ConfigFileName

	// Parse configFileName
	if cfgName, ok := optsMap["configFileName"].(string); ok && cfgName != "" {
		options = append(options, sec_fs.WithOpenConfigFileName(cfgName))
		configFileName = cfgName
	}

	if matcher := parseIgnoreMatcher(optsMap["ignoreMatcher"], configFileName); matcher != nil {
		options = append(options, sec_fs.WithIgnoreMatcher(matcher))
	}

	return options
}

type ffiIgnoreMatcher struct {
	configFileName string
	beforeNames    map[string]struct{}
	afterNames     map[string]struct{}
	beforePatterns []string
	afterPatterns  []string
}

func parseIgnoreMatcher(raw interface{}, configFileName string) sec_fs.IIgnoreMatcher {
	rawMap, ok := raw.(map[string]interface{})
	if !ok {
		return nil
	}
	matcher := &ffiIgnoreMatcher{
		configFileName: configFileName,
		beforeNames:    makeStringSet(appendStringFields(rawMap, "before", "beforeNames", "beforeExact")),
		afterNames:     makeStringSet(appendStringFields(rawMap, "after", "afterNames", "afterExact")),
		beforePatterns: appendStringFields(rawMap, "beforePatterns", "beforeGlob", "beforeGlobs"),
		afterPatterns:  appendStringFields(rawMap, "afterPatterns", "afterGlob", "afterGlobs"),
	}
	if len(matcher.beforeNames) == 0 && len(matcher.afterNames) == 0 &&
		len(matcher.beforePatterns) == 0 && len(matcher.afterPatterns) == 0 {
		return nil
	}
	return matcher
}

func appendStringFields(m map[string]interface{}, keys ...string) []string {
	var out []string
	for _, key := range keys {
		switch v := m[key].(type) {
		case string:
			if v != "" {
				out = append(out, v)
			}
		case []interface{}:
			for _, item := range v {
				if s, ok := item.(string); ok && s != "" {
					out = append(out, s)
				}
			}
		}
	}
	return out
}

func makeStringSet(values []string) map[string]struct{} {
	set := make(map[string]struct{}, len(values))
	for _, value := range values {
		set[value] = struct{}{}
	}
	return set
}

func (m *ffiIgnoreMatcher) ShouldIgnore1(encryptedName string, isDir bool) bool {
	return m.shouldIgnore(encryptedName, isDir, m.beforeNames, m.beforePatterns)
}

func (m *ffiIgnoreMatcher) ShouldIgnore2(decryptedName string, isDir bool) bool {
	return m.shouldIgnore(decryptedName, isDir, m.afterNames, m.afterPatterns)
}

func (m *ffiIgnoreMatcher) shouldIgnore(name string, isDir bool, names map[string]struct{}, patterns []string) bool {
	if !isDir && name == m.configFileName {
		return true
	}
	if _, ok := names[name]; ok {
		return true
	}
	for _, pattern := range patterns {
		if matched, err := filepath.Match(pattern, name); err == nil && matched {
			return true
		}
	}
	return false
}

// parseCreateRootOptions parses a JSON string into CreateRootOption slice.
// If the JSON string is empty, returns an empty slice.
//
// Supported options:
//   - dataFactory: data encryption factory name (string)
//   - nameFactory: name encryption factory name (string)
//   - deriverFactory: key deriver factory name (string)
//   - keyStrengthMs: key strength in milliseconds (int)
//   - configFileName: custom config file name (string)
func parseCreateRootOptions(optionsJSON string) []sec_fs.CreateRootOption {
	if optionsJSON == "" {
		return nil
	}

	// Parse JSON into a map
	var optsMap map[string]interface{}
	if err := json.Unmarshal([]byte(optionsJSON), &optsMap); err != nil {
		// If parsing fails, return empty options
		return nil
	}

	var options []sec_fs.CreateRootOption

	// Parse dataFactory
	if dataFactory, ok := optsMap["dataFactory"].(string); ok && dataFactory != "" {
		options = append(options, sec_fs.WithDataFactory(dataFactory))
	}

	// Parse nameFactory
	if nameFactory, ok := optsMap["nameFactory"].(string); ok && nameFactory != "" {
		options = append(options, sec_fs.WithNameFactory(nameFactory))
	}

	// Parse deriverFactory
	if deriverFactory, ok := optsMap["deriverFactory"].(string); ok && deriverFactory != "" {
		options = append(options, sec_fs.WithDeriverFactory(deriverFactory))
	}

	// Parse keyStrengthMs
	if keyStrengthMs, ok := optsMap["keyStrengthMs"].(float64); ok && keyStrengthMs > 0 {
		options = append(options, sec_fs.WithKeyStrengthMs(int(keyStrengthMs)))
	}

	// Parse configFileName
	if configFileName, ok := optsMap["configFileName"].(string); ok && configFileName != "" {
		options = append(options, sec_fs.WithConfigFileName(configFileName))
	}

	return options
}

// ==================== Root Operations ====================

// OpenRoot_FFI opens a secure root directory with the given parameters.
// Returns a JSON string with root_id on success, or an error message on failure.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - password: the password for encryption/decryption
//   - optionsJSON: JSON string containing OpenOptions (optional, can be empty)
//
// OpenOptions format:
//
//	{
//	  "dataFactory": "aes-ctr",
//	  "nameFactory": "aes-gcm-name",
//	  "deriverFactory": "pbkdf2",
//	  "ignoreMatcher": { ... }
//	}
func OpenRoot_FFI(rootPath string, password string, optionsJSON string) string {
	// Parse open options
	opts := parseOpenOptions(optionsJSON)

	// Open root using OpenRootQuick
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password, opts...)
	if err != nil {
		return errorResponse(err)
	}

	// Store the root instance and get its ID
	rootID := RootStore.Add(RootEntry{Root: root, RootPath: rootPath})

	return successResponse(RootOpenResult{RootID: rootID})
}

// CloseRoot_FFI closes a secure root directory.
// Returns a JSON string indicating success or failure.
func CloseRoot_FFI(rootID int64) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	err := root.Close()
	if err != nil {
		return errorResponse(err)
	}

	// Remove from store
	RootStore.Remove(rootID)

	return Success()
}

// CreateRootConfig_FFI creates a new configuration for a secure root.
// Returns a JSON string indicating success or failure.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - password: the password for encryption/decryption
//   - optionsJSON: JSON string containing CreateRootOptions (optional, can be empty)
//
// CreateRootOptions format:
//
//	{
//	  "dataFactory": "aes-ctr",
//	  "nameFactory": "aes-gcm-name",
//	  "deriverFactory": "pbkdf2",
//	  "keyStrengthMs": 100,
//	  "configFileName": "_cryption.json"
//	}
func CreateRootConfig_FFI(rootPath string, password string, optionsJSON string) string {
	// Parse create options
	opts := parseCreateRootOptions(optionsJSON)

	// Create config using CreateRootConfigQuick
	_, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, opts...)
	if err != nil {
		return errorResponse(err)
	}

	return Success()
}

// ==================== File Operations ====================

// OpenFile_FFI opens a file within a secure root.
// Returns a JSON string with file_id on success, or an error message on failure.
func OpenFile_FFI(rootID int64, path string, mode int) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	file, err := root.OpenFile(sec_fs.RelativeViewPath(path), mode)
	if err != nil {
		return errorResponse(err)
	}

	// Store the file instance and get its ID
	fileID := FileStore.Add(file)

	return successResponse(FileOpenResult{FileID: fileID})
}

// CloseFile_FFI closes a file.
// Returns a JSON string indicating success or failure.
func CloseFile_FFI(fileID int64) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	err := file.Close()
	if err != nil {
		return errorResponse(err)
	}

	// Remove from store
	FileStore.Remove(fileID)

	return Success()
}

// ReadFile_FFI reads data from a file.
// Returns a JSON string with data and size on success, or an error message on failure.
func ReadFile_FFI(fileID int64, size int) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	buf := make([]byte, size)
	n, err := file.Read(buf)
	if err != nil && err.Error() != "EOF" {
		// Ignore EOF error, it's normal when reading to end of file
		return errorResponse(err)
	}

	return successResponse(ReadResult{
		Data: buf[:n],
		Size: n,
	})
}

// WriteFile_FFI writes data to a file.
// Returns a JSON string with the number of bytes written on success, or an error message on failure.
func WriteFile_FFI(fileID int64, data []byte) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	n, err := file.Write(data)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]int{"bytes_written": n})
}

// SeekFile_FFI sets the file position.
// Returns a JSON string with the new position on success, or an error message on failure.
func SeekFile_FFI(fileID int64, offset int64, whence int) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	pos, err := file.Seek(offset, whence)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(SeekResult{Position: pos})
}

// TruncateFile_FFI truncates a file to the specified size.
// Returns a JSON string indicating success or failure.
func TruncateFile_FFI(fileID int64, size int64) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	err := file.Truncate(size)
	if err != nil {
		return errorResponse(err)
	}

	return Success()
}

// ==================== Root-level File Operations ====================

// DeleteFile_FFI deletes a file from a secure root.
// Returns a JSON string indicating success or failure.
func DeleteFile_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	err := root.DeleteFile(sec_fs.RelativeViewPath(path))
	if err != nil {
		return errorResponse(err)
	}

	return Success()
}

// Rename_FFI atomically renames a file or directory inside a secure root.
func Rename_FFI(rootID int64, oldPath string, newPath string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	if err := entry.Root.Rename(
		sec_fs.RelativeViewPath(oldPath),
		sec_fs.RelativeViewPath(newPath),
	); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func CopyEntry_FFI(srcRootID int64, srcPath string, dstRootID int64, dstPath string, overwrite bool) string {
	srcEntry, ok := RootStore.Get(srcRootID)
	if !ok {
		return errorResponseStr("source root not found")
	}
	dstEntry, ok := RootStore.Get(dstRootID)
	if !ok {
		return errorResponseStr("destination root not found")
	}
	if err := sec_fs.CopyEntry(
		srcEntry.Root,
		sec_fs.RelativeViewPath(srcPath),
		dstEntry.Root,
		sec_fs.RelativeViewPath(dstPath),
		overwrite,
	); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func CreateEmptyFile_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	if err := sec_fs.CreateEmptyFile(entry.Root, sec_fs.RelativeViewPath(path)); err != nil {
		return errorResponse(err)
	}
	return Success()
}

func CreateDirectory_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}
	if err := sec_fs.CreateDirectory(entry.Root, sec_fs.RelativeViewPath(path)); err != nil {
		return errorResponse(err)
	}
	return Success()
}

// FileExists_FFI checks if a file exists in a secure root.
// Returns a JSON string with exists=true/false on success, or an error message on failure.
func FileExists_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	exists := root.FileExists(sec_fs.RelativeViewPath(path))

	return successResponse(map[string]bool{"exists": exists})
}

// MkdirAll_FFI creates a directory and all parent directories.
// Returns a JSON string indicating success or failure.
func MkdirAll_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	err := root.MkdirAll(sec_fs.RelativeViewPath(path))
	if err != nil {
		return errorResponse(err)
	}

	return Success()
}

// ReadDir_FFI reads directory entries from a path in a secure root.
// Returns a JSON string with directory entries on success, or an error message on failure.
func ReadDir_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Create a directory walker
	walker, err := root.WalkDir(sec_fs.RelativeViewPath(path))
	if err != nil {
		return errorResponse(err)
	}
	defer walker.Close()

	// Read all entries
	entries := make([]DirEntryResult, 0)
	for walker.HasNext() {
		dirEntry, err := walker.Next()
		if err != nil {
			break // No more entries or error
		}

		// Get file info from the entry
		info, err := dirEntry.Info()
		if err != nil {
			continue // Skip entries with errors
		}

		entries = append(entries, DirEntryResult{
			Name:    dirEntry.Name(),
			IsDir:   dirEntry.IsDir(),
			Size:    info.Size(),
			ModTime: info.ModTime().Unix(),
			Mode:    uint32(info.Mode()),
			Path:    string(dirEntry.GetRelativeViewPath()),
		})
	}

	return successResponse(ReadDirResult{
		Entries: entries,
		Count:   len(entries),
	})
}

// ==================== Convenience Functions ====================

// ReadAllFile_FFI reads all data from a file.
// Returns a JSON string with all file data on success, or an error message on failure.
func ReadAllFile_FFI(fileID int64) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	// Seek to beginning
	_, err := file.Seek(0, 0)
	if err != nil {
		return errorResponse(err)
	}

	// Get file size
	size := file.Size()

	// Read all data
	buf := make([]byte, size)
	n, err := file.Read(buf)
	if err != nil && err.Error() != "EOF" {
		return errorResponse(err)
	}

	return successResponse(ReadResult{
		Data: buf[:n],
		Size: n,
	})
}

// GetFileSize_FFI returns the current size of a file.
// Returns a JSON string with the file size on success, or an error message on failure.
func GetFileSize_FFI(fileID int64) string {
	file, ok := FileStore.Get(fileID)
	if !ok {
		return errorResponseStr("file not found")
	}

	size := file.Size()

	return successResponse(FileInfoResult{Size: size})
}

// ==================== Quick Operations (without managing IDs) ====================

// QuickReadFile_FFI reads a file directly from a root without managing file IDs.
// This is useful for one-shot read operations.
func QuickReadFile_FFI(rootID int64, path string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Open file
	file, err := root.OpenFile(sec_fs.RelativeViewPath(path), os.O_RDONLY)
	if err != nil {
		return errorResponse(err)
	}
	defer file.Close()

	// Get file size
	size := file.Size()

	// Read all data
	buf := make([]byte, size)
	n, err := file.Read(buf)
	if err != nil && err.Error() != "EOF" {
		return errorResponse(err)
	}

	return successResponse(ReadResult{
		Data: buf[:n],
		Size: n,
	})
}

// QuickWriteFile_FFI writes a file directly to a root without managing file IDs.
// This is useful for one-shot write operations.
func QuickWriteFile_FFI(rootID int64, path string, data []byte) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Open file for writing (create or truncate)
	file, err := root.OpenFile(sec_fs.RelativeViewPath(path), os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		return errorResponse(err)
	}
	defer file.Close()

	// Write data
	n, err := file.Write(data)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]int{"bytes_written": n})
}
