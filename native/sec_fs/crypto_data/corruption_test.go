// Package crypto_data_test provides corruption tolerance tests.
package crypto_data_test

import (
	"io"
	"math/rand"
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestCorruptionTolerance tests the tolerance of encryption algorithms to data corruption.
// It encrypts 4MB of data, randomly corrupts 5 locations (1-1KB each), then decrypts
// and measures the extent of damage.
func TestCorruptionTolerance(t *testing.T) {
	factories := GetAllFactories()
	
	for _, f := range factories {
		t.Run(f.Name, func(t *testing.T) {
			testCorruptionTolerance(t, f.Factory)
		})
	}
}

func testCorruptionTolerance(t *testing.T, factory crypto_data.ICryptoDataFactory) {
	// Use fixed seed for reproducibility
	seed := int64(42)
	rand.Seed(seed)
	t.Logf("Using random seed: %d", seed)
	
	// Create test data: 4MB
	dataSize := int64(4 * 1024 * 1024)
	originalData := make([]byte, dataSize)
	for i := range originalData {
		originalData[i] = byte(i % 256)
	}
	
	// Create context
	storeIo := newMockReadWriterSeeker()
	keyInfo := &mockKeyInfo{key: makeTestKey(factory)}
	cfg := config.NewMemoryConfig()
	
	ctx, err := factory.NewContext(storeIo, keyInfo, cfg)
	require.NoError(t, err, "Failed to create context")
	defer ctx.Close()
	
	// Write original data
	_, err = ctx.Write(originalData)
	require.NoError(t, err, "Failed to write data")
	
	// Sync to ensure data is written
	err = ctx.Sync()
	require.NoError(t, err, "Failed to sync")
	
	// Get encrypted data from storeIo
	encryptedData := getMockData(storeIo)
	t.Logf("Original data size: %d bytes, Encrypted size: %d bytes", dataSize, len(encryptedData))
	
	// Skip mockFile (no encryption)
	if len(encryptedData) == 0 {
		t.Skip("mockFile doesn't store data, skipping")
	}
	
	// Corrupt 5 random locations (1-1KB each)
	corruptions := make([]struct {
		offset int64
		size   int64
	}, 5)
	
	for i := 0; i < 5; i++ {
		// Random offset (avoiding last 1KB)
		offset := rand.Int63n(int64(len(encryptedData)) - 1024)
		// Random size (1-1KB)
		size := rand.Int63n(1024) + 1
		corruptions[i] = struct {
			offset int64
			size   int64
		}{offset: offset, size: size}
		
		// Corrupt the data
		for j := int64(0); j < size && offset+j < int64(len(encryptedData)); j++ {
			encryptedData[offset+j] ^= byte(rand.Intn(256))
		}
		
		t.Logf("Corruption %d: offset=%d, size=%d bytes", i+1, offset, size)
	}
	
	// Write corrupted data back to storeIo
	setMockData(storeIo, encryptedData)
	
	// Decrypt all data
	_, err = ctx.Seek(0, io.SeekStart)
	require.NoError(t, err, "Failed to seek to start")
	decryptedData := make([]byte, dataSize)
	_, err = io.ReadFull(ctx, decryptedData)
	require.NoError(t, err, "Failed to decrypt data")
	
	// Compare decrypted data with original
	damagedBytes := 0
	damagedRegions := 0
	inDamagedRegion := false
	
	for i := int64(0); i < dataSize; i++ {
		if decryptedData[i] != originalData[i] {
			damagedBytes++
			if !inDamagedRegion {
				damagedRegions++
				inDamagedRegion = true
			}
		} else {
			inDamagedRegion = false
		}
	}
	
	// Calculate damage statistics
	damagePercent := float64(damagedBytes) / float64(dataSize) * 100
	
	t.Logf("=== Corruption Analysis ===")
	t.Logf("Original data size: %d bytes", dataSize)
	t.Logf("Total damaged bytes: %d (%.2f%%)", damagedBytes, damagePercent)
	t.Logf("Number of damaged regions: %d", damagedRegions)
	t.Logf("Corruption locations: %d (total %d bytes)", len(corruptions), 
		func() int64 {
			var total int64
			for _, c := range corruptions {
				total += c.size
			}
			return total
		}())
	
	// For stream ciphers (AES-CTR, ChaCha20, RC4):
	// Damage should be roughly equal to corruption size (bit-flipping property)
	// For block ciphers (AES-XTS):
	// Damage should be roughly equal to corruption size (block independence)
	
	// Expectation: damage should not exceed corruption size significantly
	// Allow 10x tolerance for block alignment and other factors
	totalCorruptionSize := int64(0)
	for _, c := range corruptions {
		totalCorruptionSize += c.size
	}
	
	maxExpectedDamage := totalCorruptionSize * 10 // 10x tolerance
	
	assert.LessOrEqual(t, int64(damagedBytes), maxExpectedDamage,
		"Damage exceeds expected threshold. Corruption might propagate beyond corrupted regions.")
	
	t.Logf("Expected max damage: %d bytes (10x corruption size)", maxExpectedDamage)
	t.Logf("Actual damage: %d bytes", damagedBytes)
	
	// Check if damage is localized (good) or spread (bad)
	if damagedRegions <= len(corruptions)*2 {
		t.Logf("✅ Damage is localized (good)")
	} else {
		t.Logf("⚠️ Damage is spread across %d regions", damagedRegions)
	}
}
