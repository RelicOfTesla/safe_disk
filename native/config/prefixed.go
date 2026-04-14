package config

// PrefixedConfig wraps a SharedConfig with a key prefix.
// This allows modules to use their own namespace without modifying the underlying config.
type PrefixedConfig struct {
	prefix string
	config SharedConfig
}

// NewPrefixedConfig creates a new PrefixedConfig with the given prefix and underlying config.
// The prefix should typically end with an underscore (e.g., "module_").
func NewPrefixedConfig(prefix string, config SharedConfig) *PrefixedConfig {
	return &PrefixedConfig{
		prefix: prefix,
		config: config,
	}
}

// GetStr retrieves a string value by key with prefix applied.
func (p *PrefixedConfig) GetStr(key string) (string, error) {
	return p.config.GetStr(p.prefix + key)
}

// GetInt retrieves an integer value by key with prefix applied.
func (p *PrefixedConfig) GetInt(key string) (int, error) {
	return p.config.GetInt(p.prefix + key)
}

// GetBool retrieves a boolean value by key with prefix applied.
func (p *PrefixedConfig) GetBool(key string) (bool, error) {
	return p.config.GetBool(p.prefix + key)
}

// SetStr sets a string value for the given key with prefix applied.
func (p *PrefixedConfig) SetStr(key, val string) error {
	return p.config.SetStr(p.prefix+key, val)
}

// SetInt sets an integer value for the given key with prefix applied.
func (p *PrefixedConfig) SetInt(key string, val int) error {
	return p.config.SetInt(p.prefix+key, val)
}

// SetBool sets a boolean value for the given key with prefix applied.
func (p *PrefixedConfig) SetBool(key string, val bool) error {
	return p.config.SetBool(p.prefix+key, val)
}

// WithGroup returns a new SharedConfig with an additional group name applied to all keys.
// The group name will be automatically suffixed with "_" to create a namespace.
// This allows chaining multiple groups.
func (p *PrefixedConfig) WithGroup(name string) SharedConfig {
	return NewPrefixedConfig(p.prefix+name+"_", p.config)
}
