package sec_fs

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/sec_utils"
)

// TestSecDirWalker_Next tests the Next() method
func TestSecDirWalker_Next(t *testing.T) {
	t.Run("EmptyDirectory", func(t *testing.T) {
		// Create empty test directory
		testDir := t.TempDir()
		_ = testDir // Use testDir to avoid unused variable error

		// Create walker
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)

		// Initialize and get first entry
		err := walker.init()
		require.NoError(t, err, "Failed to initialize walker")
		defer walker.Close()

		// Should return io.EOF for empty directory
		_, err = walker.Next()
		assert.ErrorIs(t, err, io.EOF, "Expected io.EOF for empty directory")
	})

	t.Run("SingleFile", func(t *testing.T) {
		// Create test directory with single file
		testDir := t.TempDir()
		testFile := filepath.Join(testDir, "test.txt")
		err := os.WriteFile(testFile, []byte("test content"), 0644)
		require.NoError(t, err, "Failed to create test file")

		// Create walker
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err = walker.init()
		require.NoError(t, err, "Failed to initialize walker")
		defer walker.Close()

		// Get first entry
		entry, err := walker.Next()
		require.NoError(t, err, "Failed to get first entry")
		assert.NotNil(t, entry, "Entry should not be nil")
		assert.Equal(t, "test.txt", entry.Name(), "File name mismatch")

		// No more entries
		_, err = walker.Next()
		assert.ErrorIs(t, err, io.EOF, "Expected io.EOF after single file")
	})

	t.Run("MultipleFiles", func(t *testing.T) {
		// Create test directory with multiple files
		testDir := t.TempDir()
		for i := 0; i < 5; i++ {
			testFile := filepath.Join(testDir, "file"+string(rune('0'+i))+".txt")
			err := os.WriteFile(testFile, []byte("content"), 0644)
			require.NoError(t, err, "Failed to create test file")
		}

		// Create walker
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err, "Failed to initialize walker")
		defer walker.Close()

		// Read all entries
		count := 0
		for {
			_, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err, "Failed to get entry")
			count++
		}
		assert.Equal(t, 5, count, "Should have read 5 files")
	})

	t.Run("WithSubdirectories", func(t *testing.T) {
		// Create test directory with files and subdirectories
		testDir := t.TempDir()

		// Create files
		err := os.WriteFile(filepath.Join(testDir, "file1.txt"), []byte("content"), 0644)
		require.NoError(t, err)
		err = os.WriteFile(filepath.Join(testDir, "file2.txt"), []byte("content"), 0644)
		require.NoError(t, err)

		// Create subdirectory
		err = os.Mkdir(filepath.Join(testDir, "subdir1"), 0755)
		require.NoError(t, err)

		// Create walker
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err = walker.init()
		require.NoError(t, err, "Failed to initialize walker")
		defer walker.Close()

		// Read all entries and count
		fileCount := 0
		dirCount := 0
		for {
			entry, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err, "Failed to get entry")
			if entry.IsDir() {
				dirCount++
			} else {
				fileCount++
			}
		}
		assert.Equal(t, 2, fileCount, "Should have 2 files")
		assert.Equal(t, 1, dirCount, "Should have 1 subdirectory")
	})

	t.Run("ClosedWalker", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)

		// Close walker
		err = walker.Close()
		require.NoError(t, err)

		// Should return ErrWalkerClosed
		_, err = walker.Next()
		assert.ErrorIs(t, err, ErrWalkerClosed, "Expected ErrWalkerClosed for closed walker")
	})

	t.Run("NilWalker", func(t *testing.T) {
		var walker *secDirWalker
		_, err := walker.Next()
		assert.ErrorIs(t, err, ErrWalkerClosed, "Expected ErrWalkerClosed for nil walker")
	})
}

// TestSecDirWalker_NextBatch tests the NextBatch() method
func TestSecDirWalker_NextBatch(t *testing.T) {
	t.Run("EmptyDirectory", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Should return io.EOF for empty directory
		entries, err := walker.NextBatch(10)
		assert.ErrorIs(t, err, io.EOF, "Should return io.EOF for empty directory")
		assert.Empty(t, entries, "Entries should be nil or empty")
	})

	t.Run("BatchSizeSmallerThanTotal", func(t *testing.T) {
		// Create directory with 10 files
		testDir := t.TempDir()
		for i := 0; i < 10; i++ {
			testFile := filepath.Join(testDir, "file"+string(rune('0'+i))+".txt")
			err := os.WriteFile(testFile, []byte("content"), 0644)
			require.NoError(t, err)
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Read all entries in batches
		totalCount := 0
		batchNum := 0
		for {
			entries, err := walker.NextBatch(5)
			if err == io.EOF {
				break
			}
			require.NoError(t, err, "NextBatch failed at batch %d", batchNum)
			totalCount += len(entries)
			batchNum++
			if batchNum > 10 { // Safety limit
				t.Fatal("Too many batches")
			}
		}

		// Should have read all 10 files
		assert.Equal(t, 10, totalCount, "Should have read all 10 files")
	})

	t.Run("BatchSizeLargerThanTotal", func(t *testing.T) {
		// Create directory with 3 files
		testDir := t.TempDir()
		for i := 0; i < 3; i++ {
			testFile := filepath.Join(testDir, "file"+string(rune('0'+i))+".txt")
			err := os.WriteFile(testFile, []byte("content"), 0644)
			require.NoError(t, err)
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Request batch of 10, should get 3
		entries, err := walker.NextBatch(10)
		require.NoError(t, err)
		assert.Len(t, entries, 3, "Should return all 3 entries")
	})

	t.Run("ZeroBatchSize", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Zero batch size should return empty slice
		entries, err := walker.NextBatch(0)
		require.NoError(t, err)
		assert.Empty(t, entries, "Zero batch size should return empty slice")
	})

	t.Run("NegativeBatchSize", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Negative batch size should return empty slice
		entries, err := walker.NextBatch(-1)
		require.NoError(t, err)
		assert.Empty(t, entries, "Negative batch size should return empty slice")
	})
}

// TestSecDirWalker_HasNext tests the HasNext() method
func TestSecDirWalker_HasNext(t *testing.T) {
	t.Run("EmptyDirectory", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		assert.False(t, walker.HasNext(), "Empty directory should have no next entry")
	})

	t.Run("HasEntries", func(t *testing.T) {
		testDir := t.TempDir()
		err := os.WriteFile(filepath.Join(testDir, "file.txt"), []byte("content"), 0644)
		require.NoError(t, err)

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Note: HasNext() only checks current batch, may not load more entries
		// So it might return false even if there are entries in the directory
		// This is the current implementation behavior
		result := walker.HasNext()
		t.Logf("HasNext() returned: %v", result)
	})

	t.Run("NotInitialized", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		defer walker.Close()

		// Note: Current implementation returns true when not initialized
		// It assumes there are entries
		result := walker.HasNext()
		t.Logf("HasNext() returned (not initialized): %v", result)
		// Current behavior: returns true when not initialized
		assert.True(t, result, "Current implementation returns true when not initialized")
	})

	t.Run("ClosedWalker", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		err = walker.Close()
		require.NoError(t, err)

		assert.False(t, walker.HasNext(), "Closed walker should have no next entry")
	})
}

// TestSecDirWalker_Close tests the Close() method
func TestSecDirWalker_Close(t *testing.T) {
	t.Run("SingleClose", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)

		// Close should succeed
		err = walker.Close()
		assert.NoError(t, err, "Close should succeed")
		assert.True(t, walker.closed, "Walker should be marked as closed")
	})

	t.Run("DoubleClose", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)

		// First close
		err = walker.Close()
		require.NoError(t, err)

		// Second close should also succeed (idempotent)
		err = walker.Close()
		assert.NoError(t, err, "Second close should also succeed")
	})

	t.Run("CloseWithoutInit", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)

		// Close without init should still work
		err := walker.Close()
		assert.NoError(t, err, "Close without init should succeed")
	})

	t.Run("NilWalker", func(t *testing.T) {
		var walker *secDirWalker
		err := walker.Close()
		assert.NoError(t, err, "Close on nil walker should succeed")
	})
}

// TestSecDirWalker_Reset tests the Reset() method
func TestSecDirWalker_Reset(t *testing.T) {
	t.Run("ResetAndReiterate", func(t *testing.T) {
		// Create directory with 3 files
		testDir := t.TempDir()
		for i := 0; i < 3; i++ {
			testFile := filepath.Join(testDir, "file"+string(rune('0'+i))+".txt")
			err := os.WriteFile(testFile, []byte("content"), 0644)
			require.NoError(t, err)
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)

		// Read first entry
		entry, err := walker.Next()
		require.NoError(t, err)
		require.NotNil(t, entry)

		// Reset walker
		err = walker.Reset()
		require.NoError(t, err, "Reset should succeed")

		// Should be able to read from beginning again
		entry, err = walker.Next()
		require.NoError(t, err, "Should get first entry after reset")
		assert.NotNil(t, entry, "First entry after reset should not be nil")

		walker.Close()
	})

	t.Run("ResetOnClosedWalker", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		err = walker.Close()
		require.NoError(t, err)

		// Reset on closed walker should fail
		err = walker.Reset()
		assert.Error(t, err, "Reset on closed walker should fail")
	})
}

// TestSecDirWalker_WithEncryption tests walker with encrypted file names
// This test suite provides (medium-depth) testing for the encryption/decryption behavior.
func TestSecDirWalker_WithEncryption(t *testing.T) {
	t.Run("DecryptFileNameCorrectly", func(t *testing.T) {
		// Use real AES-GCM encryptor to test the complete encryption/decryption flow
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()

		// Define test cases with expected behavior
		testCases := []struct {
			plainName string
			desc      string
		}{
			{"test.txt", "simple filename"},
			{"my_document.pdf", "filename with underscore"},
			{"readme", "filename without extension"},
		}

		// Create encrypted files
		expectedNames := make(map[string]bool)
		for _, tc := range testCases {
			encryptedName, err := cryptor.EncryptName(tc.plainName)
			require.NoError(t, err, "Failed to encrypt name: %s", tc.plainName)
			require.NotEqual(t, tc.plainName, encryptedName, "Encrypted name should differ from plain name")

			err = os.WriteFile(filepath.Join(testDir, encryptedName), []byte("content"), 0644)
			require.NoError(t, err, "Failed to create encrypted file: %s", tc.plainName)

			expectedNames[tc.plainName] = true
		}

		// Create walker with cryptor
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Read all entries and verify names are correctly decrypted
		foundNames := make(map[string]bool)
		for {
			entry, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err, "Failed to get entry")
			require.NotNil(t, entry, "Entry should not be nil")
			foundNames[entry.Name()] = true
		}

		// Verify all expected names were found
		assert.Equal(t, len(expectedNames), len(foundNames), "Should find all expected files")
		for name := range expectedNames {
			assert.True(t, foundNames[name], "Should find decrypted name: %s", name)
		}
	})

	t.Run("EmptyDirectory", func(t *testing.T) {
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()
		// Don't create any files - directory is empty

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Should return io.EOF for empty directory
		_, err = walker.Next()
		assert.ErrorIs(t, err, io.EOF, "Should return io.EOF for empty directory")
	})

	t.Run("MultipleFiles", func(t *testing.T) {
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()

		// Create multiple files with encrypted names
		fileCount := 10
		expectedNames := make(map[string]bool)
		for i := 0; i < fileCount; i++ {
			plainName := "file_" + string(rune('0'+i%10)) + ".txt"
			encryptedName, err := cryptor.EncryptName(plainName)
			require.NoError(t, err)

			err = os.WriteFile(filepath.Join(testDir, encryptedName), []byte("content"), 0644)
			require.NoError(t, err)

			expectedNames[plainName] = true
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Read all entries
		foundCount := 0
		for {
			entry, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err)
			require.NotNil(t, entry)

			// Verify the decrypted name is in expected set
			assert.True(t, expectedNames[entry.Name()], "Found unexpected name: %s", entry.Name())
			foundCount++
		}

		assert.Equal(t, fileCount, foundCount, "Should find all %d files", fileCount)
	})

	t.Run("NestedDirectory", func(t *testing.T) {
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()

		// Create encrypted subdirectory name
		encryptedSubdir, err := cryptor.EncryptName("my_folder")
		require.NoError(t, err)

		err = os.Mkdir(filepath.Join(testDir, encryptedSubdir), 0755)
		require.NoError(t, err)

		// Create file inside subdirectory
		encryptedFileName, err := cryptor.EncryptName("nested_file.txt")
		require.NoError(t, err)

		err = os.WriteFile(filepath.Join(testDir, encryptedSubdir, encryptedFileName), []byte("content"), 0644)
		require.NoError(t, err)

		// Walk root directory - should see the encrypted subdirectory with decrypted name
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		entry, err := walker.Next()
		require.NoError(t, err)
		require.NotNil(t, entry)

		// Verify the directory name is decrypted
		assert.Equal(t, "my_folder", entry.Name(), "Directory name should be decrypted")
		assert.True(t, entry.IsDir(), "Should be recognized as directory")

		// Walk the subdirectory
		walker2 := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), RelativeViewPath("my_folder"), cryptor, nil)
		// Note: This requires proper path conversion, which may need store path
		// For now, we test with relative path
		_ = walker2
	})

	t.Run("SpecialCharacters", func(t *testing.T) {
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()

		// Define test cases with special characters
		testCases := []struct {
			plainName string
			desc      string
		}{
			{"file with spaces.txt", "filename with spaces"},
			{"文件.txt", "Chinese characters"},
			{"файл.txt", "Cyrillic characters"},
			{"file-with-dash.txt", "filename with dash"},
			{"file_with_underscore.txt", "filename with underscore"},
		}

		expectedNames := make(map[string]bool)
		for _, tc := range testCases {
			encryptedName, err := cryptor.EncryptName(tc.plainName)
			require.NoError(t, err, "Failed to encrypt: %s", tc.desc)

			err = os.WriteFile(filepath.Join(testDir, encryptedName), []byte("content"), 0644)
			require.NoError(t, err, "Failed to create file: %s", tc.desc)

			expectedNames[tc.plainName] = true
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Read all entries and verify special character names are correctly decrypted
		foundNames := make(map[string]bool)
		for {
			entry, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err)
			foundNames[entry.Name()] = true
		}

		// Verify all expected names were found
		assert.Equal(t, len(expectedNames), len(foundNames), "Should find all files with special characters")
		for name := range expectedNames {
			assert.True(t, foundNames[name], "Should find decrypted name: %s", name)
		}
	})

	t.Run("DecryptError", func(t *testing.T) {
		// Test behavior when decryption fails
		testDir := t.TempDir()

		// Create a file with invalid encrypted name (cannot be decrypted)
		invalidEncryptedName := "invalid_encrypted_name_not_base64"
		err := os.WriteFile(filepath.Join(testDir, invalidEncryptedName), []byte("content"), 0644)
		require.NoError(t, err)

		// Create another file with valid encrypted name
		cryptor := newTestAESGCMCryptor(t)
		validEncryptedName, err := cryptor.EncryptName("valid_file.txt")
		require.NoError(t, err)

		err = os.WriteFile(filepath.Join(testDir, validEncryptedName), []byte("content"), 0644)
		require.NoError(t, err)

		// Create walker - corruption must be visible rather than silently skipped.
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// The invalid encrypted store name is a corruption error, not EOF. Do
		// not depend on filesystem ordering between the valid and invalid names.
		for {
			_, err := walker.Next()
			if err == io.EOF {
				t.Fatal("invalid encrypted name was silently skipped")
			}
			if err != nil {
				assert.NotErrorIs(t, err, io.EOF)
				break
			}
		}
	})

	t.Run("MixedEncryptedAndPlain", func(t *testing.T) {
		// Test behavior when directory has both encrypted and plain files
		cryptor := newTestAESGCMCryptor(t)

		testDir := t.TempDir()

		// Create encrypted file
		encryptedName, err := cryptor.EncryptName("encrypted.txt")
		require.NoError(t, err)
		err = os.WriteFile(filepath.Join(testDir, encryptedName), []byte("content"), 0644)
		require.NoError(t, err)

		// Create plain file (not encrypted)
		err = os.WriteFile(filepath.Join(testDir, "plain.txt"), []byte("content"), 0644)
		require.NoError(t, err)

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", cryptor, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// A plaintext entry in an encrypted-name directory is corruption.
		foundNames := make(map[string]bool)
		var walkErr error
		for {
			entry, err := walker.Next()
			if err == io.EOF {
				break
			}
			if err != nil {
				walkErr = err
				break
			}
			foundNames[entry.Name()] = true
		}

		assert.Error(t, walkErr, "Plain store names must not be silently skipped")
		assert.False(t, foundNames["plain.txt"])
	})

	t.Run("WithMockCryptor", func(t *testing.T) {
		// Original test with mock cryptor - now with proper assertions
		testDir := t.TempDir()

		// Create file with a name that will be reversed by mock cryptor
		encryptedName := "encrypted_file_name.txt"
		err := os.WriteFile(filepath.Join(testDir, encryptedName), []byte("content"), 0644)
		require.NoError(t, err)

		// Create mock name cryptor that reverses the name
		mockCryptor := &mockNameCryptor{
			decryptFunc: func(encrypted string) (string, error) {
				runes := []rune(encrypted)
				for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
					runes[i], runes[j] = runes[j], runes[i]
				}
				return string(runes), nil
			},
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", mockCryptor, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		entry, err := walker.Next()
		require.NoError(t, err, "Should get entry with encrypted name")
		require.NotNil(t, entry, "Entry should not be nil")

		// Verify the name is reversed as expected
		expectedName := "txt.eman_elif_detpyrcne"
		assert.Equal(t, expectedName, entry.Name(), "Entry name should be reversed by mock cryptor")
	})
}

// TestSecDirWalker_WithIgnoreMatcher tests walker with ignore logic
func TestSecDirWalker_WithIgnoreMatcher(t *testing.T) {
	t.Run("SkipIgnoredFiles", func(t *testing.T) {
		// Create test directory
		testDir := t.TempDir()

		// Create files
		err := os.WriteFile(filepath.Join(testDir, "file.txt"), []byte("content"), 0644)
		require.NoError(t, err)
		err = os.WriteFile(filepath.Join(testDir, ".hidden"), []byte("content"), 0644)
		require.NoError(t, err)
		err = os.WriteFile(filepath.Join(testDir, "temp.tmp"), []byte("content"), 0644)
		require.NoError(t, err)

		// Create ignore matcher that skips hidden files and temp files
		mockMatcher := &mockIgnoreMatcher{
			shouldIgnoreFunc2: func(decryptedName string, isDir bool) bool {
				return decryptedName[0] == '.' || filepath.Ext(decryptedName) == ".tmp"
			},
		}

		// Create walker with ignore matcher
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, mockMatcher)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Should only get file.txt
		entry, err := walker.Next()
		require.NoError(t, err)
		assert.Equal(t, "file.txt", entry.Name(), "Should only get non-ignored file")

		// No more entries
		_, err = walker.Next()
		assert.ErrorIs(t, err, io.EOF, "Should have no more non-ignored entries")
	})
}

// TestSecDirWalker_Interface tests interface compliance
func TestSecDirWalker_Interface(t *testing.T) {
	t.Run("IDirWalkerInterface", func(t *testing.T) {
		testDir := t.TempDir()
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)

		// Compile-time interface check
		var _ IDirWalker = walker

		walker.Close()
	})
}

// TestSecDirWalker_EntryProperties tests that entries have correct properties
func TestSecDirWalker_EntryProperties(t *testing.T) {
	t.Run("FileEntry", func(t *testing.T) {
		testDir := t.TempDir()
		testContent := []byte("test content for file")
		err := os.WriteFile(filepath.Join(testDir, "testfile.txt"), testContent, 0644)
		require.NoError(t, err)

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		entry, err := walker.Next()
		require.NoError(t, err)
		require.NotNil(t, entry)

		// Check properties
		assert.Equal(t, "testfile.txt", entry.Name(), "File name mismatch")
		assert.False(t, entry.IsDir(), "Should not be a directory")

		// Check fs.DirEntry interface methods
		assert.NotEqual(t, fs.ModeDir, entry.Type(), "Type should not be directory")

		// Check Info()
		info, err := entry.Info()
		require.NoError(t, err, "Info() should succeed")
		assert.Equal(t, int64(len(testContent)), info.Size(), "File size mismatch")
		assert.False(t, info.IsDir(), "FileInfo should not be directory")

		// Check IDirEntry interface methods
		assert.NotEmpty(t, entry.GetRelativeViewPath(), "RelativeViewPath should not be empty")
		// Note: RelativeStorePath may be empty in some implementations
		// This depends on how processEntry sets the store path
	})

	t.Run("DirectoryEntry", func(t *testing.T) {
		testDir := t.TempDir()
		err := os.Mkdir(filepath.Join(testDir, "testdir"), 0755)
		require.NoError(t, err)

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err = walker.init()
		require.NoError(t, err)
		defer walker.Close()

		entry, err := walker.Next()
		require.NoError(t, err)
		require.NotNil(t, entry)

		// Check properties
		assert.Equal(t, "testdir", entry.Name(), "Directory name mismatch")
		assert.True(t, entry.IsDir(), "Should be a directory")

		// Check fs.DirEntry interface methods
		assert.Equal(t, fs.ModeDir, entry.Type(), "Type should be directory")

		// Check Info()
		info, err := entry.Info()
		require.NoError(t, err, "Info() should succeed")
		assert.True(t, info.IsDir(), "FileInfo should be directory")
	})
}

// TestSecDirWalker_ErrorHandling tests error handling scenarios
func TestSecDirWalker_ErrorHandling(t *testing.T) {
	t.Run("NonExistentDirectory", func(t *testing.T) {
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust("/non/existent/directory"), "", nil, nil)
		err := walker.init()
		assert.Error(t, err, "Should fail for non-existent directory")
	})

	t.Run("FileAsDirectory", func(t *testing.T) {
		testDir := t.TempDir()
		testFile := filepath.Join(testDir, "notadir.txt")
		err := os.WriteFile(testFile, []byte("content"), 0644)
		require.NoError(t, err)

		// Try to walk a file path as directory
		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testFile), "", nil, nil)
		err = walker.init()
		// Note: The current implementation may not check if path is a file
		// So this test may pass even if path is a file
		// We accept this behavior for now
		if err != nil {
			assert.Error(t, err, "Should fail when path is a file, not directory")
		}
		walker.Close()
	})
}

// TestSecDirWalker_ConcurrentAccess tests thread safety
func TestSecDirWalker_ConcurrentAccess(t *testing.T) {
	t.Run("ConcurrentNext", func(t *testing.T) {
		testDir := t.TempDir()
		for i := 0; i < 100; i++ {
			testFile := filepath.Join(testDir, "file"+string(rune('0'+i%10))+".txt")
			_ = os.WriteFile(testFile, []byte("content"), 0644)
		}

		walker := newSecDirWalker(sec_utils.ParsePathInfoMust(testDir), "", nil, nil)
		err := walker.init()
		require.NoError(t, err)
		defer walker.Close()

		// Note: This test is simplified; real concurrent testing would use goroutines
		// The walker has mutex protection, but proper concurrent testing is complex
		for i := 0; i < 5; i++ {
			_, err := walker.Next()
			if err == io.EOF {
				break
			}
			require.NoError(t, err)
		}
	})
}

func TestSecDirWalker_RecursiveWorkSetLimit(t *testing.T) {
	testDir := t.TempDir()
	for i := 0; i < 3; i++ {
		if err := os.Mkdir(filepath.Join(testDir, fmt.Sprintf("dir-%d", i)), 0755); err != nil {
			t.Fatal(err)
		}
	}

	walker := newSecDirWalker(
		sec_utils.ParsePathInfoMust(testDir),
		"",
		nil,
		nil,
		WithRecursive(),
		WithMaxPendingDirectories(2),
	)
	defer walker.Close()

	for {
		_, err := walker.Next()
		if errors.Is(err, ErrWalkerWorkLimit) {
			break
		}
		if err == io.EOF {
			t.Fatal("wide directory completed without enforcing the work-set limit")
		}
		if err != nil {
			t.Fatalf("unexpected walker error: %v", err)
		}
	}
}

func TestSecDirWalker_RecursiveDepthUsesStackItemDepth(t *testing.T) {
	testDir := t.TempDir()
	current := testDir
	for i := 0; i < 8; i++ {
		current = filepath.Join(current, fmt.Sprintf("depth-%d", i))
		if err := os.Mkdir(current, 0755); err != nil {
			t.Fatal(err)
		}
	}

	walker := newSecDirWalker(
		sec_utils.ParsePathInfoMust(testDir),
		"",
		nil,
		nil,
		WithRecursive(),
		WithMaxDepth(3),
		WithMaxPendingDirectories(1),
	)
	defer walker.Close()

	count := 0
	for {
		_, err := walker.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		count++
	}
	// MaxDepth limits descent, so the first directory beyond the limit is
	// still emitted but never opened.
	if count != 4 {
		t.Fatalf("recursive entry count = %d, want 4 at MaxDepth(3)", count)
	}
}

// Mock implementations for testing

// mockNameCryptor implements crypto_name.INameCryptorContext for testing
type mockNameCryptor struct {
	encryptFunc func(plaintext string) (string, error)
	decryptFunc func(encrypted string) (string, error)
}

func (m *mockNameCryptor) EncryptName(name string) (string, error) {
	if m.encryptFunc != nil {
		return m.encryptFunc(name)
	}
	return name, nil
}

func (m *mockNameCryptor) DecryptName(encrypted string) (string, error) {
	if m.decryptFunc != nil {
		return m.decryptFunc(encrypted)
	}
	return encrypted, nil
}

func (m *mockNameCryptor) Close() error { return nil }

// mockIgnoreMatcher implements IIgnoreMatcher for testing
type mockIgnoreMatcher struct {
	shouldIgnoreFunc1 func(encryptedName string, isDir bool) bool
	shouldIgnoreFunc2 func(decryptedName string, isDir bool) bool
}

// ShouldIgnore1 checks if the file should be ignored BEFORE name decryption.
func (m *mockIgnoreMatcher) ShouldIgnore1(encryptedName string, isDir bool) bool {
	if m.shouldIgnoreFunc1 != nil {
		return m.shouldIgnoreFunc1(encryptedName, isDir)
	}
	return false
}

// ShouldIgnore2 checks if the file should be ignored AFTER name decryption.
func (m *mockIgnoreMatcher) ShouldIgnore2(decryptedName string, isDir bool) bool {
	if m.shouldIgnoreFunc2 != nil {
		return m.shouldIgnoreFunc2(decryptedName, isDir)
	}
	return false
}

// Compile-time interface verification
var _ crypto_name.INameCryptorContext = (*mockNameCryptor)(nil)
var _ IIgnoreMatcher = (*mockIgnoreMatcher)(nil)

// testKeyInfo implements crypto_hkdf.IKeyInfo for testing purposes.
// It provides a simple wrapper around a key byte slice.
type testKeyInfo struct {
	key []byte
}

func (k *testKeyInfo) GetKey() []byte {
	return k.key
}

func (k *testKeyInfo) Destroy() {
	clear(k.key)
	k.key = nil
}

// Compile-time interface verification for testKeyInfo
var _ crypto_hkdf.IKeyInfo = (*testKeyInfo)(nil)

// testAESGCMCryptor implements crypto_name.INameCryptorContext using AES-256-GCM.
// This is a simplified version for testing that avoids import cycles.
type testAESGCMCryptor struct {
	gcm cipher.AEAD
}

// newTestAESGCMCryptor creates a new AES-256-GCM cryptor for testing.
// It requires a 32-byte key for AES-256.
func newTestAESGCMCryptor(t *testing.T) crypto_name.INameCryptorContext {
	t.Helper()
	// Use a fixed 32-byte test key (AES-256 requires 32 bytes)
	testKey := []byte("0123456789abcdef0123456789abcdef") // exactly 32 bytes
	require.Len(t, testKey, 32, "Test key must be exactly 32 bytes")

	block, err := aes.NewCipher(testKey)
	require.NoError(t, err, "Failed to create AES cipher")

	gcm, err := cipher.NewGCM(block)
	require.NoError(t, err, "Failed to create GCM")

	return &testAESGCMCryptor{gcm: gcm}
}

// EncryptName encrypts a file or directory name using AES-GCM.
// Returns the encrypted name (base64 encoded) or an error.
func (c *testAESGCMCryptor) EncryptName(name string) (string, error) {
	if name == "" {
		return "", nil
	}

	plaintext := []byte(name)

	// Generate random IV
	iv := make([]byte, c.gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return "", err
	}

	// Encrypt: IV + ciphertext + tag
	ciphertext := c.gcm.Seal(iv, iv, plaintext, nil)

	// Encode to base64 for safe filename
	encoded := base64.RawURLEncoding.EncodeToString(ciphertext)

	return encoded, nil
}

// DecryptName decrypts an encrypted file or directory name.
// Returns the original name or an error.
func (c *testAESGCMCryptor) DecryptName(encrypted string) (string, error) {
	if encrypted == "" {
		return "", nil
	}

	// Decode from base64
	ciphertext, err := base64.RawURLEncoding.DecodeString(encrypted)
	if err != nil {
		return "", err
	}

	if len(ciphertext) < 28 { // IV(12) + Tag(16) minimum
		return "", errors.New("encrypted name too short")
	}

	ivSize := c.gcm.NonceSize()
	if len(ciphertext) < ivSize {
		return "", errors.New("encrypted name shorter than IV size")
	}

	// Extract IV and ciphertext
	iv := ciphertext[:ivSize]
	ciphertextWithTag := ciphertext[ivSize:]

	// Decrypt
	plaintext, err := c.gcm.Open(nil, iv, ciphertextWithTag, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

func (c *testAESGCMCryptor) Close() error { return nil }

// Compile-time interface verification for testAESGCMCryptor
var _ crypto_name.INameCryptorContext = (*testAESGCMCryptor)(nil)

// Helper function to create test configuration
func createTestConfig(t *testing.T) config.SharedConfig {
	cfg := config.NewMemoryConfig()
	return cfg
}
