package sec_fs

import (
	"bytes"
	"math/rand"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// ==================== Test Helpers ====================

// generateRandomData generates random test data
func generateRandomData(size int) []byte {
	data := make([]byte, size)
	rand.Read(data)
	return data
}

// ==================== SecRoot Tests ====================

// TestOpenRootDirect tests opening a root directly
func TestOpenRootDirect(t *testing.T) {
	password := "test_password_123"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Test successful open
	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Verify root path
	if string(root.GetRootPath()) != rootDir {
		t.Errorf("Expected root path %s, got %s", rootDir, root.GetRootPath())
	}

	// Verify session ID is 0 for direct mode
	if root.GetSessionID() != 0 {
		t.Errorf("Expected session ID 0 for direct mode, got %d", root.GetSessionID())
	}
}

// TestOpenRootDirect_WrongPassword tests opening with wrong password
func TestOpenRootDirect_WrongPassword(t *testing.T) {
	password := "correct_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Test with wrong password
	_, err := OpenRootDirect(rootDir, "wrong_password")
	if err == nil {
		t.Error("Expected error with wrong password, got nil")
	}
}

// TestOpenRootDirect_NonexistentDir tests opening nonexistent directory
func TestOpenRootDirect_NonexistentDir(t *testing.T) {
	_, err := OpenRootDirect("/nonexistent/path/to/root", "password")
	if err == nil {
		t.Error("Expected error for nonexistent directory, got nil")
	}
}

// TestSecRoot_GetInfo tests GetInfo method
func TestSecRoot_GetInfo(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	info, err := root.GetInfo()
	if err != nil {
		t.Fatalf("Failed to get info: %v", err)
	}

	if info.RootPath != rootDir {
		t.Errorf("Expected root path %s, got %s", rootDir, info.RootPath)
	}

	if info.Config == nil {
		t.Error("Expected config to be non-nil")
	}
}

// TestSecRoot_Close tests Close method
func TestSecRoot_Close(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}

	// Close should not return error
	if err := root.Close(); err != nil {
		t.Errorf("Close returned error: %v", err)
	}

	// Second close should be safe
	if err := root.Close(); err != nil {
		t.Errorf("Second close returned error: %v", err)
	}
}

// ==================== SecFile Tests ====================

// TestSecFile_WriteRead tests basic write and read operations
func TestSecFile_WriteRead(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Write file
	testData := []byte("Hello, Secure File System!")
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)
	err = root.WriteFile("test.txt", testDataCopy)
	if err != nil {
		t.Fatalf("Failed to write file: %v", err)
	}

	// Read file
	readData, err := root.ReadFile("test.txt")
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	if !bytes.Equal(testData, readData) {
		t.Errorf("Data mismatch: wrote %s, read %s", testData, readData)
	}
}

// TestSecFile_OpenFile_ReadMode tests opening file in read mode
func TestSecFile_OpenFile_ReadMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create test file first
	testData := []byte("Test content for reading")
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)
	root.WriteFile("read_test.txt", testDataCopy)

	// Open for reading
	file, err := root.OpenFile("read_test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	// Read all
	data, err := file.ReadAll()
	if err != nil {
		t.Fatalf("Failed to read all: %v", err)
	}

	if !bytes.Equal(testData, data) {
		t.Errorf("Data mismatch")
	}
}

// TestSecFile_OpenFile_WriteMode tests opening file in write mode
func TestSecFile_OpenFile_WriteMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Open for writing (creates new file)
	file, err := root.OpenFile("write_test.txt", "w")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}

	// Write data
	testData := []byte("New file content")
	n, err := file.Write(testData)
	if err != nil {
		t.Fatalf("Failed to write: %v", err)
	}

	if n != len(testData) {
		t.Errorf("Expected to write %d bytes, wrote %d", len(testData), n)
	}

	// Close to flush
	if err := file.Close(); err != nil {
		t.Fatalf("Failed to close file: %v", err)
	}

	// Verify file was written
	readData, err := root.ReadFile("write_test.txt")
	if err != nil {
		t.Fatalf("Failed to read written file: %v", err)
	}

	if !bytes.Equal(testData, readData) {
		t.Errorf("Data mismatch after write")
	}
}

// TestSecFile_OpenFile_AppendMode tests opening file in append mode
func TestSecFile_OpenFile_AppendMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create initial file
	initialData := []byte("Initial content")
	initialDataCopy := make([]byte, len(initialData))
	copy(initialDataCopy, initialData)
	root.WriteFile("append_test.txt", initialDataCopy)

	// Open for append
	file, err := root.OpenFile("append_test.txt", "a")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}

	// Append data
	appendData := []byte(" + appended content")
	n, err := file.Write(appendData)
	if err != nil {
		t.Fatalf("Failed to append: %v", err)
	}

	if n != len(appendData) {
		t.Errorf("Expected to write %d bytes, wrote %d", len(appendData), n)
	}

	// Close
	if err := file.Close(); err != nil {
		t.Fatalf("Failed to close: %v", err)
	}

	// Verify
	expected := append(initialData, appendData...)
	readData, err := root.ReadFile("append_test.txt")
	if err != nil {
		t.Fatalf("Failed to read: %v", err)
	}

	if !bytes.Equal(expected, readData) {
		t.Errorf("Append data mismatch")
	}
}

// TestSecFile_Seek tests seek operations
func TestSecFile_Seek(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create test file
	testData := []byte("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	root.WriteFile("seek_test.txt", testData)

	// Open for reading
	file, err := root.OpenFile("seek_test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	// Test SeekSet
	pos, err := file.Seek(10, SeekSet)
	if err != nil {
		t.Fatalf("Seek failed: %v", err)
	}
	if pos != 10 {
		t.Errorf("Expected position 10, got %d", pos)
	}

	// Read from position
	data, n, err := file.ReadSize(5)
	if err != nil {
		t.Fatalf("Read failed: %v", err)
	}
	_ = n // n is the number of bytes read
	if string(data) != "ABCDE" {
		t.Errorf("Expected 'ABCDE', got '%s'", string(data))
	}

	// Test SeekCur
	pos, err = file.Seek(5, SeekCur)
	if err != nil {
		t.Fatalf("SeekCur failed: %v", err)
	}
	if pos != 20 {
		t.Errorf("Expected position 20, got %d", pos)
	}

	// Test SeekEnd
	pos, err = file.Seek(-5, SeekEnd)
	if err != nil {
		t.Fatalf("SeekEnd failed: %v", err)
	}
	if pos != int64(len(testData)-5) {
		t.Errorf("Expected position %d, got %d", len(testData)-5, pos)
	}
}

// TestSecFile_Tell tests tell operation
func TestSecFile_Tell(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	testData := []byte("Test data for tell")
	root.WriteFile("tell_test.txt", testData)

	file, err := root.OpenFile("tell_test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	// Initial position should be 0
	pos, err := file.Tell()
	if err != nil {
		t.Fatalf("Tell failed: %v", err)
	}
	if pos != 0 {
		t.Errorf("Expected initial position 0, got %d", pos)
	}

	// Read some data
	file.ReadSize(5)

	// Position should be 5
	pos, err = file.Tell()
	if err != nil {
		t.Fatalf("Tell failed: %v", err)
	}
	if pos != 5 {
		t.Errorf("Expected position 5, got %d", pos)
	}
}

// TestSecFile_Stat tests stat operation
func TestSecFile_Stat(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	testData := []byte("Test data for stat")
	root.WriteFile("stat_test.txt", testData)

	file, err := root.OpenFile("stat_test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	stat, err := file.StatDetail()
	if err != nil {
		t.Fatalf("StatDetail failed: %v", err)
	}

	if stat.Size != int64(len(testData)) {
		t.Errorf("Expected size %d, got %d", len(testData), stat.Size)
	}

	if stat.Position != 0 {
		t.Errorf("Expected position 0, got %d", stat.Position)
	}
}

// TestSecFile_ReadAt_WriteAt tests ReadAt and WriteAt operations
func TestSecFile_ReadAt_WriteAt(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create test file
	testData := []byte("Original content for ReadAt/WriteAt test")
	root.WriteFile("rwat_test.txt", testData)

	// ReadAt test
	file, err := root.OpenFile("rwat_test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}

	data, err := file.ReadAt(9, 7)
	if err != nil {
		t.Fatalf("ReadAt failed: %v", err)
	}

	if string(data) != "content" {
		t.Errorf("Expected 'content', got '%s'", string(data))
	}

	file.Close()

	// WriteAt test
	file, err = root.OpenFile("rwat_test.txt", "w")
	if err != nil {
		t.Fatalf("Failed to open file for write: %v", err)
	}

	_, err = file.WriteAt(0, []byte("Modified"))
	if err != nil {
		t.Fatalf("WriteAt failed: %v", err)
	}

	file.Close()

	// Verify
	readData, _ := root.ReadFile("rwat_test.txt")
	if !bytes.HasPrefix(readData, []byte("Modified")) {
		t.Errorf("WriteAt modification failed")
	}
}

// TestSecFile_WriteString tests WriteString method
func TestSecFile_WriteString(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	file, err := root.OpenFile("string_test.txt", "w")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}

	testStr := "Hello, String!"
	n, err := file.WriteString(testStr)
	if err != nil {
		t.Fatalf("WriteString failed: %v", err)
	}

	if n != len(testStr) {
		t.Errorf("Expected to write %d, wrote %d", len(testStr), n)
	}

	file.Close()

	// Verify
	data, _ := root.ReadFile("string_test.txt")
	if string(data) != testStr {
		t.Errorf("String mismatch")
	}
}

// TestSecFile_WriteString tests WriteString method
func TestSecFile_InvalidMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	_, err = root.OpenFile("test.txt", "x")
	if err == nil {
		t.Error("Expected error for invalid mode, got nil")
	}
}

// TestSecFile_ReadOnWriteMode tests reading from write-mode file
func TestSecFile_ReadOnWriteMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	file, err := root.OpenFile("test.txt", "w")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	_, _, err = file.ReadSize(10)
	if err == nil {
		t.Error("Expected error when reading from write-mode file")
	}
}

// TestSecFile_WriteOnReadMode tests writing to read-mode file
func TestSecFile_WriteOnReadMode(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	root.WriteFile("test.txt", []byte("test"))

	file, err := root.OpenFile("test.txt", "r")
	if err != nil {
		t.Fatalf("Failed to open file: %v", err)
	}
	defer file.Close()

	_, err = file.Write([]byte("data"))
	if err == nil {
		t.Error("Expected error when writing to read-mode file")
	}
}

// ==================== SecDirWalker Tests ====================

// TestSecDirWalker_WalkDir tests basic directory walking
func TestSecDirWalker_WalkDir(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create some files
	root.WriteFile("file1.txt", []byte("file1"))
	root.WriteFile("file2.txt", []byte("file2"))
	root.WriteFile("subdir1/file3.txt", []byte("file3"))

	// Walk root directory
	walker, err := root.WalkDir(".", nil)
	if err != nil {
		t.Fatalf("Failed to create walker: %v", err)
	}
	defer walker.Close()

	// Count entries
	count := 0
	for walker.HasNext() {
		entry, err := walker.Next()
		if err != nil {
			t.Fatalf("Next failed: %v", err)
		}
		if entry == nil {
			break
		}
		count++
	}

	// Should have at least subdir1, subdir2, file1.txt, file2.txt
	if count < 4 {
		t.Errorf("Expected at least 4 entries, got %d", count)
	}
}

// TestSecDirWalker_NextBatch tests batch iteration
func TestSecDirWalker_NextBatch(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create files
	for i := 0; i < 10; i++ {
		root.WriteFile(RelativeViewPath(filepath.Join("batch_test", string(rune('A'+i)))+".txt"), []byte("data"))
	}

	walker, err := root.WalkDir("batch_test", nil)
	if err != nil {
		t.Fatalf("Failed to create walker: %v", err)
	}
	defer walker.Close()

	// Get batch of 5
	batch, err := walker.NextBatch(5)
	if err != nil {
		t.Fatalf("NextBatch failed: %v", err)
	}

	if len(batch) != 5 {
		t.Errorf("Expected batch of 5, got %d", len(batch))
	}

	// Get remaining
	remaining, err := walker.NextBatch(-1)
	if err != nil {
		t.Fatalf("NextBatch remaining failed: %v", err)
	}

	if len(remaining) != 5 {
		t.Errorf("Expected 5 remaining, got %d", len(remaining))
	}
}

// TestSecDirWalker_CollectFiles tests collecting only files
func TestSecDirWalker_CollectFiles(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create files and directories
	root.WriteFile("file1.txt", []byte("data"))
	root.WriteFile("file2.txt", []byte("data"))
	root.MkdirAll("dir1")

	walker, err := root.WalkDir(".", nil)
	if err != nil {
		t.Fatalf("Failed to create walker: %v", err)
	}
	defer walker.Close()

	files, err := walker.CollectFiles()
	if err != nil {
		t.Fatalf("CollectFiles failed: %v", err)
	}

	for _, f := range files {
		if f.IsDir {
			t.Errorf("CollectFiles returned a directory: %s", f.Name)
		}
	}
}

// TestSecDirWalker_CollectDirs tests collecting only directories
func TestSecDirWalker_CollectDirs(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create files and directories
	root.WriteFile("file1.txt", []byte("data"))
	root.MkdirAll("dir1")
	root.MkdirAll("dir2")

	walker, err := root.WalkDir(".", nil)
	if err != nil {
		t.Fatalf("Failed to create walker: %v", err)
	}
	defer walker.Close()

	dirs, err := walker.CollectDirs()
	if err != nil {
		t.Fatalf("CollectDirs failed: %v", err)
	}

	for _, d := range dirs {
		if !d.IsDir {
			t.Errorf("CollectDirs returned a file: %s", d.Name)
		}
	}
}

// TestSecDirWalker_Reset tests reset functionality
func TestSecDirWalker_Reset(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	root.WriteFile("file1.txt", []byte("data"))
	root.WriteFile("file2.txt", []byte("data"))

	walker, err := root.WalkDir(".", nil)
	if err != nil {
		t.Fatalf("Failed to create walker: %v", err)
	}
	defer walker.Close()

	// Iterate all
	for walker.HasNext() {
		walker.Next()
	}

	if walker.Remaining() != 0 {
		t.Errorf("Expected 0 remaining, got %d", walker.Remaining())
	}

	// Reset
	if err := walker.Reset(); err != nil {
		t.Fatalf("Reset failed: %v", err)
	}

	if walker.Remaining() == 0 {
		t.Error("Expected entries after reset")
	}
}

// TestSecDirWalker_WithOptions tests walking with options
func TestSecDirWalker_WithOptions(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, err := OpenRootDirect(rootDir, password)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer root.Close()

	// Create structure
	root.WriteFile("file1.txt", []byte("data"))
	root.MkdirAll("subdir")

	// Skip files
	walker, _ := root.WalkDir(".", &WalkOpt{SkipFiles: true})
	defer walker.Close()

	for walker.HasNext() {
		entry, _ := walker.Next()
		if entry == nil {
			break
		}
		if !entry.IsDir {
			t.Errorf("SkipFiles option failed, got file: %s", entry.Name)
		}
	}

	// Skip dirs
	walker2, _ := root.WalkDir(".", &WalkOpt{SkipDirs: true})
	defer walker2.Close()

	for walker2.HasNext() {
		entry, _ := walker2.Next()
		if entry == nil {
			break
		}
		if entry.IsDir {
			t.Errorf("SkipDirs option failed, got directory: %s", entry.Name)
		}
	}
}

// ==================== SessionManager Tests ====================

// TestSessionManager_OpenRoot tests opening root via session manager
func TestSessionManager_OpenRoot(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	// Open session
	sessionID, err := manager.OpenRoot(rootDir, password, 0)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}
	defer manager.CloseRoot(sessionID)

	if sessionID == 0 {
		t.Error("Expected non-zero session ID")
	}

	// Check session exists
	if !manager.HasSession(sessionID) {
		t.Error("Session should exist")
	}

	// List sessions
	sessions := manager.ListSessions()
	found := false
	for _, id := range sessions {
		if id == sessionID {
			found = true
			break
		}
	}
	if !found {
		t.Error("Session ID not in list")
	}
}

// TestSessionManager_GetRoot tests getting root from session
func TestSessionManager_GetRoot(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	sessionID, _ := manager.OpenRoot(rootDir, password, 0)
	defer manager.CloseRoot(sessionID)

	// Get root
	root, err := manager.GetRoot(sessionID)
	if err != nil {
		t.Fatalf("Failed to get root: %v", err)
	}

	if root == nil {
		t.Fatal("Expected non-nil root")
	}

	// Verify root works
	if string(root.GetRootPath()) != rootDir {
		t.Errorf("Expected path %s, got %s", rootDir, root.GetRootPath())
	}
}

// TestSessionManager_CloseRoot tests closing session
func TestSessionManager_CloseRoot(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	sessionID, _ := manager.OpenRoot(rootDir, password, 0)

	// Close session
	if err := manager.CloseRoot(sessionID); err != nil {
		t.Fatalf("Failed to close root: %v", err)
	}

	// Session should no longer exist
	if manager.HasSession(sessionID) {
		t.Error("Session should not exist after close")
	}

	// Getting closed session should fail
	_, err := manager.GetRoot(sessionID)
	if err == nil {
		t.Error("Expected error getting closed session")
	}
}

// TestSessionManager_CloseRoot_InvalidID tests closing invalid session
func TestSessionManager_CloseRoot_InvalidID(t *testing.T) {
	manager := NewSessionManager()

	err := manager.CloseRoot(99999)
	if err == nil {
		t.Error("Expected error closing invalid session ID")
	}
}

// TestSessionManager_ExtendSession tests extending session
func TestSessionManager_ExtendSession(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	sessionID, _ := manager.OpenRoot(rootDir, password, 10)
	defer manager.CloseRoot(sessionID)

	// Extend session
	if err := manager.ExtendSession(sessionID, 60); err != nil {
		t.Fatalf("Failed to extend session: %v", err)
	}
}

// TestSessionManager_GetSessionInfo tests getting session info
func TestSessionManager_GetSessionInfo(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	sessionID, _ := manager.OpenRoot(rootDir, password, 0)
	defer manager.CloseRoot(sessionID)

	info, err := manager.GetSessionInfo(sessionID)
	if err != nil {
		t.Fatalf("Failed to get session info: %v", err)
	}

	if info.RootPath != rootDir {
		t.Errorf("Expected root path %s, got %s", rootDir, info.RootPath)
	}

	if info.SessionID != sessionID {
		t.Errorf("Expected session ID %d, got %d", sessionID, info.SessionID)
	}
}

// TestSessionManager_Stats tests stats
func TestSessionManager_Stats(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	manager := NewSessionManager()

	// Open multiple sessions
	id1, _ := manager.OpenRoot(rootDir, password, 0)
	id2, _ := manager.OpenRoot(rootDir, password, 0)

	stats := manager.Stats()
	if stats["activeSessions"].(int) != 2 {
		t.Errorf("Expected 2 active sessions, got %v", stats["activeSessions"])
	}

	manager.CloseRoot(id1)
	manager.CloseRoot(id2)
}

// TestDefaultSessionManager tests the global session manager
func TestDefaultSessionManager(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Use global functions
	sessionID, err := OpenRoot(rootDir, password, 0)
	if err != nil {
		t.Fatalf("Failed to open root: %v", err)
	}

	root, err := GetRoot(sessionID)
	if err != nil {
		t.Fatalf("Failed to get root: %v", err)
	}

	if string(root.GetRootPath()) != rootDir {
		t.Errorf("Expected path %s, got %s", rootDir, root.GetRootPath())
	}

	if err := CloseRoot(sessionID); err != nil {
		t.Fatalf("Failed to close root: %v", err)
	}
}

// ==================== Quick Operations Tests ====================

// TestQuickReadFile tests QuickReadFile function
func TestQuickReadFile(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Write directly
	testData := []byte("Quick read test data")
	os.WriteFile(filepath.Join(rootDir, "quick.txt"), testData, 0600)

	// Actually need to encrypt it first
	root, _ := OpenRootDirect(rootDir, password)
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)
	root.WriteFile("quick.txt", testDataCopy)
	root.Close()

	// Quick read
	data, err := QuickReadFile(rootDir, password, "quick.txt")
	if err != nil {
		t.Fatalf("QuickReadFile failed: %v", err)
	}

	if !bytes.Equal(testData, data) {
		t.Errorf("Data mismatch")
	}
}

// TestQuickWriteFile tests QuickWriteFile function
func TestQuickWriteFile(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	testData := []byte("Quick write test data")

	// Make a copy since QuickWriteFile may zero the original
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)

	// Quick write
	if err := QuickWriteFile(rootDir, password, "quick_write.txt", testDataCopy); err != nil {
		t.Fatalf("QuickWriteFile failed: %v", err)
	}

	// Verify
	data, err := QuickReadFile(rootDir, password, "quick_write.txt")
	if err != nil {
		t.Fatalf("QuickReadFile failed: %v", err)
	}

	if !bytes.Equal(testData, data) {
		t.Errorf("Data mismatch")
	}
}

// TestQuickListDir tests QuickListDir function
func TestQuickListDir(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Create some files
	root, _ := OpenRootDirect(rootDir, password)
	root.WriteFile("file1.txt", []byte("data"))
	root.WriteFile("file2.txt", []byte("data"))
	root.Close()

	// Quick list
	entries, err := QuickListDir(rootDir, password, ".")
	if err != nil {
		t.Fatalf("QuickListDir failed: %v", err)
	}

	if len(entries) < 2 {
		t.Errorf("Expected at least 2 entries, got %d", len(entries))
	}
}

// ==================== Error Handling Tests ====================

// TestSecRoot_DeleteFile tests file deletion
func TestSecRoot_DeleteFile(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Create file
	root.WriteFile("to_delete.txt", []byte("data"))

	// Verify exists
	if !root.FileExists("to_delete.txt") {
		t.Fatal("File should exist")
	}

	// Delete
	if err := root.DeleteFile("to_delete.txt"); err != nil {
		t.Fatalf("DeleteFile failed: %v", err)
	}

	// Verify deleted
	if root.FileExists("to_delete.txt") {
		t.Error("File should be deleted")
	}
}

// TestSecRoot_StatFile tests file stat
func TestSecRoot_StatFile(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Stat non-existent file
	info, err := root.StatFile("nonexistent.txt")
	if err != nil {
		t.Fatalf("StatFile failed: %v", err)
	}
	if info.Exists {
		t.Error("Non-existent file should not exist")
	}

	// Create and stat
	root.WriteFile("stat_me.txt", []byte("data for stat"))

	info, err = root.StatFile("stat_me.txt")
	if err != nil {
		t.Fatalf("StatFile failed: %v", err)
	}
	if !info.Exists {
		t.Error("File should exist")
	}
}

// TestSecRoot_MkdirAll tests directory creation
func TestSecRoot_MkdirAll(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Create nested directories
	if err := root.MkdirAll("deeply/nested/directory/structure"); err != nil {
		t.Fatalf("MkdirAll failed: %v", err)
	}

	// Verify can write to it
	if err := root.WriteFile("deeply/nested/directory/structure/file.txt", []byte("data")); err != nil {
		t.Fatalf("Failed to write to nested directory: %v", err)
	}
}

// TestSecRoot_ReadDir tests ReadDir
func TestSecRoot_ReadDir(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Create files
	root.WriteFile("dir_test1.txt", []byte("data"))
	root.WriteFile("dir_test2.txt", []byte("data"))

	// Read directory
	entries, err := root.ReadDir(".")
	if err != nil {
		t.Fatalf("ReadDir failed: %v", err)
	}

	if len(entries) < 2 {
		t.Errorf("Expected at least 2 entries, got %d", len(entries))
	}
}

// ==================== Large File Tests ====================

// TestLargeFile tests handling of larger files
func TestLargeFile(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping large file test in short mode")
	}

	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Create 10 MB file
	size := 10 * 1024 * 1024
	testData := generateRandomData(size)

	// Make a copy since WriteFile may zero the original
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)

	// Write
	start := time.Now()
	if err := root.WriteFile("large_file.bin", testDataCopy); err != nil {
		t.Fatalf("Failed to write large file: %v", err)
	}
	t.Logf("Write time: %v", time.Since(start))

	// Read
	start = time.Now()
	readData, err := root.ReadFile("large_file.bin")
	if err != nil {
		t.Fatalf("Failed to read large file: %v", err)
	}
	t.Logf("Read time: %v", time.Since(start))

	if !bytes.Equal(testData, readData) {
		t.Error("Large file data mismatch")
	}
}

// ==================== Concurrent Access Tests ====================

// TestConcurrentRead tests concurrent read access
func TestConcurrentRead(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	root, _ := OpenRootDirect(rootDir, password)
	defer root.Close()

	// Create test file
	testData := []byte("Concurrent read test data")
	testDataCopy := make([]byte, len(testData))
	copy(testDataCopy, testData)
	root.WriteFile("concurrent.txt", testDataCopy)

	// Concurrent reads
	done := make(chan bool)
	for i := 0; i < 5; i++ {
		go func() {
			data, err := root.ReadFile("concurrent.txt")
			if err != nil {
				t.Errorf("Concurrent read failed: %v", err)
			}
			if !bytes.Equal(testData, data) {
				t.Error("Concurrent read data mismatch")
			}
			done <- true
		}()
	}

	// Wait for all goroutines
	for i := 0; i < 5; i++ {
		<-done
	}
}

// ==================== CryptorConfig Tests ====================

// TestCryptorConfig tests encryption mode configuration
func TestCryptorConfig(t *testing.T) {
	password := "test_password"
	rootDir, cleanup := createTestRoot(t, password)
	defer cleanup()

	// Open with incremental mode
	config := &CryptorConfig{
		Mode:      CryptModeIncremental,
		ChunkSize: 64 * 1024,
	}

	root, err := OpenRootDirect(rootDir, password, config)
	if err != nil {
		t.Fatalf("Failed to open root with config: %v", err)
	}
	defer root.Close()

	// Should be able to perform operations
	root.WriteFile("config_test.txt", []byte("test data"))
}
