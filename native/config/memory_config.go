package config

import (
	"fmt"
	"sync"
)

// MemoryConfig is an in-memory implementation of SharedConfig.
// It is thread-safe using sync.RWMutex.
//
// Note: This implementation is primarily intended for testing.
// For persistent configuration, use FileConfig instead.
type MemoryConfig struct {
	mu     sync.RWMutex
	data   map[string]interface{}
	strMap map[string]string
	intMap map[string]int
	boolMap map[string]bool
}

// NewMemoryConfig creates a new MemoryConfig instance.
func NewMemoryConfig() *MemoryConfig {
	return &MemoryConfig{
		data:    make(map[string]interface{}),
		strMap:  make(map[string]string),
		intMap:  make(map[string]int),
		boolMap: make(map[string]bool),
	}
}

// GetStr retrieves a string value by key.
func (m *MemoryConfig) GetStr(key string) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	val, ok := m.strMap[key]
	if !ok {
		return "", fmt.Errorf("key not found: %s", key)
	}
	return val, nil
}

// GetInt retrieves an integer value by key.
func (m *MemoryConfig) GetInt(key string) (int, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	val, ok := m.intMap[key]
	if !ok {
		return 0, fmt.Errorf("key not found: %s", key)
	}
	return val, nil
}

// GetBool retrieves a boolean value by key.
func (m *MemoryConfig) GetBool(key string) (bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	
	val, ok := m.boolMap[key]
	if !ok {
		return false, fmt.Errorf("key not found: %s", key)
	}
	return val, nil
}

// SetStr sets a string value for the given key.
func (m *MemoryConfig) SetStr(key, val string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.strMap[key] = val
	m.data[key] = val
	return nil
}

// SetInt sets an integer value for the given key.
func (m *MemoryConfig) SetInt(key string, val int) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.intMap[key] = val
	m.data[key] = val
	return nil
}

// SetBool sets a boolean value for the given key.
func (m *MemoryConfig) SetBool(key string, val bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	
	m.boolMap[key] = val
	m.data[key] = val
	return nil
}

// WithGroup returns a new SharedConfig with the given group name applied to all keys.
// The group name will be automatically suffixed with "_" to create a namespace.
// This returns a PrefixedConfig that wraps this MemoryConfig.
func (m *MemoryConfig) WithGroup(name string) SharedConfig {
	return NewPrefixedConfig(name+"_", m)
}
