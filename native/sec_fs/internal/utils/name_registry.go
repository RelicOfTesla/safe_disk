// Package utils provides common utility functions for the sec_fs package.
// This file implements NameRegistry[V] for factory registration with GetName() constraint.
package utils

import (
	"fmt"
)

// Namer is an interface for types that have a name.
// This is used as a type constraint for NameRegistry.
type Namer interface {
	GetName() string
}

// NameRegistry is a generic factory registry that manages factory implementations.
// It provides thread-safe registration and retrieval of factories by name.
//
// V must have a GetName() string method for name extraction.
// The type constraint ensures compile-time safety.
//
// Example usage:
//
//	type MyFactory interface {
//	    GetName() string
//	    // other methods...
//	}
//
//	registry := utils.NewNameRegistry[MyFactory]()
//	registry.Register(myFactory) // No need to pass getName function
type NameRegistry[V Namer] struct {
	registry Registry[string, V]
}

// NewNameRegistry creates a new empty NameRegistry[V].
func NewNameRegistry[V Namer]() *NameRegistry[V] {
	return &NameRegistry[V]{
		registry: *NewRegistry[string, V](),
	}
}

// Register adds a new factory to the registry.
// Returns an error if the factory is nil, name is empty, or a factory with the same name already exists.
func (r *NameRegistry[V]) Register(factory V) error {
	if any(factory) == nil {
		return fmt.Errorf("cannot register nil factory")
	}

	name := factory.GetName()
	if name == "" {
		return fmt.Errorf("factory name cannot be empty")
	}

	// Check if already exists
	if r.registry.Contains(name) {
		return fmt.Errorf("factory with name %q already registered", name)
	}

	r.registry.Add(name, factory)
	return nil
}

// Get retrieves a factory by its unique name.
// Returns the zero value and false if no factory with the given name is registered.
func (r *NameRegistry[V]) Get(name string) (V, bool) {
	return r.registry.Get(name)
}

// GetOrNil retrieves a factory by its unique name.
// Returns nil if no factory with the given name is registered.
// This is a convenience method for cases where nil return is expected.
func (r *NameRegistry[V]) GetOrNil(name string) V {
	factory, _ := r.registry.Get(name)
	return factory
}

// List returns all registered factory names.
func (r *NameRegistry[V]) List() []string {
	return r.registry.Keys()
}

// Count returns the number of registered factories.
func (r *NameRegistry[V]) Count() int {
	return r.registry.Count()
}

// Unregister removes a factory from the registry by name.
// Returns true if the factory was found and removed, false otherwise.
func (r *NameRegistry[V]) Unregister(name string) bool {
	return r.registry.Remove(name)
}

// Clear removes all factories from the registry.
func (r *NameRegistry[V]) Clear() {
	r.registry.Clear()
}

// Contains checks if a factory with the given name exists.
func (r *NameRegistry[V]) Contains(name string) bool {
	return r.registry.Contains(name)
}

// ForEach iterates over all factories in the registry and calls the provided function.
// Iteration stops if the function returns false.
func (r *NameRegistry[V]) ForEach(fn func(name string, factory V) bool) {
	r.registry.ForEach(func(key string, value V) bool {
		return fn(key, value)
	})
}
