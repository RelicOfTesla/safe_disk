// Package ffi_sec_transfer provides FFI adapter layer for sec_transfer.
// This file implements CGO callback mechanism for converting C function pointers
// to Go ProgressCallback functions.
package main

/*
#include <stdint.h>
#include <stdlib.h>

// CProgressCallback is the C function pointer type for progress reporting.
// The callback receives:
//   - transfer_type: 0 for export, 1 for import
//   - current_file: the path of the file currently being processed (can be NULL)
//   - files_completed: number of files completed
//   - files_total: total number of files
//   - bytes_completed: number of bytes completed
//   - bytes_total: total number of bytes
//   - is_complete: whether the transfer is complete
//   - error_message: error message if any (can be NULL)
typedef void (*CProgressCallback)(
    int transfer_type,
    const char* current_file,
    int files_completed,
    int files_total,
    long long bytes_completed,
    long long bytes_total,
    int is_complete,
    const char* error_message
);

// call_progress_callback is a helper C function that calls the callback.
// This function is needed to ensure proper calling convention when invoking
// the C function pointer from Go.
static void call_progress_callback(CProgressCallback callback,
                            int transfer_type,
                            const char* current_file,
                            int files_completed,
                            int files_total,
                            long long bytes_completed,
                            long long bytes_total,
                            int is_complete,
                            const char* error_message) {
    if (callback != NULL) {
        callback(transfer_type, current_file, files_completed, files_total,
                 bytes_completed, bytes_total, is_complete, error_message);
    }
}
*/
import "C"
import (
	"sync"
	"unsafe"

	"safe_disk/native/sec_fs/sec_transfer"
)

// ==================== Callback Registry ====================

// callbackRegistry stores active C callback wrappers to prevent GC collection.
// Each callback is assigned a unique ID that can be used to retrieve it later.
type callbackRegistry struct {
	mu        sync.RWMutex
	callbacks map[int64]*CProgressCallbackWrapper
	nextID    int64
}

// CProgressCallbackWrapper wraps a C function pointer and converts it to Go ProgressCallback.
type CProgressCallbackWrapper struct {
	cCallback C.CProgressCallback
	id        int64
}

// newCallbackRegistry creates a new callback registry.
func newCallbackRegistry() *callbackRegistry {
	return &callbackRegistry{
		callbacks: make(map[int64]*CProgressCallbackWrapper),
		nextID:    1,
	}
}

// register stores a C callback wrapper and returns its unique ID.
func (r *callbackRegistry) register(cCallback C.CProgressCallback) int64 {
	r.mu.Lock()
	defer r.mu.Unlock()

	id := r.nextID
	r.nextID++

	wrapper := &CProgressCallbackWrapper{
		cCallback: cCallback,
		id:        id,
	}
	r.callbacks[id] = wrapper

	return id
}

// get retrieves a C callback wrapper by its ID.
func (r *callbackRegistry) get(id int64) (*CProgressCallbackWrapper, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	wrapper, exists := r.callbacks[id]
	return wrapper, exists
}

// unregister removes a C callback wrapper by its ID.
func (r *callbackRegistry) unregister(id int64) {
	r.mu.Lock()
	defer r.mu.Unlock()

	delete(r.callbacks, id)
}

// ==================== Global Callback Registry ====================

// globalCallbackRegistry is the global registry for C callback wrappers.
var globalCallbackRegistry = newCallbackRegistry()

// ==================== C to Go Callback Conversion ====================

// CProgressCallbackToGo converts a C function pointer to a Go ProgressCallback.
// It returns a wrapper ID that should be used to unregister the callback when done.
//
// Usage:
//
//	// In C code, pass the callback function pointer
//	CProgressCallback myCallback = &my_progress_handler;
//	// In Go code, convert to Go callback
//	goCallback, id := CProgressCallbackToGo(myCallback);
//	// Use the callback
//	transfer.ExportDirectoryAsync(root, src, dest, goCallback);
//	// When done, unregister (optional - auto-unregistered on completion)
//	UnregisterCallback(id);
func CProgressCallbackToGo(cCallback C.CProgressCallback) (sec_transfer.ProgressCallback, int64) {
	if cCallback == nil {
		return nil, 0
	}

	// Register the callback and get its ID
	id := globalCallbackRegistry.register(cCallback)

	// Create a Go callback wrapper
	goCallback := func(status sec_transfer.ProgressStatus) {
		// Retrieve the C callback from registry
		wrapper, exists := globalCallbackRegistry.get(id)
		if !exists || wrapper.cCallback == nil {
			return
		}

		// Convert Go strings to C strings
		var cCurrentFile *C.char
		var cErrorMsg *C.char

		if status.CurrentFile != "" {
			cCurrentFile = C.CString(status.CurrentFile)
			defer C.free(unsafe.Pointer(cCurrentFile))
		}

		if status.Error != nil {
			cErrorMsg = C.CString(status.Error.Error())
			defer C.free(unsafe.Pointer(cErrorMsg))
		}

		// Call the C callback via the helper function
		C.call_progress_callback(
			wrapper.cCallback,
			C.int(status.TransferType),
			cCurrentFile,
			C.int(status.FilesCompleted),
			C.int(status.FilesTotal),
			C.longlong(status.BytesCompleted),
			C.longlong(status.BytesTotal),
			C.int(boolToInt(status.IsComplete)),
			cErrorMsg,
		)

		// If transfer is complete, unregister the callback
		if status.IsComplete {
			globalCallbackRegistry.unregister(id)
		}
	}

	return goCallback, id
}

// UnregisterCallback removes a callback from the registry by its ID.
// This should be called when a callback is no longer needed.
// Note: Callbacks are automatically unregistered when the transfer completes,
// so this function is typically only needed for canceling operations.
func UnregisterCallback(id int64) {
	globalCallbackRegistry.unregister(id)
}

// boolToInt converts a bool to an int (0 or 1).
func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// ==================== Exported Helper Functions ====================

// GetCallbackCount returns the number of active callbacks in the registry.
// This is primarily for debugging and testing purposes.
func GetCallbackCount() int {
	return globalCallbackRegistry.count()
}

// count returns the number of registered callbacks.
func (r *callbackRegistry) count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.callbacks)
}
