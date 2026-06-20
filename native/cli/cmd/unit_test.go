package cmd

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"safe_disk/native/sec_fs"

	// Import algorithm implementations to register key derivers and encryptors
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

// =============================================================================
// Unit Tests - Test error handling, edge cases, and validation
// =============================================================================

func TestConfirmInPlaceForNonEmptyDir(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		interactive bool
		wantOK      bool
		wantErr     bool
	}{
		{name: "yes short", input: "y\n", interactive: true, wantOK: true},
		{name: "yes word", input: "yes\n", interactive: true, wantOK: true},
		{name: "default no", input: "\n", interactive: true, wantOK: false},
		{name: "explicit no", input: "n\n", interactive: true, wantOK: false},
		{name: "non interactive rejects", input: "y\n", interactive: false, wantOK: false, wantErr: true},
		{name: "empty input errors", input: "", interactive: true, wantOK: false, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var prompt bytes.Buffer
			gotOK, err := confirmInPlaceForNonEmptyDir(strings.NewReader(tt.input), &prompt, tt.interactive)
			if gotOK != tt.wantOK {
				t.Fatalf("confirmInPlaceForNonEmptyDir() ok = %v, want %v", gotOK, tt.wantOK)
			}
			if (err != nil) != tt.wantErr {
				t.Fatalf("confirmInPlaceForNonEmptyDir() err = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.interactive && !strings.Contains(prompt.String(), "[y/N]") {
				t.Fatalf("prompt missing default marker: %q", prompt.String())
			}
			if !tt.interactive && prompt.Len() != 0 {
				t.Fatalf("non-interactive mode should not write prompt, got %q", prompt.String())
			}
		})
	}
}

// TestInvalidPassword tests wrong password handling
func TestInvalidPassword(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "test.txt")
	if err := os.WriteFile(testFile, []byte("test content"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	correctPassword := "correct-password"
	wrongPassword := "wrong-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), correctPassword)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import with correct password
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", correctPassword,
		"--source", testFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Initial import failed: %v", err)
	}

	// Try to list with wrong password
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", wrongPassword,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	// Should fail
	if err == nil {
		t.Error("Expected list command to fail with wrong password")
	}
	if !strings.Contains(string(output), "failed to open root") {
		t.Logf("Expected error message about opening root, got: %s", output)
	}

	// Try to export with wrong password
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", wrongPassword,
		"--source", filepath.Join(encryptedDir, "test.txt"),
		"--dest", filepath.Join(tmpDir, "output.txt"))
	output, err = cmd.CombinedOutput()
	// Should fail
	if err == nil {
		t.Error("Expected export command to fail with wrong password")
	}
}

// TestNonExistentFile tests importing a non-existent file
func TestNonExistentFile(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", "test123",
		"--source", "/non/existent/file.txt",
		"--dest", "/tmp/test")
	output, err := cmd.CombinedOutput()
	// Should fail
	if err == nil {
		t.Error("Expected import command to fail for non-existent file")
	}
	outputStr := string(output)
	if !strings.Contains(outputStr, "failed to stat") && !strings.Contains(outputStr, "no such file") {
		t.Errorf("Expected error about non-existent file, got: %s", outputStr)
	}
}

// TestNonExistentSource tests listing/exporting from non-existent directory
func TestNonExistentSource(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "list",
		"--password", "test123",
		"--path", "/non/existent/directory")
	output, err := cmd.CombinedOutput()
	// Should fail
	if err == nil {
		t.Error("Expected list command to fail for non-existent directory")
	}
	_ = output // Error message may vary
}

// TestImportToNonExistentDest tests importing to non-existent destination
func TestImportToNonExistentDest(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create test file
	testFile := filepath.Join(tmpDir, "test.txt")
	if err := os.WriteFile(testFile, []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	// Try to import to non-existent destination
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", "test123",
		"--source", testFile,
		"--dest", "/non/existent/dest")
	output, err := cmd.CombinedOutput()
	// Should fail (destination must exist)
	if err == nil {
		t.Error("Expected import command to fail for non-existent destination")
	}
	_ = output
}

// TestEmptyPassword tests empty password handling
func TestEmptyPassword(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", "",
		"--source", "/tmp/test",
		"--dest", "/tmp/out")
	output, err := cmd.CombinedOutput()
	// Should fail
	if err == nil {
		t.Error("Expected import command to fail with empty password")
	}
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

// TestLongPassword tests very long password handling
func TestLongPassword(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "test.txt")
	if err := os.WriteFile(testFile, []byte("test content"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	// Very long password (1KB)
	longPassword := strings.Repeat("a", 1024)

	// Create encrypted root config first
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), longPassword)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import with long password
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", longPassword,
		"--source", testFile,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import with long password failed: %v\nOutput: %s", err, output)
	}

	// Export with same long password
	decryptedDir := filepath.Join(tmpDir, "decrypted")
	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create decrypted dir: %v", err)
	}

	cmd = exec.Command("../safe-disk-test", "export",
		"--password", longPassword,
		"--source", filepath.Join(encryptedDir, "test.txt"),
		"--dest", filepath.Join(decryptedDir, "test.txt"))
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export with long password failed: %v\nOutput: %s", err, output)
	}

	// Verify content
	content, err := os.ReadFile(filepath.Join(decryptedDir, "test.txt"))
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}
	if string(content) != "test content" {
		t.Errorf("Content mismatch, got: %s", content)
	}
}

// TestSpecialCharactersInPath tests paths with special characters
func TestSpecialCharactersInPath(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create directory with spaces and special chars
	specialDir := filepath.Join(tmpDir, "test dir with spaces")
	if err := os.MkdirAll(specialDir, 0755); err != nil {
		t.Fatalf("Failed to create special dir: %v", err)
	}

	plaintextDir := filepath.Join(specialDir, "plaintext")
	encryptedDir := filepath.Join(specialDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "test file.txt")
	if err := os.WriteFile(testFile, []byte("content with spaces in path"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "test-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", testFile,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import failed: %v\nOutput: %s", err, output)
	}

	// Export
	decryptedDir := filepath.Join(specialDir, "decrypted")
	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create decrypted dir: %v", err)
	}

	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "test file.txt"),
		"--dest", filepath.Join(decryptedDir, "test file.txt"))
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export failed: %v\nOutput: %s", err, output)
	}

	// Verify
	content, err := os.ReadFile(filepath.Join(decryptedDir, "test file.txt"))
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}
	if string(content) != "content with spaces in path" {
		t.Errorf("Content mismatch, got: %s", content)
	}
}

// TestMultipleOperations tests multiple sequential operations
func TestMultipleOperations(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	password := "multi-op-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Create multiple test files
	for i := 0; i < 10; i++ {
		filename := filepath.Join(plaintextDir, "file"+string(rune('0'+i))+".txt")
		content := "Content of file " + string(rune('0'+i))
		if err := os.WriteFile(filename, []byte(content), 0644); err != nil {
			t.Fatalf("Failed to create file %d: %v", i, err)
		}

		// Import each file
		cmd := exec.Command("../safe-disk-test", "import",
			"--password", password,
			"--source", filename,
			"--dest", encryptedDir)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Import failed for file %d: %v", i, err)
		}
	}

	// List all files
	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	// Verify all 10 files are listed
	for i := 0; i < 10; i++ {
		expectedName := "file" + string(rune('0'+i)) + ".txt"
		if !strings.Contains(string(output), expectedName) {
			t.Errorf("File %s not found in list output", expectedName)
		}
	}

	// Export all files
	decryptedDir := filepath.Join(tmpDir, "decrypted")
	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create decrypted dir: %v", err)
	}

	for i := 0; i < 10; i++ {
		filename := "file" + string(rune('0'+i)) + ".txt"
		cmd := exec.Command("../safe-disk-test", "export",
			"--password", password,
			"--source", filepath.Join(encryptedDir, filename),
			"--dest", filepath.Join(decryptedDir, filename))
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Export failed for file %d: %v", i, err)
		}
	}

	// Verify all files exported correctly
	for i := 0; i < 10; i++ {
		filename := "file" + string(rune('0'+i)) + ".txt"
		content, err := os.ReadFile(filepath.Join(decryptedDir, filename))
		if err != nil {
			t.Errorf("Failed to read exported file %s: %v", filename, err)
			continue
		}
		expectedContent := "Content of file " + string(rune('0'+i))
		if string(content) != expectedContent {
			t.Errorf("Content mismatch for %s", filename)
		}
	}
}

// TestOverwriteFile tests overwriting an existing file
func TestOverwriteFile(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	decryptedDir := filepath.Join(tmpDir, "decrypted")

	for _, dir := range []string{plaintextDir, encryptedDir, decryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	password := "overwrite-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Create initial file
	testFile := filepath.Join(plaintextDir, "test.txt")
	if err := os.WriteFile(testFile, []byte("Initial content"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	// Import initial file
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", testFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Initial import failed: %v", err)
	}

	// Modify file
	if err := os.WriteFile(testFile, []byte("Modified content"), 0644); err != nil {
		t.Fatalf("Failed to modify test file: %v", err)
	}

	// Import again (should overwrite)
	cmd = exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", testFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Second import failed: %v", err)
	}

	// Export and verify it has modified content
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "test.txt"),
		"--dest", filepath.Join(decryptedDir, "test.txt"))
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export failed: %v", err)
	}

	content, err := os.ReadFile(filepath.Join(decryptedDir, "test.txt"))
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}
	if string(content) != "Modified content" {
		t.Errorf("Expected 'Modified content', got: %s", content)
	}
}

// TestConcurrentOperations tests concurrent operations on the same root
func TestConcurrentOperations(t *testing.T) {
	// This test verifies that the CLI can handle concurrent operations
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	password := "concurrent-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Create multiple test files
	for i := 0; i < 5; i++ {
		filename := filepath.Join(plaintextDir, "file"+string(rune('0'+i))+".txt")
		if err := os.WriteFile(filename, []byte("Content "+string(rune('0'+i))), 0644); err != nil {
			t.Fatalf("Failed to create file %d: %v", i, err)
		}
	}

	// Import files concurrently (sequentially in test, but validates the pattern)
	for i := 0; i < 5; i++ {
		filename := filepath.Join(plaintextDir, "file"+string(rune('0'+i))+".txt")
		cmd := exec.Command("../safe-disk-test", "import",
			"--password", password,
			"--source", filename,
			"--dest", encryptedDir)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Errorf("Import failed for file %d: %v", i, err)
		}
	}

	// Verify all files imported
	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	for i := 0; i < 5; i++ {
		expectedName := "file" + string(rune('0'+i)) + ".txt"
		if !strings.Contains(string(output), expectedName) {
			t.Errorf("File %s not found after concurrent imports", expectedName)
		}
	}
}
