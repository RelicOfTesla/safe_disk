package cmd

import (
	"bytes"
	"crypto/rand"
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
// Functional Tests - Test actual functionality with real encryption/decryption
// =============================================================================

// TestImportExportFile tests importing a single file and exporting it back
func TestImportExportFile(t *testing.T) {
	// Setup: create temp directories
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

	// Create test file with known content
	testFile := filepath.Join(plaintextDir, "test.txt")
	testContent := []byte("Hello, Safe Disk! This is a test file with known content.")
	if err := os.WriteFile(testFile, testContent, 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "test-password-123"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Step 1: Import file
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", testFile,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import command failed: %v\nOutput: %s", err, output)
	}
	if !strings.Contains(string(output), "Import successful") {
		t.Errorf("Expected 'Import successful' in output, got: %s", output)
	}

	// Step 2: Verify file exists in encrypted root
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to open encrypted root: %v", err)
	}
	defer root.Close()

	exists := root.FileExists("test.txt")
	if !exists {
		t.Error("File 'test.txt' does not exist in encrypted root")
	}

	// Step 3: Export file
	exportFile := filepath.Join(decryptedDir, "test.txt")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "test.txt"),
		"--dest", exportFile)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export command failed: %v\nOutput: %s", err, output)
	}

	// Step 4: Verify content matches
	decryptedContent, err := os.ReadFile(exportFile)
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}

	if !bytes.Equal(decryptedContent, testContent) {
		t.Errorf("Content mismatch!\nExpected: %s\nGot: %s", testContent, decryptedContent)
	}
}

// TestImportExportDirectory tests importing a directory and exporting it back
func TestImportExportDirectory(t *testing.T) {
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

	// Create test directory structure
	testFiles := map[string][]byte{
		"file1.txt":               []byte("Content of file1"),
		"file2.txt":               []byte("Content of file2"),
		"subdir/file3.txt":        []byte("Content of file3 in subdir"),
		"subdir/nested/file4.txt": []byte("Content of file4 in nested subdir"),
	}

	for relPath, content := range testFiles {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create test file %s: %v", relPath, err)
		}
	}

	password := "test-password-456"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Step 1: Import directory
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import command failed: %v\nOutput: %s", err, output)
	}

	// Step 2: Export directory
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export command failed: %v\nOutput: %s", err, output)
	}

	// Step 3: Verify all files exist and content matches
	for relPath, expectedContent := range testFiles {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		decryptedContent, err := os.ReadFile(decryptedPath)
		if err != nil {
			t.Errorf("Failed to read decrypted file %s: %v", relPath, err)
			continue
		}

		if !bytes.Equal(decryptedContent, expectedContent) {
			t.Errorf("Content mismatch for %s!\nExpected: %s\nGot: %s",
				relPath, expectedContent, decryptedContent)
		}
	}

	// Step 4: Verify directory structure
	for relPath := range testFiles {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		if _, err := os.Stat(decryptedPath); os.IsNotExist(err) {
			t.Errorf("File %s does not exist in decrypted directory", relPath)
		}
	}
}

// TestListCommand tests the list command
func TestListCommand(t *testing.T) {
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

	// Create test files
	testFiles := map[string][]byte{
		"file1.txt":        []byte("Content 1"),
		"file2.txt":        []byte("Content 2"),
		"subdir/file3.txt": []byte("Content 3"),
	}

	for relPath, content := range testFiles {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create test file %s: %v", relPath, err)
		}
	}

	password := "test-password-789"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import files
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import command failed: %v", err)
	}

	// Test list command
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List command failed: %v\nOutput: %s", err, output)
	}

	// Verify output contains expected files (non-recursive)
	outputStr := string(output)
	// Only top-level items should be shown
	expectedFiles := []string{"file1.txt", "file2.txt", "subdir"}
	for _, file := range expectedFiles {
		if !strings.Contains(outputStr, file) {
			t.Errorf("Expected file '%s' in list output, got: %s", file, outputStr)
		}
	}
	// file3.txt is inside subdir, should NOT be shown in non-recursive list
	if strings.Contains(outputStr, "file3.txt") {
		t.Error("file3.txt should not be shown in non-recursive list (it's inside subdir)")
	}
}

func TestListCommandReportsUnexpectedPlainStoreEntry(t *testing.T) {
	tmpDir := t.TempDir()
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	password := "list-corruption-password"

	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password); err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}
	if err := os.WriteFile(filepath.Join(encryptedDir, "unexpected-plaintext-entry"), []byte("invalid"), 0600); err != nil {
		t.Fatalf("Failed to inject unexpected plain store entry: %v", err)
	}

	cmd := exec.Command("../safe-disk-test", "list", "--password", password, "--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("list must fail rather than silently omit a corrupted store entry; output: %s", output)
	}
	if !strings.Contains(string(output), "decrypt_entry_name") {
		t.Fatalf("expected decrypt_entry_name error, got: %s", output)
	}
}

// TestLargeFile tests importing/exporting a large file
func TestLargeFile(t *testing.T) {
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

	// Create a large file (1MB)
	largeFile := filepath.Join(plaintextDir, "large.bin")
	largeContent := make([]byte, 1024*1024) // 1MB
	if _, err := rand.Read(largeContent); err != nil {
		t.Fatalf("Failed to generate random content: %v", err)
	}
	if err := os.WriteFile(largeFile, largeContent, 0644); err != nil {
		t.Fatalf("Failed to create large file: %v", err)
	}

	password := "test-large-file-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import large file
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", largeFile,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import command failed: %v\nOutput: %s", err, output)
	}

	// Export large file
	exportFile := filepath.Join(decryptedDir, "large.bin")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "large.bin"),
		"--dest", exportFile)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export command failed: %v\nOutput: %s", err, output)
	}

	// Verify content matches
	decryptedContent, err := os.ReadFile(exportFile)
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}

	if !bytes.Equal(decryptedContent, largeContent) {
		t.Error("Large file content mismatch after export")
	}
}

// TestBinaryFile tests importing/exporting binary files
func TestBinaryFile(t *testing.T) {
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

	// Create binary file with all byte values
	binaryFile := filepath.Join(plaintextDir, "binary.bin")
	binaryContent := make([]byte, 256)
	for i := 0; i < 256; i++ {
		binaryContent[i] = byte(i)
	}
	if err := os.WriteFile(binaryFile, binaryContent, 0644); err != nil {
		t.Fatalf("Failed to create binary file: %v", err)
	}

	password := "test-binary-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", binaryFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import command failed: %v", err)
	}

	// Export
	exportFile := filepath.Join(decryptedDir, "binary.bin")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "binary.bin"),
		"--dest", exportFile)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export command failed: %v", err)
	}

	// Verify
	decryptedContent, err := os.ReadFile(exportFile)
	if err != nil {
		t.Fatalf("Failed to read decrypted file: %v", err)
	}

	if !bytes.Equal(decryptedContent, binaryContent) {
		t.Error("Binary file content mismatch after export")
	}
}

// TestEmptyFile tests importing/exporting an empty file
func TestEmptyFile(t *testing.T) {
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

	// Create empty file
	emptyFile := filepath.Join(plaintextDir, "empty.txt")
	if err := os.WriteFile(emptyFile, []byte{}, 0644); err != nil {
		t.Fatalf("Failed to create empty file: %v", err)
	}

	password := "test-empty-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", emptyFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import command failed: %v", err)
	}

	// Export
	exportFile := filepath.Join(decryptedDir, "empty.txt")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "empty.txt"),
		"--dest", exportFile)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export command failed: %v", err)
	}

	// Verify file exists and is empty
	info, err := os.Stat(exportFile)
	if err != nil {
		t.Fatalf("Failed to stat exported file: %v", err)
	}
	if info.Size() != 0 {
		t.Errorf("Expected empty file, got size %d", info.Size())
	}
}

// TestUnicodeFilename tests files with unicode characters in filename
func TestUnicodeFilename(t *testing.T) {
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

	// Create files with unicode names
	unicodeFiles := map[string][]byte{
		"中文文件.txt":         []byte("Chinese filename"),
		"日本語ファイル.txt":      []byte("Japanese filename"),
		"한국어파일.txt":        []byte("Korean filename"),
		"Ελληνικά.txt":     []byte("Greek filename"),
		"العربية.txt":      []byte("Arabic filename"),
		"עברית.txt":        []byte("Hebrew filename"),
		"emoji_🎉_file.txt": []byte("Emoji filename"),
	}

	for filename, content := range unicodeFiles {
		fullPath := filepath.Join(plaintextDir, filename)
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create unicode file %s: %v", filename, err)
		}
	}

	password := "test-unicode-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import all files
	for filename := range unicodeFiles {
		cmd := exec.Command("../safe-disk-test", "import",
			"--password", password,
			"--source", filepath.Join(plaintextDir, filename),
			"--dest", encryptedDir)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Import command failed for %s: %v", filename, err)
		}
	}

	// Export all files
	for filename, expectedContent := range unicodeFiles {
		exportFile := filepath.Join(decryptedDir, filename)
		cmd := exec.Command("../safe-disk-test", "export",
			"--password", password,
			"--source", filepath.Join(encryptedDir, filename),
			"--dest", exportFile)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Export command failed for %s: %v", filename, err)
		}

		// Verify content
		decryptedContent, err := os.ReadFile(exportFile)
		if err != nil {
			t.Errorf("Failed to read decrypted file %s: %v", filename, err)
			continue
		}

		if !bytes.Equal(decryptedContent, expectedContent) {
			t.Errorf("Content mismatch for %s", filename)
		}
	}
}

// TestExportToStdout tests exporting a file to stdout
func TestExportToStdout(t *testing.T) {
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
	testFile := filepath.Join(plaintextDir, "stdout_test.txt")
	testContent := []byte("This content should go to stdout")
	if err := os.WriteFile(testFile, testContent, 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "test-stdout-password"

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
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import command failed: %v", err)
	}

	// Export to stdout (no --dest or --dest -)
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", filepath.Join(encryptedDir, "stdout_test.txt"))
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export to stdout failed: %v\nOutput: %s", err, output)
	}

	// Verify output matches original content
	if !bytes.Contains(output, testContent) {
		t.Errorf("Stdout output doesn't match expected content\nExpected: %s\nGot: %s",
			testContent, output)
	}
}

// TestSkipRecursive tests the --skip-recursive flag
func TestSkipRecursive(t *testing.T) {
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

	// Create nested directory structure
	testFiles := map[string][]byte{
		"top_level.txt":     []byte("Top level file"),
		"subdir/nested.txt": []byte("Nested file"),
	}

	for relPath, content := range testFiles {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create test file %s: %v", relPath, err)
		}
	}

	password := "test-skip-recursive-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import with --skip-recursive
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir,
		"--skip-recursive")
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import with --skip-recursive failed: %v", err)
	}

	// Export with --skip-recursive
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir,
		"--skip-recursive")
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export with --skip-recursive failed: %v", err)
	}

	// Verify only top-level files were exported
	topLevelFile := filepath.Join(decryptedDir, "top_level.txt")
	if _, err := os.Stat(topLevelFile); os.IsNotExist(err) {
		t.Error("Top-level file was not exported with --skip-recursive")
	}

	// Note: The behavior of --skip-recursive depends on implementation
	// This test just verifies the flag is accepted and doesn't cause errors
}
