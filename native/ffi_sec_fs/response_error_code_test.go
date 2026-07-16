package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"testing"

	"safe_disk/native/sec_fs"
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
