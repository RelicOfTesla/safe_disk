// Package crypto_hkdf provides key derivation interfaces and factory registry.
// This file implements the registry for managing key deriver implementations.
package crypto_hkdf

import (
	"safe_disk/native/sec_fs/internal/utils"
)

// ==================== KeyDeriverRegistry ====================

// KeyDeriverRegistry is a type alias for NameRegistry[IKeyDeriver].
// It provides thread-safe registration and retrieval of key derivers by name.
type KeyDeriverRegistry = utils.NameRegistry[IKeyDeriver]

// NewKeyDeriverRegistry creates a new empty registry.
func NewKeyDeriverRegistry() *KeyDeriverRegistry {
	return utils.NewNameRegistry[IKeyDeriver]()
}

// ==================== Global Registry ====================

// globalRegistry is the default global registry.
var globalRegistry = NewKeyDeriverRegistry()

// RegisterKeyDeriver registers a key deriver in the global registry.
// Returns an error if a deriver with the same name already exists.
func RegisterKeyDeriver(deriver IKeyDeriver) error {
	return globalRegistry.Register(deriver)
}

// GetKeyDeriver retrieves a key deriver from the global registry by name.
// Returns nil if no deriver with the given name is registered.
func GetKeyDeriver(name string) IKeyDeriver {
	return globalRegistry.GetOrNil(name)
}

// ListKeyDerivers returns all registered key deriver names in the global registry.
func ListKeyDerivers() []string {
	return globalRegistry.List()
}

// UnregisterKeyDeriver removes a key deriver from the global registry by name.
// Returns true if the deriver was found and removed, false otherwise.
func UnregisterKeyDeriver(name string) bool {
	return globalRegistry.Unregister(name)
}

// GetGlobalRegistry returns the global key deriver registry.
// This is useful for advanced use cases that need direct access to the registry.
func GetGlobalRegistry() *KeyDeriverRegistry {
	return globalRegistry
}
