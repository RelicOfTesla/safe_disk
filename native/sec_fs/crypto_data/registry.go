// Package crypto_data provides cryptographic data processing interfaces and factory registry.
// This file implements the factory registry for managing cryptor implementations.
package crypto_data

import (
	"fmt"
	"sync"
)

// ==================== Factory Registry ====================

// FactoryRegistry manages registered cryptor factories.
// It provides thread-safe registration and retrieval of factories by name or mode.
type FactoryRegistry struct {
	mu       sync.RWMutex
	factories map[string]ICryptoDataFactory
	byMode   map[CryptMode][]ICryptoDataFactory
}

// NewFactoryRegistry creates a new empty factory registry.
func NewFactoryRegistry() *FactoryRegistry {
	return &FactoryRegistry{
		factories: make(map[string]ICryptoDataFactory),
		byMode:    make(map[CryptMode][]ICryptoDataFactory),
	}
}

// Register adds a new cryptor factory to the registry.
// Returns an error if a factory with the same name already exists.
func (r *FactoryRegistry) Register(factory ICryptoDataFactory) error {
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

	// Also index by mode
	caps := factory.GetCapabilities()
	r.byMode[caps.Mode] = append(r.byMode[caps.Mode], factory)

	return nil
}

// Get retrieves a factory by its unique name.
// Returns nil if no factory with the given name is registered.
func (r *FactoryRegistry) Get(name string) ICryptoDataFactory {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return r.factories[name]
}

// GetByMode retrieves all factories that support the given encryption mode.
// Returns an empty slice if no factories support the mode.
func (r *FactoryRegistry) GetByMode(mode CryptMode) []ICryptoDataFactory {
	r.mu.RLock()
	defer r.mu.RUnlock()

	// Return a copy to prevent modification of the internal slice
	factories := r.byMode[mode]
	result := make([]ICryptoDataFactory, len(factories))
	copy(result, factories)
	return result
}

// List returns all registered factory names.
func (r *FactoryRegistry) List() []string {
	r.mu.RLock()
	defer r.mu.RUnlock()

	names := make([]string, 0, len(r.factories))
	for name := range r.factories {
		names = append(names, name)
	}
	return names
}

// Count returns the number of registered factories.
func (r *FactoryRegistry) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return len(r.factories)
}

// Unregister removes a factory from the registry by name.
// Returns true if the factory was found and removed, false otherwise.
func (r *FactoryRegistry) Unregister(name string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	factory, exists := r.factories[name]
	if !exists {
		return false
	}

	delete(r.factories, name)

	// Remove from byMode index
	caps := factory.GetCapabilities()
	factories := r.byMode[caps.Mode]
	for i, f := range factories {
		if f.GetName() == name {
			r.byMode[caps.Mode] = append(factories[:i], factories[i+1:]...)
			break
		}
	}

	return true
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
	return globalRegistry.Get(name)
}

// GetFactoryByMode retrieves all factories from the global registry
// that support the given encryption mode.
func GetFactoryByMode(mode CryptMode) []ICryptoDataFactory {
	return globalRegistry.GetByMode(mode)
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
