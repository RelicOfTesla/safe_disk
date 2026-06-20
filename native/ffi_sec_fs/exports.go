// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains CGO export functions that can be called from C.
//
// To use these exports, compile with CGO enabled:
//
//	go build -buildmode=c-shared -o libffi_sec_fs.so
package main

/*
#include <stdlib.h>
#include <stdint.h>

// CProgressCallback is the C function pointer type for progress reporting.
typedef void (*CProgressCallback)(
    const char* current_file,
    int files_completed,
    int files_total,
    int is_complete,
    const char* error_message
);
*/
import "C"
import (
	"unsafe"
)

// ==================== Root Operations ====================

//export sec_root_open
func sec_root_open(rootPath *C.char, password *C.char, configJSON *C.char) *C.char {
	goRootPath := C.GoString(rootPath)
	goPassword := C.GoString(password)
	goConfigJSON := C.GoString(configJSON)

	result := OpenRoot_FFI(goRootPath, goPassword, goConfigJSON)
	return C.CString(result)
}

//export sec_root_close
func sec_root_close(rootID C.int64_t) *C.char {
	result := CloseRoot_FFI(int64(rootID))
	return C.CString(result)
}

//export sec_create_root_config
func sec_create_root_config(rootPath *C.char, password *C.char, optionsJSON *C.char) *C.char {
	goRootPath := C.GoString(rootPath)
	goPassword := C.GoString(password)
	goOptionsJSON := C.GoString(optionsJSON)

	result := CreateRootConfig_FFI(goRootPath, goPassword, goOptionsJSON)
	return C.CString(result)
}

// ==================== File Operations ====================

//export sec_file_open
func sec_file_open(rootID C.int64_t, path *C.char, mode C.int) *C.char {
	goPath := C.GoString(path)
	result := OpenFile_FFI(int64(rootID), goPath, int(mode))
	return C.CString(result)
}

//export sec_file_close
func sec_file_close(fileID C.int64_t) *C.char {
	result := CloseFile_FFI(int64(fileID))
	return C.CString(result)
}

//export sec_file_read
func sec_file_read(fileID C.int64_t, size C.int) *C.char {
	result := ReadFile_FFI(int64(fileID), int(size))
	return C.CString(result)
}

//export sec_file_write
func sec_file_write(fileID C.int64_t, data *C.char, size C.int) *C.char {
	goData := C.GoBytes(unsafe.Pointer(data), size)
	result := WriteFile_FFI(int64(fileID), goData)
	return C.CString(result)
}

//export sec_file_seek
func sec_file_seek(fileID C.int64_t, offset C.int64_t, whence C.int) *C.char {
	result := SeekFile_FFI(int64(fileID), int64(offset), int(whence))
	return C.CString(result)
}

//export sec_file_truncate
func sec_file_truncate(fileID C.int64_t, size C.int64_t) *C.char {
	result := TruncateFile_FFI(int64(fileID), int64(size))
	return C.CString(result)
}

// ==================== Root-level File Operations ====================

//export sec_file_delete
func sec_file_delete(rootID C.int64_t, path *C.char) *C.char {
	goPath := C.GoString(path)
	result := DeleteFile_FFI(int64(rootID), goPath)
	return C.CString(result)
}

//export sec_file_exists
func sec_file_exists(rootID C.int64_t, path *C.char) *C.char {
	goPath := C.GoString(path)
	result := FileExists_FFI(int64(rootID), goPath)
	return C.CString(result)
}

//export sec_mkdir_all
func sec_mkdir_all(rootID C.int64_t, path *C.char) *C.char {
	goPath := C.GoString(path)
	result := MkdirAll_FFI(int64(rootID), goPath)
	return C.CString(result)
}

//export sec_read_dir
func sec_read_dir(rootID C.int64_t, path *C.char) *C.char {
	goPath := C.GoString(path)
	result := ReadDir_FFI(int64(rootID), goPath)
	return C.CString(result)
}

// ==================== Quick Operations ====================

//export sec_quick_read_file
func sec_quick_read_file(rootID C.int64_t, path *C.char) *C.char {
	goPath := C.GoString(path)
	result := QuickReadFile_FFI(int64(rootID), goPath)
	return C.CString(result)
}

//export sec_quick_write_file
func sec_quick_write_file(rootID C.int64_t, path *C.char, data *C.char, size C.int) *C.char {
	goPath := C.GoString(path)
	goData := C.GoBytes(unsafe.Pointer(data), size)
	result := QuickWriteFile_FFI(int64(rootID), goPath, goData)
	return C.CString(result)
}

// ==================== Utility Functions ====================

//export sec_free_string
func sec_free_string(s *C.char) {
	C.free(unsafe.Pointer(s))
}

//export sec_clear_secure_memory
func sec_clear_secure_memory(data unsafe.Pointer, size C.int) *C.char {
	if data != nil && size > 0 {
		buf := unsafe.Slice((*byte)(data), int(size))
		memZero(buf)
	}
	return C.CString(Success())
}

// ==================== Transfer Operations (Async) ====================

//export sec_export_directory_async
func sec_export_directory_async(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	result := ExportDirectoryAsync_FFI(int64(rootID), goSrcPath, goDestPath)
	return C.CString(result)
}

//export sec_import_directory_async
func sec_import_directory_async(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	result := ImportDirectoryAsync_FFI(int64(rootID), goSrcPath, goDestPath)
	return C.CString(result)
}

//export sec_export_file_async
func sec_export_file_async(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	result := ExportFileAsync_FFI(int64(rootID), goSrcPath, goDestPath)
	return C.CString(result)
}

//export sec_import_file_async
func sec_import_file_async(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	result := ImportFileAsync_FFI(int64(rootID), goSrcPath, goDestPath)
	return C.CString(result)
}

// ==================== Transfer Progress Query ====================

//export action_task_get_progress
func action_task_get_progress(taskID *C.char) *C.char {
	goJobID := C.GoString(taskID)
	result := GetTransferProgress_FFI(goJobID)
	return C.CString(result)
}

//export action_task_close
func action_task_close(taskID *C.char) *C.char {
	goJobID := C.GoString(taskID)
	result := RollbackTransfer_FFI(goJobID)
	return C.CString(result)
}

// ==================== Transfer Operations (Async with Callback) ====================

//export sec_export_directory_async_with_callback
func sec_export_directory_async_with_callback(rootID C.int64_t, srcPath *C.char, destPath *C.char, callback C.CProgressCallback) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	// Convert C callback to Go callback
	goCallback := CProgressCallbackToGo(callback)

	result := ExportDirectoryAsyncWithCallback_FFI(int64(rootID), goSrcPath, goDestPath, goCallback)
	return C.CString(result)
}

//export sec_import_directory_async_with_callback
func sec_import_directory_async_with_callback(rootID C.int64_t, srcPath *C.char, destPath *C.char, callback C.CProgressCallback) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	// Convert C callback to Go callback
	goCallback := CProgressCallbackToGo(callback)

	result := ImportDirectoryAsyncWithCallback_FFI(int64(rootID), goSrcPath, goDestPath, goCallback)
	return C.CString(result)
}

//export sec_export_file_async_with_callback
func sec_export_file_async_with_callback(rootID C.int64_t, srcPath *C.char, destPath *C.char, callback C.CProgressCallback) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	// Convert C callback to Go callback
	goCallback := CProgressCallbackToGo(callback)

	result := ExportFileAsyncWithCallback_FFI(int64(rootID), goSrcPath, goDestPath, goCallback)
	return C.CString(result)
}

//export sec_import_file_async_with_callback
func sec_import_file_async_with_callback(rootID C.int64_t, srcPath *C.char, destPath *C.char, callback C.CProgressCallback) *C.char {
	goSrcPath := C.GoString(srcPath)
	goDestPath := C.GoString(destPath)

	// Convert C callback to Go callback
	goCallback := CProgressCallbackToGo(callback)

	result := ImportFileAsyncWithCallback_FFI(int64(rootID), goSrcPath, goDestPath, goCallback)
	return C.CString(result)
}

// ==================== Transfer V3 Operations ====================

//export sec_transfer_v3_list_unfinished
func sec_transfer_v3_list_unfinished(rootID C.int64_t) *C.char {
	result := TransferV3ListUnfinished_FFI(int64(rootID))
	return C.CString(result)
}

//export sec_transfer_v3_clean_unfinished
func sec_transfer_v3_clean_unfinished(rootID C.int64_t, opID *C.char) *C.char {
	result := TransferV3CleanUnfinished_FFI(int64(rootID), C.GoString(opID))
	return C.CString(result)
}

//export sec_transfer_v3_recover_convert
func sec_transfer_v3_recover_convert(rootPath *C.char) *C.char {
	result := TransferV3RecoverConvert_FFI(C.GoString(rootPath))
	return C.CString(result)
}

//export sec_transfer_v3_convert_root
func sec_transfer_v3_convert_root(rootPath *C.char, password *C.char, kind *C.char) *C.char {
	result := TransferV3ConvertRoot_FFI(C.GoString(rootPath), C.GoString(password), C.GoString(kind))
	return C.CString(result)
}

//export sec_transfer_v3_import_file
func sec_transfer_v3_import_file(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	result := TransferV3ImportFile_FFI(int64(rootID), C.GoString(srcPath), C.GoString(destPath))
	return C.CString(result)
}

//export sec_transfer_v3_import_directory
func sec_transfer_v3_import_directory(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	result := TransferV3ImportDirectory_FFI(int64(rootID), C.GoString(srcPath), C.GoString(destPath))
	return C.CString(result)
}

//export sec_transfer_v3_export_file
func sec_transfer_v3_export_file(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	result := TransferV3ExportFile_FFI(int64(rootID), C.GoString(srcPath), C.GoString(destPath))
	return C.CString(result)
}

//export sec_transfer_v3_export_directory
func sec_transfer_v3_export_directory(rootID C.int64_t, srcPath *C.char, destPath *C.char) *C.char {
	result := TransferV3ExportDirectory_FFI(int64(rootID), C.GoString(srcPath), C.GoString(destPath))
	return C.CString(result)
}
