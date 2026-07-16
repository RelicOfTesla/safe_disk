// Package sec_fs_test provides tests for sec_fs package.
// This file contains tests for multi-layer directory file read/write operations.
package sec_fs_test

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"safe_disk/native/sec_fs"

	// Import algorithm implementations to trigger init() registration
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_xts"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/chacha20"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/none"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/rc4"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/pbkdf2"
)

// TestMultiLayerDirectoryReadWrite tests file read/write operations in multi-layer directories.
// This test verifies:
// 1. Multi-layer directory creation (a/b/c/d/e)
// 2. File creation in each layer
// 3. File write operations
// 4. File close and reopen
// 5. File read verification
// 6. All name encryption and data encryption algorithm combinations
func TestMultiLayerDirectoryReadWrite(t *testing.T) {
	// Define test configurations
	nameFactories := []string{"AES-256-GCM", "None", "RC4"}
	dataFactories := []string{"AES-CTR", "AES-XTS", "ChaCha20", "RC4"}

	// Test all combinations
	for _, nameFactory := range nameFactories {
		for _, dataFactory := range dataFactories {
			testName := fmt.Sprintf("NameFactory_%s_DataFactory_%s", nameFactory, dataFactory)
			t.Run(testName, func(t *testing.T) {
				testMultiLayerDirectoryReadWriteWithAlgorithms(t, nameFactory, dataFactory)
			})
		}
	}
}

// testMultiLayerDirectoryReadWriteWithAlgorithms tests file operations with specific algorithms.
func testMultiLayerDirectoryReadWriteWithAlgorithms(t *testing.T, nameFactory string, dataFactory string) {
	// Create temporary directory for test
	tempDir := t.TempDir()
	rootPath := sec_fs.FullStorePath(filepath.Join(tempDir, "safe_disk_root"))
	password := "test-password-123"

	// Step 1: Create encrypted root directory
	t.Logf("Creating encrypted root directory at: %s", rootPath)
	t.Logf("Name factory: %s, Data factory: %s", nameFactory, dataFactory)

	_, _, err := sec_fs.CreateRootConfigQuick(rootPath, password,
		sec_fs.WithNameFactory(nameFactory),
		sec_fs.WithDataFactory(dataFactory),
		sec_fs.WithKeyStrengthMs(10), // Use low strength for faster testing
	)
	require.NoError(t, err, "Failed to create root config")

	// Step 2: Open encrypted root directory
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to open root")
	defer root.Close()

	// Step 3: Create multi-layer directory structure
	// Structure:
	//   level1/
	//     file1.txt
	//     level2/
	//       file2.txt
	//       level3/
	//         file3.txt
	//         level4/
	//           file4.txt
	//           level5/
	//             file5.txt

	layers := []struct {
		dirPath  string
		fileName string
		content  string
	}{
		{"level1", "file1.txt", "Content of file 1 in level 1"},
		{"level1/level2", "file2.txt", "Content of file 2 in level 2"},
		{"level1/level2/level3", "file3.txt", "Content of file 3 in level 3"},
		{"level1/level2/level3/level4", "file4.txt", "Content of file 4 in level 4"},
		{"level1/level2/level3/level4/level5", "file5.txt", "Content of file 5 in level 5"},
	}

	// Step 4: Create directories and files, write content
	t.Log("Creating directories and files...")
	for _, layer := range layers {
		// Create directory
		err := root.MkdirAll(sec_fs.RelativeViewPath(layer.dirPath))
		require.NoError(t, err, "Failed to create directory: %s", layer.dirPath)

		// Create file path
		filePath := sec_fs.RelativeViewPath(filepath.Join(layer.dirPath, layer.fileName))

		// Open file for writing
		file, err := root.OpenFile(filePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
		require.NoError(t, err, "Failed to open file for writing: %s", filePath)

		// Write content
		_, err = file.Write([]byte(layer.content))
		require.NoError(t, err, "Failed to write to file: %s", filePath)

		// Close file
		err = file.Close()
		require.NoError(t, err, "Failed to close file: %s", filePath)

		t.Logf("Created file: %s (%d bytes)", filePath, len(layer.content))
	}

	// Step 5: Close root to ensure all data is flushed
	err = root.Close()
	require.NoError(t, err, "Failed to close root after writing")

	// Step 6: Reopen root directory
	root, err = sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to reopen root")
	defer root.Close()

	// Step 7: Verify all files
	t.Log("Verifying file contents...")
	for _, layer := range layers {
		filePath := sec_fs.RelativeViewPath(filepath.Join(layer.dirPath, layer.fileName))

		// Open file for reading
		file, err := root.OpenFile(filePath, os.O_RDONLY)
		require.NoError(t, err, "Failed to open file for reading: %s", filePath)

		// Read content
		buffer := make([]byte, 1024)
		n, err := file.Read(buffer)
		require.NoError(t, err, "Failed to read from file: %s", filePath)

		// Verify content
		actualContent := string(buffer[:n])
		assert.Equal(t, layer.content, actualContent, "Content mismatch for file: %s", filePath)

		// Close file
		err = file.Close()
		require.NoError(t, err, "Failed to close file: %s", filePath)

		t.Logf("Verified file: %s (expected %d bytes, got %d bytes)", filePath, len(layer.content), n)
	}

	t.Log("All files verified successfully!")
}

// TestMultiLayerDirectoryWithLargeFiles tests file operations with larger files.
func TestMultiLayerDirectoryWithLargeFiles(t *testing.T) {
	// Test with different file sizes
	testSizes := []int{
		100,              // 100 bytes
		1024,             // 1 KB
		10 * 1024,        // 10 KB
		100 * 1024,       // 100 KB
		1024 * 1024,      // 1 MB
		10 * 1024 * 1024, // 10 MB
	}

	// Test with default algorithms (AES-256-GCM + AES-CTR)
	for _, size := range testSizes {
		testName := fmt.Sprintf("FileSize_%dBytes", size)
		t.Run(testName, func(t *testing.T) {
			testMultiLayerDirectoryWithLargeFile(t, size)
		})
	}
}

// testMultiLayerDirectoryWithLargeFile tests file operations with a specific file size.
func testMultiLayerDirectoryWithLargeFile(t *testing.T, fileSize int) {
	// Create temporary directory for test
	tempDir := t.TempDir()
	rootPath := sec_fs.FullStorePath(filepath.Join(tempDir, "safe_disk_root"))
	password := "test-password-123"

	// Create encrypted root directory
	_, _, err := sec_fs.CreateRootConfigQuick(rootPath, password,
		sec_fs.WithNameFactory("AES-256-GCM"),
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithKeyStrengthMs(10),
	)
	require.NoError(t, err, "Failed to create root config")

	// Open encrypted root directory
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to open root")
	defer root.Close()

	// Create multi-layer directory
	dirPath := "level1/level2/level3"
	err = root.MkdirAll(sec_fs.RelativeViewPath(dirPath))
	require.NoError(t, err, "Failed to create directory: %s", dirPath)

	// Create file path
	filePath := sec_fs.RelativeViewPath(filepath.Join(dirPath, "large_file.bin"))

	// Generate test data with known pattern
	testData := make([]byte, fileSize)
	for i := range testData {
		testData[i] = byte(i % 256)
	}

	// Open file for writing
	file, err := root.OpenFile(filePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	require.NoError(t, err, "Failed to open file for writing: %s", filePath)

	// Write content
	n, err := file.Write(testData)
	require.NoError(t, err, "Failed to write to file: %s", filePath)
	require.Equal(t, fileSize, n, "Write length mismatch")

	// Close file
	err = file.Close()
	require.NoError(t, err, "Failed to close file: %s", filePath)

	// Close root
	err = root.Close()
	require.NoError(t, err, "Failed to close root after writing")

	// Reopen root directory
	root, err = sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to reopen root")
	defer root.Close()

	// Open file for reading
	file, err = root.OpenFile(filePath, os.O_RDONLY)
	require.NoError(t, err, "Failed to open file for reading: %s", filePath)

	// Read content
	readData := make([]byte, fileSize+1024) // Extra buffer for safety
	n, err = file.Read(readData)
	require.NoError(t, err, "Failed to read from file: %s", filePath)
	require.Equal(t, fileSize, n, "Read length mismatch")

	// Verify content
	readData = readData[:n]
	assert.Equal(t, testData, readData, "Content mismatch for file: %s", filePath)

	// Close file
	err = file.Close()
	require.NoError(t, err, "Failed to close file: %s", filePath)

	t.Logf("Successfully verified large file: %d bytes", fileSize)
}

// TestMultiLayerDirectoryWithRandomAccess tests random access read/write in multi-layer directories.
func TestMultiLayerDirectoryWithRandomAccess(t *testing.T) {
	// Create temporary directory for test
	tempDir := t.TempDir()
	rootPath := sec_fs.FullStorePath(filepath.Join(tempDir, "safe_disk_root"))
	password := "test-password-123"

	// Create encrypted root directory
	_, _, err := sec_fs.CreateRootConfigQuick(rootPath, password,
		sec_fs.WithNameFactory("AES-256-GCM"),
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithKeyStrengthMs(10),
	)
	require.NoError(t, err, "Failed to create root config")

	// Open encrypted root directory
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to open root")
	defer root.Close()

	// Create multi-layer directory
	dirPath := "level1/level2/level3"
	err = root.MkdirAll(sec_fs.RelativeViewPath(dirPath))
	require.NoError(t, err, "Failed to create directory: %s", dirPath)

	// Create file path
	filePath := sec_fs.RelativeViewPath(filepath.Join(dirPath, "random_access.bin"))

	// Create initial file with 10KB of data
	initialSize := 10 * 1024
	initialData := make([]byte, initialSize)
	for i := range initialData {
		initialData[i] = byte(i % 256)
	}

	// Open file for writing
	file, err := root.OpenFile(filePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	require.NoError(t, err, "Failed to open file for writing: %s", filePath)

	// Write initial content
	_, err = file.Write(initialData)
	require.NoError(t, err, "Failed to write initial data")

	// Close file
	err = file.Close()
	require.NoError(t, err, "Failed to close file after initial write")

	// Reopen file for random access
	file, err = root.OpenFile(filePath, os.O_RDWR)
	require.NoError(t, err, "Failed to open file for random access: %s", filePath)
	defer file.Close()

	// Test random write at different positions
	testWrites := []struct {
		offset int64
		data   []byte
	}{
		{0, []byte("Header data at position 0")},
		{1024, []byte("Middle data at position 1024")},
		{8 * 1024, []byte("Near end data at position 8192")},
	}

	for _, tw := range testWrites {
		// Seek to position
		pos, err := file.Seek(tw.offset, io_SeekSet)
		require.NoError(t, err, "Failed to seek to position %d", tw.offset)
		require.Equal(t, tw.offset, pos, "Seek position mismatch")

		// Write data
		n, err := file.Write(tw.data)
		require.NoError(t, err, "Failed to write at position %d", tw.offset)
		require.Equal(t, len(tw.data), n, "Write length mismatch")

		t.Logf("Wrote %d bytes at position %d", len(tw.data), tw.offset)
	}

	// Test random read at different positions
	testReads := []struct {
		offset   int64
		expected []byte
	}{
		{0, testWrites[0].data},
		{1024, testWrites[1].data},
		{8 * 1024, testWrites[2].data},
	}

	for _, tr := range testReads {
		// Seek to position
		pos, err := file.Seek(tr.offset, io_SeekSet)
		require.NoError(t, err, "Failed to seek to position %d", tr.offset)
		require.Equal(t, tr.offset, pos, "Seek position mismatch")

		// Read data
		buffer := make([]byte, len(tr.expected))
		n, err := file.Read(buffer)
		require.NoError(t, err, "Failed to read at position %d", tr.offset)
		require.Equal(t, len(tr.expected), n, "Read length mismatch")

		// Verify content
		assert.Equal(t, tr.expected, buffer, "Content mismatch at position %d", tr.offset)

		t.Logf("Read %d bytes at position %d: %q", len(buffer), tr.offset, string(buffer[:min(20, len(buffer))]))
	}

	// Close file
	err = file.Close()
	require.NoError(t, err, "Failed to close file after random access")

	t.Log("Random access test completed successfully!")
}

// TestMultiLayerDirectoryFileDeletion tests file deletion in multi-layer directories.
func TestMultiLayerDirectoryFileDeletion(t *testing.T) {
	// Create temporary directory for test
	tempDir := t.TempDir()
	rootPath := sec_fs.FullStorePath(filepath.Join(tempDir, "safe_disk_root"))
	password := "test-password-123"

	// Create encrypted root directory
	_, _, err := sec_fs.CreateRootConfigQuick(rootPath, password,
		sec_fs.WithNameFactory("AES-256-GCM"),
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithKeyStrengthMs(10),
	)
	require.NoError(t, err, "Failed to create root config")

	// Open encrypted root directory
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	require.NoError(t, err, "Failed to open root")
	defer root.Close()

	// Create multi-layer directory
	dirPath := "level1/level2/level3"
	err = root.MkdirAll(sec_fs.RelativeViewPath(dirPath))
	require.NoError(t, err, "Failed to create directory: %s", dirPath)

	// Create multiple files
	files := []struct {
		path    string
		content string
	}{
		{filepath.Join(dirPath, "file1.txt"), "Content 1"},
		{filepath.Join(dirPath, "file2.txt"), "Content 2"},
		{filepath.Join(dirPath, "file3.txt"), "Content 3"},
	}

	// Write files
	for _, f := range files {
		file, err := root.OpenFile(sec_fs.RelativeViewPath(f.path), os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
		require.NoError(t, err, "Failed to create file: %s", f.path)

		_, err = file.Write([]byte(f.content))
		require.NoError(t, err, "Failed to write to file: %s", f.path)

		err = file.Close()
		require.NoError(t, err, "Failed to close file: %s", f.path)
	}

	// Verify files exist
	for _, f := range files {
		exists := root.FileExists(sec_fs.RelativeViewPath(f.path))
		assert.True(t, exists, "File should exist: %s", f.path)
	}

	// Delete a file
	fileToDelete := sec_fs.RelativeViewPath(filepath.Join(dirPath, "file2.txt"))
	err = root.DeleteFile(fileToDelete)
	require.NoError(t, err, "Failed to delete file: %s", fileToDelete)

	// Verify file is deleted
	exists := root.FileExists(fileToDelete)
	assert.False(t, exists, "File should not exist after deletion: %s", fileToDelete)

	// Verify other files still exist
	for _, f := range []string{files[0].path, files[2].path} {
		exists := root.FileExists(sec_fs.RelativeViewPath(f))
		assert.True(t, exists, "File should still exist: %s", f)
	}

	t.Log("File deletion test completed successfully!")
}

// Constants for Seek whence values (to avoid importing os in constants)
const (
	io_SeekSet = 0 // Seek from start
)

// min returns the minimum of two integers.
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
