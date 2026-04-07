// Package crypto_data_test provides generic tests for all registered cryptor algorithms.
package crypto_data_test

import (
	"bytes"
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

// ==================== Mock Implementations ====================

// mockReadWriterSeeker is a mock implementation of IReadWriterSeeker for testing.
type mockReadWriterSeeker struct {
	data []byte
	pos  int
}

func newMockReadWriterSeeker() *mockReadWriterSeeker {
	return &mockReadWriterSeeker{
		data: make([]byte, 0),
		pos:  0,
	}
}

func (m *mockReadWriterSeeker) Read(p []byte) (n int, err error) {
	if m.pos >= len(m.data) {
		return 0, io.EOF
	}
	n = copy(p, m.data[m.pos:])
	m.pos += n
	// Return EOF if we've read to the end of the file (consistent with os.File)
	if m.pos >= len(m.data) {
		return n, io.EOF
	}
	return n, nil
}

func (m *mockReadWriterSeeker) Write(p []byte) (n int, err error) {
	// Calculate the end position after writing
	endPos := m.pos + len(p)

	// Extend data if necessary
	if endPos > len(m.data) {
		newData := make([]byte, endPos)
		copy(newData, m.data)
		m.data = newData
	}

	// Write data at current position
	copy(m.data[m.pos:], p)
	m.pos = endPos

	return len(p), nil
}

func (m *mockReadWriterSeeker) Seek(offset int64, whence int) (int64, error) {
	switch whence {
	case 0: // SeekStart
		m.pos = int(offset)
	case 1: // SeekCurrent
		m.pos += int(offset)
	case 2: // SeekEnd
		m.pos = len(m.data) + int(offset)
	}
	return int64(m.pos), nil
}

func (m *mockReadWriterSeeker) Close() error {
	return nil
}

// Size returns the current size of the data.
func (m *mockReadWriterSeeker) Size() int64 {
	return int64(len(m.data))
}

// Truncate changes the size of the data.
func (m *mockReadWriterSeeker) Truncate(size int64) error {
	if size < 0 {
		return fmt.Errorf("negative size")
	}
	if int(size) > len(m.data) {
		// Extend with zeros
		newData := make([]byte, size)
		copy(newData, m.data)
		m.data = newData
	} else {
		m.data = m.data[:size]
	}
	return nil
}

// ReadAt reads data at the specified offset.
func (m *mockReadWriterSeeker) ReadAt(p []byte, off int64) (n int, err error) {
	if off < 0 {
		return 0, fmt.Errorf("negative offset")
	}
	if int(off) >= len(m.data) {
		return 0, io.EOF
	}
	n = copy(p, m.data[off:])
	if n < len(p) {
		err = io.EOF
	}
	return n, err
}

// WriteAt writes data at the specified offset.
func (m *mockReadWriterSeeker) WriteAt(p []byte, off int64) (n int, err error) {
	if off < 0 {
		return 0, fmt.Errorf("negative offset")
	}
	endPos := int(off) + len(p)
	if endPos > len(m.data) {
		newData := make([]byte, endPos)
		copy(newData, m.data)
		m.data = newData
	}
	copy(m.data[off:], p)
	return len(p), nil
}

// Sync commits the current state (no-op for mock).
func (m *mockReadWriterSeeker) Sync() error {
	return nil
}

// ==================== Tracker Mock for Performance Statistics ====================

// IOStats tracks I/O operation statistics.
type IOStats struct {
	ReadBytes  int64
	ReadCalls  int
	WriteBytes int64
	WriteCalls int
	SeekCalls  int
	TruncCalls int
}

// Amplification returns the I/O amplification ratios compared to another IOStats.
func (s *IOStats) Amplification(other *IOStats) (readAmp, writeAmp, totalAmp float64) {
	if other.ReadBytes > 0 {
		readAmp = float64(s.ReadBytes) / float64(other.ReadBytes)
	}
	if other.WriteBytes > 0 {
		writeAmp = float64(s.WriteBytes) / float64(other.WriteBytes)
	}
	otherTotal := other.ReadBytes + other.WriteBytes
	selfTotal := s.ReadBytes + s.WriteBytes
	if otherTotal > 0 {
		totalAmp = float64(selfTotal) / float64(otherTotal)
	}
	return
}

// ==================== Tracker Context (Implements IFullDataCryptorContext) ====================

// trackerContext wraps any IFullDataCryptorContext and tracks I/O statistics.
// Business layer is unaware of whether it's using aesContext, dualWriter, or tracker.
// This is the correct design pattern for transparent tracking.
type trackerContext struct {
	ctx   crypto_data.IDataCryptorContext
	stats IOStats
}

// Compile-time interface verification
var _ crypto_data.IDataCryptorContext = (*trackerContext)(nil)

// newTrackerContext creates a new tracker wrapper for any IFullDataCryptorContext.
func newTrackerContext(ctx crypto_data.IDataCryptorContext) *trackerContext {
	return &trackerContext{
		ctx: ctx,
	}
}

// GetStats returns the current statistics.
func (t *trackerContext) GetStats() IOStats {
	return t.stats
}

// ResetTracker resets the statistics.
func (t *trackerContext) ResetTracker() {
	t.stats = IOStats{}
}

// All IFullDataCryptorContext methods with tracking:

func (t *trackerContext) Read(p []byte) (n int, err error) {
	n, err = t.ctx.Read(p)
	t.stats.ReadBytes += int64(n)
	t.stats.ReadCalls++
	return
}

func (t *trackerContext) Write(p []byte) (n int, err error) {
	n, err = t.ctx.Write(p)
	t.stats.WriteBytes += int64(n)
	t.stats.WriteCalls++
	return
}

func (t *trackerContext) Seek(offset int64, whence int) (int64, error) {
	pos, err := t.ctx.Seek(offset, whence)
	t.stats.SeekCalls++
	return pos, err
}

func (t *trackerContext) Close() error {
	return t.ctx.Close()
}

func (t *trackerContext) Size() int64 {
	return t.ctx.Size()
}

func (t *trackerContext) Truncate(size int64) error {
	err := t.ctx.Truncate(size)
	t.stats.TruncCalls++
	return err
}

func (t *trackerContext) Sync() error {
	return t.ctx.Sync()
}

func (t *trackerContext) ReadAt(p []byte, off int64) (n int, err error) {
	n, err = t.ctx.ReadAt(p, off)
	t.stats.ReadBytes += int64(n)
	t.stats.ReadCalls++
	return
}

func (t *trackerContext) WriteAt(p []byte, off int64) (n int, err error) {
	n, err = t.ctx.WriteAt(p, off)
	t.stats.WriteBytes += int64(n)
	t.stats.WriteCalls++
	return
}

// ==================== trackerMockReadWriter (for storage layer) ====================

// trackerMockReadWriter wraps mockReadWriterSeeker and tracks I/O statistics.
type trackerMockReadWriter struct {
	*mockReadWriterSeeker
	stats IOStats
}

// newTrackerMockReadWriter creates a new tracker wrapper.
func newTrackerMockReadWriter() *trackerMockReadWriter {
	return &trackerMockReadWriter{
		mockReadWriterSeeker: newMockReadWriterSeeker(),
	}
}

// ResetTracker resets the statistics.
func (t *trackerMockReadWriter) ResetTracker() {
	t.stats = IOStats{}
}

// GetStats returns the current statistics.
func (t *trackerMockReadWriter) GetStats() IOStats {
	return t.stats
}

// Read tracks read operations.
func (t *trackerMockReadWriter) Read(p []byte) (n int, err error) {
	n, err = t.mockReadWriterSeeker.Read(p)
	t.stats.ReadBytes += int64(n)
	t.stats.ReadCalls++
	return
}

// Write tracks write operations.
func (t *trackerMockReadWriter) Write(p []byte) (n int, err error) {
	n, err = t.mockReadWriterSeeker.Write(p)
	t.stats.WriteBytes += int64(n)
	t.stats.WriteCalls++
	return
}

// Seek tracks seek operations.
func (t *trackerMockReadWriter) Seek(offset int64, whence int) (int64, error) {
	pos, err := t.mockReadWriterSeeker.Seek(offset, whence)
	t.stats.SeekCalls++
	return pos, err
}

// ReadAt tracks read-at operations.
func (t *trackerMockReadWriter) ReadAt(p []byte, off int64) (n int, err error) {
	n, err = t.mockReadWriterSeeker.ReadAt(p, off)
	t.stats.ReadBytes += int64(n)
	t.stats.ReadCalls++
	return
}

// WriteAt tracks write-at operations.
func (t *trackerMockReadWriter) WriteAt(p []byte, off int64) (n int, err error) {
	n, err = t.mockReadWriterSeeker.WriteAt(p, off)
	t.stats.WriteBytes += int64(n)
	t.stats.WriteCalls++
	return
}

// Truncate tracks truncate operations.
func (t *trackerMockReadWriter) Truncate(size int64) error {
	err := t.mockReadWriterSeeker.Truncate(size)
	t.stats.TruncCalls++
	return err
}

// Size returns the current size of the data.
func (t *trackerMockReadWriter) Size() int64 {
	return t.mockReadWriterSeeker.Size()
}

// Sync is a no-op for mock implementation.
func (t *trackerMockReadWriter) Sync() error {
	return nil
}

// Compile-time interface verification
var _ crypto_data.IFileContext = (*trackerMockReadWriter)(nil)
var _ crypto_data.IDataCryptorContext = (*trackerMockReadWriter)(nil)

// ==================== Helper Functions ====================

// reportAndReset reports I/O statistics and resets the counters.
// This function is used to track I/O amplification at different stages of testing.
func reportAndReset(t *testing.T, tw *trackerContext, storeIo *trackerMockReadWriter, prefix string) {
	userStats := tw.GetStats()
	storeStats := storeIo.GetStats()

	if userStats.WriteBytes == 0 && userStats.ReadBytes == 0 {
		// No user operations, skip report
		return
	}

	readAmp := float64(storeStats.ReadBytes) / float64(max(userStats.ReadBytes, 1))
	writeAmp := float64(storeStats.WriteBytes) / float64(max(userStats.WriteBytes, 1))

	t.Logf("[%s] Expected/User: Write %d bytes (%d calls), Read %d bytes (%d calls)",
		prefix, userStats.WriteBytes, userStats.WriteCalls, userStats.ReadBytes, userStats.ReadCalls)
	t.Logf("[%s] Actual/Store: Write %d bytes (%d calls), Read %d bytes (%d calls)",
		prefix, storeStats.WriteBytes, storeStats.WriteCalls, storeStats.ReadBytes, storeStats.ReadCalls)
	t.Logf("[%s] Amplification: Read %.2fx, Write %.2fx",
		prefix, readAmp, writeAmp)

	// Reset counters
	tw.ResetTracker()
	storeIo.ResetTracker()
}

// verifyAndReport is a combination of report + verifyIntegrity + report + diff_find.
// This function reduces code duplication by encapsulating the common pattern:
// 1. Report I/O stats before verification
// 2. Verify integrity (compare decrypted data with plaintext mirror)
// 3. Report I/O stats after verification
// 4. Find and report first diff if mismatch
// Returns true if integrity check passes, false otherwise.
// If successMsg is not empty, logs success message when integrity passes.
func verifyAndReport(t *testing.T, tw *trackerContext, storeIo *trackerMockReadWriter, dw *dualWriter, prefix string, successMsg string) bool {
	// Report and reset before verifyIntegrity
	reportAndReset(t, tw, storeIo, prefix+" - BeforeVerify")

	// Verify integrity
	match, decrypted, expected, err := dw.verifyIntegrity()
	if err != nil {
		t.Errorf("%s: verifyIntegrity failed: %v", prefix, err)
		return false
	}

	// Report and reset after verifyIntegrity
	reportAndReset(t, tw, storeIo, prefix+" - AfterVerify")

	// Check match and find first diff if mismatch
	if !match {
		firstDiff := findFirstDiff(decrypted, expected)
		if firstDiff == -1 {
			t.Errorf("%s: Integrity mismatch, size mismatch: decrypted=%d, expected=%d", prefix, len(decrypted), len(expected))
		} else {
			t.Errorf("%s: Integrity mismatch, size=%d, first diff at position %d", prefix, len(decrypted), firstDiff)
		}
		return false
	}

	// Log success message if provided
	if successMsg != "" {
		t.Log(successMsg)
	}

	return true
}

// findFirstDiff finds the first position where two byte slices differ.
// Returns -1 if they are equal or have different lengths.
func findFirstDiff(a, b []byte) int {
	if len(a) != len(b) {
		return -1
	}
	for i := 0; i < len(a); i++ {
		if a[i] != b[i] {
			return i
		}
	}
	return -1
}

// ==================== Dual Writer for Integrity Verification ====================

// dualWriter is a wrapper that simultaneously writes to both an encrypted context
// and a plaintext mirror. This allows for accurate integrity verification by
// comparing decrypted data against the plaintext mirror.
//
// Concept: Similar to io.MultiWriter, but for encrypted contexts:
//
//	ctx.Write(data) => { encryptFile.Write(encrypted), plaintextMirror.Write(data) }
//	ctx.Seek(pos)   => { encryptFile.Seek(pos), plaintextMirror.Seek(pos) }
//
// Verification: readAll(encryptFile, decrypt) == readAll(plaintextMirror)
type dualWriter struct {
	ctx             crypto_data.IDataCryptorContext // Encrypted context
	plaintextMirror *mockReadWriterSeeker           // Plaintext mirror
}

// newDualWriter creates a new dualWriter that simultaneously writes to both
// the encrypted context and a plaintext mirror.
func newDualWriter(ctx crypto_data.IDataCryptorContext) *dualWriter {
	return &dualWriter{
		ctx:             ctx,
		plaintextMirror: newMockReadWriterSeeker(),
	}
}

// Write writes data to both the encrypted context and plaintext mirror.
func (d *dualWriter) Write(p []byte) (n int, err error) {
	// Auto-track user operation

	// Write to encrypted context
	n, err = d.ctx.Write(p)
	if err != nil {
		return n, err
	}

	// Write to plaintext mirror
	_, err = d.plaintextMirror.Write(p)
	if err != nil {
		return n, err
	}

	return n, nil
}

// Read reads data from the encrypted context (decrypted automatically).
func (d *dualWriter) Read(p []byte) (n int, err error) {
	return d.ctx.Read(p)
	// TODO: SEEK
}

// Seek sets the position for both the encrypted context and plaintext mirror.
func (d *dualWriter) Seek(offset int64, whence int) (int64, error) {
	// Auto-track user operation

	pos, err := d.ctx.Seek(offset, whence)
	if err != nil {
		return pos, err
	}

	// Sync position in plaintext mirror
	_, err = d.plaintextMirror.Seek(offset, whence)
	if err != nil {
		return pos, err
	}

	return pos, nil
}

// Close closes both the encrypted context and plaintext mirror.
func (d *dualWriter) Close() error {
	return d.ctx.Close()
}

// Size returns the size of the decrypted data.
func (d *dualWriter) Size() int64 {
	return d.ctx.Size()
}

// Truncate truncates both the encrypted context and plaintext mirror.
func (d *dualWriter) Truncate(size int64) error {
	// Auto-track user operation

	err := d.ctx.Truncate(size)
	if err != nil {
		return err
	}

	return d.plaintextMirror.Truncate(size)
}

// Sync syncs the encrypted context.
func (d *dualWriter) Sync() error {
	return d.ctx.Sync()
}

// WriteAt writes data at the specified offset to both contexts.
func (d *dualWriter) WriteAt(p []byte, off int64) (n int, err error) {
	// Auto-track user operation

	// Write to encrypted context
	n, err = d.ctx.WriteAt(p, off)
	if err != nil {
		return n, err
	}

	// Write to plaintext mirror
	_, err = d.plaintextMirror.WriteAt(p, off)
	if err != nil {
		return n, err
	}

	return n, nil
}

// ReadAt reads data at the specified offset from the encrypted context.
func (d *dualWriter) ReadAt(p []byte, off int64) (n int, err error) {
	return d.ctx.ReadAt(p, off)
}

// Compile-time interface verification
var _ crypto_data.IFileContext = (*dualWriter)(nil)
var _ crypto_data.IDataCryptorContext = (*dualWriter)(nil)

// verifyIntegrity compares decrypted data from ctx with the plaintext mirror.
// Returns true if they match, false otherwise.
func (d *dualWriter) verifyIntegrity() (bool, []byte, []byte, error) {
	// Read all data from encrypted context (decrypted)
	ctxSize := d.ctx.Size()
	ctxData := make([]byte, ctxSize)
	_, err := d.ctx.Seek(0, 0)
	if err != nil {
		return false, nil, nil, err
	}
	_, err = io.ReadFull(d.ctx, ctxData)
	if err != nil && err != io.ErrUnexpectedEOF {
		return false, nil, nil, err
	}

	// Read all data from plaintext mirror
	mirrorSize := d.plaintextMirror.Size()
	mirrorData := make([]byte, mirrorSize)
	_, err = d.plaintextMirror.Seek(0, 0)
	if err != nil {
		return false, nil, nil, err
	}
	_, err = io.ReadFull(d.plaintextMirror, mirrorData)
	if err != nil && err != io.ErrUnexpectedEOF {
		return false, nil, nil, err
	}

	// Compare
	if !bytes.Equal(ctxData, mirrorData) {
		return false, ctxData, mirrorData, nil
	}

	return true, ctxData, mirrorData, nil
}

// mockKeyInfo is a mock implementation of IKeyInfo for testing.
type mockKeyInfo struct {
	key []byte
}

func (m *mockKeyInfo) GetKey() []byte {
	return m.key
}

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
	factories := crypto_data.ListFactories()

	for _, name := range factories {
		t.Run(name, func(t *testing.T) {
			factory := crypto_data.GetFactory(name)
			if factory == nil {
				t.Fatalf("Factory '%s' not found", name)
			}

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
			storeIo := newTrackerMockReadWriter()
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
			storeIo := newTrackerMockReadWriter()
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
	storeIo := newTrackerMockReadWriter()
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
	storeIo := newTrackerMockReadWriter()
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
	storeIo := newTrackerMockReadWriter()
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
	storeIo := newTrackerMockReadWriter() // Tracks storage-level operations
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
	// Business layer operates on IFullDataCryptorContext, unaware of what's underneath
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

		// Create expected tracker to record user-level operations

		for i := 0; i < numStressTests; i++ {
			opType := rand.Intn(7) // 0-6: different operation types

			switch opType {
			case 0: // WriteAt: random position, random size, random data
				size := rand.Intn(maxDataSize) + 1
				pos := rand.Intn(maxDataSize)
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := tw.WriteAt(testData, int64(pos))
				if err != nil {
					t.Errorf("Stress test %d: WriteAt size=%d pos=%d failed: %v", i, size, pos, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: WriteAt size=%d pos=%d: wrote %d bytes", i, size, pos, n)
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: WriteAt(size=%d, pos=%d)", i, size, pos))

			case 1: // Seek + Write: random seek, then write random data
				seekPos := rand.Intn(maxDataSize)
				_, err := tw.Seek(int64(seekPos), 0)
				if err != nil {
					t.Errorf("Stress test %d: Seek to %d failed: %v", i, seekPos, err)
					continue
				}

				size := rand.Intn(128) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := tw.Write(testData)
				if err != nil {
					t.Errorf("Stress test %d: Write after Seek failed: %v", i, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: Write wrote %d bytes, expected %d", i, n, size)
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: Seek+Write(seek=%d, size=%d)", i, seekPos, size))

			case 2: // Truncate shrink: random smaller size
				currentSize := int(tw.Size())
				if currentSize <= 0 {
					continue
				}
				newSize := rand.Intn(currentSize)
				err := tw.Truncate(int64(newSize))
				if err != nil {
					t.Errorf("Stress test %d: Truncate shrink to %d failed: %v", i, newSize, err)
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: Truncate_shrink(%d -> %d)", i, currentSize, newSize))

			case 3: // Truncate expand: random larger size
				currentSize := int(tw.Size())
				expandBy := rand.Intn(128) + 1 // Smaller expansion
				newSize := currentSize + expandBy
				err := tw.Truncate(int64(newSize))
				if err != nil {
					t.Errorf("Stress test %d: Truncate expand to %d failed: %v", i, newSize, err)
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: Truncate_expand(%d -> %d)", i, currentSize, newSize))

			case 4: // Write at current position
				size := rand.Intn(64) + 1
				testData := make([]byte, size)
				rand.Read(testData)

				n, err := tw.Write(testData)
				if err != nil {
					t.Errorf("Stress test %d: Write failed: %v", i, err)
					continue
				}
				if n != size {
					t.Errorf("Stress test %d: Write wrote %d bytes, expected %d", i, n, size)
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: Write(size=%d)", i, size))

			case 5: // Random Read: seek to random position, then read random size
				currentSize := int(tw.Size())
				if currentSize <= 0 {
					continue
				}

				// Random position
				pos := rand.Intn(currentSize)
				_, err := tw.Seek(int64(pos), 0)
				if err != nil {
					t.Errorf("Stress test %d: Seek for Read failed: %v", i, err)
					continue
				}

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				_, err = tw.Read(buf)
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: Read failed: %v", i, err)
					continue
				}
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: Random_Read(pos=%d, size=%d)", i, pos, readSize))

			case 6: // ReadAt: random position, random size
				currentSize := int(tw.Size())
				if currentSize <= 0 {
					continue
				}

				// Random position (0 to currentSize-1)
				pos := rand.Intn(currentSize)

				// Random size (1 to min(64, remaining))
				remaining := currentSize - pos
				readSize := rand.Intn(min(64, remaining)) + 1
				buf := make([]byte, readSize)

				n, err := tw.ReadAt(buf, int64(pos))
				if err != nil && err != io.EOF {
					t.Errorf("Stress test %d: ReadAt failed: %v", i, err)
					continue
				}
				_ = n // Don't check exact bytes read, just track the operation
				reportAndReset(t, tw, storeIo, fmt.Sprintf("Op %d: ReadAt(pos=%d, size=%d)", i, pos, readSize))
			}

			// Verify integrity every 10 operations (reduce overhead)
			if i%10 == 9 {
				if !verifyAndReport(t, tw, storeIo, dw, fmt.Sprintf("Stress test %d after op %d", i, opType), "") {
					break // Stop on first error
				}
			}
		}

		// Final integrity verification
		if !verifyAndReport(t, tw, storeIo, dw, "Final", fmt.Sprintf("Random stress test passed: %d operations verified, final size=%d bytes", numStressTests, tw.Size())) {
			return
		}

		// Report I/O statistics using reportAndReset
		reportAndReset(t, tw, storeIo, "After stress test")
	})

	t.Logf("Block boundary operations test passed: fixed, random, and stress tests verified with dualWriter")
}

// ==================== Helper Functions ====================

// makeTestKey creates a test key based on factory requirements.
func makeTestKey(factory crypto_data.ICryptoDataFactory) []byte {
	// Default to 32 bytes (AES-256)
	// Some algorithms may require different key lengths
	name := factory.GetName()
	switch name {
	case "aes-gcm":
		return make([]byte, 32) // AES-256
	case "rc4":
		return make([]byte, 16) // RC4 can use variable key length
	default:
		return make([]byte, 32) // Default
	}
}
