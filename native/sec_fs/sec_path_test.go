// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains tests for path encryption/decryption functions.
package sec_fs

import (
	"encoding/base64"
	"testing"

	"safe_disk/native/sec_fs/sec_utils"
)

// ==================== Path Encryption Tests ====================

// TestPathEncryption_AllPathFormats tests path encryption/decryption for all supported path formats.
func TestPathEncryption_AllPathFormats(t *testing.T) {
	// Create a mock name cryptor
	key := []byte("test-key-32-bytes-long-enough!!!")

	encryptFunc := func(plaintext string) (string, error) {
		if plaintext == "" || plaintext == "." || plaintext == ".." {
			return plaintext, nil
		}
		result := make([]byte, len(plaintext))
		for i, c := range []byte(plaintext) {
			result[i] = c ^ key[i%len(key)]
		}
		// Use Base64 encoding to avoid path separator characters
		return "enc_" + base64.RawURLEncoding.EncodeToString(result), nil
	}

	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" || encrypted == "." || encrypted == ".." {
			return encrypted, nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return encrypted, nil // Not encrypted, return as-is
		}
		data := encrypted[4:]
		decoded, err := base64.RawURLEncoding.DecodeString(data)
		if err != nil {
			return "", err
		}
		result := make([]byte, len(decoded))
		for i, c := range []byte(decoded) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	tests := []struct {
		name      string
		viewPath  RelativeViewPath
		wantError bool
	}{
		// 1. UNC paths (Windows network paths)
		{"UNC path", "\\\\192.168.1.2\\share\\documents\\report.pdf", false},
		{"UNC path with IP", "\\\\192.168.30.100\\data\\files\\config.json", false},
		{"UNC path with hostname", "\\\\server\\share\\folder\\file.txt", false},

		// 2. files:// URI
		{"files:// URI", "files:///documents/report.pdf", false},
		{"files:// nested", "files:///a/b/c/d/file.txt", false},
		{"files:// with backslash separator", "files:///documents\\report.pdf", false},

		// 3. file:// URI (already supported)
		{"file:// URI", "file:///documents/report.pdf", false},
		{"file:// with host", "file://server/share/file.txt", false},

		// 4. Arbitrary URI scheme (xxxx://, xxxx:///)
		{"custom:// URI", "custom://host/path/file.txt", false},
		{"custom:/// URI", "custom:///path/to/file.txt", false},
		{"custom:// with backslash", "custom://host\\path\\file.txt", false},
		{"custom:/// with backslash", "custom:///path\\to\\file.txt", false},
		{"myscheme:// URI", "myscheme://server/share/data.json", false},
		{"test-scheme:/// URI", "test-scheme:///a/b/c/file.dat", false},
		{"abc123:// URI", "abc123://host/path", false},
		{"x.y-z:/// URI", "x.y-z:///data/file.txt", false},

		// 5. Unix absolute paths
		{"Unix absolute path", "/documents/report.pdf", false},
		{"Unix nested path", "/a/b/c/d/file.txt", false},
		{"Unix root", "/", false},

		// 6. Windows drive letters
		{"Windows drive C", "C:\\Documents\\report.pdf", false},
		{"Windows drive D", "d:\\data\\files\\config.json", false},
		{"Windows drive lowercase", "e:\\test\\file.txt", false},

		// 7. Relative paths
		{"Relative path", "documents/report.pdf", false},
		{"Relative nested", "a/b/c/d/file.txt", false},

		// 8. Mixed separators (Windows drive with forward slashes)
		{"Windows drive mixed separators (normalized)", "d:\\data\\files\\config.json", false},

		// 9. Paths with current directory (.) and parent directory (..)
		{"Path with .", "d:\\data\\.\\config.json", false},
		{"Path with ..", "d:\\data\\..\\config.json", false},
		{"Path with multiple ..", "d:\\a\\b\\..\\..\\c\\file.txt", false},
		{"Relative path with .", "documents/./report.pdf", false},
		{"Relative path with ..", "documents/../config.json", false},

		// 10. Complex mixed paths (edge cases)
		{"Complex path 1", "d:\\data\\.\\files\\..\\config.json", false},
		{"Complex path 3", "/a/b/../c/./d/file.txt", false},

		// 11. Consecutive separators (normalized to single separator)
		{"Consecutive backslashes (normalized)", "d:\\data\\files\\config.json", false},
		{"Consecutive forward slashes (normalized)", "/a/b/c/file.txt", false},

		// 12. Extreme edge cases
		{"Extreme mixed path (normalized)", "d:\\xxx\\.\\xxx\\.xxxx\\...\\....\\..\\....", false},

		// 13. URI + Windows drive path combinations
		{"file:// + Windows drive", "file://d:\\data\\file.txt", false},
		{"files:// + Windows drive", "files://d:\\data\\file.txt", false},
		{"file:/// + Windows drive", "file:///d:\\data\\file.txt", false},
		{"files:/// + Windows drive", "files:///d:\\data\\file.txt", false},

		// 14. Unix path with colons (not URI)
		{"Unix path with colon", "/xx/xxx:xx/xxx:/xxxx", false},
		{"Unix path with multiple colons", "/a/b:c/d:e/f:g", false},
		{"Unix path with colon at end", "/path/to/file:attribute", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Encrypt
			storePath, err := ViewPathToStorePath(tt.viewPath, nameCryptor)
			if tt.wantError {
				if err == nil {
					t.Error("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("encryption error: %v", err)
			}

			t.Logf("ViewPath: %q -> StorePath: %q", tt.viewPath, storePath)

			// Decrypt back
			decryptedPath, err := StorePathToViewPath(storePath, nameCryptor)
			if err != nil {
				t.Fatalf("decryption error: %v", err)
			}

			// Round-trip should restore cleaned original
			cleanedInput := sec_utils.PathClean(string(tt.viewPath))
			if string(decryptedPath) != cleanedInput {
				t.Errorf("round trip failed:\n  input:    %q\n  cleaned:   %q\n  encrypted: %q\n  decrypted: %q", tt.viewPath, cleanedInput, storePath, decryptedPath)
			}

			t.Logf("✓ Round trip: %q -> %q -> %q", tt.viewPath, storePath, decryptedPath)
		})
	}
}

// TestPathEncryption_NoEncryption tests that paths are unchanged when no cryptor is provided.
func TestPathEncryption_NoEncryption(t *testing.T) {
	viewPath := RelativeViewPath("documents/report.pdf")

	// No cryptor (nil)
	storePath, err := ViewPathToStorePath(viewPath, nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if string(storePath) != string(viewPath) {
		t.Errorf("path should be unchanged when no cryptor, got: %q", storePath)
	}

	// Decrypt with no cryptor
	decryptedPath, err := StorePathToViewPath(storePath, nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if string(decryptedPath) != string(viewPath) {
		t.Errorf("path should be unchanged when no cryptor, got: %q", decryptedPath)
	}
}
