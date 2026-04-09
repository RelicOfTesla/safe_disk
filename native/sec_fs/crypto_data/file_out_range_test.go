package crypto_data_test

import (
	"io"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"safe_disk/native/sec_fs/crypto_data"
)

// TestReadAtBehavior tests ReadAt behavior focusing on position and size tracking.
// Data content verification is in generic_test.go.
//
// Test scenarios:
//  1. ReadAt from position 0 - verify position unchanged
//  2. ReadAt from middle position - verify position unchanged
//  3. ReadAt beyond file end - verify position unchanged, returns EOF
//  4. ReadAt partial read - verify position unchanged
//  5. ReadAt should NOT change current seek position
func TestReadAtBehavior(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
			defer ctx.Close()

			// Write test data: "Hello, World!" (13 bytes)
			testData := []byte("Hello, World!")
			n, err := ctx.Write(testData)
			require.NoError(t, err, "Write failed")
			require.EqualValues(t, len(testData), n, "Write length")

			// After Write(13 bytes): pos=13, size=13
			checkFilePosAndSize(t, ctx, 13, 13)

			// Test 1: ReadAt from position 0
			// ReadAt should NOT change seek position
			ctx.Seek(5, io.SeekStart) // Set position to 5
			checkFilePosAndSize(t, ctx, 5, 13)

			buf := make([]byte, 5)
		n, err = ctx.ReadAt(buf, 0)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(0) failed: %v", err)
			}
			// ReadAt should NOT change position (still 5)
			checkFilePosAndSize(t, ctx, 5, 13)

			// Test 2: ReadAt from middle position
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 7)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(7) failed: %v", err)
			}
			// ReadAt should NOT change position (still 5)
			checkFilePosAndSize(t, ctx, 5, 13)

			// Test 3: ReadAt beyond file end
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 20)
			assert.EqualValues(t, 0, n, "ReadAt beyond end should return 0")
			assert.Equal(t, io.EOF, err, "ReadAt beyond end should return EOF")
			// ReadAt should NOT change position (still 5)
			checkFilePosAndSize(t, ctx, 5, 13)

			// Test 4: ReadAt partial read
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 10)
			assert.EqualValues(t, 3, n, "ReadAt partial length")
			if err != io.EOF && err != io.ErrUnexpectedEOF {
				t.Errorf("ReadAt partial: expected EOF, got %v", err)
			}
			// ReadAt should NOT change position (still 5)
			checkFilePosAndSize(t, ctx, 5, 13)

			// Test 5: ReadAt should NOT change current seek position
			pos, err := ctx.Seek(5, io.SeekStart)
			require.NoError(t, err, "Seek(5) failed")
			require.EqualValues(t, int64(5), pos, "Seek position")
			checkFilePosAndSize(t, ctx, 5, 13)

			buf = make([]byte, 5)
			ctx.ReadAt(buf, 0)

			// Verify ReadAt did not change position
			checkFilePosAndSize(t, ctx, 5, 13)
		})
	}
}

// ==================== Test: ReadAt/WriteAt Seek Position ====================
// TestReadAtWriteAtSeekPosition tests that ReadAt/WriteAt do not change seek position
//
// Test scenarios:
//  1. ReadAt_SeekCheck: ReadAt should NOT change seek position
//  2. WriteAt_SeekCheck: WriteAt should NOT change seek position
//  3. Multiple_ReadAt_WriteAt_SeekCheck: Multiple ReadAt/WriteAt operations
func TestReadAtWriteAtSeekPosition(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			t.Run("ReadAt_SeekCheck", func(t *testing.T) {
				testReadAtSeekPosition(t, ff.Factory)
			})

			t.Run("WriteAt_SeekCheck", func(t *testing.T) {
				testWriteAtSeekPosition(t, ff.Factory)
			})

			t.Run("Multiple_ReadAt_WriteAt_SeekCheck", func(t *testing.T) {
				testMultipleReadAtWriteAtSeekPosition(t, ff.Factory)
			})
		})
	}
}

func testReadAtSeekPosition(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data
	testData := []byte("Hello, World!")
	n, err := ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// After Write(13 bytes): pos=13, size=13
	checkFilePosAndSize(t, ctx, 13, 13)

	// Seek to position 5
	pos, err := ctx.Seek(5, io.SeekStart)
	require.NoError(t, err, "Seek(5) failed")
	require.EqualValues(t, int64(5), pos, "Seek position")
	checkFilePosAndSize(t, ctx, 5, 13)

	// ReadAt should NOT change seek position
	buf := make([]byte, 5)
	n, err = ctx.ReadAt(buf, 0)
	if err != nil && err != io.EOF {
		t.Errorf("ReadAt failed: %v", err)
	}
	require.EqualValues(t, 5, n, "ReadAt length")

	// Verify seek position unchanged (still 5)
	checkFilePosAndSize(t, ctx, 5, 13)
}

func testWriteAtSeekPosition(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data
	testData := []byte("Hello, World!")
	n, err := ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// After Write(13 bytes): pos=13, size=13
	checkFilePosAndSize(t, ctx, 13, 13)

	// WriteAt should NOT change seek position
	n, err = ctx.WriteAt([]byte("World"), 20)
	if err != nil || n != 5 {
		t.Errorf("WriteAt failed: n=%d, err=%v", n, err)
	}

	// Verify seek position unchanged (still 13) and size is 25
	checkFilePosAndSize(t, ctx, 13, 25)
}

func testMultipleReadAtWriteAtSeekPosition(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	n, err := ctx.Write([]byte("Initial"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 7, n, "Write length")
	checkFilePosAndSize(t, ctx, 7, 7)

	// Seek to position 10
	pos, err := ctx.Seek(10, io.SeekStart)
	require.NoError(t, err, "Seek(10) failed")
	require.EqualValues(t, int64(10), pos, "Seek position")
	checkFilePosAndSize(t, ctx, 10, 7)

	// Multiple ReadAt operations
	buf := make([]byte, 5)
	ctx.ReadAt(buf, 0)
	checkFilePosAndSize(t, ctx, 10, 7)

	ctx.ReadAt(buf, 5)
	checkFilePosAndSize(t, ctx, 10, 7)

	// Multiple WriteAt operations
	ctx.WriteAt([]byte("test"), 20)
	checkFilePosAndSize(t, ctx, 10, 24)

	ctx.WriteAt([]byte("test"), 30)
	checkFilePosAndSize(t, ctx, 10, 34)

}

// Helper to get current seek position
func mustSeekCurrent(ctx crypto_data.IDataCryptorContext) int64 {
	pos, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		return -1
	}
	return pos
}

// ==================== Test: Gap Append ====================
// TestGapAppend tests that writing beyond file end fills gap with zeros
//
// Test scenarios:
//  1. WriteAt_GapFill: WriteAt beyond file end fills gap with zeros
//  2. SeekWrite_GapFill: Seek beyond end + Write fills gap with zeros
//  3. SeekBeyondEnd_Read: Seek beyond end + Read returns (0, io.EOF)
//  4. MultipleGaps: Multiple gaps in file
//  5. LargeGap: Large gap filling (e.g., 1KB gap)
//  6. TruncateExpand: Truncate to larger size should fill with zeros
//  7. GapIntegrity: Verify gap data is correctly encrypted/decrypted
//  8. TruncateExpand_SeekCheck: Truncate expand should not change seek position
func TestGapAppend(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			// Test 1: WriteAt beyond file end
			t.Run("WriteAt_GapFill", func(t *testing.T) {
				testWriteAtGapFill(t, ff.Factory)
			})

			// Test 2: Seek beyond end + Write
			t.Run("SeekWrite_GapFill", func(t *testing.T) {
				testSeekWriteGapFill(t, ff.Factory)
			})

			// Test 3: Seek beyond end + Read
			t.Run("SeekBeyondEnd_Read", func(t *testing.T) {
				testSeekBeyondEndRead(t, ff.Factory)
			})

			// Test 4: Multiple gaps
			t.Run("MultipleGaps", func(t *testing.T) {
				testMultipleGaps(t, ff.Factory)
			})

			// Test 5: Large gap
			t.Run("LargeGap", func(t *testing.T) {
				testLargeGap(t, ff.Factory)
			})

			// Test 6: Truncate expand
			t.Run("TruncateExpand", func(t *testing.T) {
				testTruncateExpandGap(t, ff.Factory)
			})

			// Test 7: Gap integrity
			t.Run("GapIntegrity", func(t *testing.T) {
				testGapIntegrity(t, ff.Factory)
			})

			// Test 8: Truncate expand with seek position check
			t.Run("TruncateExpand_SeekCheck", func(t *testing.T) {
				testTruncateExpandSeekCheck(t, ff.Factory)
			})
		})
	}
}

func testWriteAtGapFill(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	initialData := []byte("Hello")
	n, err := ctx.Write(initialData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(initialData), n, "Write length")

	// After Write(5 bytes): pos=5, size=5
	checkFilePosAndSize(t, ctx, 5, 5)

	// WriteAt beyond file end (gap of 95 bytes)
	testData := []byte("World")
	n, err = ctx.WriteAt(testData, 100)
	require.NoError(t, err, "WriteAt failed")
	require.EqualValues(t, len(testData), n, "WriteAt length")

	// CRITICAL: WriteAt should NOT change seek position, size should be 105
	checkFilePosAndSize(t, ctx, 5, 105)
}

func testSeekWriteGapFill(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	initialData := []byte("Hello")
	n, err := ctx.Write(initialData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(initialData), n, "Write length")

	// After Write(5 bytes): pos=5, size=5
	checkFilePosAndSize(t, ctx, 5, 5)

	// Seek beyond file end
	pos, err := ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek failed")
	require.EqualValues(t, int64(100), pos, "Seek position")
	checkFilePosAndSize(t, ctx, 100, 5)

	// Write at gap position
	testData := []byte("World")
	n, err = ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// After Seek(100) + Write(5 bytes): pos=105, size=105
	checkFilePosAndSize(t, ctx, 105, 105)
}

func testSeekBeyondEndRead(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data: "Hello" (5 bytes)
	testData := []byte("Hello")
	n, err := ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// After Write(5 bytes): pos=5, size=5
	checkFilePosAndSize(t, ctx, 5, 5)

	// Test 1: Seek beyond file end
	_, err = ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek beyond end failed")
	checkFilePosAndSize(t, ctx, 100, 5)

	// Test 2: Read after Seek beyond end should return 0, io.EOF
	buf := make([]byte, 10)
	n, err = ctx.Read(buf)
	assert.EqualValues(t, 0, n, "Read after Seek beyond end should return 0")
	assert.Equal(t, io.EOF, err, "Read after Seek beyond end should return EOF")
	checkFilePosAndSize(t, ctx, 100, 5)

	// Test 3: Write after Seek beyond end fills gap
	_, err = ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek(100) failed")
	checkFilePosAndSize(t, ctx, 100, 5)

	n, err = ctx.Write([]byte("World"))
	require.NoError(t, err, "Write at 100 failed")
	require.EqualValues(t, 5, n, "Write length")

	// After Write(5 bytes) at position 100: pos=105, size=105
	checkFilePosAndSize(t, ctx, 105, 105)
}

func testMultipleGaps(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// WriteAt at position 100 (initial file is empty, pos=0, size=0)
	checkFilePosAndSize(t, ctx, 0, 0)

	n, err := ctx.WriteAt([]byte("First"), 100)
	require.NoError(t, err, "WriteAt(100) failed")
	require.EqualValues(t, 5, n, "WriteAt length")
	// WriteAt should NOT change position (still 0), size should be 105
	checkFilePosAndSize(t, ctx, 0, 105)

	// WriteAt at position 50 (creates gap 0-50 and 55-100)
	n, err = ctx.WriteAt([]byte("Mid"), 50)
	require.NoError(t, err, "WriteAt(50) failed")
	require.EqualValues(t, 3, n, "WriteAt length")
	// WriteAt should NOT change position (still 0), size should be 105
	checkFilePosAndSize(t, ctx, 0, 105)

	// WriteAt at position 200 (creates gap 105-200)
	n, err = ctx.WriteAt([]byte("Last"), 200)
	require.NoError(t, err, "WriteAt(200) failed")
	require.EqualValues(t, 4, n, "WriteAt length")
	// WriteAt should NOT change position (still 0), size should be 204
	checkFilePosAndSize(t, ctx, 0, 204)

}

func testLargeGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write start data
	n, err := ctx.Write([]byte("Start"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 5, n, "Write length")
	checkFilePosAndSize(t, ctx, 5, 5)

	// WriteAt at 1KB position (large gap)
	largeGapSize := int64(1 * 1024) // 1KB
	n, err = ctx.WriteAt([]byte("End"), largeGapSize)
	require.NoError(t, err, "WriteAt failed")
	require.EqualValues(t, 3, n, "WriteAt length")

	// WriteAt should NOT change position (still 5), size should be largeGapSize+3
	checkFilePosAndSize(t, ctx, 5, largeGapSize+3)
}

func testTruncateExpandGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data: "Hello" (5 bytes)
	n, err := ctx.Write([]byte("Hello"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 5, n, "Write length")
	checkFilePosAndSize(t, ctx, 5, 5)

	// Test: Truncate to larger size (expand)
	err = ctx.Truncate(100)
	require.NoError(t, err, "Truncate(100) failed")

	// Truncate should NOT change seek position (still 5), size should be 100
	checkFilePosAndSize(t, ctx, 5, 100)
}

func testGapIntegrity(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write 100 bytes (data content verification is in generic_test.go)
	n, err := ctx.Write(make([]byte, 100))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 100, n, "Write length")
	checkFilePosAndSize(t, ctx, 100, 100)

	// WriteAt at position 500 (gap of 400 bytes)
	n, err = ctx.WriteAt([]byte("EndData"), 500)
	require.NoError(t, err, "WriteAt failed")
	require.EqualValues(t, 7, n, "WriteAt length")

	// WriteAt should NOT change position (still 100), size should be 507
	checkFilePosAndSize(t, ctx, 100, 507)
}

func testTruncateExpandSeekCheck(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	n, err := ctx.Write([]byte("Hello"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 5, n, "Write length")
	checkFilePosAndSize(t, ctx, 5, 5)

	// Test 1: Truncate to larger size
	err = ctx.Truncate(100)
	require.NoError(t, err, "Truncate(100) failed")

	// Truncate should NOT change seek position (still 5), size should be 100
	checkFilePosAndSize(t, ctx, 5, 100)

	// Test 2: Truncate expand again (multiple expands)
	err = ctx.Truncate(200)
	require.NoError(t, err, "Truncate(200) failed")

	// Truncate should NOT change seek position (still 5), size should be 200
	checkFilePosAndSize(t, ctx, 5, 200)
}

// ==================== Test: Seek + Size + Offset ====================
// TestSeekSizePlusOffset tests Seek, Write, WriteAt operations at various positions
// and verifies that position and size are correctly tracked.
// Data content verification is in generic_test.go.
//
// Test scenario:
//  1. initData() - Initialize with 200 bytes
//  2. Seek(FileSize+100) - Seek beyond file end
//  3. Write("test1", 100 bytes) - Write at gap position
//  4. Check tell() == pos1 and size()
//  5. Seek(FileSize-50) - Seek to near end
//  6. WriteAt("test2", FileSize+120) - WriteAt beyond end
//  7. Check tell() == pos2 and size()
func TestSeekSizePlusOffset(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
			defer ctx.Close()

			// ==================== Step 1: Initialize with data ====================
			// Write initial data: 200 bytes (data content verification is in generic_test.go)
			n, err := ctx.Write(make([]byte, 200))
			require.NoError(t, err, "Step 1: Write failed")
			require.EqualValues(t, 200, n, "Step 1: Write length")

			initialSize := ctx.Size()

			require.EqualValues(t, int64(200), initialSize, "Step 1: Initial size")

			// ==================== Step 2: Seek beyond file end ====================
			seekPos := initialSize + 100 // 200 + 100 = 300
			pos, err := ctx.Seek(seekPos, io.SeekStart)
			require.NoError(t, err, "Step 2: Seek(%d) failed", seekPos)
			require.EqualValues(t, seekPos, pos, "Step 2: Seek position")

			// ==================== Step 3: Write at gap position ====================
			// Write 100 bytes at position 300
			n, err = ctx.Write(make([]byte, 100))
			require.NoError(t, err, "Step 3: Write failed")
			require.EqualValues(t, 100, n, "Step 3: Write length")

			// ==================== Step 4: Check tell() and size() ====================
			pos1 := ctx.Size() // Should be 400 (300 + 100)
			tell1, err := ctx.Seek(0, io.SeekCurrent)
			require.NoError(t, err, "Step 4: Tell failed")

			assert.EqualValues(t, int64(400), tell1, "Step 4: Tell position")
			assert.EqualValues(t, int64(400), pos1, "Step 4: Size")

			// ==================== Step 5: Seek to near end ====================
			seekPos2 := pos1 - 50 // 400 - 50 = 350
			pos, err = ctx.Seek(seekPos2, io.SeekStart)
			require.NoError(t, err, "Step 5: Seek(%d) failed", seekPos2)

			// ==================== Step 6: WriteAt beyond end ====================
			// WriteAt at position pos1 + 120 = 520
			writeAtOffset := pos1 + 120 // 400 + 120 = 520
			n, err = ctx.WriteAt(make([]byte, 80), writeAtOffset)
			require.NoError(t, err, "Step 6: WriteAt(%d) failed", writeAtOffset)
			require.EqualValues(t, 80, n, "Step 6: WriteAt length")

			// ==================== Step 7: Check tell() and size() ====================
			// WriteAt should NOT change tell position
			tell2, err := ctx.Seek(0, io.SeekCurrent)
			require.NoError(t, err, "Step 7: Tell failed")
			// tell2 should still be 350 (unchanged by WriteAt)
			assert.EqualValues(t, int64(350), tell2, "Step 7: Tell position (WriteAt should not change tell)")

			size2 := ctx.Size()
			// size2 should be 600 (520 + 80)
			assert.EqualValues(t, int64(600), size2, "Step 7: Size")
		})
	}
}

// ==================== Test: Truncate Shrink Updates Position ====================
// TestTruncateShrinkUpdatesPos verifies that Truncate shrink correctly updates the position.
// This is a safety test to prevent a bug where pos is not updated after Truncate shrink,
// causing subsequent Write operations to write at incorrect positions.
// Data content verification is in generic_test.go.
func TestTruncateShrinkUpdatesPos(t *testing.T) {
	for _, factory := range GetAllFactories() {
		t.Run(factory.Name, func(t *testing.T) {
			ctx := CreateContext(t, factory.Factory)
			defer ctx.Close()

			// Write 200 bytes (data content verification is in generic_test.go)
			n, err := ctx.Write(make([]byte, 200))
			require.NoError(t, err, "Initial write failed")
			require.EqualValues(t, 200, n, "Initial write length")

			// Now pos should be 200
			pos, _ := ctx.Seek(0, io.SeekCurrent)
			assert.EqualValues(t, int64(200), pos, "After write position")

			// Truncate shrink to 50
			err = ctx.Truncate(50)
			require.NoError(t, err, "Truncate shrink failed")

			// Verify size is now 50
			assert.EqualValues(t, int64(50), ctx.Size(), "After truncate size")

			// Verify pos is updated to 50 (not 200)
			pos, _ = ctx.Seek(0, io.SeekCurrent)
			assert.EqualValues(t, int64(50), pos, "After truncate shrink position")

			// Now write some data - it should be at position 50
			n, err = ctx.Write(make([]byte, 5))
			require.NoError(t, err, "Write after truncate failed")
			require.EqualValues(t, 5, n, "Write after truncate length")

			// Verify size is now 55 (50 + 5)
			assert.EqualValues(t, int64(55), ctx.Size(), "After write size")

			// Verify position is now 55 (50 + 5)
			pos, _ = ctx.Seek(0, io.SeekCurrent)
			assert.EqualValues(t, int64(55), pos, "After write position")

		})
	}
}
