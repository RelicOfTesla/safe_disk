// Package crypto_name provides cryptographic name processing interfaces and factory registry.
// This file implements the factory registry for managing name cryptor implementations.
package crypto_name

import (
	"safe_disk/native/sec_fs/internal/utils"
)

// ==================== NameFactoryRegistry ====================

// NameFactoryRegistry is a type alias for NameRegistry[ICryptoNameFactory].
// It provides thread-safe registration and retrieval of factories by name.
type NameFactoryRegistry = utils.NameRegistry[ICryptoNameFactory]

// NewNameFactoryRegistry creates a new empty factory registry.
func NewNameFactoryRegistry() *NameFactoryRegistry {
	return utils.NewNameRegistry[ICryptoNameFactory]()
}

// ==================== Global Registry ====================

// globalRegistry is the default global factory registry.
var globalRegistry = NewNameFactoryRegistry()

// RegisterNameFactory registers a name cryptor factory in the global registry.
// Returns an error if a factory with the same name already exists.
func RegisterNameFactory(factory ICryptoNameFactory) error {
	return globalRegistry.Register(factory)
}

// GetNameFactory retrieves a factory from the global registry by name.
// Returns nil if no factory with the given name is registered.
func GetNameFactory(name string) ICryptoNameFactory {
	return globalRegistry.GetOrNil(name)
}

// ListNameFactories returns all registered factory names in the global registry.
func ListNameFactories() []string {
	return globalRegistry.List()
}

// UnregisterNameFactory removes a factory from the global registry by name.
// Returns true if the factory was found and removed, false otherwise.
func UnregisterNameFactory(name string) bool {
	return globalRegistry.Unregister(name)
}

// GetGlobalRegistry returns the global factory registry.
// This is useful for advanced use cases that need direct access to the registry.
func GetGlobalRegistry() *NameFactoryRegistry {
	return globalRegistry
}
