// Package crypto_name provides cryptographic name processing interfaces and factory registry.
// This file implements the factory registry for managing name cryptor implementations.
package crypto_name

import (
	"fmt"
	"sync"
)

// ==================== NameFactoryRegistry ====================

// NameFactoryRegistry manages registered name cryptor factories.
// It provides thread-safe registration and retrieval of factories by name.
type NameFactoryRegistry struct {
	mu        sync.RWMutex
	factories map[string]ICryptoNameFactory
}

// NewNameFactoryRegistry creates a new empty factory registry.
func NewNameFactoryRegistry() *NameFactoryRegistry {
	return &NameFactoryRegistry{
		factories: make(map[string]ICryptoNameFactory),
	}
}

// Register adds a new name cryptor factory to the registry.
// Returns an error if a factory with the same name already exists.
func (r *NameFactoryRegistry) Register(factory ICryptoNameFactory) error {
	if factory == nil {
		return fmt.Errorf("cannot register nil factory")
	}

	name := factory.GetName()
	if name == "" {
		return fmt.Errorf("factory name cannot be empty")
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.factories[name]; exists {
		return fmt.Errorf("factory with name %q already registered", name)
	}

	r.factories[name] = factory
	return nil
}

// Get retrieves a factory by its unique name.
// Returns nil if no factory with the given name is registered.
func (r *NameFactoryRegistry) Get(name string) ICryptoNameFactory {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return r.factories[name]
}

// List returns all registered factory names.
func (r *NameFactoryRegistry) List() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	names := make([]string, 0, len(r.factories))
	for name := range r.factories {
		names = append(names, name)
	}
	return names
}

// Count returns the number of registered factories.
func (r *NameFactoryRegistry) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return len(r.factories)
}

// Unregister removes a factory from the registry by name.
// Returns true if the factory was found and removed, false otherwise.
func (r *NameFactoryRegistry) Unregister(name string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.factories[name]; !exists {
		return false
	}

	delete(r.factories, name)
	return true
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
	return globalRegistry.Get(name)
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
