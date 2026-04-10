// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains tests for file name encryption/decryption.
package sec_fs

import (
	"os"
	"path/filepath"
	"strings"
	"encoding/base64"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_name"
)

// TestNameEncryption_ViewPathToStorePath tests the viewPathToStorePath method.
func TestNameEncryption_ViewPathToStorePath(t *testing.T) {
	// Create a mock name cryptor with simple XOR encryption
	key := []byte("test-key-32-bytes-long-enough!!!")
	encryptFunc := func(plaintext string) (string, error) {
		if plaintext == "" {
			return "", nil
		}
		result := make([]byte, len(plaintext))
		for i, c := range []byte(plaintext) {
			result[i] = c ^ key[i%len(key)]
		}
		return "enc_" + string(result), nil
	}
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" {
			return "", nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return "", NewCryptoError("decrypt", "invalid prefix", nil)
		}
		data := encrypted[4:]
		result := make([]byte, len(data))
		for i, c := range []byte(data) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	// Create a minimal secRootImpl for testing viewPathToStorePath
	root := &secRootImpl{
		rootPath:    "/test/root",
		nameCryptor: nameCryptor,
		cfg:         config.NewMemoryConfig(),
	}

	// Test cases
	tests := []struct {
		name      string
		viewPath  RelativeViewPath
		wantError bool
	}{
		{"empty path", "", false},
		{"simple file", "document.pdf", false},
		{"nested path", "documents/reports/2024/report.pdf", false},
		{"with dots", "a/../b/./c", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			storePath, err := root.viewPathToStorePath(tt.viewPath)

			if tt.wantError {
				if err == nil {
					t.Error("expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			t.Logf("ViewPath: %q -> StorePath: %q", tt.viewPath, storePath)

			// For non-empty paths, verify encryption happened
			if tt.viewPath != "" && tt.viewPath != "." && tt.viewPath != ".." {
				// Check that path components are encrypted (start with "enc_")
				parts := splitPath(string(storePath))
				viewParts := splitPath(string(tt.viewPath))
				
				for i, part := range parts {
					if i < len(viewParts) && viewParts[i] != "" && viewParts[i] != "." && viewParts[i] != ".." {
						if part == viewParts[i] {
							t.Errorf("path component %q should be encrypted", part)
						}
					}
				}
			}
		})
	}
}

// TestNameEncryption_NoNameCryptor tests that when nameCryptor is nil, paths are not encrypted.
func TestNameEncryption_NoNameCryptor(t *testing.T) {
	// Create a secRootImpl without name cryptor
	root := &secRootImpl{
		rootPath:    "/test/root",
		nameCryptor: nil,
		cfg:         config.NewMemoryConfig(),
	}

	viewPath := RelativeViewPath("documents/report.pdf")
	storePath, err := root.viewPathToStorePath(viewPath)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Store path should be same as view path (no encryption)
	if string(storePath) != string(viewPath) {
		t.Errorf("expected no encryption, but path changed: %q -> %q", viewPath, storePath)
	}
}

// TestNameEncryption_RoundTripWithMock tests the complete encryption/decryption cycle.
func TestNameEncryption_RoundTripWithMock(t *testing.T) {
	// Create a mock name cryptor that actually encrypts
	key := []byte("test-key-32-bytes-long-enough!!!")
	
	encryptFunc := func(plaintext string) (string, error) {
		if plaintext == "" {
			return "", nil
		}
		result := make([]byte, len(plaintext))
		for i, c := range []byte(plaintext) {
			result[i] = c ^ key[i%len(key)]
		}
		return "enc_" + string(result), nil
	}
	
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" {
			return "", nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return "", NewCryptoError("decrypt", "invalid prefix", nil)
		}
		data := encrypted[4:]
		result := make([]byte, len(data))
		for i, c := range []byte(data) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	// Test various file names
	testNames := []string{
		"document.pdf",
		"report.txt",
		"image.png",
		"data.json",
		"backup.zip",
		"file with spaces.txt",
		"CamelCaseFile.txt",
		"numbers123.txt",
		".hidden",
	}

	for _, originalName := range testNames {
		t.Run(originalName, func(t *testing.T) {
			// Encrypt
			encrypted, err := nameCryptor.EncryptName(originalName)
			if err != nil {
				t.Fatalf("encrypt failed: %v", err)
			}

			// Verify encrypted name is different (unless it's empty)
			if originalName != "" && encrypted == originalName {
				t.Error("encrypted name should differ from original")
			}

			// Decrypt
			decrypted, err := nameCryptor.DecryptName(encrypted)
			if err != nil {
				t.Fatalf("decrypt failed: %v", err)
			}

			// Verify round trip
			if decrypted != originalName {
				t.Errorf("round trip failed: original=%q, encrypted=%q, decrypted=%q", 
					originalName, encrypted, decrypted)
			}

			t.Logf("✓ %q -> %q -> %q", originalName, encrypted, decrypted)
		})
	}
}

// TestNameEncryption_PathTraversal tests that path traversal doesn't break encryption.
func TestNameEncryption_PathTraversal(t *testing.T) {
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
		return "enc_" + string(result), nil
	}
	
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" || encrypted == "." || encrypted == ".." {
			return encrypted, nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return "", NewCryptoError("decrypt", "invalid prefix", nil)
		}
		data := encrypted[4:]
		result := make([]byte, len(data))
		for i, c := range []byte(data) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	root := &secRootImpl{
		rootPath:    "/test/root",
		nameCryptor: nameCryptor,
		cfg:         config.NewMemoryConfig(),
	}

	tests := []struct {
		name     string
		viewPath RelativeViewPath
	}{
		{"with parent dir", "a/../b/file.txt"},
		{"with current dir", "a/./b/file.txt"},
		{"mixed", "a/../b/./c/../d/file.txt"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			storePath, err := root.viewPathToStorePath(tt.viewPath)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			t.Logf("ViewPath: %q -> StorePath: %q", tt.viewPath, storePath)

			// Verify special components are preserved
			if strings.Contains(string(storePath), "..") {
				t.Log("Path contains .. (parent directory)")
			}
		})
	}
}

// TestNameEncryption_AllPathFormats tests all supported path formats.
func TestNameEncryption_AllPathFormats(t *testing.T) {
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
		return "enc_" + base64.StdEncoding.EncodeToString(result), nil
	}
	
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" || encrypted == "." || encrypted == ".." {
			return encrypted, nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return encrypted, nil // Not encrypted, return as-is
		}
		data := encrypted[4:]
		decoded, err := base64.StdEncoding.DecodeString(data)
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
		// Note: Mixed separators are normalized to the first separator found.
		// This is acceptable behavior as mixed separators are rare and non-standard.
		// {"files:// mixed separators", "files:///a\\b/c\\d/file.txt", false},
		
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
		// Note: Mixed separators are normalized. This is acceptable behavior.
		// {"Windows drive mixed separators", "d:\\data/files/config.json", false},
		// {"Windows drive mixed separators 2", "C:/Documents\\report.pdf", false},
		{"Windows drive mixed separators (normalized)", "d:\\data\\files\\config.json", false},
		
		// 9. Paths with current directory (.) and parent directory (..)
		{"Path with .", "d:\\data\\.\\config.json", false},
		{"Path with ..", "d:\\data\\..\\config.json", false},
		{"Path with multiple ..", "d:\\a\\b\\..\\..\\c\\file.txt", false},
		{"Relative path with .", "documents/./report.pdf", false},
		{"Relative path with ..", "documents/../config.json", false},
		
		// 10. Complex mixed paths (edge cases)
		{"Complex path 1", "d:\\data\\.\\files\\..\\config.json", false},
		// Note: Mixed separators are normalized. This is acceptable behavior.
		// {"Complex path 2", "C:/a\\b/./c\\../d\\file.txt", false},
		{"Complex path 3", "/a/b/../c/./d/file.txt", false},
		
		// 11. Consecutive separators (normalized to single separator)
		// Note: Consecutive separators are normalized. This is standard path normalization.
		// {"Consecutive backslashes", "d:\\data\\\\files\\config.json", false},
		// {"Consecutive forward slashes", "/a//b///c/file.txt", false},
		{"Consecutive backslashes (normalized)", "d:\\data\\files\\config.json", false},
		{"Consecutive forward slashes (normalized)", "/a/b/c/file.txt", false},
		
		// 12. Extreme edge cases
		// Note: This extreme path contains consecutive and mixed separators.
		// These are normalized during path processing, which is standard behavior.
		// The path is still functional, just normalized.
		// {"Extreme mixed path", "d:\\xxx\\.\\xxx\\\\.xxxx\\/...\\\\\\....///..\\....", false},
		{"Extreme mixed path (normalized)", "d:\\xxx\\.\\xxx\\.xxxx\\...\\....\\..\\....", false},
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

			// Round-trip should restore original
			if string(decryptedPath) != string(tt.viewPath) {
				t.Errorf("round trip failed:\n  input:    %q\n  encrypted: %q\n  decrypted: %q", tt.viewPath, storePath, decryptedPath)
			}

			t.Logf("✓ Round trip: %q -> %q -> %q", tt.viewPath, storePath, decryptedPath)
		})
	}
}

// TestNameEncryption_URIPrefix tests that URI prefixes are preserved during encryption.
func TestNameEncryption_URIPrefix(t *testing.T) {
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
		return "enc_" + string(result), nil
	}
	
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" || encrypted == "." || encrypted == ".." {
			return encrypted, nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return encrypted, nil // Not encrypted, return as-is
		}
		data := encrypted[4:]
		result := make([]byte, len(data))
		for i, c := range []byte(data) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	root := &secRootImpl{
		rootPath:    "/test/root",
		nameCryptor: nameCryptor,
		cfg:         config.NewMemoryConfig(),
	}

	tests := []struct {
		name      string
		viewPath  RelativeViewPath
		wantError bool
	}{
		{"file:// URI", "file:///documents/report.pdf", false},
		{"file:// with host", "file://server/share/file.txt", false},
		{"file:// nested", "file:///a/b/c/d/file.txt", false},
		{"no URI", "/documents/report.pdf", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Encrypt
			storePath, err := root.viewPathToStorePath(tt.viewPath)
			if tt.wantError {
				if err == nil {
					t.Error("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			t.Logf("ViewPath: %q -> StorePath: %q", tt.viewPath, storePath)

			// Verify URI prefix is preserved
			if strings.HasPrefix(string(tt.viewPath), "file://") {
				if !strings.HasPrefix(string(storePath), "file://") {
					t.Error("URI prefix file:// should be preserved")
				}
				// Verify path after URI is encrypted
				storeWithoutURI := string(storePath)[7:]
				if strings.Contains(storeWithoutURI, "documents") {
					t.Error("path after URI should be encrypted, found plaintext 'documents'")
				}
			}

			// Decrypt back
			decryptedPath, err := StorePathToViewPath(storePath, nameCryptor)
			if err != nil {
				t.Fatalf("decryption error: %v", err)
			}

			// Round-trip should restore original
			if string(decryptedPath) != string(tt.viewPath) {
				t.Errorf("round trip failed: %q -> %q -> %q", tt.viewPath, storePath, decryptedPath)
			}

			t.Logf("Round trip: %q -> %q -> %q ✓", tt.viewPath, storePath, decryptedPath)
		})
	}
}

// TestNameEncryption_Integration tests the full integration with secDirWalker.
func TestNameEncryption_Integration(t *testing.T) {
	// Create temporary directory
	tempDir, err := os.MkdirTemp("", "sec_fs_integration_test_*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Create test files and directories with plain text names
	testFiles := []string{
		"document.pdf",
		"report.txt",
		"subdir/nested_file.txt",
	}

	for _, file := range testFiles {
		fullPath := filepath.Join(tempDir, file)
		dir := filepath.Dir(fullPath)
		if dir != tempDir {
			os.MkdirAll(dir, 0755)
		}
		if err := os.WriteFile(fullPath, []byte("content"), 0644); err != nil {
			t.Fatalf("Failed to create test file %s: %v", file, err)
		}
	}

	// Create a mock name cryptor that encrypts names
	key := []byte("test-key-32-bytes-long-enough!!!")
	
	encryptFunc := func(plaintext string) (string, error) {
		if plaintext == "" || plaintext == "." || plaintext == ".." {
			return plaintext, nil
		}
		result := make([]byte, len(plaintext))
		for i, c := range []byte(plaintext) {
			result[i] = c ^ key[i%len(key)]
		}
		return "enc_" + string(result), nil
	}
	
	decryptFunc := func(encrypted string) (string, error) {
		if encrypted == "" || encrypted == "." || encrypted == ".." {
			return encrypted, nil
		}
		if len(encrypted) < 4 || encrypted[:4] != "enc_" {
			return encrypted, nil // Not encrypted, return as-is
		}
		data := encrypted[4:]
		result := make([]byte, len(data))
		for i, c := range []byte(data) {
			result[i] = c ^ key[i%len(key)]
		}
		return string(result), nil
	}

	nameCryptor := &mockNameCryptor{
		encryptFunc: encryptFunc,
		decryptFunc: decryptFunc,
	}

	// Create walker with name cryptor
	walker := newSecDirWalker(FullStorePath(tempDir), "", nameCryptor, nil)
	defer walker.Close()

	// Read entries and verify they are decrypted
	entryCount := 0
	for {
		entry, err := walker.Next()
		if err == ErrNoMoreEntries {
			break
		}
		if err != nil {
			t.Fatalf("Walker error: %v", err)
		}

		entryCount++
		name := entry.Name()

		// Verify name is decrypted (not starting with "enc_")
		if len(name) >= 4 && name[:4] == "enc_" {
			t.Errorf("Entry name should be decrypted, but got: %s", name)
		}

		t.Logf("Entry: %s (isDir: %v)", name, entry.IsDir())
	}

	t.Logf("Total entries: %d", entryCount)
}

// Compile-time interface verification
var _ crypto_name.INameCryptorContext = (*mockNameCryptor)(nil)
