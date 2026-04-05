package config

// SharedConfig defines a unified configuration interface for Safe Disk.
// Each module using SharedConfig should add its own key prefix (e.g., "xxx_").
type SharedConfig interface {
	// Getters
	GetStr(key string) (string, error)
	GetInt(key string) (int, error)
	GetBool(key string) (bool, error)

	// Setters
	SetStr(key, val string) error
	SetInt(key string, val int) error
	SetBool(key string, val bool) error

	// WithPrefix returns a new SharedConfig with the given prefix applied to all keys.
	// This allows modules to use their own namespace without modifying the underlying config.
	WithPrefix(prefix string) SharedConfig
}
