// Package crypto_data provides cryptographic data processing interfaces and factory registry.
// This file implements the factory registry for managing cryptor implementations.
package crypto_data

import (
	"safe_disk/native/sec_fs/internal/utils"
)

// ==================== FactoryRegistry ====================

// FactoryRegistry is a type alias for NameRegistry[ICryptoDataFactory].
// It provides thread-safe registration and retrieval of factories by name.
type FactoryRegistry = utils.NameRegistry[ICryptoDataFactory]

// NewFactoryRegistry creates a new empty factory registry.
func NewFactoryRegistry() *FactoryRegistry {
	return utils.NewNameRegistry[ICryptoDataFactory]()
}

// ==================== Global Registry ====================

// globalRegistry is the default global factory registry.
var globalRegistry = NewFactoryRegistry()

// RegisterFactory registers a cryptor factory in the global registry.
// Returns an error if a factory with the same name already exists.
func RegisterFactory(factory ICryptoDataFactory) error {
	return globalRegistry.Register(factory)
}

// GetFactory retrieves a factory from the global registry by name.
// Returns nil if no factory with the given name is registered.
func GetFactory(name string) ICryptoDataFactory {
	return globalRegistry.GetOrNilFold(name)
}

// ListFactories returns all registered factory names in the global registry.
func ListFactories() []string {
	return globalRegistry.List()
}

// UnregisterFactory removes a factory from the global registry by name.
// Returns true if the factory was found and removed, false otherwise.
func UnregisterFactory(name string) bool {
	return globalRegistry.Unregister(name)
}

// GetGlobalRegistry returns the global factory registry.
// This is useful for advanced use cases that need direct access to the registry.
func GetGlobalRegistry() *FactoryRegistry {
	return globalRegistry
}
