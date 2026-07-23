package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"
)

type webDavOperation struct {
	cancel          context.CancelFunc
	cancelRequested bool
	done            bool
	state           string
	response        string
}

type webDavOperationStore struct {
	mu  sync.Mutex
	ops map[string]*webDavOperation
}

func newWebDavOperationStore() *webDavOperationStore {
	return &webDavOperationStore{ops: make(map[string]*webDavOperation)}
}

func (s *webDavOperationStore) start(
	operationID string,
	fn func(context.Context) string,
) string {
	if operationID == "" {
		return errorResponseStr("operation id is required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	op := &webDavOperation{cancel: cancel, state: "running"}
	s.mu.Lock()
	if _, exists := s.ops[operationID]; exists {
		s.mu.Unlock()
		cancel()
		return errorResponseStr(fmt.Sprintf("operation already exists: %s", operationID))
	}
	s.ops[operationID] = op
	s.mu.Unlock()

	go func() {
		response := fn(ctx)
		s.mu.Lock()
		op.done = true
		op.response = response
		switch {
		case op.cancelRequested || errors.Is(ctx.Err(), context.Canceled):
			op.state = "cancelled"
		case errors.Is(ctx.Err(), context.DeadlineExceeded):
			op.state = "failed"
		default:
			op.state = "completed"
		}
		s.mu.Unlock()
		cancel()
	}()

	return SuccessWithData(map[string]string{
		"operation_id": operationID,
		"state":        "running",
	})
}

func (s *webDavOperationStore) cancel(operationID string) bool {
	s.mu.Lock()
	op, exists := s.ops[operationID]
	active := exists && !op.done
	if active {
		op.cancelRequested = true
	}
	s.mu.Unlock()
	if !active {
		return false
	}
	op.cancel()
	return true
}

func (s *webDavOperationStore) poll(operationID string) string {
	if operationID == "" {
		return errorResponseStr("operation id is required")
	}
	s.mu.Lock()
	op, exists := s.ops[operationID]
	if !exists {
		s.mu.Unlock()
		return errorResponseStr("webdav operation not found")
	}
	if !op.done {
		s.mu.Unlock()
		return SuccessWithData(map[string]string{"state": "running"})
	}
	state, response := op.state, op.response
	delete(s.ops, operationID)
	s.mu.Unlock()

	data := map[string]interface{}{"state": state}
	if response != "" {
		data["response"] = jsonRawMessage(response)
	}
	return SuccessWithData(data)
}

// jsonRawMessage keeps the native operation response nested as JSON instead
// of forcing Dart to parse a JSON string inside the polling response.
type jsonRawMessage string

func (m jsonRawMessage) MarshalJSON() ([]byte, error) {
	if !json.Valid([]byte(m)) {
		return nil, errors.New("invalid nested webdav response")
	}
	return []byte(m), nil
}

var webDavOperations = newWebDavOperationStore()

func WebDavMountStart_FFI(operationID, sessionID string) string {
	return webDavOperations.start(operationID, func(ctx context.Context) string {
		mounted, err := WebDavManager.Mount(ctx, sessionID)
		if err != nil {
			return errorResponse(err)
		}
		if ctx.Err() != nil {
			// A mount can finish at the same time cancellation is requested.
			// Never leave that race as an invisible system mount.
			if cleanupErr := WebDavManager.Unmount(context.Background(), sessionID); cleanupErr != nil {
				return errorResponse(errors.Join(err, cleanupErr))
			}
			return SuccessWithData(map[string]bool{"mounted": false})
		}
		return SuccessWithData(map[string]interface{}{
			"mounted":    true,
			"mount_path": mounted.Path(),
		})
	})
}

func WebDavUnmountStart_FFI(operationID, sessionID string) string {
	return webDavOperations.start(operationID, func(ctx context.Context) string {
		if err := WebDavManager.Unmount(ctx, sessionID); err != nil {
			return errorResponse(err)
		}
		return SuccessWithData(map[string]bool{"mounted": false})
	})
}

func WebDavOperationPoll_FFI(operationID string) string {
	return webDavOperations.poll(operationID)
}

func WebDavOperationCancel_FFI(operationID string) string {
	return SuccessWithData(map[string]bool{
		"active": webDavOperations.cancel(operationID),
	})
}
