package crypto_data_test

import (
	"bytes"
	"io"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"safe_disk/native/sec_fs/crypto_data"
)

//  2. ReadAt from middle position
//  3. ReadAt beyond file end (should return 0, io.EOF)
//  4. ReadAt partial read (should return partial data with EOF)
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

			// Test 1: ReadAt from position 0
			buf := make([]byte, 5)
			n, err = ctx.ReadAt(buf, 0)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(0) failed: %v", err)
			}
			assert.EqualValues(t, "Hello", string(buf[:n]), "ReadAt(0)")
			t.Logf("Test 1: ReadAt(0, 5) = %q", buf[:n])

			// Test 2: ReadAt from middle position
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 7)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(7) failed: %v", err)
			}
			assert.EqualValues(t, "World", string(buf[:n]), "ReadAt(7)")
			t.Logf("Test 2: ReadAt(7, 5) = %q", buf[:n])

			// Test 3: ReadAt beyond file end
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 20)
			assert.EqualValues(t, 0, n, "ReadAt beyond end should return 0")
			assert.Equal(t, io.EOF, err, "ReadAt beyond end should return EOF")
			t.Logf("Test 3: ReadAt(20, 5) = n=%d, err=%v", n, err)

			// Test 4: ReadAt partial read
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 10)
			assert.EqualValues(t, 3, n, "ReadAt partial length")
			assert.EqualValues(t, "ld!", string(buf[:n]), "ReadAt partial data")
			if err != io.EOF && err != io.ErrUnexpectedEOF {
				t.Errorf("ReadAt partial: expected EOF, got %v", err)
			}
			t.Logf("Test 4: ReadAt(10, 5) = n=%d, data=%q, err=%v", n, buf[:n], err)

			// Test 5: ReadAt should NOT change current seek position
			pos, err := ctx.Seek(5, io.SeekStart)
			require.NoError(t, err, "Seek(5) failed")
			require.EqualValues(t, int64(5), pos, "Seek position")

			buf = make([]byte, 5)
			ctx.ReadAt(buf, 0)

			pos, err = ctx.Seek(0, io.SeekCurrent)
			require.NoError(t, err, "Seek current failed")
			assert.EqualValues(t, int64(5), pos, "ReadAt should not change seek position")
			t.Logf("Test 5: ReadAt does not change seek position (still at %d)", pos)
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
	ctx.Write(testData)

	// Seek to position 5
	pos, err := ctx.Seek(5, io.SeekStart)
	require.NoError(t, err, "Seek(5) failed")
	require.EqualValues(t, int64(5), pos, "Seek position")

	// ReadAt should NOT change seek position
	buf := make([]byte, 5)
	n, err := ctx.ReadAt(buf, 0)
	if err != nil && err != io.EOF {
		t.Errorf("ReadAt failed: %v", err)
	}
	require.EqualValues(t, 5, n, "ReadAt length")

	// Verify seek position unchanged
	pos, err = ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, int64(5), pos, "ReadAt should not change seek position")
	t.Logf("ReadAt preserved seek position at %d", pos)
}

func testWriteAtSeekPosition(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data
	testData := []byte("Hello, World!")
	n, err := ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// Record current position (should be 13)
	posAfterWrite, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	require.EqualValues(t, int64(13), posAfterWrite, "After Write position")

	// WriteAt should NOT change seek position
	n, err = ctx.WriteAt([]byte("World"), 20)
	if err != nil || n != 5 {
		t.Errorf("WriteAt failed: n=%d, err=%v", n, err)
	}

	// Verify seek position unchanged
	posAfterWriteAt, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, posAfterWrite, posAfterWriteAt, "WriteAt should not change seek position")
	t.Logf("WriteAt preserved seek position at %d", posAfterWriteAt)

	// Verify size
	assert.EqualValues(t, int64(25), ctx.Size(), "Size after WriteAt")
}

func testMultipleReadAtWriteAtSeekPosition(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	ctx.Write([]byte("Initial"))

	// Seek to position 10
	ctx.Seek(10, io.SeekStart)

	// Multiple ReadAt operations
	buf := make([]byte, 5)
	ctx.ReadAt(buf, 0)
	assert.EqualValues(t, int64(10), mustSeekCurrent(ctx), "After first ReadAt")

	ctx.ReadAt(buf, 5)
	assert.EqualValues(t, int64(10), mustSeekCurrent(ctx), "After second ReadAt")

	// Multiple WriteAt operations
	ctx.WriteAt([]byte("test"), 20)
	assert.EqualValues(t, int64(10), mustSeekCurrent(ctx), "After first WriteAt")

	ctx.WriteAt([]byte("test"), 30)
	assert.EqualValues(t, int64(10), mustSeekCurrent(ctx), "After second WriteAt")

	t.Logf("Multiple ReadAt/WriteAt operations preserved seek position at 10")
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

	// Record current position (should be 5)
	posAfterWrite, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	require.EqualValues(t, int64(5), posAfterWrite, "After Write position")

	// WriteAt beyond file end (gap of 95 bytes)
	testData := []byte("World")
	n, err = ctx.WriteAt(testData, 100)
	require.NoError(t, err, "WriteAt failed")
	require.EqualValues(t, len(testData), n, "WriteAt length")

	// CRITICAL: WriteAt should NOT change seek position
	posAfterWriteAt, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, posAfterWrite, posAfterWriteAt, "WriteAt should not change seek position")
	t.Logf("WriteAt preserved seek position at %d", posAfterWriteAt)

	// Verify size is 105
	assert.EqualValues(t, int64(105), ctx.Size(), "Size after WriteAt")

	// Seek to beginning and read all data
	_, err = ctx.Seek(0, io.SeekStart)
	require.NoError(t, err, "Seek start failed")

	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 105, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 105)
	copy(expected[:5], initialData)
	copy(expected[100:105], testData)


	// Verify gap is filled with zeros
	if ok, idx := isZero(allData[5:100]); !ok {
		t.Errorf("Gap byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}
}

func testSeekWriteGapFill(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	initialData := []byte("Hello")
	n, err := ctx.Write(initialData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(initialData), n, "Write length")

	// Seek beyond file end
	pos, err := ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek failed")
	require.EqualValues(t, int64(100), pos, "Seek position")

	// Write at gap position
	testData := []byte("World")
	n, err = ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// Verify tell() == 105 (Write changes seek position)
	pos, err = ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, int64(105), pos, "After SeekWrite position")

	// Verify size is 105
	assert.EqualValues(t, int64(105), ctx.Size(), "Size after SeekWrite")

	// Seek to beginning and read all data
	_, err = ctx.Seek(0, io.SeekStart)
	require.NoError(t, err, "Seek start failed")

	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 105, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 105)
	copy(expected[:5], initialData)
	copy(expected[100:105], testData)


	// Verify gap is filled with zeros
	if ok, idx := isZero(allData[5:100]); !ok {
		t.Errorf("Gap byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}
}

func testSeekBeyondEndRead(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data: "Hello" (5 bytes)
	testData := []byte("Hello")
	n, err := ctx.Write(testData)
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, len(testData), n, "Write length")

	// Test 1: Seek beyond file end
	pos, err := ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek beyond end failed")
	assert.EqualValues(t, int64(100), pos, "Seek position")
	t.Logf("Test 1: Seek(100) = %d, err=%v", pos, err)

	// Test 2: Read after Seek beyond end should return 0, io.EOF
	// This is the UNIQUE test case!
	buf := make([]byte, 10)
	n, err = ctx.Read(buf)
	assert.EqualValues(t, 0, n, "Read after Seek beyond end should return 0")
	assert.Equal(t, io.EOF, err, "Read after Seek beyond end should return EOF")
	t.Logf("Test 2: Read after Seek(100) = n=%d, err=%v", n, err)

	// Test 3: Write after Seek beyond end fills gap with zeros
	pos, err = ctx.Seek(100, io.SeekStart)
	require.NoError(t, err, "Seek(100) failed")

	n, err = ctx.Write([]byte("World"))
	require.NoError(t, err, "Write at 100 failed")
	require.EqualValues(t, 5, n, "Write length")

	assert.EqualValues(t, int64(105), ctx.Size(), "Size after Write at 100")
	t.Logf("Test 3: Write at 100, file size = %d", ctx.Size())

	// Test 4: Verify gap filled with zeros
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 105, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 105)
	copy(expected[:5], testData)
	copy(expected[100:105], []byte("World"))


	// First 5 bytes should be "Hello"
	assert.EqualValues(t, "Hello", string(allData[:5]), "First 5 bytes")

	// Verify gap is filled with zeros
	if ok, idx := isZero(allData[5:100]); !ok {
		t.Errorf("Gap byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}
}

func testMultipleGaps(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write at position 100
	ctx.WriteAt([]byte("First"), 100)

	// Write at position 50 (creates gap 0-50 and 55-100)
	ctx.WriteAt([]byte("Mid"), 50)

	// Write at position 200 (creates gap 105-200)
	ctx.WriteAt([]byte("Last"), 200)

	// Verify size
	assert.EqualValues(t, int64(204), ctx.Size(), "Multiple gaps size")

	// Read all data
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 204)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 204, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 204)
	copy(expected[50:53], []byte("Mid"))
	copy(expected[100:105], []byte("First"))
	copy(expected[200:204], []byte("Last"))


	// Verify gaps are filled with zeros
	if ok, idx := isZero(allData[0:50]); !ok {
		t.Errorf("Gap 0-50 byte %d: expected 0, got %d", 0+idx, allData[0+idx])
	}
	if ok, idx := isZero(allData[53:100]); !ok {
		t.Errorf("Gap 53-100 byte %d: expected 0, got %d", 53+idx, allData[53+idx])
	}
	if ok, idx := isZero(allData[105:200]); !ok {
		t.Errorf("Gap 105-200 byte %d: expected 0, got %d", 105+idx, allData[105+idx])
	}

	t.Logf("Multiple gaps test passed: size=%d, all gaps verified", ctx.Size())
}

func testLargeGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write start data
	ctx.Write([]byte("Start"))

	// WriteAt at 1KB position (large gap)
	largeGapSize := int64(1 * 1024) // 1KB
	ctx.WriteAt([]byte("End"), largeGapSize)

	// Verify size
	assert.EqualValues(t, largeGapSize+3, ctx.Size(), "Large gap size")

	// Read all data for comprehensive verification
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, largeGapSize+3)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, int(largeGapSize+3), n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, largeGapSize+3)
	copy(expected[:5], []byte("Start"))
	copy(expected[largeGapSize:], []byte("End"))


	// Verify gap is filled with zeros
	if ok, idx := isZero(allData[5:largeGapSize]); !ok {
		t.Errorf("Gap byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}

	// Verify by sampling (additional check)
	buf := make([]byte, 1)
	samplePositions := []int64{100, 512, 768}
	for _, pos := range samplePositions {
		n, err := ctx.ReadAt(buf, pos)
		if err != nil && err != io.EOF {
			t.Errorf("ReadAt(%d) failed: %v", pos, err)
		}
		if n == 1 && buf[0] != 0 {
			t.Errorf("Gap position %d: expected 0, got %d", pos, buf[0])
		}
	}

	// Verify end data
	ctx.ReadAt(buf, largeGapSize)
	assert.EqualValues(t, byte('E'), buf[0], "End position should be 'E'")
}

func testTruncateExpandGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data: "Hello" (5 bytes)
	n, err := ctx.Write([]byte("Hello"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 5, n, "Write length")

	// Test 1: Truncate to larger size (expand)
	err = ctx.Truncate(100)
	require.NoError(t, err, "Truncate(100) failed")

	// Verify size
	assert.EqualValues(t, int64(100), ctx.Size(), "After Truncate(100) size")
	t.Logf("Test 1: Truncate(100) -> size=%d", ctx.Size())

	// Read all and verify zeros
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 100)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 100, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 100)
	copy(expected[:5], []byte("Hello"))


	// First 5 bytes should be "Hello"
	assert.EqualValues(t, "Hello", string(allData[:5]), "First 5 bytes")

	// Bytes 5-99 should be zeros
	if ok, idx := isZero(allData[5:100]); !ok {
		t.Errorf("Expanded byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}

	t.Logf("Test 2: Truncate expand filled with zeros: 'Hello' + 95 zeros")
}

func testGapIntegrity(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write known data
	knownData := makeSequentialBytes(100)
	ctx.Write(knownData)

	// Write at position 500 (gap of 400 bytes)
	endData := []byte("EndData")
	ctx.WriteAt(endData, 500)

	// Verify size
	assert.EqualValues(t, int64(507), ctx.Size(), "Gap integrity size")

	// Read back and verify
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 507)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 507, n, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 507)
	copy(expected[:100], makeSequentialBytes(100))
	copy(expected[500:], endData)


	// Verify known data
	assert.EqualValues(t, knownData, allData[:100], "Known data")

	// Verify gap is filled with zeros
	if ok, idx := isZero(allData[100:500]); !ok {
		t.Errorf("Gap byte %d: expected 0, got %d", 100+idx, allData[100+idx])
	}

	// Verify end data
	assert.EqualValues(t, "EndData", string(allData[500:507]), "End data")

	t.Logf("Gap integrity: known data + 400-byte gap + end data verified, size=%d", ctx.Size())
}

func testTruncateExpandSeekCheck(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	n, err := ctx.Write([]byte("Hello"))
	require.NoError(t, err, "Write failed")
	require.EqualValues(t, 5, n, "Write length")

	// Record current position (should be 5)
	posAfterWrite, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	require.EqualValues(t, int64(5), posAfterWrite, "After Write position")

	// Test 1: Truncate to larger size
	err = ctx.Truncate(100)
	require.NoError(t, err, "Truncate(100) failed")

	// CRITICAL: Truncate should NOT change seek position
	posAfterTruncate, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, posAfterWrite, posAfterTruncate, "Truncate should not change seek position")
	t.Logf("Truncate preserved seek position at %d", posAfterTruncate)

	// Verify size
	assert.EqualValues(t, int64(100), ctx.Size(), "After Truncate(100) size")
	t.Logf("Test 1: Truncate(100) -> size=%d", ctx.Size())

	// Test 2: Truncate expand again (multiple expands)
	err = ctx.Truncate(200)
	require.NoError(t, err, "Truncate(200) failed")

	// Verify seek position still unchanged
	posAfterTruncate2, err := ctx.Seek(0, io.SeekCurrent)
	require.NoError(t, err, "Seek current failed")
	assert.EqualValues(t, posAfterWrite, posAfterTruncate2, "Truncate(200) should not change seek position")
	t.Logf("Truncate(200) preserved seek position at %d", posAfterTruncate2)

	assert.EqualValues(t, int64(200), ctx.Size(), "After Truncate(200) size")
	t.Logf("Test 2: Truncate(200) -> size=%d", ctx.Size())

	// Test 3: Verify data content after Truncate expand
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 200)
	nRead, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	assert.EqualValues(t, 200, nRead, "ReadAll length")

	// Verify data with bytes.Equal
	expected := make([]byte, 200)
	copy(expected[:5], []byte("Hello"))


	// First 5 bytes should be "Hello"
	assert.EqualValues(t, "Hello", string(allData[:5]), "First 5 bytes")

	// Bytes 5-199 should be zeros
	if ok, idx := isZero(allData[5:200]); !ok {
		t.Errorf("Expanded byte %d: expected 0, got %d", 5+idx, allData[5+idx])
	}
}

// ==================== Test: Seek + Size + Offset ====================
// TestSeekSizePlusOffset tests Seek, Write, WriteAt operations at various positions
// and verifies that position and size are correctly tracked.
//
// Test scenario:
//  1. initData() - Initialize with 200 bytes
//  2. Seek(FileSize+100) - Seek beyond file end
//  3. Write("test1", 100 bytes) - Write at gap position
//  4. Check tell() == pos1 and size()
//  5. Seek(FileSize-50) - Seek to near end
//  6. WriteAt("test2", FileSize+120) - WriteAt beyond end
//  7. Check tell() == pos2 and size()
//  8. Verify data integrity
func TestSeekSizePlusOffset(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
			defer ctx.Close()

			// ==================== Step 1: Initialize with data ====================
			// Write initial data: 200 bytes
			initData := makeSequentialBytes(200)
			n, err := ctx.Write(initData)
			require.NoError(t, err, "Step 1: Write failed")
			require.EqualValues(t, len(initData), n, "Step 1: Write length")

			initialSize := ctx.Size()
			t.Logf("Step 1: Initial write %d bytes, size=%d", len(initData), initialSize)

			require.EqualValues(t, int64(len(initData)), initialSize, "Step 1: Initial size")

			// ==================== Step 2: Seek beyond file end ====================
			seekPos := initialSize + 100 // 200 + 100 = 300
			pos, err := ctx.Seek(seekPos, io.SeekStart)
			require.NoError(t, err, "Step 2: Seek(%d) failed", seekPos)
			require.EqualValues(t, seekPos, pos, "Step 2: Seek position")
			t.Logf("Step 2: Seek(%d) -> pos=%d", seekPos, pos)

			// ==================== Step 3: Write at gap position ====================
			// Write 100 bytes at position 300
			test1Data := bytes.Repeat([]byte{'1'}, 100)
			n, err = ctx.Write(test1Data)
			require.NoError(t, err, "Step 3: Write failed")
			require.EqualValues(t, len(test1Data), n, "Step 3: Write length")

			// ==================== Step 4: Check tell() and size() ====================
			pos1 := ctx.Size() // Should be 400 (300 + 100)
			tell1, err := ctx.Seek(0, io.SeekCurrent)
			require.NoError(t, err, "Step 4: Tell failed")

			assert.EqualValues(t, int64(400), tell1, "Step 4: Tell position")
			assert.EqualValues(t, int64(400), pos1, "Step 4: Size")
			t.Logf("Step 3-4: Write 100 bytes at 300, tell=%d, size=%d", tell1, pos1)

			// ==================== Step 5: Seek to near end ====================
			seekPos2 := pos1 - 50 // 400 - 50 = 350
			pos, err = ctx.Seek(seekPos2, io.SeekStart)
			require.NoError(t, err, "Step 5: Seek(%d) failed", seekPos2)
			t.Logf("Step 5: Seek(%d) -> pos=%d", seekPos2, pos)

			// ==================== Step 6: WriteAt beyond end ====================
			// WriteAt at position pos1 + 120 = 520
			writeAtOffset := pos1 + 120 // 400 + 120 = 520
			test2Data := bytes.Repeat([]byte{'2'}, 80)
			n, err = ctx.WriteAt(test2Data, writeAtOffset)
			require.NoError(t, err, "Step 6: WriteAt(%d) failed", writeAtOffset)
			require.EqualValues(t, len(test2Data), n, "Step 6: WriteAt length")

			// ==================== Step 7: Check tell() and size() ====================
			// WriteAt should NOT change tell position
			tell2, err := ctx.Seek(0, io.SeekCurrent)
			require.NoError(t, err, "Step 7: Tell failed")
			// tell2 should still be 350 (unchanged by WriteAt)
			assert.EqualValues(t, int64(350), tell2, "Step 7: Tell position (WriteAt should not change tell)")

			size2 := ctx.Size()
			// size2 should be 600 (520 + 80)
			assert.EqualValues(t, int64(600), size2, "Step 7: Size")
			t.Logf("Step 6-7: WriteAt 80 bytes at %d, tell=%d, size=%d", writeAtOffset, tell2, size2)

			// ==================== Step 8: Verify data integrity ====================
			ctx.Seek(0, io.SeekStart)
			allData := make([]byte, size2)
			n, err = io.ReadFull(ctx, allData)
			if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
				t.Fatalf("Step 8: ReadAll failed: %v", err)
			}
			assert.EqualValues(t, int64(n), size2, "Step 8: ReadAll length")

			// Verify data integrity
			t.Logf("Step 8: ReadAll %d bytes, verifying data integrity...", n)

			// Verify initial data (0-199)
			assert.EqualValues(t, makeSequentialBytes(200), allData[:200], "Initial data")

			// Verify test1 data (at initialSize + 100)
			test1Start := int(initialSize + 100)
			assert.EqualValues(t, bytes.Repeat([]byte{'1'}, 100), allData[test1Start:test1Start+100], "test1 data")

			// Verify test2 data (at writeAtOffset)
			test2Start := int(writeAtOffset)
			assert.EqualValues(t, bytes.Repeat([]byte{'2'}, 80), allData[test2Start:test2Start+80], "test2 data")

			t.Logf("Step 8: Data verification complete, total size=%d", size2)
		})
	}
}

// ==================== Test: Truncate Shrink Updates Position ====================
// TestTruncateShrinkUpdatesPos verifies that Truncate shrink correctly updates the position.
// This is a safety test to prevent a bug where pos is not updated after Truncate shrink,
// causing subsequent Write operations to write at incorrect positions.
func TestTruncateShrinkUpdatesPos(t *testing.T) {
	for _, factory := range GetAllFactories() {
		t.Run(factory.Name, func(t *testing.T) {
			ctx := CreateContext(t, factory.Factory)
			defer ctx.Close()

			// Write 200 bytes
			data := makeSequentialBytes(200)
			n, err := ctx.Write(data)
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
			newData := []byte("Hello")
			n, err = ctx.Write(newData)
			require.NoError(t, err, "Write after truncate failed")
			require.EqualValues(t, 5, n, "Write after truncate length")

			// Verify size is now 55 (50 + 5)
			assert.EqualValues(t, int64(55), ctx.Size(), "After write size")

			// Verify data integrity
			ctx.Seek(0, io.SeekStart)
			allData := make([]byte, 55)
			_, err = io.ReadFull(ctx, allData)
			require.NoError(t, err, "Read failed")

			// Verify first 50 bytes are preserved
			assert.EqualValues(t, makeSequentialBytes(50), allData[:50], "First 50 bytes")

			// Verify last 5 bytes are "Hello"
			assert.EqualValues(t, "Hello", string(allData[50:55]), "Last 5 bytes")

			t.Logf("Truncate shrink pos update test passed: size=%d, pos updated correctly", ctx.Size())
		})
	}
}
