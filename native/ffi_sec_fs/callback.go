// Package main provides the Transfer V3 CGO progress callback adapter.
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
