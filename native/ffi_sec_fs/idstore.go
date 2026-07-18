// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains IDStore for ID-based instance management.
package main

import (
	"sync"
	"sync/atomic"
)

// IDStore is a thread-safe generic container that manages items with unique int64 IDs.
type IDStore[T any] struct {
	mu     sync.RWMutex
	items  map[int64]T
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

// Len returns the number of currently stored items.
func (s *IDStore[T]) Len() int {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return len(s.items)
}

// TakeWhere removes and returns every item selected by predicate. It lets a
// parent resource release dependent handles before the parent is closed.
func (s *IDStore[T]) TakeWhere(predicate func(T) bool) []T {
	s.mu.Lock()
	defer s.mu.Unlock()
	items := make([]T, 0)
	for id, item := range s.items {
		if predicate(item) {
			items = append(items, item)
			delete(s.items, id)
		}
	}
	return items
}

////

type KeyValueMap[K comparable, V any] struct {
	items map[K]V
	mu    sync.RWMutex
}

func NewKeyValueMap[K comparable, V any]() *KeyValueMap[K, V] {
	return &KeyValueMap[K, V]{items: make(map[K]V)}
}

func (m *KeyValueMap[K, V]) Get(key K) (V, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	value, ok := m.items[key]
	return value, ok
}
func (m *KeyValueMap[K, V]) Set(key K, value V) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.items[key] = value
}
func (m *KeyValueMap[K, V]) Remove(key K) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.items, key)
}
