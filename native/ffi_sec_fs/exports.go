// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains CGO export functions that can be called from C.
//
// To use these exports, compile with CGO enabled:
//   go build -buildmode=c-shared -o libffi_sec_fs.so
package ffi_sec_fs

/*
#include <stdlib.h>
#include <stdint.h>
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
