// Package utils provides common utility functions for the sec_fs package.
// This file implements Registry[K, V] for key-value based registry management.
package utils

import (
	"sync"
)

// Registry is a thread-safe generic container that manages items with user-provided keys.
// It provides basic CRUD operations and is designed to be used as a foundation for
// various registry implementations.
//
// K must be comparable (supports == and != operations).
// V can be any type.
//
// Example usage:
//
//	var registry utils.Registry[string, MyFactory]
//	registry.Add("factory1", factory)
//	f, ok := registry.Get("factory1")
type Registry[K comparable, V any] struct {
	mu    sync.RWMutex
	items map[K]V
}

// NewRegistry creates a new empty Registry[K, V].
func NewRegistry[K comparable, V any]() *Registry[K, V] {
	return &Registry[K, V]{
		items: make(map[K]V),
	}
}

// Add adds an item with the given key.
// If an item with the key already exists, it will be overwritten.
func (r *Registry[K, V]) Add(key K, value V) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[key] = value
}

// Get retrieves an item by its key.
// Returns the item and true if found, or zero value and false if not.
func (r *Registry[K, V]) Get(key K) (V, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	item, ok := r.items[key]
	return item, ok
}

// Remove removes an item by its key.
// Returns true if the item was found and removed, false otherwise.
func (r *Registry[K, V]) Remove(key K) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	if _, ok := r.items[key]; ok {
		delete(r.items, key)
		return true
	}
	return false
}

// Contains checks if an item with the given key exists.
func (r *Registry[K, V]) Contains(key K) bool {
	r.mu.RLock()
	defer r.mu.RUnlock()
	_, ok := r.items[key]
	return ok
}

// Clear removes all items from the registry.
func (r *Registry[K, V]) Clear() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = make(map[K]V)
}

// Count returns the number of items in the registry.
func (r *Registry[K, V]) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return len(r.items)
}

// List returns a slice of all items in the registry.
// The order of items is not guaranteed.
func (r *Registry[K, V]) List() []V {
	r.mu.RLock()
	defer r.mu.RUnlock()
	result := make([]V, 0, len(r.items))
	for _, item := range r.items {
		result = append(result, item)
	}
	return result
}

// Keys returns a slice of all keys in the registry.
// The order of keys is not guaranteed.
func (r *Registry[K, V]) Keys() []K {
	r.mu.RLock()
	defer r.mu.RUnlock()
	keys := make([]K, 0, len(r.items))
	for key := range r.items {
		keys = append(keys, key)
	}
	return keys
}

// ForEach iterates over all items in the registry and calls the provided function.
// Iteration stops if the function returns false.
func (r *Registry[K, V]) ForEach(fn func(key K, value V) bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	for key, value := range r.items {
		if !fn(key, value) {
			break
		}
	}
}
