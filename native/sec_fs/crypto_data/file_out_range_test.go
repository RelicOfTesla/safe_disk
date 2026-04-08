package crypto_data_test

import (
	"bytes"
	"io"
	"testing"

	"safe_disk/native/sec_fs/crypto_data"
)

// ==================== Test: ReadAt Behavior ====================
// TestReadAtBehavior tests ReadAt behavior consistency with os.File
//
// Test scenarios:
//  1. ReadAt from position 0
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
			if err != nil || n != len(testData) {
				t.Fatalf("Write failed: n=%d, err=%v", n, err)
			}

			// Test 1: ReadAt from position 0
			buf := make([]byte, 5)
			n, err = ctx.ReadAt(buf, 0)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(0) failed: %v", err)
			}
			if string(buf[:n]) != "Hello" {
				t.Errorf("ReadAt(0): expected 'Hello', got %q", buf[:n])
			}
			t.Logf("Test 1: ReadAt(0, 5) = %q", buf[:n])

			// Test 2: ReadAt from middle position
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 7)
			if err != nil && err != io.EOF {
				t.Errorf("ReadAt(7) failed: %v", err)
			}
			if string(buf[:n]) != "World" {
				t.Errorf("ReadAt(7): expected 'World', got %q", buf[:n])
			}
			t.Logf("Test 2: ReadAt(7, 5) = %q", buf[:n])

			// Test 3: ReadAt beyond file end
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 20)
			if n != 0 {
				t.Errorf("ReadAt beyond end: expected n=0, got n=%d", n)
			}
			if err != io.EOF {
				t.Errorf("ReadAt beyond end: expected io.EOF, got %v", err)
			}
			t.Logf("Test 3: ReadAt(20, 5) = n=%d, err=%v", n, err)

			// Test 4: ReadAt partial read
			buf = make([]byte, 5)
			n, err = ctx.ReadAt(buf, 10)
			if n != 3 {
				t.Errorf("ReadAt partial: expected n=3, got n=%d", n)
			}
			if string(buf[:n]) != "ld!" {
				t.Errorf("ReadAt partial: expected 'ld!', got %q", buf[:n])
			}
			if err != io.EOF && err != io.ErrUnexpectedEOF {
				t.Errorf("ReadAt partial: expected EOF, got %v", err)
			}
			t.Logf("Test 4: ReadAt(10, 5) = n=%d, data=%q, err=%v", n, buf[:n], err)

			// Test 5: ReadAt should NOT change current seek position
			pos, err := ctx.Seek(5, io.SeekStart)
			if err != nil || pos != 5 {
				t.Fatalf("Seek(5) failed: pos=%d, err=%v", pos, err)
			}

			buf = make([]byte, 5)
			ctx.ReadAt(buf, 0)

			pos, err = ctx.Seek(0, io.SeekCurrent)
			if err != nil {
				t.Errorf("Seek current failed: %v", err)
			}
			if pos != 5 {
				t.Errorf("ReadAt changed seek position: expected 5, got %d", pos)
			}
			t.Logf("Test 5: ReadAt does not change seek position (still at %d)", pos)
		})
	}
}

// ==================== Test: ReadAt/WriteAt Seek Position Check ====================
// TestReadAtWriteAtSeekPosition verifies ReadAt/WriteAt do not change seek position
//
// Test scenarios:
//  1. ReadAt should not change seek position
//  2. WriteAt should not change seek position
//  3. Multiple ReadAt/WriteAt should preserve seek position
func TestReadAtWriteAtSeekPosition(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
			defer ctx.Close()

			// Write initial data: "Hello, World!" (13 bytes)
			testData := []byte("Hello, World!")
			n, err := ctx.Write(testData)
			if err != nil || n != len(testData) {
				t.Fatalf("Write failed: n=%d, err=%v", n, err)
			}

			// Test 1: ReadAt should not change seek position
			t.Run("ReadAt_SeekCheck", func(t *testing.T) {
				// Seek to position 5
				pos, err := ctx.Seek(5, io.SeekStart)
				if err != nil || pos != 5 {
					t.Fatalf("Seek(5) failed: pos=%d, err=%v", pos, err)
				}

				// ReadAt at position 0
				buf := make([]byte, 5)
				n, err := ctx.ReadAt(buf, 0)
				if err != nil && err != io.EOF {
					t.Errorf("ReadAt failed: %v", err)
				}
				if n != 5 {
					t.Errorf("ReadAt: expected n=5, got n=%d", n)
				}

				// Verify seek position unchanged (should still be 5)
				pos, err = ctx.Seek(0, io.SeekCurrent)
				if err != nil {
					t.Errorf("Seek current failed: %v", err)
				}
				if pos != 5 {
					t.Errorf("ReadAt changed seek position: expected 5, got %d", pos)
				}
				t.Logf("ReadAt(0, 5) -> seek position still at %d", pos)
			})

			// Test 2: WriteAt should not change seek position
			t.Run("WriteAt_SeekCheck", func(t *testing.T) {
				// Seek to position 7
				pos, err := ctx.Seek(7, io.SeekStart)
				if err != nil || pos != 7 {
					t.Fatalf("Seek(7) failed: pos=%d, err=%v", pos, err)
				}

				// WriteAt at position 0
				n, err := ctx.WriteAt([]byte("HELLO"), 0)
				if err != nil {
					t.Errorf("WriteAt failed: %v", err)
				}
				if n != 5 {
					t.Errorf("WriteAt: expected n=5, got n=%d", n)
				}

				// Verify seek position unchanged (should still be 7)
				pos, err = ctx.Seek(0, io.SeekCurrent)
				if err != nil {
					t.Errorf("Seek current failed: %v", err)
				}
				if pos != 7 {
					t.Errorf("WriteAt changed seek position: expected 7, got %d", pos)
				}
				t.Logf("WriteAt(0, 5) -> seek position still at %d", pos)
			})

			// Test 3: Multiple ReadAt/WriteAt should preserve seek position
			t.Run("Multiple_ReadAt_WriteAt_SeekCheck", func(t *testing.T) {
				// Seek to position 10
				pos, err := ctx.Seek(10, io.SeekStart)
				if err != nil || pos != 10 {
					t.Fatalf("Seek(10) failed: pos=%d, err=%v", pos, err)
				}

				// Multiple ReadAt
				for i := 0; i < 5; i++ {
					buf := make([]byte, 2)
					ctx.ReadAt(buf, int64(i*2))
				}

				// Verify seek position unchanged (should still be 10)
				pos, err = ctx.Seek(0, io.SeekCurrent)
				if err != nil {
					t.Errorf("Seek current failed: %v", err)
				}
				if pos != 10 {
					t.Errorf("Multiple ReadAt changed seek position: expected 10, got %d", pos)
				}

				// Multiple WriteAt
				for i := 0; i < 5; i++ {
					ctx.WriteAt([]byte("XX"), int64(i*3))
				}

				// Verify seek position unchanged (should still be 10)
				pos, err = ctx.Seek(0, io.SeekCurrent)
				if err != nil {
					t.Errorf("Seek current failed: %v", err)
				}
				if pos != 10 {
					t.Errorf("Multiple WriteAt changed seek position: expected 10, got %d", pos)
				}
				t.Logf("Multiple ReadAt/WriteAt -> seek position still at %d", pos)
			})
		})
	}
}

// ==================== Test: Gap Append Tests ====================
// TestGapAppend tests the ensure_append_gap() functionality across all algorithms.
// This verifies that gaps are correctly filled with encrypted zeros (or zeros for mockFile).
//
// Test scenarios:
//  1. WriteAt_GapFill: WriteAt beyond file end should fill gap with zeros
//  2. SeekWrite_GapFill: Seek beyond end + Write should fill gap
//  3. SeekBeyondEnd_Read: Seek beyond end + Read returns (0, io.EOF)
//  4. MultipleGaps: Multiple gap-filling operations
//  5. LargeGap: Large gap filling (e.g., 1KB gap)
//  6. TruncateExpand: Truncate to larger size should fill with zeros
//  7. GapIntegrity: Verify gap data is correctly encrypted/decrypted
//  8. TruncateExpand_SeekCheck: Truncate expand should not change seek position
func TestGapAppend(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			// Test 1: Gap fill with WriteAt
			t.Run("WriteAt_GapFill", func(t *testing.T) {
				testWriteAtGapFill(t, ff.Factory)
			})

			// Test 2: Gap fill with Seek+Write
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

			// Test 6: Truncate expand (basic)
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

// testWriteAtGapFill tests that WriteAt beyond file end fills gap with zeros
// Also verifies that WriteAt does NOT change seek position
func testWriteAtGapFill(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	initialData := []byte("Hello")
	n, err := ctx.Write(initialData)
	if err != nil || n != len(initialData) {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Record current position (should be 5)
	posAfterWrite, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Fatalf("Seek current failed: %v", err)
	}
	if posAfterWrite != 5 {
		t.Errorf("After Write, pos should be 5, got %d", posAfterWrite)
	}

	// WriteAt beyond file end (gap of 95 bytes)
	testData := []byte("World")
	n, err = ctx.WriteAt(testData, 100)
	if err != nil || n != len(testData) {
		t.Fatalf("WriteAt failed: n=%d, err=%v", n, err)
	}

	// CRITICAL: WriteAt should NOT change seek position
	posAfterWriteAt, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Errorf("Seek current failed: %v", err)
	}
	if posAfterWriteAt != posAfterWrite {
		t.Errorf("WriteAt changed seek position: expected %d, got %d", posAfterWrite, posAfterWriteAt)
	} else {
		t.Logf("WriteAt preserved seek position at %d", posAfterWriteAt)
	}

	// Verify size is 105
	size := ctx.Size()
	if size != 105 {
		t.Errorf("Size mismatch: expected 105, got %d", size)
	}

	// Seek to beginning and read all data
	_, err = ctx.Seek(0, io.SeekStart)
	if err != nil {
		t.Fatalf("Seek start failed: %v", err)
	}

	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 105)
	copy(expected[:5], initialData)
	copy(expected[100:105], testData)

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got:      %q\n  expected: %q", allData, expected)
		for i := 0; i < 105; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("WriteAt test passed: size=%d, data verified with bytes.Equal", size)
	}

	// ADDITIONAL VERIFICATION: Verify gap is filled with zeros
	for i := 5; i < 100; i++ {
		if allData[i] != 0 {
			t.Errorf("Gap byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}
}

// testSeekWriteGapFill tests that Seek beyond end + Write fills gap with zeros
// Also verifies that Write DOES change seek position
func testSeekWriteGapFill(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	initialData := []byte("Hello")
	n, err := ctx.Write(initialData)
	if err != nil || n != len(initialData) {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Seek beyond file end
	pos, err := ctx.Seek(100, io.SeekStart)
	if err != nil || pos != 100 {
		t.Fatalf("Seek failed: pos=%d, err=%v", pos, err)
	}

	// Write at gap position
	testData := []byte("World")
	n, err = ctx.Write(testData)
	if err != nil || n != len(testData) {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Verify tell() == 105 (Write changes seek position)
	pos, err = ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Fatalf("Seek current failed: %v", err)
	}
	if pos != 105 {
		t.Errorf("Tell position: expected 105, got %d", pos)
	}

	// Verify size is 105
	size := ctx.Size()
	if size != 105 {
		t.Errorf("Size mismatch: expected 105, got %d", size)
	}

	// Seek to beginning and read all data
	_, err = ctx.Seek(0, io.SeekStart)
	if err != nil {
		t.Fatalf("Seek start failed: %v", err)
	}

	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 105)
	copy(expected[:5], initialData)
	copy(expected[100:105], testData)

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got:      %q\n  expected: %q", allData, expected)
		for i := 0; i < 105; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("SeekWrite test passed: size=%d, data verified with bytes.Equal", size)
	}

	// ADDITIONAL VERIFICATION: Verify gap is filled with zeros
	for i := 5; i < 100; i++ {
		if allData[i] != 0 {
			t.Errorf("Gap byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}
}

// testSeekBeyondEndRead tests that Seek beyond file end + Read returns (0, io.EOF)
// This is a unique scenario not covered by other tests
func testSeekBeyondEndRead(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write test data: "Hello" (5 bytes)
	testData := []byte("Hello")
	n, err := ctx.Write(testData)
	if err != nil || n != len(testData) {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Test 1: Seek beyond file end
	pos, err := ctx.Seek(100, io.SeekStart)
	if err != nil {
		t.Errorf("Seek beyond end failed: %v", err)
	}
	if pos != 100 {
		t.Errorf("Seek position: expected 100, got %d", pos)
	}
	t.Logf("Test 1: Seek(100) = %d, err=%v", pos, err)

	// Test 2: Read after Seek beyond end should return 0, io.EOF
	// This is the UNIQUE test case!
	buf := make([]byte, 10)
	n, err = ctx.Read(buf)
	if n != 0 {
		t.Errorf("Read after Seek beyond end: expected n=0, got n=%d", n)
	}
	if err != io.EOF {
		t.Errorf("Read after Seek beyond end: expected io.EOF, got %v", err)
	}
	t.Logf("Test 2: Read after Seek(100) = n=%d, err=%v", n, err)

	// Test 3: Write after Seek beyond end fills gap with zeros
	pos, err = ctx.Seek(100, io.SeekStart)
	if err != nil {
		t.Fatalf("Seek(100) failed: %v", err)
	}

	n, err = ctx.Write([]byte("World"))
	if err != nil || n != 5 {
		t.Fatalf("Write at 100 failed: n=%d, err=%v", n, err)
	}

	size := ctx.Size()
	if size != 105 {
		t.Errorf("File size: expected 105, got %d", size)
	}
	t.Logf("Test 3: Write at 100, file size = %d", size)

	// Test 4: Verify gap filled with zeros
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 105)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 105)
	copy(expected[:5], testData)
	copy(expected[100:105], []byte("World"))

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got:      %q\n  expected: %q", allData, expected)
		for i := 0; i < 105; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Test 4: Data verified with bytes.Equal, size=%d", size)
	}

	// First 5 bytes should be "Hello"
	if string(allData[:5]) != "Hello" {
		t.Errorf("First 5 bytes: expected 'Hello', got %q", allData[:5])
	}

	// Bytes 5-99 should be zeros
	for i := 5; i < 100; i++ {
		if allData[i] != 0 {
			t.Errorf("Gap byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}

	// Bytes 100-104 should be "World"
	if string(allData[100:105]) != "World" {
		t.Errorf("Bytes 100-104: expected 'World', got %q", allData[100:105])
	}

	t.Logf("Test 4: Gap filled with zeros, data = 'Hello' + 95 zeros + 'World'")
}

// testMultipleGaps tests multiple gap-filling operations
func testMultipleGaps(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data at position 0
	ctx.Write([]byte("A"))

	// Write at position 50 (gap 1: 49 bytes)
	ctx.WriteAt([]byte("B"), 50)

	// Write at position 100 (gap 2: 49 bytes)
	ctx.WriteAt([]byte("C"), 100)

	// Write at position 200 (gap 3: 99 bytes)
	ctx.WriteAt([]byte("D"), 200)

	// Verify size is 201
	size := ctx.Size()
	if size != 201 {
		t.Errorf("Size mismatch: expected 201, got %d", size)
	}

	// Read all and verify gaps
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 201)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if n != 201 {
		t.Errorf("ReadAll returned wrong length: expected 201, got %d", n)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 201)
	expected[0] = 'A'
	expected[50] = 'B'
	expected[100] = 'C'
	expected[200] = 'D'

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got len=%d, expected len=%d", len(allData), len(expected))
		for i := 0; i < 201; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Multiple gaps: Data verified with bytes.Equal, size=%d", size)
	}

	// Verify data at each position
	if allData[0] != 'A' {
		t.Errorf("Position 0: expected 'A', got %d", allData[0])
	}
	if allData[50] != 'B' {
		t.Errorf("Position 50: expected 'B', got %d", allData[50])
	}
	if allData[100] != 'C' {
		t.Errorf("Position 100: expected 'C', got %d", allData[100])
	}
	if allData[200] != 'D' {
		t.Errorf("Position 200: expected 'D', got %d", allData[200])
	}

	// Verify all gaps are filled with zeros
	gaps := []struct {
		start, end int
	}{
		{1, 50},
		{51, 100},
		{101, 200},
	}

	for _, gap := range gaps {
		for i := gap.start; i < gap.end; i++ {
			if allData[i] != 0 {
				t.Errorf("Gap [%d-%d) byte %d: expected 0, got %d", gap.start, gap.end, i, allData[i])
				break
			}
		}
	}

	t.Logf("Multiple gaps: 3 gaps filled with zeros, size=%d", size)
}

// testLargeGap tests large gap filling
func testLargeGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	ctx.Write([]byte("Start"))

	// WriteAt at 1KB position (large gap)
	largeGapSize := int64(1 * 1024) // 1KB
	ctx.WriteAt([]byte("End"), largeGapSize)

	// Verify size
	size := ctx.Size()
	if size != largeGapSize+3 {
		t.Errorf("Size mismatch: expected %d, got %d", largeGapSize+3, size)
	}

	// Read all data for comprehensive verification
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, largeGapSize+3)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if int64(n) != largeGapSize+3 {
		t.Errorf("ReadAll returned wrong length: expected %d, got %d", largeGapSize+3, n)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, largeGapSize+3)
	copy(expected[:5], []byte("Start"))
	copy(expected[largeGapSize:], []byte("End"))

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got len=%d, expected len=%d", len(allData), len(expected))
		// Only show first diff if any
		for i := range allData {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Large gap: Data verified with bytes.Equal, size=%d", size)
	}

	// Verify by sampling (not reading all data)
	// Check a few positions in the gap
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
	if buf[0] != 'E' {
		t.Errorf("End position %d: expected 'E', got %d", largeGapSize, buf[0])
	}

	t.Logf("Large gap: 1KB gap filled with zeros, size=%d", size)
}

// testTruncateExpandGap tests Truncate expand fills gap with zeros
func testTruncateExpandGap(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data: "Hello" (5 bytes)
	n, err := ctx.Write([]byte("Hello"))
	if err != nil || n != 5 {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Test 1: Truncate to larger size (expand)
	err = ctx.Truncate(100)
	if err != nil {
		t.Fatalf("Truncate(100) failed: %v", err)
	}

	// Verify size
	size := ctx.Size()
	if size != 100 {
		t.Errorf("Size after Truncate: expected 100, got %d", size)
	}
	t.Logf("Test 1: Truncate(100) -> size=%d", size)

	// Read all and verify zeros
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 100)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if n != 100 {
		t.Errorf("ReadAll returned wrong length: expected 100, got %d", n)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 100)
	copy(expected[:5], []byte("Hello"))

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got len=%d, expected len=%d", len(allData), len(expected))
		for i := 0; i < 100; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Test 1: Data verified with bytes.Equal, size=%d", size)
	}

	// First 5 bytes should be "Hello"
	if string(allData[:5]) != "Hello" {
		t.Errorf("First 5 bytes: expected 'Hello', got %q", allData[:5])
	}

	// Bytes 5-99 should be zeros
	for i := 5; i < 100; i++ {
		if allData[i] != 0 {
			t.Errorf("Expanded byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}

	t.Logf("Test 2: Truncate expand filled with zeros: 'Hello' + 95 zeros")
}

// testGapIntegrity tests that gap data can be correctly read back after encryption/decryption
func testGapIntegrity(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write known data
	knownData := make([]byte, 100)
	for i := range knownData {
		knownData[i] = byte(i % 256)
	}
	ctx.Write(knownData)

	// Write at position 500 (gap of 400 bytes)
	endData := []byte("EndData")
	ctx.WriteAt(endData, 500)

	// Verify size
	size := ctx.Size()
	if size != 507 {
		t.Errorf("Size mismatch: expected 507, got %d", size)
	}

	// Read back and verify
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 507)
	n, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if n != 507 {
		t.Errorf("ReadAll returned wrong length: expected 507, got %d", n)
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 507)
	for i := 0; i < 100; i++ {
		expected[i] = byte(i % 256)
	}
	copy(expected[500:], endData)

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got len=%d, expected len=%d", len(allData), len(expected))
		for i := 0; i < 507; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Gap integrity: Data verified with bytes.Equal, size=%d", size)
	}

	// Verify known data
	for i := 0; i < 100; i++ {
		if allData[i] != knownData[i] {
			t.Errorf("Known data mismatch at %d: expected %d, got %d", i, knownData[i], allData[i])
			break
		}
	}

	// Verify gap is zeros
	gapCorrect := true
	for i := 100; i < 500; i++ {
		if allData[i] != 0 {
			gapCorrect = false
			t.Errorf("Gap byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}

	// Verify end data
	if string(allData[500:507]) != "EndData" {
		t.Errorf("End data mismatch: expected 'EndData', got %q", allData[500:507])
	}

	if gapCorrect {
		t.Logf("Gap integrity: known data + 400-byte gap + end data verified, size=%d, read=%d", size, n)
	}
}

// testTruncateExpandSeekCheck tests that Truncate expand does not change seek position
func testTruncateExpandSeekCheck(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write initial data
	n, err := ctx.Write([]byte("Hello"))
	if err != nil || n != 5 {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Record current position (should be 5)
	posAfterWrite, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Fatalf("Seek current failed: %v", err)
	}
	if posAfterWrite != 5 {
		t.Errorf("After Write, pos should be 5, got %d", posAfterWrite)
	}

	// Test 1: Truncate to larger size
	err = ctx.Truncate(100)
	if err != nil {
		t.Fatalf("Truncate(100) failed: %v", err)
	}

	// CRITICAL: Truncate should NOT change seek position
	posAfterTruncate, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Errorf("Seek current failed: %v", err)
	}
	if posAfterTruncate != posAfterWrite {
		t.Errorf("Truncate changed seek position: expected %d, got %d", posAfterWrite, posAfterTruncate)
	} else {
		t.Logf("Truncate preserved seek position at %d", posAfterTruncate)
	}

	// Verify size
	size := ctx.Size()
	if size != 100 {
		t.Errorf("Size after Truncate: expected 100, got %d", size)
	}
	t.Logf("Test 1: Truncate(100) -> size=%d", size)

	// Test 2: Truncate expand again (multiple expands)
	err = ctx.Truncate(200)
	if err != nil {
		t.Fatalf("Truncate(200) failed: %v", err)
	}

	// Verify seek position still unchanged
	posAfterTruncate2, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Errorf("Seek current failed: %v", err)
	}
	if posAfterTruncate2 != posAfterWrite {
		t.Errorf("Truncate(200) changed seek position: expected %d, got %d", posAfterWrite, posAfterTruncate2)
	} else {
		t.Logf("Truncate(200) preserved seek position at %d", posAfterTruncate2)
	}

	size = ctx.Size()
	if size != 200 {
		t.Errorf("Size after second Truncate: expected 200, got %d", size)
	}
	t.Logf("Test 2: Truncate(200) -> size=%d", size)

	// ADDITIONAL VERIFICATION: Verify data content after Truncate expand
	ctx.Seek(0, io.SeekStart)
	allData := make([]byte, 200)
	nRead, err := io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if nRead != 200 {
		t.Errorf("ReadAll returned wrong length: expected 200, got %d", nRead)
	}

	// Verify first 5 bytes are "Hello"
	if string(allData[:5]) != "Hello" {
		t.Errorf("First 5 bytes: expected 'Hello', got %q", allData[:5])
	}

	// Verify bytes 5-199 are zeros (expanded by Truncate)
	for i := 5; i < 200; i++ {
		if allData[i] != 0 {
			t.Errorf("Expanded byte %d: expected 0, got %d", i, allData[i])
			break
		}
	}

	// ADDITIONAL VERIFICATION: bytes.Equal for whole data comparison
	expected := make([]byte, 200)
	copy(expected[:5], []byte("Hello"))

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got len=%d, expected len=%d", len(allData), len(expected))
		for i := 0; i < 200; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("Test 3: Data verified with bytes.Equal after Truncate expand")
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
			initData := make([]byte, 200)
			for i := range initData {
				initData[i] = byte(i % 256)
			}
			n, err := ctx.Write(initData)
			if err != nil {
				t.Fatalf("Step 1: Write failed: %v", err)
			}
			if n != len(initData) {
				t.Fatalf("Step 1: Write returned wrong length: got %d, want %d", n, len(initData))
			}

			initialSize := ctx.Size()
			t.Logf("Step 1: Initial write %d bytes, size=%d", len(initData), initialSize)

			if initialSize != int64(len(initData)) {
				t.Fatalf("Step 1: Initial size mismatch: got %d, want %d", initialSize, len(initData))
			}

			// ==================== Step 2: Seek beyond file end ====================
			// Seek to FileSize + 100 (beyond end)
			seekPos := initialSize + 100
			pos, err := ctx.Seek(seekPos, io.SeekStart)
			if err != nil {
				t.Fatalf("Step 2: Seek failed: %v", err)
			}
			if pos != seekPos {
				t.Errorf("Step 2: Seek position: expected %d, got %d", seekPos, pos)
			}
			t.Logf("Step 2: Seek to %d (FileSize+100)", pos)

			// ==================== Step 3: Write at gap position ====================
			// Write 100 bytes of "test1" data at the gap position
			test1Data := make([]byte, 100)
			for i := range test1Data {
				test1Data[i] = byte('1')
			}

			n, err = ctx.Write(test1Data)
			if err != nil {
				t.Fatalf("Step 3: Write test1 failed: %v", err)
			}
			if n != len(test1Data) {
				t.Fatalf("Step 3: Write test1 returned wrong length: got %d, want %d", n, len(test1Data))
			}

			// ==================== Step 4: Check position and size ====================
			// tell() should be at the end of what we just wrote
			expectedPos1 := seekPos + int64(len(test1Data))
			currentPos, err := ctx.Seek(0, io.SeekCurrent)
			if err != nil {
				t.Fatalf("Step 4: tell() failed: %v", err)
			}
			if currentPos != expectedPos1 {
				t.Errorf("Step 4: Position mismatch: got %d, want %d", currentPos, expectedPos1)
			}

			// Size should now be FileSize + 100 (gap) + 100 (written) = FileSize + 200
			expectedSize1 := initialSize + 200
			actualSize1 := ctx.Size()
			if actualSize1 != expectedSize1 {
				t.Errorf("Step 4: Size mismatch: got %d, want %d", actualSize1, expectedSize1)
			}

			t.Logf("Step 4: After Write, pos=%d, size=%d (expected pos=%d, size=%d)",
				currentPos, actualSize1, expectedPos1, expectedSize1)

			// ==================== Step 5: Seek to near end ====================
			// Seek to FileSize(new) - 50
			seekPos2 := actualSize1 - 50
			pos, err = ctx.Seek(seekPos2, io.SeekStart)
			if err != nil {
				t.Fatalf("Step 5: Seek failed: %v", err)
			}
			if pos != seekPos2 {
				t.Errorf("Step 5: Seek position: expected %d, got %d", seekPos2, pos)
			}
			t.Logf("Step 5: Seek to %d (FileSize-50)", pos)

			// ==================== Step 6: WriteAt beyond end ====================
			// WriteAt at FileSize(new) + 120 (beyond current end)
			writeAtOffset := actualSize1 + 120
			test2Data := make([]byte, 80)
			for i := range test2Data {
				test2Data[i] = byte('2')
			}

			n, err = ctx.WriteAt(test2Data, writeAtOffset)
			if err != nil {
				t.Fatalf("Step 6: WriteAt failed: %v", err)
			}
			if n != len(test2Data) {
				t.Fatalf("Step 6: WriteAt returned wrong length: got %d, want %d", n, len(test2Data))
			}
			t.Logf("Step 6: WriteAt %d bytes at offset %d", len(test2Data), writeAtOffset)

			// ==================== Step 7: Check position and size ====================
			// tell() should NOT have changed (WriteAt doesn't affect position)
			currentPos2, err := ctx.Seek(0, io.SeekCurrent)
			if err != nil {
				t.Fatalf("Step 7: tell() failed: %v", err)
			}
			if currentPos2 != seekPos2 {
				t.Errorf("Step 7: Position changed after WriteAt: got %d, want %d (WriteAt should not change position)",
					currentPos2, seekPos2)
			}

			// Size should now be writeAtOffset + len(test2Data)
			expectedSize2 := writeAtOffset + int64(len(test2Data))
			actualSize2 := ctx.Size()
			if actualSize2 != expectedSize2 {
				t.Errorf("Step 7: Size mismatch: got %d, want %d", actualSize2, expectedSize2)
			}

			t.Logf("Step 7: After WriteAt, pos=%d, size=%d (expected pos=%d, size=%d)",
				currentPos2, actualSize2, seekPos2, expectedSize2)

			// ==================== Step 8: Verify data integrity ====================
			// Seek to start
			pos, err = ctx.Seek(0, io.SeekStart)
			if err != nil {
				t.Fatalf("Step 8: Seek to start failed: %v", err)
			}

			// Read all data
			allData := make([]byte, actualSize2)
			n, err = ctx.Read(allData)
			if err != nil && err != io.EOF {
				t.Fatalf("Step 8: Read failed: %v", err)
			}
			if int64(n) != actualSize2 {
				t.Errorf("Step 8: Read returned wrong length: got %d, want %d", n, actualSize2)
			}

			// Verify initial data (0-199)
			for i := 0; i < 200; i++ {
				expected := byte(i % 256)
				if allData[i] != expected {
					t.Errorf("Step 8: Initial data mismatch at %d: got %d, want %d", i, allData[i], expected)
					break
				}
			}

			// Verify test1 data (at initialSize + 100)
			test1Start := int(initialSize + 100)
			for i := 0; i < 100; i++ {
				if allData[test1Start+i] != byte('1') {
					t.Errorf("Step 8: test1 data mismatch at %d: got %d, want %d", test1Start+i, allData[test1Start+i], byte('1'))
					break
				}
			}

			// Verify test2 data (at writeAtOffset)
			test2Start := int(writeAtOffset)
			for i := 0; i < 80; i++ {
				if allData[test2Start+i] != byte('2') {
					t.Errorf("Step 8: test2 data mismatch at %d: got %d, want %d", test2Start+i, allData[test2Start+i], byte('2'))
					break
				}
			}

			t.Logf("Step 8: Data verification complete, total size=%d", actualSize2)
		})
	}
}

// ==================== Test: Truncate Shrink Pos Update ====================
// TestTruncateShrinkUpdatesPos verifies that Truncate shrink correctly updates the position.
// This is a safety test to prevent a bug where pos is not updated after Truncate shrink,
// causing subsequent Write operations to write at incorrect positions.
func TestTruncateShrinkUpdatesPos(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
			defer ctx.Close()

			// Write 200 bytes
			data := make([]byte, 200)
			for i := range data {
				data[i] = byte(i)
			}
			n, err := ctx.Write(data)
			if err != nil || n != 200 {
				t.Fatalf("Initial write failed: n=%d, err=%v", n, err)
			}

			// Now pos should be 200
			pos, _ := ctx.Seek(0, io.SeekCurrent)
			if pos != 200 {
				t.Errorf("After write, pos should be 200, got %d", pos)
			}

			// Truncate shrink to 50
			err = ctx.Truncate(50)
			if err != nil {
				t.Fatalf("Truncate shrink failed: %v", err)
			}

			// Verify size is now 50
			if ctx.Size() != 50 {
				t.Errorf("After truncate, size should be 50, got %d", ctx.Size())
			}

			// Verify pos is updated to 50 (not 200)
			pos, _ = ctx.Seek(0, io.SeekCurrent)
			if pos != 50 {
				t.Errorf("After truncate shrink, pos should be updated to 50, got %d", pos)
			}

			// Now write some data - it should be at position 50
			newData := []byte("Hello")
			n, err = ctx.Write(newData)
			if err != nil || n != 5 {
				t.Fatalf("Write after truncate failed: n=%d, err=%v", n, err)
			}

			// Verify size is now 55 (50 + 5)
			if ctx.Size() != 55 {
				t.Errorf("After write, size should be 55, got %d", ctx.Size())
			}

			// Verify data integrity
			ctx.Seek(0, io.SeekStart)
			allData := make([]byte, 55)
			_, err = io.ReadFull(ctx, allData)
			if err != nil {
				t.Fatalf("Read failed: %v", err)
			}

			// Verify first 50 bytes are preserved
			for i := 0; i < 50; i++ {
				if allData[i] != byte(i) {
					t.Errorf("Data mismatch at position %d: expected %d, got %d", i, byte(i), allData[i])
					break
				}
			}

			// Verify last 5 bytes are "Hello"
			if string(allData[50:55]) != "Hello" {
				t.Errorf("Data mismatch at end: expected 'Hello', got %q", allData[50:55])
			}

			t.Logf("Truncate shrink pos update test passed: size=%d, pos updated correctly", ctx.Size())
		})
	}
}
