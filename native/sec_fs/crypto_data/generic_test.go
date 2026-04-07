// Package crypto_data_test provides generic tests for all registered cryptor algorithms.
package crypto_data_test

import (
	"fmt"
	"io"
	"math/rand"
	"os"
	"strconv"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"

	// Import algorithm implementations to trigger init() registration
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"
)

// ==================== Test List Factories ====================

func TestListFactories(t *testing.T) {
	factories := crypto_data.ListFactories()
	if len(factories) == 0 {
		t.Error("No cryptor factories registered")
	}

	t.Logf("Registered factories: %v", factories)

	for _, name := range factories {
		factory := crypto_data.GetFactory(name)
		if factory == nil {
			t.Errorf("Factory '%s' returned nil", name)
			continue
		}

		if factory.GetName() != name {
			t.Errorf("Factory name mismatch: expected '%s', got '%s'", name, factory.GetName())
		}
	}
}

// ==================== Test All Factories ====================

func TestAllFactories(t *testing.T) {
	// Use GetAllFactories() to include all factories including test-only ones
	factories := GetAllFactories()

	for _, ff := range factories {
		name := ff.Name
		factory := ff.Factory

		t.Run(name, func(t *testing.T) {
			// Test 1: Factory name
			t.Run("FactoryName", func(t *testing.T) {
				testFactoryName(t, factory, name)
			})

			// Test 2: Capabilities
			t.Run("Capabilities", func(t *testing.T) {
				testCapabilities(t, factory)
			})

			// Test 3: Create context
			t.Run("CreateContext", func(t *testing.T) {
				testCreateContext(t, factory)
			})

			// Test 4: Encrypt/Decrypt correctness
			t.Run("EncryptDecrypt", func(t *testing.T) {
				testEncryptDecrypt(t, factory)
			})

			// Test 5: Multiple write/read
			t.Run("MultipleWriteRead", func(t *testing.T) {
				testMultipleWriteRead(t, factory)
			})

			// Test 6: Seek operations
			t.Run("SeekOperations", func(t *testing.T) {
				testSeekOperations(t, factory)
			})

			// Test 7: Random delete
			t.Run("RandomDelete", func(t *testing.T) {
				testRandomDelete(t, factory)
			})

			// Test 8: Block boundary operations (neighbor block corruption test)
			t.Run("BlockBoundaryOperations", func(t *testing.T) {
				testBlockBoundaryOperations(t, factory)
			})

			// Test 9: Dual-writer integrity (MultiWriter-like verification)
			t.Run("DualWriterIntegrity", func(t *testing.T) {
				testDualWriterIntegrity(t, factory)
			})
		})
	}
}

// ==================== Individual Test Functions ====================

func testFactoryName(t *testing.T, factory crypto_data.ICryptoDataFactory, expectedName string) {
	name := factory.GetName()
	if name != expectedName {
		t.Errorf("Expected factory name '%s', got '%s'", expectedName, name)
	}
	t.Logf("Factory name: %s", name)
}

func testCapabilities(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	caps := factory.GetCapabilities()

	t.Logf("Capabilities: Mode=%v, Streaming=%v, RandomAccess=%v, Modification=%v, RandomDelete=%v",
		caps.Mode, caps.StreamingComplexity, caps.RandomAccessComplexity, caps.ModificationComplexity, caps.RandomDeleteComplexity)

	// Verify mode is valid
	if caps.Mode < crypto_data.CryptModeNormal || caps.Mode > crypto_data.CryptModeIncremental {
		t.Errorf("Invalid mode: %v", caps.Mode)
	}
}

func testCreateContext(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	storeIo := newMockReadWriterSeeker()
	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer ctx.Close()

	t.Logf("Context created successfully")
}

func testEncryptDecrypt(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	// Test data
	testCases := []struct {
		name string
		data []byte
	}{
		{"Small", []byte("Hello, World!")},
		{"Medium", make([]byte, 1024)},   // 1KB
		{"Large", make([]byte, 64*1024)}, // 64KB
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Fill with pattern if not small
			if tc.name != "Small" {
				for i := range tc.data {
					tc.data[i] = byte(i % 256)
				}
			}

			// Create new context for each test case (isolation)
			storeIo := newTrackerContext(newMockReadWriterSeeker())
			keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
			cfg := config.NewMemoryConfig()

			ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
			if err != nil {
				t.Fatalf("Failed to create context: %v", err)
			}
			defer ctx.Close()

			// Create trackerContext to track user-level operations
			tw := newTrackerContext(ctx)

			// Create dualWriter for integrity verification
			dw := newDualWriter(tw)

			// Write (encrypt) using dualWriter
			n, err := dw.Write(tc.data)
			if err != nil {
				t.Fatalf("Failed to write: %v", err)
			}
			if n != len(tc.data) {
				t.Errorf("Expected to write %d bytes, wrote %d", len(tc.data), n)
			}

			// Verify integrity using dualWriter
			if verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Encrypt/Decrypt verified for %d bytes", len(tc.data))) {
				// Success
			}
		})
	}
}

func testMultipleWriteRead(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	// Note: Some algorithms (like AES-GCM in Normal mode) don't support multiple writes
	// to the same context. This test creates separate contexts for each chunk,
	// which simulates writing to separate files.

	chunks := [][]byte{
		[]byte("First chunk of data"),
		[]byte("Second chunk of data"),
		[]byte("Third chunk of data"),
	}

	// Test: Write each chunk in a separate context (simulating separate files)
	for i, chunk := range chunks {
		t.Run(fmt.Sprintf("Chunk%d", i+1), func(t *testing.T) {
			storeIo := newTrackerContext(newMockReadWriterSeeker())
			keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
			cfg := config.NewMemoryConfig()

			ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
			if err != nil {
				t.Fatalf("Failed to create context: %v", err)
			}
			defer ctx.Close()

			// Create trackerContext to track user-level operations
			tw := newTrackerContext(ctx)

			// Create dualWriter for integrity verification
			dw := newDualWriter(tw)

			// Write chunk using dualWriter
			n, err := dw.Write(chunk)
			if err != nil {
				t.Fatalf("Failed to write chunk: %v", err)
			}
			if n != len(chunk) {
				t.Errorf("Expected to write %d bytes, wrote %d", len(chunk), n)
			}

			// Verify integrity using dualWriter
			if verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Chunk %d verified: %d bytes", i+1, len(chunk))) {
				// Success
			}
		})
	}
}

func testSeekOperations(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	storeIo := newTrackerContext(newMockReadWriterSeeker())
	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer ctx.Close()

	// Create trackerContext to track user-level operations
	tw := newTrackerContext(ctx)

	// Create dualWriter for integrity verification
	dw := newDualWriter(tw)

	// Write test data using dualWriter
	testData := []byte("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	_, err = dw.Write(testData)
	if err != nil {
		t.Fatalf("Failed to write: %v", err)
	}

	// Test SeekStart on dualWriter
	pos, err := dw.Seek(10, 0)
	if err != nil {
		t.Errorf("SeekStart failed: %v", err)
	}
	if pos != 10 {
		t.Errorf("SeekStart: expected pos 10, got %d", pos)
	}

	// Read from position 10
	buf := make([]byte, 5)
	n, err := dw.Read(buf)
	if err != nil {
		t.Errorf("Read after SeekStart failed: %v", err)
	}
	if string(buf[:n]) != "ABCDE" {
		t.Errorf("Read after SeekStart: expected 'ABCDE', got '%s'", string(buf[:n]))
	}

	// Test SeekCurrent on dualWriter
	pos, err = dw.Seek(5, 1)
	if err != nil {
		t.Errorf("SeekCurrent failed: %v", err)
	}
	// Current pos was 15, +5 = 20
	if pos != 20 {
		t.Errorf("SeekCurrent: expected pos 20, got %d", pos)
	}

	// Test SeekEnd on dualWriter
	pos, err = dw.Seek(-5, 2)
	if err != nil {
		t.Errorf("SeekEnd failed: %v", err)
	}
	// len(testData) - 5 = 31
	if pos != 31 {
		t.Errorf("SeekEnd: expected pos 31, got %d", pos)
	}

	// Verify integrity using dualWriter
	if verifyAndReport(t, tw, storeIo, dw, "", "Seek operations verified with full integrity check") {
		// Success
	}
}

func testRandomDelete(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	storeIo := newTrackerContext(newMockReadWriterSeeker())
	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer ctx.Close()

	// Create dual writer for integrity verification
	dw := newDualWriter(ctx)

	// Wrap with trackerContext to track user-level operations
	tw := newTrackerContext(dw)

	// Create initial data (1000 bytes)
	initialData := make([]byte, 1000)
	for i := range initialData {
		initialData[i] = byte(i % 256)
	}

	// Write initial data
	_, err = tw.Write(initialData)
	if err != nil {
		t.Fatalf("Failed to write initial data: %v", err)
	}

	initialSize := tw.Size()
	t.Logf("Initial size: %d bytes", initialSize)

	// Verify initial write integrity
	if !verifyAndReport(t, tw, storeIo, dw, "Initial write", "Initial write integrity verified") {
		return
	}

	// Test 1: Truncate to remove data from the end
	t.Log("Before truncate shrink")

	err = tw.Truncate(800)
	if err != nil {
		t.Fatalf("Truncate failed: %v", err)
	}

	newSize := tw.Size()
	if newSize != 800 {
		t.Errorf("After truncate: expected size 800, got %d", newSize)
	}
	t.Logf("After truncate: size = %d bytes", newSize)

	// Verify integrity after truncate shrink
	if !verifyAndReport(t, tw, storeIo, dw, "Truncate shrink", "Truncate shrink integrity verified") {
		return
	}

	// Test 2: Expand file with Truncate
	t.Log("Before truncate expand")

	err = tw.Truncate(1200)
	if err != nil {
		t.Fatalf("Truncate to expand failed: %v", err)
	}

	expandedSize := tw.Size()
	if expandedSize != 1200 {
		t.Errorf("After expand: expected size 1200, got %d", expandedSize)
	}
	t.Logf("After expand: size = %d bytes", expandedSize)

	// RC4 deadlock marker removed

	// Verify integrity after truncate expand (expanded area should be zeros)
	if !verifyAndReport(t, tw, storeIo, dw, "Truncate expand", "Truncate expand integrity verified") {
		return
	}

	// RC4 deadlock marker removed

	// Test 3: Simulate "delete in middle" by overwriting with zeros
	// This is not a real delete, but simulates the effect
	t.Log("Before write zeros")

	_, err = tw.Seek(400, 0)
	if err != nil {
		t.Fatalf("Seek to 400 failed: %v", err)
	}

	zeros := make([]byte, 100)
	_, err = tw.Write(zeros)
	if err != nil {
		t.Fatalf("Write zeros failed: %v", err)
	}
	t.Logf("Wrote 100 zeros at position 400")

	// Verify integrity after write
	if !verifyAndReport(t, tw, storeIo, dw, "Write zeros", "Write zeros integrity verified") {
		return
	}

	t.Logf("Random delete test passed: all data integrity verified")
}

// testDualWriterIntegrity tests data integrity using a dual-writer mechanism.
// Similar to io.MultiWriter, this approach writes to both:
//   - Encrypted context (ctx): stores encrypted data
//   - Plaintext mirror: stores plaintext data
//
// Verification: After each operation, we compare:
//
//	decrypt(ctx) == plaintextMirror
//
// This is more accurate than hash-based verification because it directly
// compares the expected plaintext with the decrypted data.
func testDualWriterIntegrity(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	storeIo := newTrackerContext(newMockReadWriterSeeker())
	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer ctx.Close()

	// Create trackerContext to track user-level operations
	tw := newTrackerContext(ctx)

	// Create dual writer
	dw := newDualWriter(tw)

	// Create initial data
	initialSize := 256
	initialData := make([]byte, initialSize)
	for i := range initialData {
		initialData[i] = byte(i % 256)
	}

	// Write initial data
	_, err = dw.Write(initialData)
	if err != nil {
		t.Fatalf("Failed to write initial data: %v", err)
	}

	// Verify integrity after initial write
	if !verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Initial write verified: size=%d bytes", initialSize)) {
		return
	}

	// Test operations
	testCases := []struct {
		name string
		op   func() error
		desc string
	}{
		{
			name: "WriteAt_block_boundary",
			op: func() error {
				data := []byte("MODIFIED_AT_BLOCK_BOUNDARY")
				_, err := dw.WriteAt(data, 16)
				return err
			},
			desc: "WriteAt at block boundary (pos=16)",
		},
		{
			name: "WriteAt_block_middle",
			op: func() error {
				data := []byte("MODIFIED_IN_MIDDLE")
				_, err := dw.WriteAt(data, 40)
				return err
			},
			desc: "WriteAt at block middle (pos=40)",
		},
		{
			name: "WriteAt_cross_boundary",
			op: func() error {
				data := []byte("CROSSING_BOUNDARY")
				_, err := dw.WriteAt(data, 15)
				return err
			},
			desc: "WriteAt crossing block boundary (pos=15)",
		},
		{
			name: "Seek_and_Write",
			op: func() error {
				_, err := dw.Seek(100, 0)
				if err != nil {
					return err
				}
				_, err = dw.Write([]byte("SEEK_AND_WRITE"))
				return err
			},
			desc: "Seek then Write",
		},
		{
			name: "Truncate_shrink",
			op: func() error {
				return dw.Truncate(200)
			},
			desc: "Truncate to shrink (256 -> 200)",
		},
		{
			name: "Truncate_expand",
			op: func() error {
				return dw.Truncate(300)
			},
			desc: "Truncate to expand (200 -> 300)",
		},
		{
			name: "Small_write",
			op: func() error {
				_, err := dw.WriteAt([]byte("X"), 50)
				return err
			},
			desc: "Write single byte",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			err := tc.op()
			if err != nil {
				t.Fatalf("Operation failed: %v", err)
			}

			// Verify integrity after operation
			if !verifyAndReport(t, tw, storeIo, dw, tc.desc, fmt.Sprintf("%s: integrity verified", tc.desc)) {
				return
			}
		})
	}

	t.Logf("Dual-writer integrity test passed: all operations verified")
}

// testBlockBoundaryOperations tests random operations with different data sizes
// to detect neighbor block corruption issues using dualWriter.
// AES uses 16-byte blocks, so we test:
// - Sizes smaller than block size: 1, 8, 15 bytes
// - Size equal to block size: 16 bytes
// - Sizes larger than block size: 17, 24, 31, 32, 48 bytes
// - Cross-block boundary sizes: 15, 17 bytes
func testBlockBoundaryOperations(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	// Create the chain: storeIo -> totalStoreIo -> baseStore
	// This allows tracking both per-step and cumulative storage operations
	baseStore := newMockReadWriterSeeker()
	totalStoreIo := newTrackerContext(baseStore) // Tracks total storage operations (never reset)
	storeIo := newTrackerContext(totalStoreIo)  // Tracks storage operations (reset per step)

	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	if err != nil {
		t.Fatalf("Failed to create context: %v", err)
	}
	defer ctx.Close()

	// Create dual writer for integrity verification
	dw := newDualWriter(ctx)

	// Wrap with trackerContext to track user-level operations
	tw := newTrackerContext(dw)

	// Create initial data (256 bytes = 16 blocks of 16 bytes each)
	initialSize := 256
	initialData := make([]byte, initialSize)
	for i := range initialData {
		initialData[i] = byte(i % 256)
	}

	// Write initial data using dualWriter
	_, err = tw.Write(initialData)
	if err != nil {
		t.Fatalf("Failed to write initial data: %v", err)
	}

	// Verify initial write
	if !verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Initial data written and verified: size=%d bytes", initialSize)) {
		return
	}

	// Test 1: Fixed position tests
	t.Run("FixedPositions", func(t *testing.T) {
		// Test data sizes: smaller than block, equal to block, larger than block
		testSizes := []int{
			1, 8, 15, // smaller than block size (16)
			16,         // equal to block size
			17, 24, 31, // larger than block size
			32, 48, 64, // multiple blocks
		}

		// Test positions: block boundary, block middle, cross-block boundary
		testPositions := []int{
			0, 16, 32, 64, // block boundaries
			8, 24, 40, 72, // block middle
			15, 31, 47, 79, // cross-block boundary
		}

		for _, size := range testSizes {
			for _, pos := range testPositions {
				if pos+size > initialSize {
					continue // skip if exceeds initial data size
				}

				// Create test data with unique pattern
				testData := make([]byte, size)
				for i := range testData {
					testData[i] = byte((pos + i) % 256)
				}

				// WriteAt at position using dualWriter
				n, err := tw.WriteAt(testData, int64(pos))
				if err != nil {
					t.Errorf("WriteAt size=%d pos=%d failed: %v", size, pos, err)
					continue
				}
				if n != size {
					t.Errorf("WriteAt size=%d pos=%d: expected %d bytes, got %d", size, pos, size, n)
					continue
				}

				// Verify integrity using dualWriter
				if !verifyAndReport(t, tw, storeIo, dw, fmt.Sprintf("size=%d pos=%d", size, pos), "") {
					continue
				}
			}
		}

		// Report I/O statistics after all fixed position tests
		reportAndReset(t, tw, storeIo, "After fixed positions tests")

		t.Logf("Fixed positions test passed: all sizes and positions verified")
	})

	t.Run("RandomStressTest", func(t *testing.T) {
		// Use fixed seed for reproducibility (set env SEED to override)
		seed := int64(42)
		if envSeed := os.Getenv("SEED"); envSeed != "" {
			if s, err := strconv.ParseInt(envSeed, 10, 64); err == nil {
				seed = s
			}
		}
		rand.Seed(seed)
		t.Logf("Using random seed: %d", seed)

		numStressTests := 200 // Reduced for performance
		maxDataSize := 512   // Reduced max size

		// Create cumulative tracker for the stress test
		// runFile tracks cumulative user operations (never reset)
		// totalStoreIo is created in testBlockBoundaryOperations (never reset)
		var runFile *trackerContext = newTrackerContext(tw)

		for i := 0; i < numStressTests; i++ {
			opType := rand.Intn(7) // 0-6: different operation types

			switch opType {
			case 0: // WriteAt: random position, random size, random data
				size := rand.Intn(maxDataSize) + 1
				pos := rand.Intn(maxDataSize)
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := runFile.WriteAt(testData, int64(pos))
				if err != nil {
					t.Errorf("Stress test %d: WriteAt size=%d pos=%d failed: %v", i, size, pos, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: WriteAt size=%d pos=%d: wrote %d bytes", i, size, pos, n)
				}

			case 1: // Seek + Write: random seek, then write random data
				seekPos := rand.Intn(maxDataSize)
				_, err := runFile.Seek(int64(seekPos), 0)
				if err != nil {
					t.Errorf("Stress test %d: Seek to %d failed: %v", i, seekPos, err)
					continue
				}

				size := rand.Intn(128) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := runFile.Write(testData)
				if err != nil {
					t.Errorf("Stress test %d: Write after Seek failed: %v", i, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: Write wrote %d bytes, expected %d", i, n, size)
				}

			case 2: // Truncate shrink: random smaller size
				currentSize := int(runFile.Size())
				if currentSize <= 0 {
					continue
				}
				newSize := rand.Intn(currentSize)
				err := runFile.Truncate(int64(newSize))
				if err != nil {
					t.Errorf("Stress test %d: Truncate shrink to %d failed: %v", i, newSize, err)
				}

			case 3: // Truncate expand: random larger size
				currentSize := int(runFile.Size())
				expandBy := rand.Intn(128) + 1 // Smaller expansion
				newSize := currentSize + expandBy
				err := runFile.Truncate(int64(newSize))
				if err != nil {
					t.Errorf("Stress test %d: Truncate expand to %d failed: %v", i, newSize, err)
				}

			case 4: // Write at current position
				size := rand.Intn(64) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := runFile.Write(testData)
				if err != nil {
					t.Errorf("Stress test %d: Write failed: %v", i, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: Write wrote %d bytes, expected %d", i, n, size)
				}

			case 5: // Random Read: seek to random position, then read random size
				currentSize := int(runFile.Size())
				if currentSize <= 0 {
					continue
				}

				// Random position
				pos := rand.Intn(currentSize)
				_, err := runFile.Seek(int64(pos), 0)
				if err != nil {
					t.Errorf("Stress test %d: Seek for Read failed: %v", i, err)
					continue
				}

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				_, err = runFile.Read(buf)
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: Read failed: %v", i, err)
					continue
				}

			case 6: // ReadAt: random position, random size
				currentSize := int(runFile.Size())
				if currentSize <= 0 {
					continue
				}

				// Random position (0 to currentSize-1)
				pos := rand.Intn(currentSize)

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				n, err := runFile.ReadAt(buf, int64(pos))
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: ReadAt failed: %v", i, err)
					continue
				}
				_ = n // Don't check exact bytes read, just track the operation
			}

			// Verify integrity after each operation (per-step statistics)
			// tw and storeIo are reset after each verification
			if !verifyAndReport(t, tw, storeIo, dw, fmt.Sprintf("Step %d (opType=%d)", i, opType), "") {
				break // Stop on first error
			}
		}

		// Final cumulative statistics (never reset)
		// runFile and totalStoreIo track total operations across all iterations
		if !verifyAndReport(t, runFile, totalStoreIo, dw, "Total", fmt.Sprintf("Random stress test passed: %d operations verified, final size=%d bytes", numStressTests, runFile.Size())) {
			return
		}
	})

	t.Logf("Block boundary operations test passed: fixed, random, and stress tests verified with dualWriter")
}

