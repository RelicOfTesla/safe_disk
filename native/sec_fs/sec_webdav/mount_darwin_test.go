//go:build darwin

package sec_webdav

import "testing"

func TestExtractURLHost(t *testing.T) {
	tests := []struct {
		url  string
		want string
	}{
		{"http://127.0.0.1:8080/webdav/abc/", "127.0.0.1:8080"},
		{"https://localhost/webdav/abc/", "localhost"},
		{"http://192.168.1.1:1234", "192.168.1.1:1234"},
		{"https://example.com/path?q=1", "example.com"},
		{"http://host:80/path#frag", "host:80"},
	}
	for _, tt := range tests {
		got := extractURLHost(tt.url)
		if got != tt.want {
			t.Errorf("extractURLHost(%q) = %q, want %q", tt.url, got, tt.want)
		}
	}
}
