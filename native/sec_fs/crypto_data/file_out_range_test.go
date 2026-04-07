package crypto_data_test

import (
	"bytes"
	"io"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"
)

// ==================== Test Factory ====================

// ContextFactory creates IFullDataCryptorContext for testing
type ContextFactory struct {
	Name    string
	Factory crypto_data.ICryptoDataFactory
}

// GetAllFactories returns all context factories for testing
func GetAllFactories() []ContextFactory {
	// TODO: crypto_data.ListFactories()
	return []ContextFactory{
		{Name: "mockFile", Factory: nil},
		{Name: "rc4", Factory: rc4.NewFactory()},
		{Name: "aes-gcm", Factory: aes_gcm.NewFactory()},
	}
}

// CreateContext creates a context for testing
func CreateContext(t *testing.T, factory crypto_data.ICryptoDataFactory) crypto_data.IDataCryptorContext {
	if factory == nil {
		return newMockReadWriterSeeker()
	}

	storeIo := newMockReadWriterSeeker()
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	keyInfo := &mockKeyInfo{key: key}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	return ctx
}

// ==================== Test 1 & 2: Gap Write ====================

// TestFileOutOfRange tests writing beyond file end
// Test 1: WriteAt(pos=100) -> tell()==104 -> ReadAll == "prefix\0\0...test"
// Test 2: Seek(100)+Write -> tell()==104 -> ReadAll == "prefix\0\0...test"
func TestFileOutOfRange(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			// Test 1: WriteAt beyond file end
			t.Run("WriteAt", func(t *testing.T) {
				testWriteAtOutOfRange(t, ff.Factory)
			})

			// Test 2: Seek beyond file end + Write
			t.Run("SeekWrite", func(t *testing.T) {
				testSeekWriteOutOfRange(t, ff.Factory)
			})
		})
	}
}

func testWriteAtOutOfRange(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write "prefix" (6 bytes)
	prefix := []byte("prefix")
	n, err := ctx.Write(prefix)
	if err != nil || n != len(prefix) {
		t.Fatalf("Write prefix failed: n=%d, err=%v", n, err)
	}

	// WriteAt "test" at position 100
	test := []byte("test")
	n, err = ctx.WriteAt(test, 100)
	if err != nil || n != len(test) {
		t.Fatalf("WriteAt failed: n=%d, err=%v", n, err)
	}

	// Verify tell() == 6 (WriteAt does not change seek position)
	pos, err := ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Fatalf("Seek current failed: %v", err)
	}
	if pos != 6 {
		t.Errorf("WriteAt changed seek position: expected 6, got %d", pos)
	}

	// Seek to beginning and read all
	_, err = ctx.Seek(0, io.SeekStart)
	if err != nil {
		t.Fatalf("Seek start failed: %v", err)
	}

	allData := make([]byte, 104)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}

	// Verify result: "prefix" + 95 zeros + "test"
	expected := make([]byte, 104)
	copy(expected[:6], prefix)
	copy(expected[100:104], test)

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got:      %q\n  expected: %q", allData, expected)
		for i := 0; i < 104; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("WriteAt test passed: size=%d, first 20 bytes=%q", len(allData), allData[:20])
	}
}

func testSeekWriteOutOfRange(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	ctx := CreateContext(t, factory)
	defer ctx.Close()

	// Write "prefix" (6 bytes)
	prefix := []byte("prefix")
	n, err := ctx.Write(prefix)
	if err != nil || n != len(prefix) {
		t.Fatalf("Write prefix failed: n=%d, err=%v", n, err)
	}

	// Seek to position 100 and write "test"
	pos, err := ctx.Seek(100, io.SeekStart)
	if err != nil || pos != 100 {
		t.Fatalf("Seek(100) failed: pos=%d, err=%v", pos, err)
	}

	test := []byte("test")
	n, err = ctx.Write(test)
	if err != nil || n != len(test) {
		t.Fatalf("Write failed: n=%d, err=%v", n, err)
	}

	// Verify tell() == 104
	pos, err = ctx.Seek(0, io.SeekCurrent)
	if err != nil {
		t.Fatalf("Seek current failed: %v", err)
	}
	if pos != 104 {
		t.Errorf("Tell position: expected 104, got %d", pos)
	}

	// Seek to beginning and read all
	_, err = ctx.Seek(0, io.SeekStart)
	if err != nil {
		t.Fatalf("Seek start failed: %v", err)
	}

	allData := make([]byte, 104)
	n, err = io.ReadFull(ctx, allData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		t.Fatalf("ReadAll failed: %v", err)
	}

	// Verify result: "prefix" + 95 zeros + "test"
	expected := make([]byte, 104)
	copy(expected[:6], prefix)
	copy(expected[100:104], test)

	if !bytes.Equal(allData, expected) {
		t.Errorf("Data mismatch:\n  got:      %q\n  expected: %q", allData, expected)
		for i := 0; i < 104; i++ {
			if allData[i] != expected[i] {
				t.Errorf("First diff at position %d: got %d, expected %d", i, allData[i], expected[i])
				break
			}
		}
	} else {
		t.Logf("SeekWrite test passed: size=%d, first 20 bytes=%q", len(allData), allData[:20])
	}
}

// ==================== Test 3: ReadAt Behavior ====================

// TestReadAtBehavior tests ReadAt behavior consistency with os.File
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

// ==================== Test 4: SeekOut + Read ====================

// TestSeekOutReadBehavior tests Seek beyond file end + Read behavior
func TestSeekOutReadBehavior(t *testing.T) {
	factories := GetAllFactories()

	for _, ff := range factories {
		t.Run(ff.Name, func(t *testing.T) {
			ctx := CreateContext(t, ff.Factory)
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
		})
	}
}
