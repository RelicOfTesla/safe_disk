package main

import (
	"context"
	"fmt"
	"sync"
)

type runtimeOperationStore struct {
	mu      sync.Mutex
	cancels map[string]context.CancelFunc
}

func newRuntimeOperationStore() *runtimeOperationStore {
	return &runtimeOperationStore{cancels: make(map[string]context.CancelFunc)}
}

func (s *runtimeOperationStore) run(operationID string, fn func(context.Context) string) string {
	if operationID == "" {
		return errorResponseStr("operation id is required")
	}

	ctx, cancel := context.WithCancel(context.Background())
	s.mu.Lock()
	if _, exists := s.cancels[operationID]; exists {
		s.mu.Unlock()
		cancel()
		return errorResponseStr(fmt.Sprintf("operation already active: %s", operationID))
	}
	s.cancels[operationID] = cancel
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		delete(s.cancels, operationID)
		s.mu.Unlock()
		cancel()
	}()
	return fn(ctx)
}

func (s *runtimeOperationStore) cancel(operationID string) bool {
	s.mu.Lock()
	cancel, exists := s.cancels[operationID]
	s.mu.Unlock()
	if exists {
		cancel()
	}
	return exists
}

var runtimeOperations = newRuntimeOperationStore()
