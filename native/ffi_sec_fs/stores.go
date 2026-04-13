// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains global stores for root and file instances.
package main

import (
	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

// RootEntry stores both the root and its path.
type RootEntry struct {
	Root     sec_fs.ISecRoot
	RootPath string
}

// Global stores for root and file instances.
var (
	// RootStore manages RootEntry instances with int64 IDs.
	RootStore = NewIDStore[RootEntry]()

	// FileStore manages ISecFile instances with int64 IDs.
	FileStore = NewIDStore[sec_fs.ISecFile]()

	// TaskStore manages ITask instances with string IDs.
	TaskStore = NewKeyValueMap[string, sec_transfer.ITask]()
)
