// Package crypto_data_test provides test helpers for crypto_data tests.
package crypto_data_test

import (
	"bytes"
	"fmt"
	"io"
	"runtime"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_xts"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/chacha20"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/random_access_adapter"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/rc4"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

// ==================== Mock Factory ====================

// mockFactory is a mock implementation of ICryptoDataFactory for testing.
// It returns mockReadWriterSeeker directly without any encryption.
type mockFactory struct {
	name string
}

func newMockFactory() *mockFactory {
	return &mockFactory{name: "mockFile"}
}

func (f *mockFactory) GetName() string {
	return f.name
}

func (f *mockFactory) GetCapabilities() crypto_data.CryptorCapabilities {
	return crypto_data.CryptorCapabilities{
		Mode:                   crypto_data.CryptModeNormal,
		StreamingComplexity:    crypto_data.O1,
		RandomAccessComplexity: crypto_data.O1,
		ModificationComplexity: crypto_data.O1,
		RandomDeleteComplexity: crypto_data.O1,
		MaxFileSize:            0,
		RecommendedChunkSize:   0,
	}
}

func (f *mockFactory) GetRequireMinKeyLength() int {
	return 0 // mock does not require a real key
}

func (f *mockFactory) NewContext(storeFileIo crypto_data.IFileContext, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_data.IDataCryptorContext, error) {
	// Return a new mockReadWriterSeeker (no encryption, just in-memory storage)
	return newMockReadWriterSeeker(), nil
}

// ==================== Test Factory ====================

// ContextFactory creates IFullDataCryptorContext for testing
type ContextFactory struct {
	Name    string
	Factory crypto_data.ICryptoDataFactory
}

// GetAllFactories returns all context factories for testing
func GetAllFactories() []ContextFactory {
	_ = random_access_adapter.NewFactory
	_ = rc4.NewFactory
	_ = aes_ctr.NewFactory
	_ = aes_gcm.NewFactory
	_ = aes_xts.NewFactory
	_ = chacha20.NewFactory
	return []ContextFactory{
		{Name: "mockFile", Factory: newMockFactory()},
		{Name: "rc4", Factory: rc4.NewFactory()},
		//{Name: "rc4+random-access", Factory: random_access_adapter.NewFactory(rc4.NewFactory(), 4096)},
		{Name: "aes-ctr", Factory: aes_ctr.NewFactory()},
		//{Name: "aes-ctr+random-access", Factory: random_access_adapter.NewFactory(aes_ctr.NewFactory(), 4096)},
		{Name: "aes-gcm", Factory: aes_gcm.NewFactory()},
		//{Name: "aes-gcm+random-access", Factory: random_access_adapter.NewFactory(aes_gcm.NewFactory(), 4096)},
		{Name: "aes-xts", Factory: aes_xts.NewFactory()},
		{Name: "chacha20", Factory: chacha20.NewFactory()},
		//{Name: "chacha20+random-access", Factory: random_access_adapter.NewFactory(chacha20.NewFactory(), 4096)},
	}
}

// ==================== Memory Stats ====================

// MemoryStats holds memory usage statistics for a test
type MemoryStats struct {
	AllocMB      float64 // Current allocated memory (MB)
	TotalAllocMB float64 // Cumulative allocated memory (MB)
	SysMB        float64 // Memory obtained from OS (MB)
	NumGC        uint32  // Number of GC cycles
	HeapAllocMB  float64 // Heap allocated memory (MB)
	HeapSysMB    float64 // Heap system memory (MB)
}

// GetMemoryStats returns current memory statistics
func GetMemoryStats() MemoryStats {
	var m runtime.MemStats
	runtime.GC() // Force GC before reading stats
	runtime.ReadMemStats(&m)
	return MemoryStats{
		AllocMB:      float64(m.Alloc) / 1024 / 1024,
		TotalAllocMB: float64(m.TotalAlloc) / 1024 / 1024,
		SysMB:        float64(m.Sys) / 1024 / 1024,
		NumGC:        m.NumGC,
		HeapAllocMB:  float64(m.HeapAlloc) / 1024 / 1024,
		HeapSysMB:    float64(m.HeapSys) / 1024 / 1024,
	}
}

// MemoryDiff represents the difference in memory usage
type MemoryDiff struct {
	AllocDeltaMB      float64
	TotalAllocDeltaMB float64
	HeapAllocDeltaMB  float64
	NumGC             uint32
}

// Sub calculates the difference between two MemoryStats
func (m MemoryStats) Sub(other MemoryStats) MemoryDiff {
	return MemoryDiff{
		AllocDeltaMB:      m.AllocMB - other.AllocMB,
		TotalAllocDeltaMB: m.TotalAllocMB - other.TotalAllocMB,
		HeapAllocDeltaMB:  m.HeapAllocMB - other.HeapAllocMB,
		NumGC:             m.NumGC - other.NumGC,
	}
}

// String returns a formatted string representation
func (d MemoryDiff) String() string {
	return fmt.Sprintf("Alloc: %.2fMB, Heap: %.2fMB, TotalAlloc: %.2fMB, GC: %d",
		d.AllocDeltaMB, d.HeapAllocDeltaMB, d.TotalAllocDeltaMB, d.NumGC)
}

// ==================== Mock Implementations ====================

// mockReadWriterSeeker is a mock implementation of IReadWriterSeeker for testing.
type mockReadWriterSeeker struct {
	data []byte
	pos  int
}

var _ crypto_data.IFileContext = (*mockReadWriterSeeker)(nil)
var _ crypto_data.IDataCryptorContext = (*mockReadWriterSeeker)(nil)

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

// ensure_append_gap checks if there is a gap between current size and target position,
// and fills it with zeros if necessary.
// This is the standard gap-filling logic for consistency with other implementations.
func (m *mockReadWriterSeeker) ensure_append_gap(targetPos int64) error {
	if targetPos <= int64(len(m.data)) {
		return nil // No gap to fill
	}

	// Extend with zeros
	newData := make([]byte, targetPos)
	copy(newData, m.data)
	m.data = newData
	return nil
}

func (m *mockReadWriterSeeker) Write(p []byte) (n int, err error) {
	// Check and fill gap if writing beyond current size
	if err := m.ensure_append_gap(int64(m.pos)); err != nil {
		return 0, err
	}

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

	// Handle expand: fill gap with zeros
	if size > int64(len(m.data)) {
		if err := m.ensure_append_gap(size); err != nil {
			return err
		}
	} else {
		// Handle shrink
		m.data = m.data[:size]
	}

	// Update pos if it's beyond the new size
	if m.pos > int(size) {
		m.pos = int(size)
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

	// Check and fill gap if writing beyond current size
	if err := m.ensure_append_gap(off); err != nil {
		return 0, err
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

// ==================== IO Statistics ====================

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

// ==================== Tracker Context ====================

// trackerContext wraps any IFullDataCryptorContext and tracks I/O statistics.
// Business layer is unaware of whether it's using aesContext, dualWriter, or tracker.
// This is the correct design pattern for transparent tracking.
type trackerContext struct {
	ctx   crypto_data.IDataCryptorContext
	stats IOStats
}

// Compile-time interface verification
var _ crypto_data.IFileContext = (*trackerContext)(nil)
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

// ==================== Mock Key Info ====================

// mockKeyInfo is a mock implementation of IKeyInfo for testing.
type mockKeyInfo struct {
	key []byte
}

func (m *mockKeyInfo) GetKey() []byte {
	return m.key
}

// ==================== Helper Functions ====================

// makeTestKey creates a test key based on factory requirements.
func makeTestKey(factory crypto_data.ICryptoDataFactory) []byte {
	// Get minimum key length from factory
	keyLen := factory.GetRequireMinKeyLength()
	if keyLen == 0 {
		keyLen = 32 // Default to 32 bytes if not specified
	}
	return make([]byte, keyLen)
}

// CreateContext creates a context for testing
func CreateContext(t *testing.T, factory crypto_data.ICryptoDataFactory) crypto_data.IDataCryptorContext {
	if factory == nil {
		return newMockReadWriterSeeker()
	}

	storeIo := newMockReadWriterSeeker()
	key := makeTestKey(factory)
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

// reportAndReset reports I/O statistics and resets the counters.
// This function is used to track I/O amplification at different stages of testing.
func reportAndReset(t *testing.T, tw *trackerContext, storeIo *trackerContext, prefix string, _disableReport ...bool) {
	userStats := tw.GetStats()
	storeStats := storeIo.GetStats()

	if userStats.WriteBytes == 0 && userStats.ReadBytes == 0 && userStats.ReadCalls == 0 && userStats.WriteCalls == 0 {
		// No user operations, skip report
		return
	}

	if len(_disableReport) == 0 || !_disableReport[0] {
		readAmp := float64(storeStats.ReadBytes) / float64(max(userStats.ReadBytes, 1))
		writeAmp := float64(storeStats.WriteBytes) / float64(max(userStats.WriteBytes, 1))
		readCallAmp := float64(storeStats.ReadCalls) / float64(max(userStats.ReadCalls, 1))
		writeCallAmp := float64(storeStats.WriteCalls) / float64(max(userStats.WriteCalls, 1))

		t.Logf("[%s] Expected/User: Write %d bytes (%d calls), Read %d bytes (%d calls)",
			prefix, userStats.WriteBytes, userStats.WriteCalls, userStats.ReadBytes, userStats.ReadCalls)
		t.Logf("[%s] Actual/Store: Write %d bytes (%d calls), Read %d bytes (%d calls)",
			prefix, storeStats.WriteBytes, storeStats.WriteCalls, storeStats.ReadBytes, storeStats.ReadCalls)
		t.Logf("[%s] Amplification: Read %.2fx/%.2fx, Write %.2fx/%.2fx",
			prefix, readAmp, readCallAmp, writeAmp, writeCallAmp)
	}

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
func verifyAndReport(t *testing.T, tw *trackerContext, storeIo *trackerContext, dw *multiWriter, prefix string,
	successMsg string, _disableReport ...bool) bool {
	// Sync to flush any cached data before reporting stats
	// This is important for adapters like RC4+Adapter that cache writes
	dw.Sync()

	// Report and reset before verifyIntegrity
	reportAndReset(t, tw, storeIo, prefix+" - BeforeVerify", _disableReport...)

	// Verify integrity
	match, decrypted, expected, err := dw.verifyIntegrity()
	if err != nil {
		t.Errorf("%s: verifyIntegrity failed: %v", prefix, err)
		return false
	}

	// Report and reset after verifyIntegrity
	reportAndReset(t, tw, storeIo, prefix+" - AfterVerify", _disableReport...)

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

// ==================== Multi Writer for Multiple Contexts ====================

// multiWriter is a wrapper that simultaneously writes to multiple contexts.
// This is similar to io.MultiWriter, but for encrypted contexts.
//
// Concept: Similar to io.MultiWriter, but for encrypted contexts:
//
//	ctx.Write(data) => { writer1.Write(data), writer2.Write(data), ... }
//	ctx.Seek(pos)   => { writer1.Seek(pos), writer2.Seek(pos), ... }
//
// Usage:
//
//	mw := newMultiWriter(ctx1, ctx2, ctx3)
//	mw.Write(data) // Writes to all three contexts
type multiWriter struct {
	writers []crypto_data.IDataCryptorContext
}

var _ crypto_data.IFileContext = (*multiWriter)(nil)
var _ crypto_data.IDataCryptorContext = (*multiWriter)(nil)

// newMultiWriter creates a new multiWriter that simultaneously writes to all given contexts.
// The first writer is considered the primary writer for operations that return values (Read, Size, etc.).
func newMultiWriter(writers ...crypto_data.IDataCryptorContext) *multiWriter {
	return &multiWriter{
		writers: writers,
	}
}

// Write writes data to all contexts.
func (m *multiWriter) Write(p []byte) (n int, err error) {
	if len(m.writers) == 0 {
		return 0, nil
	}

	// Write to all writers
	for i, w := range m.writers {
		n, err = w.Write(p)
		if err != nil {
			return n, err
		}
		_ = i // suppress unused variable warning
	}

	return n, nil
}

// Read reads data from the primary context (first writer).
func (m *multiWriter) Read(p []byte) (n int, err error) {
	if len(m.writers) == 0 {
		return 0, io.EOF
	}

	// Read from the primary writer (first)
	n, err = m.writers[0].Read(p)
	if n > 0 {
		// Advance other writers' positions to keep in sync
		for i := 1; i < len(m.writers); i++ {
			m.writers[i].Seek(int64(n), io.SeekCurrent)
		}
	}
	return n, err
}

// Seek sets the position for all contexts.
func (m *multiWriter) Seek(offset int64, whence int) (int64, error) {
	if len(m.writers) == 0 {
		return 0, nil
	}

	var pos int64
	var err error

	// Seek all writers
	for _, w := range m.writers {
		pos, err = w.Seek(offset, whence)
		if err != nil {
			return pos, err
		}
	}

	return pos, nil
}

// Close closes all contexts.
func (m *multiWriter) Close() error {
	var firstErr error
	for _, w := range m.writers {
		if err := w.Close(); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

// Size returns the size of the primary context.
func (m *multiWriter) Size() int64 {
	if len(m.writers) == 0 {
		return 0
	}
	return m.writers[0].Size()
}

// Truncate truncates all contexts.
func (m *multiWriter) Truncate(size int64) error {
	for _, w := range m.writers {
		if err := w.Truncate(size); err != nil {
			return err
		}
	}
	return nil
}

// Sync syncs all contexts.
func (m *multiWriter) Sync() error {
	var firstErr error
	for _, w := range m.writers {
		if err := w.Sync(); err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return firstErr
}

// WriteAt writes data at the specified offset to all contexts.
func (m *multiWriter) WriteAt(p []byte, off int64) (n int, err error) {
	if len(m.writers) == 0 {
		return 0, nil
	}

	// Write to all writers
	for _, w := range m.writers {
		n, err = w.WriteAt(p, off)
		if err != nil {
			return n, err
		}
	}

	return n, nil
}

// ReadAt reads data at the specified offset from the primary context.
func (m *multiWriter) ReadAt(p []byte, off int64) (n int, err error) {
	if len(m.writers) == 0 {
		return 0, io.EOF
	}
	return m.writers[0].ReadAt(p, off)
}

// Compile-time interface verification
var _ crypto_data.IFileContext = (*multiWriter)(nil)

// ==================== Dual Writer (Convenience Wrapper) ====================

// newDualWriter creates a new multiWriter with exactly 2 contexts:
// an encrypted context and a plaintext mirror.
// This maintains backward compatibility with existing tests.
func newDualWriter(ctx crypto_data.IDataCryptorContext) *multiWriter {
	return newMultiWriter(ctx, newMockReadWriterSeeker())
}

// verifyIntegrity compares decrypted data from the first context with the second context (plaintext mirror).
// Returns true if they match, false otherwise.
func (m *multiWriter) verifyIntegrity() (bool, []byte, []byte, error) {
	// Need at least 2 writers for verification
	if len(m.writers) < 2 {
		return true, nil, nil, nil
	}

	// Save current positions to restore later
	positions := make([]int64, len(m.writers))
	for i, w := range m.writers {
		positions[i], _ = w.Seek(0, io.SeekCurrent)
	}
	defer func() {
		for i, w := range m.writers {
			w.Seek(positions[i], io.SeekStart)
		}
	}()

	// Get sizes
	ctxSize := m.writers[0].Size()
	mirrorSize := m.writers[1].Size()

	// Quick size check
	if ctxSize != mirrorSize {
		// Size mismatch: read data for error reporting
		return false, readAllDataFrom(m.writers[0], ctxSize), readAllDataFrom(m.writers[1], mirrorSize), nil
	}

	// Stream-based comparison with small buffer
	_, err := m.writers[0].Seek(0, io.SeekStart)
	if err != nil {
		return false, nil, nil, err
	}
	_, err = m.writers[1].Seek(0, io.SeekStart)
	if err != nil {
		return false, nil, nil, err
	}

	// Use small buffer for comparison (4KB)
	bufSize := 4096
	ctxBuf := make([]byte, bufSize)
	mirrorBuf := make([]byte, bufSize)

	for {
		n1, err1 := m.writers[0].Read(ctxBuf)
		n2, err2 := m.writers[1].Read(mirrorBuf)

		// Check if we reached end of both files
		if err1 == io.EOF && err2 == io.EOF {
			break
		}

		// Check for unexpected errors
		if err1 != nil && err1 != io.EOF {
			return false, nil, nil, err1
		}
		if err2 != nil && err2 != io.EOF {
			return false, nil, nil, err2
		}

		// Check if same amount of data was read
		if n1 != n2 {
			// Data mismatch: read full data for error reporting
			return false, readAllDataFrom(m.writers[0], ctxSize), readAllDataFrom(m.writers[1], mirrorSize), nil
		}

		// Compare buffers
		if !bytes.Equal(ctxBuf[:n1], mirrorBuf[:n2]) {
			// Data mismatch: read full data for error reporting
			return false, readAllDataFrom(m.writers[0], ctxSize), readAllDataFrom(m.writers[1], mirrorSize), nil
		}

		// If one reached EOF, both should have
		if err1 == io.EOF || err2 == io.EOF {
			break
		}
	}

	// Data matches - return empty slices (no need to keep large data in memory)
	return true, nil, nil, nil
}

// readAllDataFrom reads all data from a ReadSeeker (used for error reporting)
func readAllDataFrom(r io.ReadSeeker, size int64) []byte {
	if size == 0 {
		return nil
	}
	data := make([]byte, size)
	r.Seek(0, io.SeekStart)
	n, _ := r.Read(data)
	return data[:n]
}
