// Package crypto_data_test provides test helpers for crypto_data tests.
package crypto_data_test

import (
	"bytes"
	"fmt"
	"io"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_gcm"
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
	return []ContextFactory{
		{Name: "mockFile", Factory: newMockFactory()},
		{Name: "rc4", Factory: rc4.NewFactory()},
		{Name: "rc4+random-access", Factory: random_access_adapter.NewFactory(rc4.NewFactory(), 4096)},
		{Name: "aes-gcm", Factory: aes_gcm.NewFactory()},
	}
}

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
	// Read from encrypted context (decrypted automatically)
	n, err = d.ctx.Read(p)
	if n > 0 {
		// Advance mirror position to keep in sync with ctx
		d.plaintextMirror.Seek(int64(n), io.SeekCurrent)
	}
	return n, err
}

// Seek sets the position for both the encrypted context and plaintext mirror.
func (d *dualWriter) Seek(offset int64, whence int) (int64, error) {
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
	// Save current positions to restore later
	ctxPos, _ := d.ctx.Seek(0, io.SeekCurrent)
	mirrorPos, _ := d.plaintextMirror.Seek(0, io.SeekCurrent)

	// Read all data from encrypted context (decrypted)
	ctxSize := d.ctx.Size()
	ctxData := make([]byte, ctxSize)
	_, err := d.ctx.Seek(0, io.SeekStart)
	if err != nil {
		return false, nil, nil, err
	}
	_, err = io.ReadFull(d.ctx, ctxData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false, nil, nil, err
	}

	// Read all data from plaintext mirror
	mirrorSize := d.plaintextMirror.Size()
	mirrorData := make([]byte, mirrorSize)
	_, err = d.plaintextMirror.Seek(0, io.SeekStart)
	if err != nil {
		return false, nil, nil, err
	}
	_, err = io.ReadFull(d.plaintextMirror, mirrorData)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false, nil, nil, err
	}

	// Restore positions
	d.ctx.Seek(ctxPos, io.SeekStart)
	d.plaintextMirror.Seek(mirrorPos, io.SeekStart)

	// Compare
	if !bytes.Equal(ctxData, mirrorData) {
		return false, ctxData, mirrorData, nil
	}

	return true, ctxData, mirrorData, nil
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
func reportAndReset(t *testing.T, tw *trackerContext, storeIo *trackerContext, prefix string) {
	userStats := tw.GetStats()
	storeStats := storeIo.GetStats()

	if userStats.WriteBytes == 0 && userStats.ReadBytes == 0 {
		// No user operations, skip report
		return
	}

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
func verifyAndReport(t *testing.T, tw *trackerContext, storeIo *trackerContext, dw *dualWriter, prefix string, successMsg string) bool {
	// Sync to flush any cached data before reporting stats
	// This is important for adapters like RC4+Adapter that cache writes
	dw.ctx.Sync()

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
