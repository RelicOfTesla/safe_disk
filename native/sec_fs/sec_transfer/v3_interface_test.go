package sec_transfer

import (
	"context"
	"errors"
	"testing"
)

func TestGetDefaultTransferV3DoesNotPanicWithoutRegistration(t *testing.T) {
	transferV3FactoryMu.Lock()
	previous := transferV3Factory
	transferV3Factory = nil
	transferV3FactoryMu.Unlock()
	t.Cleanup(func() {
		RegisterTransferV3Factory(previous)
	})

	manager := GetDefaultTransferV3()
	if manager == nil {
		t.Fatal("expected unavailable manager")
	}
	if err := manager.ImportFile(context.Background(), ImportFileRequest{}, nil); !errors.Is(err, ErrTransferV3NotRegistered) {
		t.Fatalf("ImportFile error = %v, want ErrTransferV3NotRegistered", err)
	}
	if _, err := manager.ListUnfinishedOperations(context.Background(), ""); !errors.Is(err, ErrTransferV3NotRegistered) {
		t.Fatalf("ListUnfinishedOperations error = %v, want ErrTransferV3NotRegistered", err)
	}
}

func TestGetDefaultTransferV3RejectsNilFactoryResult(t *testing.T) {
	transferV3FactoryMu.Lock()
	previous := transferV3Factory
	transferV3Factory = func() V3Transfer { return nil }
	transferV3FactoryMu.Unlock()
	t.Cleanup(func() {
		RegisterTransferV3Factory(previous)
	})

	_, err := GetDefaultTransferV3().RecoverConvert(context.Background(), "")
	if !errors.Is(err, ErrTransferV3NotRegistered) {
		t.Fatalf("RecoverConvert error = %v, want ErrTransferV3NotRegistered", err)
	}
}
