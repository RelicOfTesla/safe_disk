// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This package uses ffi_stores for root and file management.
package main

import (
	"safe_disk/native/ffi_comm"
	"safe_disk/native/ffi_stores"
	"safe_disk/native/sec_fs"
)

// GetRootStore returns the global root store.
// This is primarily used for testing purposes.
func GetRootStore() *ffi_comm.IDStore[sec_fs.ISecRoot] {
	return ffi_stores.RootStore
}

// GetFileStore returns the global file store.
// This is primarily used for testing purposes.
func GetFileStore() *ffi_comm.IDStore[sec_fs.ISecFile] {
	return ffi_stores.FileStore
}

// ClearStores clears all items from all stores.
// This is primarily used for testing purposes.
func ClearStores() {
	ffi_stores.ClearStores()
}
