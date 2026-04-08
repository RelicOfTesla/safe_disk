// Package crypto_key_test provides mock implementations for testing.
package crypto_hkdf_test

import (
	"sync"

	"safe_disk/native/config"
)

// ==================== MockConfig ====================

// MockConfig implements config.SharedConfig for testing.
type MockConfig struct {
	storage *mockStorage
	prefix  string
}

type mockStorage struct {
	mu      sync.RWMutex
	strMap  map[string]string
	intMap  map[string]int
	boolMap map[string]bool
}

func newMockStorage() *mockStorage {
	return &mockStorage{
		strMap:  make(map[string]string),
		intMap:  make(map[string]int),
		boolMap: make(map[string]bool),
	}
}

// NewMockConfig creates a new MockConfig.
func NewMockConfig() *MockConfig {
	return &MockConfig{
		storage: newMockStorage(),
		prefix:  "",
	}
}

// ==================== config.SharedConfig Interface ====================

func (c *MockConfig) GetStr(key string) (string, error) {
	c.storage.mu.RLock()
	defer c.storage.mu.RUnlock()
	if val, ok := c.storage.strMap[c.prefix+key]; ok {
		return val, nil
	}
	return "", nil
}

func (c *MockConfig) GetInt(key string) (int, error) {
	c.storage.mu.RLock()
	defer c.storage.mu.RUnlock()
	if val, ok := c.storage.intMap[c.prefix+key]; ok {
		return val, nil
	}
	return 0, nil
}

func (c *MockConfig) GetBool(key string) (bool, error) {
	c.storage.mu.RLock()
	defer c.storage.mu.RUnlock()
	if val, ok := c.storage.boolMap[c.prefix+key]; ok {
		return val, nil
	}
	return false, nil
}

func (c *MockConfig) SetStr(key, val string) error {
	c.storage.mu.Lock()
	defer c.storage.mu.Unlock()
	c.storage.strMap[c.prefix+key] = val
	return nil
}

func (c *MockConfig) SetInt(key string, val int) error {
	c.storage.mu.Lock()
	defer c.storage.mu.Unlock()
	c.storage.intMap[c.prefix+key] = val
	return nil
}

func (c *MockConfig) SetBool(key string, val bool) error {
	c.storage.mu.Lock()
	defer c.storage.mu.Unlock()
	c.storage.boolMap[c.prefix+key] = val
	return nil
}

func (c *MockConfig) WithGroup(name string) config.SharedConfig {
	return &MockConfig{
		storage: c.storage,
		prefix:  c.prefix + name + "_",
	}
}

// ==================== Interface Verification ====================

var _ config.SharedConfig = (*MockConfig)(nil)
