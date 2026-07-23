package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"testing"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
	"safe_disk/native/sec_fs/sec_webdav"
)

func TestErrorResponseUsesStableCodesForClassifiableRootErrors(t *testing.T) {
	tests := []struct {
		name string
		err  error
		code int
	}{
		{name: "invalid password", err: sec_fs.ErrInvalidPassword, code: ErrorCodeInvalidPassword},
		{name: "missing verifier", err: sec_fs.ErrPasswordVerifierMissing, code: ErrorCodePasswordVerifierAbsent},
		{name: "invalid config", err: sec_fs.ErrInvalidConfig, code: ErrorCodeInvalidConfig},
		{name: "corrupt transfer marker", err: sec_transfer.ErrTransferMarkerCorrupt, code: ErrorCodeTransferMarkerCorrupt},
		{name: "transfer unavailable", err: sec_transfer.ErrTransferV3NotRegistered, code: ErrorCodeTransferV3Unavailable},
		{name: "invalid path", err: sec_fs.ErrInvalidPath, code: ErrorCodeInvalidPath},
		{name: "path traversal", err: sec_fs.ErrPathTraversal, code: ErrorCodePathTraversal},
		{name: "not directory", err: sec_fs.ErrNotADirectory, code: ErrorCodeNotDirectory},
		{name: "unsupported operation", err: sec_fs.ErrUnsupportedOperation, code: ErrorCodeUnsupportedOperation},
		{name: "webdav mount unsupported", err: sec_webdav.ErrMountUnsupported, code: ErrorCodeWebDavMountUnsupported},
		{name: "webdav mount failed", err: sec_webdav.ErrMountFailed, code: ErrorCodeWebDavMountFailed},
		{
			name: "wrapped invalid password",
			err:  fmt.Errorf("open root: %w", sec_fs.ErrInvalidPassword),
			code: ErrorCodeInvalidPassword,
		},
		{name: "unknown", err: errors.New("unknown failure"), code: 0},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var response Response
			if err := json.Unmarshal([]byte(errorResponse(test.err)), &response); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if response.Success {
				t.Fatal("error response unexpectedly succeeded")
			}
			if response.Code != test.code {
				t.Fatalf("code = %d, want %d", response.Code, test.code)
			}
		})
	}
}
