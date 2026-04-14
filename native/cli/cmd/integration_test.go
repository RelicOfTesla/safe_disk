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
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

// TestMain builds the binary once for all integration tests
func TestMain(m *testing.M) {
	// Build the binary (we're in cli/cmd, so go up to cli directory)
	cmd := exec.Command("go", "build", "-o", "safe-disk-test", ".")
	cmd.Dir = ".." // cli directory (parent of cmd)
	if err := cmd.Run(); err != nil {
		panic("Failed to build binary: " + err.Error())
	}

	// Run tests
	code := m.Run()

	// Cleanup
	os.Remove("../safe-disk-test")

	os.Exit(code)
}

func TestVersionIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	if !strings.Contains(string(output), "Safe Disk CLI v") {
		t.Errorf("Expected version output, got: %s", output)
	}
}

func TestHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	if !strings.Contains(string(output), "Safe Disk CLI") {
		t.Errorf("Expected help output, got: %s", output)
	}
}

func TestListMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "list", "--path", "/tmp/test")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	// Cobra adds "Error: " prefix to errors
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestImportMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--source", "/tmp/test", "--dest", "/tmp/enc")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestExportMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--source", "/tmp/enc", "--dest", "/tmp/plain")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestImportMissingSourceIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--password", "test123", "--dest", "/tmp/enc")
	output, err := cmd.CombinedOutput()
	// Should fail because source is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "source path is required") {
		t.Errorf("Expected 'source path is required' error, got: %s", output)
	}
}

func TestExportMissingSourceIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--password", "test123", "--dest", "/tmp/plain")
	output, err := cmd.CombinedOutput()
	// Should fail because source is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "source path is required") {
		t.Errorf("Expected 'source path is required' error, got: %s", output)
	}
}

func TestListHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "list", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--path", "-p", "-d"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

func TestImportHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--source", "--dest", "--skip-recursive"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

func TestExportHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--source", "--dest", "--skip-recursive"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

// =============================================================================
// Integration Tests - Test complete workflows
// =============================================================================

// TestFullWorkflow tests the complete import -> list -> export workflow
func TestFullWorkflow(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-integration-*")
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
	testStructure := map[string][]byte{
		"root_file.txt":              []byte("Root level file content"),
		"docs/readme.txt":            []byte("Documentation file"),
		"docs/api/guide.txt":         []byte("API guide"),
		"src/main.go":                []byte("package main\n\nfunc main() {}"),
		"src/utils/helper.txt":       []byte("Helper utilities"),
		"data/empty.txt":             []byte(""),
	}

	for relPath, content := range testStructure {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
	}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create file %s: %v", relPath, err)
	}
	}

	password := "integration-test-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Step 1: Import directory
	t.Log("Step 1: Import directory")
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import failed: %v\nOutput: %s", err, output)
	}
	if !strings.Contains(string(output), "Import successful") {
		t.Errorf("Expected 'Import successful' in output, got: %s", output)
	}

	// Step 2: List files
	t.Log("Step 2: List files")
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v\nOutput: %s", err, output)
	}
	listOutput := string(output)
	t.Logf("List output:\n%s", listOutput)

	// Verify all top-level items are listed
	expectedItems := []string{"root_file.txt", "docs", "src", "data"}
	for _, item := range expectedItems {
		if !strings.Contains(listOutput, item) {
			t.Errorf("Expected item '%s' in list output", item)
		}
	}

	// Step 3: Export directory
	t.Log("Step 3: Export directory")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export failed: %v\nOutput: %s", err, output)
	}

	// Step 4: Verify all files exported correctly
	t.Log("Step 4: Verify exported files")
	for relPath, expectedContent := range testStructure {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		decryptedContent, err := os.ReadFile(decryptedPath)
		if err != nil {
			t.Errorf("Failed to read decrypted file %s: %v", relPath, err)
			continue
		}
		if !bytes.Equal(decryptedContent, expectedContent) {
			t.Errorf("Content mismatch for %s\nExpected: %s\nGot: %s",
				relPath, expectedContent, decryptedContent)
		}
	}

	// Step 5: Verify directory structure preserved
	t.Log("Step 5: Verify directory structure")
	for relPath := range testStructure {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		if _, err := os.Stat(decryptedPath); os.IsNotExist(err) {
			t.Errorf("File %s does not exist in decrypted directory", relPath)
		}
	}
}

// TestRoundTripConsistency verifies data integrity after multiple import/export cycles
func TestRoundTripConsistency(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-roundtrip-*")
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

	// Create test file with binary content
	testFile := filepath.Join(plaintextDir, "test.bin")
	testContent := make([]byte, 1024)
	for i := range testContent {
		testContent[i] = byte(i % 256)
	}
	if err := os.WriteFile(testFile, testContent, 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "roundtrip-password"

	// Initialize encrypted root for first cycle
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Perform 5 round trips
	for cycle := 0; cycle < 5; cycle++ {
		t.Logf("Round trip cycle %d", cycle+1)

		// Import
		cmd := exec.Command("../safe-disk-test", "import",
			"--password", password,
			"--source", testFile,
			"--dest", encryptedDir)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Import failed in cycle %d: %v", cycle+1, err)
		}

		// Export
		exportDir := filepath.Join(tmpDir, "export"+string(rune('0'+cycle)))
		if err := os.MkdirAll(exportDir, 0755); err != nil {
			t.Fatalf("Failed to create export dir: %v", err)
		}

		cmd = exec.Command("../safe-disk-test", "export",
			"--password", password,
			"--source", filepath.Join(encryptedDir, "test.bin"),
			"--dest", filepath.Join(exportDir, "test.bin"))
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Export failed in cycle %d: %v", cycle+1, err)
		}

		// Verify content
		exportedContent, err := os.ReadFile(filepath.Join(exportDir, "test.bin"))
		if err != nil {
			t.Fatalf("Failed to read exported file in cycle %d: %v", cycle+1, err)
		}
		if !bytes.Equal(exportedContent, testContent) {
			t.Fatalf("Content mismatch in cycle %d", cycle+1)
		}

		// Clean up encrypted root for next cycle
		os.RemoveAll(encryptedDir)

		// Recreate encrypted root for next cycle
		if cycle < 4 {
			os.MkdirAll(encryptedDir, 0755)
			_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
			if err != nil {
				t.Fatalf("Failed to recreate encrypted root for cycle %d: %v", cycle+2, err)
			}
		}
	}
}

// TestListSpecificFile tests listing a specific file
func TestListSpecificFile(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-list-file-*")
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
	testFile := filepath.Join(plaintextDir, "specific.txt")
	testContent := "Specific file content"
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "list-file-password"

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
		t.Fatalf("Import failed: %v", err)
	}

	// List specific file
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", filepath.Join(encryptedDir, "specific.txt"))
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List specific file failed: %v\nOutput: %s", err, output)
	}

	// Verify output shows the file
	if !strings.Contains(string(output), "specific.txt") {
		t.Errorf("Expected 'specific.txt' in output, got: %s", output)
	}
	if !strings.Contains(string(output), "FILE") {
		t.Errorf("Expected 'FILE' type in output, got: %s", output)
	}
}

// TestListDirectoryWithNestedStructure tests listing a directory with nested structure
func TestListDirectoryWithNestedStructure(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-list-nested-*")
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

	// Create nested structure
	nestedFiles := map[string][]byte{
		"level1/level2/level3/deep.txt": []byte("Deeply nested file"),
		"level1/level2/mid.txt":         []byte("Mid-level file"),
		"level1/top.txt":                []byte("Top-level file"),
	}

	for relPath, content := range nestedFiles {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
	}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create file %s: %v", relPath, err)
	}
	}

	password := "list-nested-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import failed: %v", err)
	}

	// List root
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	// Verify top-level structure
	outputStr := string(output)
	t.Logf("List output:\n%s", outputStr)
	// Only top-level items should be shown (non-recursive list)
	expectedItems := []string{"level1"}
	for _, item := range expectedItems {
		if !strings.Contains(outputStr, item) {
			t.Errorf("Expected '%s' in list output", item)
		}
	}

	// Verify nested structure by exporting and checking files
	decryptedDir := filepath.Join(tmpDir, "decrypted")
	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create decrypted dir: %v", err)
	}

	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export failed: %v", err)
	}

	// Verify all nested files exist after export
	expectedFiles := map[string][]byte{
		"level1/level2/level3/deep.txt": []byte("Deeply nested file"),
		"level1/level2/mid.txt":         []byte("Mid-level file"),
		"level1/top.txt":                []byte("Top-level file"),
	}
	for relPath, expectedContent := range expectedFiles {
		fullPath := filepath.Join(decryptedDir, relPath)
		actualContent, err := os.ReadFile(fullPath)
		if err != nil {
			t.Errorf("File %s not found after export: %v", relPath, err)
			continue
		}
		if string(actualContent) != string(expectedContent) {
			t.Errorf("File %s content mismatch: expected %s, got %s", relPath, expectedContent, actualContent)
		}
	}
}

// TestMultipleUsersDifferentPasswords tests multiple encryption roots with different passwords
func TestMultipleUsersDifferentPasswords(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-multi-user-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	user1Dir := filepath.Join(tmpDir, "user1")
	user2Dir := filepath.Join(tmpDir, "user2")

	for _, dir := range []string{plaintextDir, user1Dir, user2Dir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
	}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "secret.txt")
	testContent := "Secret content"
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password1 := "user1-password"
	password2 := "user2-password"

	// Initialize user1's encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(user1Dir), password1)
	if err != nil {
		t.Fatalf("Failed to create user1's encrypted root: %v", err)
	}

	// Initialize user2's encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(user2Dir), password2)
	if err != nil {
		t.Fatalf("Failed to create user2's encrypted root: %v", err)
	}

	// Import to user1's encrypted root
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password1,
		"--source", testFile,
		"--dest", user1Dir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import to user1 failed: %v", err)
	}

	// Import to user2's encrypted root
	cmd = exec.Command("../safe-disk-test", "import",
		"--password", password2,
		"--source", testFile,
		"--dest", user2Dir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import to user2 failed: %v", err)
	}

	// Verify user1 can access with password1
	decryptedDir1 := filepath.Join(tmpDir, "decrypted1")
	os.MkdirAll(decryptedDir1, 0755)
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password1,
		"--source", filepath.Join(user1Dir, "secret.txt"),
		"--dest", filepath.Join(decryptedDir1, "secret.txt"))
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export from user1 failed: %v", err)
	}

	// Verify user2 can access with password2
	decryptedDir2 := filepath.Join(tmpDir, "decrypted2")
	os.MkdirAll(decryptedDir2, 0755)
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password2,
		"--source", filepath.Join(user2Dir, "secret.txt"),
		"--dest", filepath.Join(decryptedDir2, "secret.txt"))
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export from user2 failed: %v", err)
	}

	// Verify content from both users
	content1, err := os.ReadFile(filepath.Join(decryptedDir1, "secret.txt"))
	if err != nil {
		t.Fatalf("Failed to read user1's decrypted file: %v", err)
	}
	content2, err := os.ReadFile(filepath.Join(decryptedDir2, "secret.txt"))
	if err != nil {
		t.Fatalf("Failed to read user2's decrypted file: %v", err)
	}

	if string(content1) != testContent || string(content2) != testContent {
		t.Error("Content mismatch between users")
	}

	// Verify cross-password access fails
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password2,
		"--source", filepath.Join(user1Dir, "secret.txt"),
		"--dest", filepath.Join(tmpDir, "should_fail.txt"))
	if _, err := cmd.CombinedOutput(); err == nil {
		t.Error("Expected export to fail with wrong password")
	}
}
