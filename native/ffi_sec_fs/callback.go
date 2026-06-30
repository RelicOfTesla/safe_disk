// Package main provides FFI adapter layer for sec_fs and Transfer V3.
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
//   - is_complete: whether the transfer is complete
//   - error_message: error message if any (can be NULL)
typedef void (*CProgressCallback)(
    const char* current_file,
    int files_completed,
    int files_total,
    int is_complete,
    const char* error_message
);

// call_progress_callback is a helper C function that calls the callback.
// This function is needed to ensure proper calling convention when invoking
// the C function pointer from Go.
static void call_progress_callback(CProgressCallback callback,
                            const char* current_file,
                            int files_completed,
                            int files_total,
                            int is_complete,
                            const char* error_message) {
    if (callback != NULL) {
        callback(current_file, files_completed, files_total,
                 is_complete, error_message);
    }
}
*/
import "C"
import (
	"unsafe"

	"safe_disk/native/sec_fs/sec_transfer"
)

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
func CProgressCallbackToGo(cCallback C.CProgressCallback) sec_transfer.ProgressCallback {
	if cCallback == nil {
		return nil
	}

	// Create a Go callback wrapper
	goCallback := func(status sec_transfer.ITransferProgress) {

		// Convert Go strings to C strings
		var cCurrentFile *C.char
		var cErrorMsg *C.char

		if status.GetCurrentFile() != "" {
			cCurrentFile = C.CString(status.GetCurrentFile())
			defer C.free(unsafe.Pointer(cCurrentFile))
		}

		if err := status.GetError(); err != nil {
			cErrorMsg = C.CString(err.Error())
			defer C.free(unsafe.Pointer(cErrorMsg))
		}

		// Call the C callback via the helper function
		C.call_progress_callback(
			cCallback,
			cCurrentFile,
			C.int(status.GetCompleted()),
			C.int(status.GetTotal()),
			C.int(boolToInt(status.IsComplete())),
			cErrorMsg,
		)

	}

	return goCallback
}

func CProgressCallbackToGoV3(cCallback C.CProgressCallback) sec_transfer.V3ProgressCallback {
	if cCallback == nil {
		return nil
	}

	return func(event sec_transfer.ProgressEvent) {
		var cCurrentFile *C.char
		var cErrorMsg *C.char

		if event.CurrentPath != "" {
			cCurrentFile = C.CString(event.CurrentPath)
			defer C.free(unsafe.Pointer(cCurrentFile))
		}

		if event.Error != nil {
			cErrorMsg = C.CString(event.Error.Error())
			defer C.free(unsafe.Pointer(cErrorMsg))
		}

		C.call_progress_callback(
			cCallback,
			cCurrentFile,
			C.int(event.DoneFiles),
			C.int(event.TotalFiles),
			C.int(boolToInt(event.Complete)),
			cErrorMsg,
		)
	}
}

// boolToInt converts a bool to an int (0 or 1).
func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
