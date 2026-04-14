package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestTransferV3FFIRoundTrip(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	out := filepath.Join(tmp, "out")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "a.txt"), []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}

	options := `{"dataFactory":"aes-ctr","nameFactory":"none"}`
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", options))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	assertSuccess(t, TransferV3ImportDirectory_FFI(rootID, plain, ""))
	assertSuccess(t, TransferV3ExportDirectory_FFI(rootID, "", out))
	data, err := os.ReadFile(filepath.Join(out, "a.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "hello" {
		t.Fatalf("unexpected export content: %q", string(data))
	}
	unfinished := assertSuccess(t, TransferV3ListUnfinished_FFI(rootID))
	if got := unfinished["data"].(map[string]interface{})["count"].(float64); got != 0 {
		t.Fatalf("expected no unfinished operations, got %.0f", got)
	}
}

func assertSuccess(t *testing.T, raw string) map[string]interface{} {
	t.Helper()
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &resp); err != nil {
		t.Fatalf("invalid json response %q: %v", raw, err)
	}
	if ok, _ := resp["success"].(bool); !ok {
		t.Fatalf("ffi response failed: %s", raw)
	}
	return resp
}
