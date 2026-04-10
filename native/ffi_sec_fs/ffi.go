// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains FFI interface implementations that delegate to sec_fs.
package main

import (
	"encoding/json"
	"os"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

// ==================== Response Helper Functions ====================

// successResponse creates a success JSON response.
func successResponse(data interface{}) string {
	return SuccessWithData(data)
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
	Name     string `json:"name"`
	IsDir    bool   `json:"is_dir"`
	Size     int64  `json:"size"`
	ModTime  int64  `json:"mod_time"`
	Mode     uint32 `json:"mode"`
	Path     string `json:"path"`
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
//   - ignoreMatcher: ignore matcher configuration (TODO: not implemented yet)
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

	// Parse configFileName
	if configFileName, ok := optsMap["configFileName"].(string); ok && configFileName != "" {
		options = append(options, sec_fs.WithOpenConfigFileName(configFileName))
	}

	// TODO: Parse ignoreMatcher if needed in the future

	return options
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
//   {
//     "dataFactory": "aes-ctr",
//     "nameFactory": "aes-gcm-name",
//     "deriverFactory": "pbkdf2",
//     "ignoreMatcher": { ... }
//   }
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
//   {
//     "dataFactory": "aes-ctr",
//     "nameFactory": "aes-gcm-name",
//     "deriverFactory": "pbkdf2",
//     "keyStrengthMs": 100,
//     "configFileName": "_cryption.json"
//   }
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
	var entries []DirEntryResult
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
			ModTime: info.ModTime().UnixNano(),
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

// ==================== Transfer Operations (Async) ====================

// ExportDirectoryAsync_FFI exports an encrypted directory to a plaintext directory asynchronously.
func ExportDirectoryAsync_FFI(rootID int64, srcPath string, destPath string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Use transfer service from sec_transfer package
	svc := sec_transfer.GetDefaultTransferManager()
	taskInfo, err := svc.ExportDirectoryAsync(root, sec_fs.RelativeViewPath(srcPath), sec_fs.FullStorePath(destPath), nil, nil)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskInfo.TaskID, "status": "started"})
}

// ImportDirectoryAsync_FFI imports a plaintext directory into an encrypted directory asynchronously.
func ImportDirectoryAsync_FFI(rootID int64, srcPath string, destPath string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Use transfer service from sec_transfer package
	svc := sec_transfer.GetDefaultTransferManager()
	taskInfo, err := svc.ImportDirectoryAsync(sec_fs.FullStorePath(srcPath), root, sec_fs.RelativeViewPath(destPath), nil, nil)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskInfo.TaskID, "status": "started"})
}

// ExportFileAsync_FFI exports an encrypted file to a plaintext file asynchronously.
func ExportFileAsync_FFI(rootID int64, srcPath string, destPath string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Use transfer service from sec_transfer package
	svc := sec_transfer.GetDefaultTransferManager()
	taskInfo, err := svc.ExportFileAsync(root, sec_fs.RelativeViewPath(srcPath), sec_fs.FullStorePath(destPath), nil, nil)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskInfo.TaskID, "status": "started"})
}

// ImportFileAsync_FFI imports a plaintext file into an encrypted file asynchronously.
func ImportFileAsync_FFI(rootID int64, srcPath string, destPath string) string {
	entry, ok := RootStore.Get(rootID)
	root := entry.Root
	if !ok {
		return errorResponseStr("root not found")
	}

	// Use transfer service from sec_transfer package
	svc := sec_transfer.GetDefaultTransferManager()
	taskInfo, err := svc.ImportFileAsync(sec_fs.FullStorePath(srcPath), root, sec_fs.RelativeViewPath(destPath), nil, nil)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskInfo.TaskID, "status": "started"})
}

// GetTransferProgress_FFI gets the progress of a transfer job.
func GetTransferProgress_FFI(taskID string) string {
	svc := sec_transfer.GetDefaultTransferManager()
	job, err := svc.GetTaskProgress(taskID)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(job)
}

// RollbackTransfer_FFI cancels a transfer job.
func RollbackTransfer_FFI(taskID string) string {
	svc := sec_transfer.GetDefaultTransferManager()
	err := svc.RollbackTask(taskID)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(map[string]string{"status": "cancelled"})
}

// ==================== Helper Functions ====================

// getRoot retrieves an ISecRoot instance by its ID from ffi_stores.
func getRoot(rootID int64) (sec_fs.ISecRoot, bool) {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return nil, false
	}
	return entry.Root, true
}
