package main

import "testing"

func TestNativeLibraryBaseNameFor(t *testing.T) {
	tests := map[string]string{
		"windows": "ffi_sec_fs",
		"linux":   "libffi_sec_fs",
		"darwin":  "libffi_sec_fs",
	}
	for goos, want := range tests {
		if got := nativeLibraryBaseNameFor(goos); got != want {
			t.Fatalf("nativeLibraryBaseNameFor(%q) = %q, want %q", goos, got, want)
		}
	}
}
