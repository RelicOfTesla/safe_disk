package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
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

func TestClearSecureMemoryFFI(t *testing.T) {
	secret := []byte("sensitive data")
	assertSuccess(t, ClearSecureMemory_FFI(secret))
	for i, b := range secret {
		if b != 0 {
			t.Fatalf("expected secret byte %d to be cleared, got %d", i, b)
		}
	}
}

func TestTransferV3FFIWithEncryptedNames(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	out := filepath.Join(tmp, "out")
	if err := os.MkdirAll(filepath.Join(plain, "目录"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "目录", "文件.txt"), []byte("ffi encrypted names"), 0644); err != nil {
		t.Fatal(err)
	}

	options := `{"dataFactory":"aes-ctr","nameFactory":"aes-gcm-name"}`
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", options))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	assertSuccess(t, TransferV3ImportDirectory_FFI(rootID, plain, ""))
	if raw := QuickReadFile_FFI(rootID, "目录/文件.txt"); !jsonSuccess(raw) {
		t.Fatalf("expected quick read through encrypted names to succeed: %s", raw)
	}
	if containsDiskName(t, rootPath, "目录") || containsDiskName(t, rootPath, "文件.txt") {
		t.Fatal("plain directory or file name leaked to store path")
	}
	assertSuccess(t, TransferV3ExportDirectory_FFI(rootID, "", out))
	data, err := os.ReadFile(filepath.Join(out, "目录", "文件.txt"))
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != "ffi encrypted names" {
		t.Fatalf("unexpected export content: %q", string(data))
	}
}

func TestCLIAndFFICreateOpenCompatibility(t *testing.T) {
	tmp := t.TempDir()
	cliBin := filepath.Join(tmp, "safe-disk-test")
	buildCtx, cancelBuild := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancelBuild()
	build := exec.CommandContext(buildCtx, "go", "build", "-o", cliBin, ".")
	build.Dir = "../cli"
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("failed to build CLI: %v\nOutput: %s", err, output)
	}

	password := "compat-password"
	cliRoot := filepath.Join(tmp, "cli-root")
	createByCLI := commandWithTimeout(t, cliBin, "create", "--path", cliRoot, "--password", password)
	if output, err := createByCLI.CombinedOutput(); err != nil {
		t.Fatalf("CLI create failed: %v\nOutput: %s", err, output)
	}
	rootResp := assertSuccess(t, OpenRoot_FFI(cliRoot, password, ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "from-ffi.txt", []byte("ffi writes cli root")))
	assertSuccess(t, CloseRoot_FFI(rootID))
	exportFromCLIRoot := filepath.Join(tmp, "export-from-cli-root.txt")
	exportByCLI := commandWithTimeout(t, cliBin, "export",
		"--password", password,
		"--source", filepath.Join(cliRoot, "from-ffi.txt"),
		"--dest", exportFromCLIRoot)
	if output, err := exportByCLI.CombinedOutput(); err != nil {
		t.Fatalf("CLI export from FFI-written CLI root failed: %v\nOutput: %s", err, output)
	}
	if data, err := os.ReadFile(exportFromCLIRoot); err != nil {
		t.Fatal(err)
	} else if string(data) != "ffi writes cli root" {
		t.Fatalf("unexpected CLI export content: %q", string(data))
	}

	ffiRoot := filepath.Join(tmp, "ffi-root")
	assertSuccess(t, CreateRootConfig_FFI(ffiRoot, password, `{"dataFactory":"aes-ctr","nameFactory":"none"}`))
	plainFile := filepath.Join(tmp, "plain.txt")
	if err := os.WriteFile(plainFile, []byte("created by ffi, imported by cli"), 0644); err != nil {
		t.Fatal(err)
	}
	importByCLI := commandWithTimeout(t, cliBin, "import",
		"--password", password,
		"--source", plainFile,
		"--dest", filepath.Join(ffiRoot, "from-cli.txt"))
	if output, err := importByCLI.CombinedOutput(); err != nil {
		t.Fatalf("CLI import into FFI-created root failed: %v\nOutput: %s", err, output)
	}
	rootResp = assertSuccess(t, OpenRoot_FFI(ffiRoot, password, ""))
	rootID = int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)
	if raw := QuickReadFile_FFI(rootID, "from-cli.txt"); !jsonSuccess(raw) {
		t.Fatalf("expected FFI to read CLI-imported file: %s", raw)
	}
}

func commandWithTimeout(t *testing.T, name string, args ...string) *exec.Cmd {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	t.Cleanup(cancel)
	return exec.CommandContext(ctx, name, args...)
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

func jsonSuccess(raw string) bool {
	var resp map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &resp); err != nil {
		return false
	}
	ok, _ := resp["success"].(bool)
	return ok
}

func containsDiskName(t *testing.T, rootPath string, name string) bool {
	t.Helper()
	found := false
	err := filepath.WalkDir(rootPath, func(path string, entry os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.Name() == name {
			found = true
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return found
}
