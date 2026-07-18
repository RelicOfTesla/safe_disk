package sec_transfer_v3

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs/sec_transfer"
)

func TestListUnfinishedOperationsRejectsUnreadableOrInvalidMarkers(t *testing.T) {
	tests := []struct {
		name     string
		fileName string
		data     string
	}{
		{name: "invalid json", fileName: "broken.json", data: "{"},
		{name: "missing operation status", fileName: "broken.json", data: `{"version":3,"op_id":"broken","type":"import","entry_kind":"file"}`},
		{name: "unsupported type", fileName: "broken.json", data: `{"version":3,"op_id":"broken","type":"legacy","status":"running"}`},
		{name: "file name does not match operation id", fileName: "other.json", data: `{"version":3,"op_id":"broken","type":"import","entry_kind":"file","status":"running"}`},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			rootPath := t.TempDir()
			markerDir := activeDir(rootPath)
			if err := os.MkdirAll(markerDir, 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(markerDir, test.fileName), []byte(test.data), 0600); err != nil {
				t.Fatal(err)
			}

			_, err := New().ListUnfinishedOperations(context.Background(), rootPath)
			if !errors.Is(err, sec_transfer.ErrTransferMarkerCorrupt) {
				t.Fatalf("error = %v, want ErrTransferMarkerCorrupt", err)
			}
		})
	}
}
