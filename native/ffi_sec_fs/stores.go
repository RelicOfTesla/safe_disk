// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains global stores for root and file instances.
package main

import "safe_disk/native/sec_fs"

// Global stores for root and file instances.
var (
	// RootStore manages ISecRoot instances with int64 IDs.
	RootStore = NewIDStore[sec_fs.ISecRoot]()

	// FileStore manages ISecFile instances with int64 IDs.
	FileStore = NewIDStore[sec_fs.ISecFile]()
)

// ClearStores clears all items from all stores.
func ClearStores() {
	RootStore.Clear()
	FileStore.Clear()
}
