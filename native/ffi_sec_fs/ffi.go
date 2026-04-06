// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains FFI interface implementations that delegate to sec_fs.
package main

import (
	"encoding/json"
	"fmt"
	"os"

	"safe_disk/native/config"
	
	
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

// parseConfig parses a JSON string into a config.SharedConfig.
// Returns a MemoryConfig populated with the JSON data.
func parseConfig(configJSON string) (config.SharedConfig, error) {
	cfg := config.NewMemoryConfig()
	
	if configJSON == "" {
		return cfg, nil
	}
	
	var data map[string]interface{}
	if err := json.Unmarshal([]byte(configJSON), &data); err != nil {
		return nil, fmt.Errorf("invalid config JSON: %w", err)
	}
	
	for key, value := range data {
		switch v := value.(type) {
		case string:
			cfg.SetStr(key, v)
		case float64:
			cfg.SetInt(key, int(v))
		case bool:
			cfg.SetBool(key, v)
		}
	}
	
	return cfg, nil
}

// ==================== Root Operations ====================

// OpenRoot_FFI opens a secure root directory with the given parameters.
// Returns a JSON string with root_id on success, or an error message on failure.
func OpenRoot_FFI(rootPath string, password string, configJSON string) string {
	cfg, err := parseConfig(configJSON)
	if err != nil {
		return errorResponse(err)
	}

	root, err := sec_fs.OpenRoot(sec_fs.FullStorePath(rootPath), password, cfg)
	if err != nil {
		return errorResponse(err)
	}

	// Store the root instance and get its ID
	rootID := RootStore.Add(root)

	return successResponse(RootOpenResult{RootID: rootID})
}

// CloseRoot_FFI closes a secure root directory.
// Returns a JSON string indicating success or failure.
func CloseRoot_FFI(rootID int64) string {
	root, ok := RootStore.Get(rootID)
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

// ==================== File Operations ====================

// OpenFile_FFI opens a file within a secure root.
// Returns a JSON string with file_id on success, or an error message on failure.
func OpenFile_FFI(rootID int64, path string, mode int) string {
	root, ok := RootStore.Get(rootID)
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
	root, ok := RootStore.Get(rootID)
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
	root, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	exists := root.FileExists(sec_fs.RelativeViewPath(path))

	return successResponse(map[string]bool{"exists": exists})
}

// MkdirAll_FFI creates a directory and all parent directories.
// Returns a JSON string indicating success or failure.
func MkdirAll_FFI(rootID int64, path string) string {
	root, ok := RootStore.Get(rootID)
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
	root, ok := RootStore.Get(rootID)
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
		entry, err := walker.Next()
		if err != nil {
			break // No more entries or error
		}

		entries = append(entries, DirEntryResult{
			Name:    entry.Name,
			IsDir:   entry.IsDir,
			Size:    entry.Size,
			ModTime: entry.ModTime,
			Mode:    uint32(entry.Mode),
			Path:    entry.RelativePath.String(),
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
	root, ok := RootStore.Get(rootID)
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
	root, ok := RootStore.Get(rootID)
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

// ==================== JSON Config Parsing Helper ====================
// parseConfig is now defined at the top of the file (returns config.SharedConfig).

// ==================== Transfer Operations (Async) ====================

// ExportDirectoryAsync_FFI exports an encrypted directory to a plaintext directory asynchronously.
func ExportDirectoryAsync_FFI(rootID int64, srcPath string, destPath string) string {
	root, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	// Create job
	taskID := sec_transfer.GetTaskManager().CreateTask(sec_transfer.TransferTypeExport)

	// Create wrapper callback to update job progress
	callback := func(status sec_transfer.ProgressStatus) {
		sec_transfer.GetTaskManager().UpdateTask(taskID, status)
	}

	svc := sec_transfer.DefaultTransferService
	err := svc.ExportDirectoryAsync(root, sec_fs.RelativeViewPath(srcPath), sec_transfer.ExternalPath(destPath), nil, callback)
	if err != nil {
		sec_transfer.GetTaskManager().RemoveTask(taskID)
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskID, "status": "started"})
}

// ImportDirectoryAsync_FFI imports a plaintext directory into an encrypted directory asynchronously.
func ImportDirectoryAsync_FFI(rootID int64, srcPath string, destPath string) string {
	root, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	// Create job
	taskID := sec_transfer.GetTaskManager().CreateTask(sec_transfer.TransferTypeImport)

	// Create wrapper callback to update job progress
	callback := func(status sec_transfer.ProgressStatus) {
		sec_transfer.GetTaskManager().UpdateTask(taskID, status)
	}

	svc := sec_transfer.DefaultTransferService
	err := svc.ImportDirectoryAsync(root, sec_transfer.ExternalPath(srcPath), sec_fs.RelativeViewPath(destPath), nil, callback)
	if err != nil {
		sec_transfer.GetTaskManager().RemoveTask(taskID)
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskID, "status": "started"})
}

// ExportFileAsync_FFI exports an encrypted file to a plaintext file asynchronously.
func ExportFileAsync_FFI(rootID int64, srcPath string, destPath string) string {
	root, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	// Create job
	taskID := sec_transfer.GetTaskManager().CreateTask(sec_transfer.TransferTypeExport)

	// Create wrapper callback to update job progress
	callback := func(status sec_transfer.ProgressStatus) {
		sec_transfer.GetTaskManager().UpdateTask(taskID, status)
	}

	svc := sec_transfer.DefaultTransferService
	err := svc.ExportFileAsync(root, sec_fs.RelativeViewPath(srcPath), sec_transfer.ExternalPath(destPath), nil, callback)
	if err != nil {
		sec_transfer.GetTaskManager().RemoveTask(taskID)
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskID, "status": "started"})
}

// ImportFileAsync_FFI imports a plaintext file into an encrypted file asynchronously.
func ImportFileAsync_FFI(rootID int64, srcPath string, destPath string) string {
	root, ok := RootStore.Get(rootID)
	if !ok {
		return errorResponseStr("root not found")
	}

	// Create job
	taskID := sec_transfer.GetTaskManager().CreateTask(sec_transfer.TransferTypeImport)

	// Create wrapper callback to update job progress
	callback := func(status sec_transfer.ProgressStatus) {
		sec_transfer.GetTaskManager().UpdateTask(taskID, status)
	}

	svc := sec_transfer.DefaultTransferService
	err := svc.ImportFileAsync(root, sec_transfer.ExternalPath(srcPath), sec_fs.RelativeViewPath(destPath), nil, callback)
	if err != nil {
		sec_transfer.GetTaskManager().RemoveTask(taskID)
		return errorResponse(err)
	}

	return successResponse(map[string]string{"task_id": taskID, "status": "started"})
}

// GetTransferProgress_FFI gets the progress of a transfer job.
func GetTransferProgress_FFI(taskID string) string {
	job, err := sec_transfer.DefaultTransferService.GetTaskProgress(taskID)
	if err != nil {
		return errorResponse(err)
	}

	return successResponse(job)
}

// CancelTransfer_FFI cancels a transfer job.
func CancelTransfer_FFI(taskID string) string {
	err := sec_transfer.DefaultTransferService.CancelTask(taskID)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(map[string]string{"status": "cancelled"})
}

// ==================== Async Directory Transfer Operations (from ffi_sec_transfer) ====================

// TransferResult represents the result of a transfer FFI operation.
type TransferResult struct {
	Success      bool   `json:"success"`
	FilesCount   int    `json:"files_count"`
	TotalBytes   int64  `json:"total_bytes"`
	ErrorMessage string `json:"error_message,omitempty"`
}

// getRoot retrieves an ISecRoot instance by its ID from ffi_stores.
func getRoot(rootID int64) (sec_fs.ISecRoot, bool) {
	return RootStore.Get(rootID)
}

// ExportDirectoryAsync_FFI exports an encrypted directory to a plaintext directory asynchronously.
// callback parameter is used to notify Flutter about progress.

