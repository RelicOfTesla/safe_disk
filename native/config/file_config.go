package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

// FileConfig is a persistent file-based implementation of SharedConfig.
// It stores configuration in a JSON file and persists changes automatically.
// Thread-safe using sync.RWMutex.
type FileConfig struct {
	mu       sync.RWMutex
	filePath string
	data     map[string]interface{}
	strMap   map[string]string
	intMap   map[string]int
	boolMap  map[string]bool
}

// NewFileConfig creates a new FileConfig instance with the given file path.
// If the file exists, it loads the configuration from the file.
// If the file doesn't exist, it creates an empty configuration.
func NewFileConfig(filePath string) (*FileConfig, error) {
	fc := &FileConfig{
		filePath: filePath,
		data:     make(map[string]interface{}),
		strMap:   make(map[string]string),
		intMap:   make(map[string]int),
		boolMap:  make(map[string]bool),
	}

	// Ensure directory exists
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, err
	}

	// Load existing file if it exists
	if _, err := os.Stat(filePath); err == nil {
		if err := fc.load(); err != nil {
			return nil, err
		}
	}

	return fc, nil
}

// load reads the configuration from the JSON file.
func (f *FileConfig) load() error {
	data, err := os.ReadFile(f.filePath)
	if err != nil {
		return err
	}

	if len(data) == 0 {
		return nil
	}

	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	// Clear existing maps
	f.data = make(map[string]interface{})
	f.strMap = make(map[string]string)
	f.intMap = make(map[string]int)
	f.boolMap = make(map[string]bool)

	// Populate maps
	for key, value := range raw {
		f.data[key] = value
		switch v := value.(type) {
		case string:
			f.strMap[key] = v
		case float64:
			f.intMap[key] = int(v)
		case bool:
			f.boolMap[key] = v
		}
	}

	return nil
}

// save writes the configuration to the JSON file.
func (f *FileConfig) save() error {
	data, err := json.MarshalIndent(f.data, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(f.filePath, data, 0644)
}

// GetStr retrieves a string value by key.
func (f *FileConfig) GetStr(key string) (string, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()

	val, ok := f.strMap[key]
	if !ok {
		return "", ErrKeyNotFound{Key: key}
	}
	return val, nil
}

// GetInt retrieves an integer value by key.
func (f *FileConfig) GetInt(key string) (int, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()

	val, ok := f.intMap[key]
	if !ok {
		return 0, ErrKeyNotFound{Key: key}
	}
	return val, nil
}

// GetBool retrieves a boolean value by key.
func (f *FileConfig) GetBool(key string) (bool, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()

	val, ok := f.boolMap[key]
	if !ok {
		return false, ErrKeyNotFound{Key: key}
	}
	return val, nil
}

// SetStr sets a string value for the given key and persists to file.
func (f *FileConfig) SetStr(key, val string) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.strMap[key] = val
	f.data[key] = val

	return f.save()
}

// SetInt sets an integer value for the given key and persists to file.
func (f *FileConfig) SetInt(key string, val int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.intMap[key] = val
	f.data[key] = val

	return f.save()
}

// SetBool sets a boolean value for the given key and persists to file.
func (f *FileConfig) SetBool(key string, val bool) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.boolMap[key] = val
	f.data[key] = val

	return f.save()
}

// WithGroup returns a new SharedConfig with the given group name as a prefix.
// The group name will be automatically suffixed with "_" to create a namespace.
// For example: cfg.WithGroup("pbkdf2") creates a config with prefix "pbkdf2_".
func (f *FileConfig) WithGroup(name string) SharedConfig {
	return NewPrefixedConfig(name+"_", f)
}

// GetFilePath returns the file path of this configuration.
func (f *FileConfig) GetFilePath() string {
	return f.filePath
}

// Reload reloads the configuration from the file.
func (f *FileConfig) Reload() error {
	f.mu.Lock()
	defer f.mu.Unlock()

	return f.load()
}

// ==================== Error Types ====================

// ErrKeyNotFound is returned when a key is not found in the configuration.
type ErrKeyNotFound struct {
	Key string
}

func (e ErrKeyNotFound) Error() string {
	return "key not found: " + e.Key
}
