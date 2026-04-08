// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains IDStore for ID-based instance management.
package main

import (
	"sync"
	"sync/atomic"
)

// IDStore is a thread-safe generic container that manages items with unique int64 IDs.
type IDStore[T any] struct {
	mu    sync.RWMutex
	items map[int64]T
	nextID atomic.Int64
}

// NewIDStore creates a new empty IDStore[T].
func NewIDStore[T any]() *IDStore[T] {
	s := &IDStore[T]{items: make(map[int64]T)}
	s.nextID.Store(1)
	return s
}

// Add adds a new item to the store and returns its unique ID.
func (s *IDStore[T]) Add(item T) int64 {
	id := s.nextID.Add(1) - 1
	s.mu.Lock()
	s.items[id] = item
	s.mu.Unlock()
	return id
}

// Get retrieves an item by its ID.
func (s *IDStore[T]) Get(id int64) (T, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	item, ok := s.items[id]
	return item, ok
}

// Remove removes an item by its ID.
func (s *IDStore[T]) Remove(id int64) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; ok {
		delete(s.items, id)
		return true
	}
	return false
}

// Contains checks if an item with the given ID exists.
func (s *IDStore[T]) Contains(id int64) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.items[id]
	return ok
}

// Clear removes all items from the store.
func (s *IDStore[T]) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items = make(map[int64]T)
}

// Count returns the number of items in the store.
func (s *IDStore[T]) Count() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.items)
}

// List returns a slice of all items in the store.
func (s *IDStore[T]) List() []T {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]T, 0, len(s.items))
	for _, item := range s.items {
		result = append(result, item)
	}
	return result
}
