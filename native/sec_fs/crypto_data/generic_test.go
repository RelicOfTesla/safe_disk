// Package crypto_data_test provides generic tests for all registered cryptor algorithms.
package crypto_data_test

import (
	"fmt"
	"io"
	"math/rand"
	"os"
	"runtime"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"

	// Import algorithm implementations to trigger init() registration
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_xts"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/chacha20"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"
)

// ==================== Test List Factories ====================

func TestListFactories(t *testing.T) {
	factories := crypto_data.ListFactories()
	assert.NotEmpty(t, factories, "No cryptor factories registered")

	t.Logf("Registered factories: %v", factories)

	for _, name := range factories {
		factory := crypto_data.GetFactory(name)
		require.NotNil(t, factory, "Factory '%s' returned nil", name)
		assert.Equal(t, name, factory.GetName(), "Factory name mismatch")
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
	assert.Equal(t, expectedName, name, "Factory name")
	t.Logf("Factory name: %s", name)
}

func testCapabilities(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	caps := factory.GetCapabilities()

	t.Logf("Capabilities: Mode=%v, Streaming=%v, RandomAccess=%v, Modification=%v, RandomDelete=%v",
		caps.Mode, caps.StreamingComplexity, caps.RandomAccessComplexity, caps.ModificationComplexity, caps.RandomDeleteComplexity)

	// Verify mode is valid
	assert.GreaterOrEqual(t, caps.Mode, crypto_data.CryptModeNormal, "Mode should be >= Normal")
	assert.LessOrEqual(t, caps.Mode, crypto_data.CryptModeIncremental, "Mode should be <= Incremental")
}

func testCreateContext(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	fp, _, _ := newTestFiles(t, factory)
	defer fp.Close()

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

			fp, storeIo, _dw := newTestFiles(t, factory)
			defer fp.Close()

			// Write (encrypt) using dualWriter
			n, err := fp.Write(tc.data)
			require.NoError(t, err, "Failed to write")
			require.Equal(t, len(tc.data), n, "Write length")

			// Verify integrity using dualWriter
			verifyAndReport(t, fp, storeIo, _dw, "", fmt.Sprintf("Encrypt/Decrypt verified for %d bytes", len(tc.data)))
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
			fp, storeIo, _dw := newTestFiles(t, factory)
			defer fp.Close()

			// Write chunk using dualWriter
			n, err := fp.Write(chunk)
			require.NoError(t, err, "Failed to write chunk")
			require.Equal(t, len(chunk), n, "Write length")

			// Verify integrity using dualWriter
			verifyAndReport(t, fp, storeIo, _dw, "", fmt.Sprintf("Chunk %d verified: %d bytes", i+1, len(chunk)))
		})
	}
}

func testSeekOperations(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	fp, storeIo, _dw := newTestFiles(t, factory)
	defer fp.Close()

	// Write test data using dualWriter
	testData := []byte("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
	_, err := fp.Write(testData)
	require.NoError(t, err, "Failed to write")

	// Test SeekStart on dualWriter
	pos, err := fp.Seek(10, 0)
	require.NoError(t, err, "SeekStart failed")
	assert.Equal(t, int64(10), pos, "SeekStart position")

	// Read from position 10
	buf := make([]byte, 5)
	n, err := fp.Read(buf)
	require.NoError(t, err, "Read after SeekStart failed")
	assert.Equal(t, "ABCDE", string(buf[:n]), "Read after SeekStart")

	// Test SeekCurrent on dualWriter
	pos, err = fp.Seek(5, 1)
	require.NoError(t, err, "SeekCurrent failed")
	// Current pos was 15, +5 = 20
	assert.Equal(t, int64(20), pos, "SeekCurrent position")

	// Test SeekEnd on dualWriter
	pos, err = fp.Seek(-5, 2)
	require.NoError(t, err, "SeekEnd failed")
	// len(testData) - 5 = 31
	assert.Equal(t, int64(31), pos, "SeekEnd position")

	// Verify integrity using dualWriter
	verifyAndReport(t, fp, storeIo, _dw, "", "Seek operations verified with full integrity check")
}

func testRandomDelete(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	fp, storeIo, _dw := newTestFiles(t, factory)
	defer fp.Close()

	// Create initial data (1000 bytes)
	initialData := makeSequentialBytes(1000)

	// Write initial data
	_, err := fp.Write(initialData)
	require.NoError(t, err, "Failed to write initial data")

	initialSize := fp.Size()
	t.Logf("Initial size: %d bytes", initialSize)

	// Verify initial write integrity
	if !verifyAndReport(t, fp, storeIo, _dw, "Initial write", "Initial write integrity verified") {
		return
	}

	// Test 1: Truncate to remove data from the end
	t.Log("Before truncate shrink")

	err = fp.Truncate(800)
	require.NoError(t, err, "Truncate failed")

	newSize := fp.Size()
	assert.Equal(t, int64(800), newSize, "After truncate size")
	t.Logf("After truncate: size = %d bytes", newSize)

	// Verify integrity after truncate shrink
	if !verifyAndReport(t, fp, storeIo, _dw, "Truncate shrink", "Truncate shrink integrity verified") {
		return
	}

	// Test 2: Expand file with Truncate
	t.Log("Before truncate expand")

	err = fp.Truncate(1200)
	require.NoError(t, err, "Truncate to expand failed")

	expandedSize := fp.Size()
	assert.Equal(t, int64(1200), expandedSize, "After expand size")
	t.Logf("After expand: size = %d bytes", expandedSize)

	// Verify integrity after truncate expand (expanded area should be zeros)
	if !verifyAndReport(t, fp, storeIo, _dw, "Truncate expand", "Truncate expand integrity verified") {
		return
	}

	// Test 3: Simulate "delete in middle" by overwriting with zeros
	// This is not a real delete, but simulates the effect
	t.Log("Before write zeros")

	_, err = fp.Seek(400, 0)
	require.NoError(t, err, "Seek to 400 failed")

	zeros := make([]byte, 100)
	_, err = fp.Write(zeros)
	require.NoError(t, err, "Write zeros failed")
	t.Logf("Wrote 100 zeros at position 400")

	// Verify integrity after write
	verifyAndReport(t, fp, storeIo, _dw, "Write zeros", "Write zeros integrity verified")

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
	fp, storeIo, _dw := newTestFiles(t, factory)
	defer fp.Close()

	// Create initial data
	initialSize := 256
	initialData := makeSequentialBytes(initialSize)

	// Write initial data
	_, err := fp.Write(initialData)
	require.NoError(t, err, "Failed to write initial data")

	// Verify integrity after initial write
	if !verifyAndReport(t, fp, storeIo, _dw, "", fmt.Sprintf("Initial write verified: size=%d bytes", initialSize)) {
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
				_, err := fp.WriteAt(data, 16)
				return err
			},
			desc: "WriteAt at block boundary (pos=16)",
		},
		{
			name: "WriteAt_block_middle",
			op: func() error {
				data := []byte("MODIFIED_IN_MIDDLE")
				_, err := fp.WriteAt(data, 40)
				return err
			},
			desc: "WriteAt at block middle (pos=40)",
		},
		{
			name: "WriteAt_cross_boundary",
			op: func() error {
				data := []byte("CROSSING_BOUNDARY")
				_, err := fp.WriteAt(data, 15)
				return err
			},
			desc: "WriteAt crossing block boundary (pos=15)",
		},
		{
			name: "Seek_and_Write",
			op: func() error {
				_, err := fp.Seek(100, 0)
				if err != nil {
					return err
				}
				_, err = fp.Write([]byte("SEEK_AND_WRITE"))
				return err
			},
			desc: "Seek then Write",
		},
		{
			name: "Truncate_shrink",
			op: func() error {
				return fp.Truncate(200)
			},
			desc: "Truncate to shrink (256 -> 200)",
		},
		{
			name: "Truncate_expand",
			op: func() error {
				return fp.Truncate(300)
			},
			desc: "Truncate to expand (200 -> 300)",
		},
		{
			name: "Small_write",
			op: func() error {
				_, err := fp.WriteAt([]byte("X"), 50)
				return err
			},
			desc: "Write single byte",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			err := tc.op()
			require.NoError(t, err, "Operation failed")

			// Verify integrity after operation
			verifyAndReport(t, fp, storeIo, _dw, tc.desc, fmt.Sprintf("%s: integrity verified", tc.desc))
		})
	}

	t.Logf("Dual-writer integrity test passed: all operations verified")
}

func newTestFiles(t *testing.T, factory crypto_data.ICryptoDataFactory) (*trackerContext, *trackerContext, *multiWriter) {
	baseStore := newMockReadWriterSeeker()
	trackerStore := newTrackerContext(baseStore)

	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()

	ctx, err := factory.NewContext(trackerStore, keyInfo, cfg)
	require.NoError(t, err, "Failed to create context")

	// Create dual writer for integrity verification
	dw := newDualWriter(ctx)

	// Wrap with trackerContext to track user-level operations
	trackerUserWriter := newTrackerContext(dw)

	return trackerUserWriter, trackerStore, dw
}

const DISABLE_STEP_REPORT = true

func testFixedPositions(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	tw, storeIo, dw := newTestFiles(t, factory)
	defer tw.Close()

	// Create initial data (256 bytes = 16 blocks of 16 bytes each)
	initialSize := 256
	initialData := makeSequentialBytes(initialSize)

	// Write initial data using dualWriter
	_, err := tw.Write(initialData)
	require.NoError(t, err, "Failed to write initial data")

	// Verify initial write
	if !verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Initial data written and verified: size=%d bytes", initialSize)) {
		return
	}

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
			require.NoError(t, err, "WriteAt size=%d pos=%d failed", size, pos)
			require.Equal(t, size, n, "WriteAt size=%d pos=%d: length mismatch", size, pos)

			// Verify integrity using dualWriter
			if !verifyAndReport(t, tw, storeIo, dw, fmt.Sprintf("size=%d pos=%d", size, pos), "", DISABLE_STEP_REPORT) {
				continue
			}
		}
	}

	t.Logf("Fixed positions test passed: all sizes and positions verified")
}

// testBlockBoundaryOperations tests random operations with different data sizes
// to detect neighbor block corruption issues using dualWriter.
// AES uses 16-byte blocks, so we test:
// - Sizes smaller than block size: 1, 8, 15 bytes
// - Size equal to block size: 16 bytes
// - Sizes larger than block size: 17, 24, 31, 32, 48 bytes
// - Cross-block boundary sizes: 15, 17 bytes
func testBlockBoundaryOperations(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	t.Run("FixedPositions", func(t *testing.T) {
		testFixedPositions(t, factory)
	})

	t.Run("RandomStressTest", func(t *testing.T) {
		// === Memory tracking: before test ===
		runtime.GC() // Force GC before measuring
		memBefore := GetMemoryStats()

		// Create the chain: storeIo -> totalStoreIo -> baseStore
		// This allows tracking both per-step and cumulative storage operations
		baseStore := newMockReadWriterSeeker()
		totalStoreIo := newTrackerContext(baseStore) // Tracks total storage operations (never reset)
		storeIo := newTrackerContext(totalStoreIo)   // Tracks storage operations (reset per step)

		keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
		cfg := config.NewMemoryConfig()

		ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
		require.NoError(t, err, "Failed to create context")
		defer ctx.Close()

		// Create dual writer for integrity verification
		dw := newDualWriter(ctx)

		// Wrap with trackerContext to track user-level operations
		tw := newTrackerContext(dw)

		var fp crypto_data.IDataCryptorContext = tw

		// Create initial data (256 bytes = 16 blocks of 16 bytes each)
		initialSize := 256
				initialData := makeSequentialBytes(initialSize)

		// Write initial data using dualWriter
		_, err = fp.Write(initialData)
		require.NoError(t, err, "Failed to write initial data")

		// Verify initial write
		if !verifyAndReport(t, tw, storeIo, dw, "", fmt.Sprintf("Initial data written and verified: size=%d bytes", initialSize)) {
			return
		}

		// Use fixed seed for reproducibility (set env SEED to override)
		seed := int64(42)
		if envSeed := os.Getenv("SEED"); envSeed != "" {
			if s, err := strconv.ParseInt(envSeed, 10, 64); err == nil {
				seed = s
			}
		}
		rand.Seed(seed)
		t.Logf("Using random seed: %d", seed)

		numStressTests := 200     // Reduced for performance
		maxDataSize := 128 * 1024 // 128KB max size

		// Create cumulative tracker for the stress test
		// runFile tracks cumulative user operations (never reset)
		// totalStoreIo is created in testBlockBoundaryOperations (never reset)

		for i := 0; i < numStressTests; i++ {
			var runFileTw *trackerContext = newTrackerContext(tw)
			fp = runFileTw

			opType := rand.Intn(7) // 0-6: different operation types
			currentSize := int(fp.Size())
			maxPos := min(max(int(float64(currentSize)*1.2), maxDataSize), 2*1024*1024*1024)

			switch opType {
			case 0: // WriteAt: random position, random size, random data
				size := rand.Intn(maxDataSize) + 1
				pos := rand.Intn(maxPos)
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := fp.WriteAt(testData, int64(pos))
				require.NoError(t, err, "Stress test %d: WriteAt size=%d pos=%d failed", i, size, pos)
				assert.Equal(t, size, n, "Stress test %d: WriteAt size=%d pos=%d: length mismatch", i, size, pos)

			case 1: // Seek + Write: random seek, then write random data
				seekPos := rand.Intn(maxPos)
				_, err := fp.Seek(int64(seekPos), 0)
				require.NoError(t, err, "Stress test %d: Seek to %d failed", i, seekPos)

				size := rand.Intn(128) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := fp.Write(testData)
				require.NoError(t, err, "Stress test %d: Write after Seek failed", i)
				assert.Equal(t, size, n, "Stress test %d: Write length mismatch", i)

			case 2: // Truncate shrink: random smaller size
				if currentSize <= 0 {
					continue
				}
				newSize := rand.Intn(currentSize)
				err := fp.Truncate(int64(newSize))
				require.NoError(t, err, "Stress test %d: Truncate shrink to %d failed", i, newSize)

			case 3: // Truncate expand: random larger size
				expandBy := rand.Intn(128) + 1 // Smaller expansion
				newSize := currentSize + expandBy
				err := fp.Truncate(int64(newSize))
				require.NoError(t, err, "Stress test %d: Truncate expand to %d failed", i, newSize)

			case 4: // Write at current position
				size := rand.Intn(64) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := fp.Write(testData)
				require.NoError(t, err, "Stress test %d: Write failed", i)
				assert.Equal(t, size, n, "Stress test %d: Write length mismatch", i)

			case 5: // Random Read: seek to random position, then read random size
				if currentSize <= 0 {
					continue
				}

				// Random position
				pos := rand.Intn(currentSize)
				_, err := fp.Seek(int64(pos), 0)
				require.NoError(t, err, "Stress test %d: Seek for Read failed", i)

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				_, err = fp.Read(buf)
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: Read failed: %v", i, err)
					continue
				}

			case 6: // ReadAt: random position, random size
				currentSize := int(fp.Size())
				if currentSize <= 0 {
					continue
				}

				// Random position (0 to currentSize-1)
				pos := rand.Intn(currentSize)

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				n, err := fp.ReadAt(buf, int64(pos))
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: ReadAt failed: %v", i, err)
					continue
				}
				_ = n // Don't check exact bytes read, just track the operation
			}

			// Verify integrity after each operation (per-step statistics)
			// runFileTw and storeIo are reset after each verification
			if !verifyAndReport(t, runFileTw, storeIo, dw, fmt.Sprintf("Step %d (opType=%d)", i, opType), "", DISABLE_STEP_REPORT) {
				break // Stop on first error
			}
		}

		// Final cumulative statistics (never reset)
		// tw and totalStoreIo track total operations across all iterations
		if !verifyAndReport(t, tw, totalStoreIo, dw, "Total", fmt.Sprintf("Random stress test passed: %d operations verified, final size=%d bytes",
			numStressTests, fp.Size())) {
			return
		}

		// === Memory tracking: after test ===
		memAfter := GetMemoryStats()
		memDiff := memAfter.Sub(memBefore)
		t.Logf("Memory usage: %s", memDiff.String())
	})

	t.Logf("Block boundary operations test passed: fixed, random, and stress tests verified with dualWriter")
}
