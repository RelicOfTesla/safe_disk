//go:build windows

package sec_webdav

import "testing"

func TestWindowsWebDAVUNC(t *testing.T) {
	got, err := windowsWebDAVUNC("http://127.0.0.1:4321/webdav/session-1/")
	if err != nil {
		t.Fatal(err)
	}
	if want := `\\127.0.0.1@4321\DavWWWRoot\webdav\session-1`; got != want {
		t.Fatalf("UNC = %q, want %q", got, want)
	}
}

func TestWindowsWebDAVUNCRejectsNonLoopback(t *testing.T) {
	if _, err := windowsWebDAVUNC("http://example.test:4321/webdav/session-1/"); err == nil {
		t.Fatal("non-loopback URL was accepted")
	}
}
