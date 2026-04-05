// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This package only does type conversion and delegates all operations to the sec_fs package.
package ffi_sec_fs

import (
	"safe_disk/native/ffi_comm"
	"safe_disk/native/sec_fs"
)

// ==================== Global Stores ====================

var (
	// rootStore manages ISecRoot instances with int64 IDs.
	rootStore = ffi_comm.NewIDStore[sec_fs.ISecRoot]()

	// fileStore manages ISecFile instances with int64 IDs.
	fileStore = ffi_comm.NewIDStore[sec_fs.ISecFile]()
)

// InitStores initializes the global stores.
// This function is called automatically on package initialization.
func InitStores() {
	// Stores are already initialized via global variables.
	// This function is provided for explicit initialization if needed.
}

// ==================== Store Access Functions ====================

// GetRootStore returns the global root store.
// This is primarily used for testing purposes.
func GetRootStore() *ffi_comm.IDStore[sec_fs.ISecRoot] {
	return rootStore
}

// GetFileStore returns the global file store.
// This is primarily used for testing purposes.
func GetFileStore() *ffi_comm.IDStore[sec_fs.ISecFile] {
	return fileStore
}

// ClearStores clears all items from both stores.
// This is primarily used for testing purposes.
func ClearStores() {
	rootStore.Clear()
	fileStore.Clear()
}
