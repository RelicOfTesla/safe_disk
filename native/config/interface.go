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

	// WithGroup returns a new SharedConfig with the given group name applied to all keys.
	// The group name will be automatically suffixed with "_" to create a namespace.
	// Example: cfg.WithGroup("pbkdf2") creates a config with prefix "pbkdf2_".
	WithGroup(name string) SharedConfig
}
