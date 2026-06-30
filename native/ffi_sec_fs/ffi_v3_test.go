package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"safe_disk/native/sec_fs/sec_transfer"
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

func TestTransferV3FFIProgressCallback(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"a.txt", "b.txt"} {
		if err := os.WriteFile(filepath.Join(plain, name), []byte(name), 0644); err != nil {
			t.Fatal(err)
		}
	}

	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"aes-ctr","nameFactory":"none"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	var events []sec_transfer.ProgressEvent
	assertSuccess(t, ImportDirectoryAsyncWithCallback_FFI(rootID, plain, "", func(event sec_transfer.ProgressEvent) {
		events = append(events, event)
	}))
	if len(events) == 0 {
		t.Fatal("expected at least one progress event")
	}
	last := events[len(events)-1]
	if !last.Complete {
		t.Fatalf("expected final progress event to be complete: %#v", last)
	}
	if last.DoneFiles != 2 || last.TotalFiles != 2 {
		t.Fatalf("unexpected final progress counts: done=%d total=%d", last.DoneFiles, last.TotalFiles)
	}
}

func TestTransferV3FFICancelRuntimeOperation(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "cancel.txt"), []byte("cancel me"), 0644); err != nil {
		t.Fatal(err)
	}

	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"aes-ctr","nameFactory":"none"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	started := make(chan struct{})
	release := make(chan struct{})
	resultCh := make(chan string, 1)
	var once sync.Once
	go func() {
		resultCh <- TransferV3ImportDirectoryWithOperation_FFI(
			"ffi-cancel-test",
			rootID,
			plain,
			"",
			func(event sec_transfer.ProgressEvent) {
				if !event.Complete {
					once.Do(func() { close(started) })
					<-release
				}
			},
		)
	}()

	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for operation registration")
	}
	if active := assertSuccess(t, TransferV3Cancel_FFI("ffi-cancel-test"))["data"].(map[string]interface{})["active"].(bool); !active {
		t.Fatal("expected active operation to accept cancellation")
	}
	if active := assertSuccess(t, TransferV3Cancel_FFI("ffi-cancel-test"))["data"].(map[string]interface{})["active"].(bool); !active {
		t.Fatal("expected repeated cancellation to remain idempotent while active")
	}
	close(release)

	select {
	case result := <-resultCh:
		if jsonSuccess(result) {
			t.Fatalf("expected canceled transfer to fail: %s", result)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for canceled operation")
	}
	if active := assertSuccess(t, TransferV3Cancel_FFI("ffi-cancel-test"))["data"].(map[string]interface{})["active"].(bool); active {
		t.Fatal("completed operation remained in runtime registry")
	}

	unfinished := assertSuccess(t, TransferV3ListUnfinished_FFI(rootID))
	if got := unfinished["data"].(map[string]interface{})["count"].(float64); got != 1 {
		t.Fatalf("expected canceled operation marker, got %.0f", got)
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

func TestOpenRootFFIIgnoreMatcher(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"aes-ctr","nameFactory":"none"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "keep.txt", []byte("keep")))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "skip.tmp", []byte("skip")))
	assertSuccess(t, CloseRoot_FFI(rootID))

	openOptions := `{"ignoreMatcher":{"afterPatterns":["*.tmp"]}}`
	rootResp = assertSuccess(t, OpenRoot_FFI(rootPath, "pw", openOptions))
	rootID = int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	readDir := assertSuccess(t, ReadDir_FFI(rootID, ""))
	entries := readDir["data"].(map[string]interface{})["entries"].([]interface{})
	var names []string
	for _, entry := range entries {
		names = append(names, entry.(map[string]interface{})["name"].(string))
	}
	if !containsString(names, "keep.txt") {
		t.Fatalf("expected keep.txt in entries: %#v", names)
	}
	if containsString(names, "skip.tmp") {
		t.Fatalf("expected skip.tmp to be ignored: %#v", names)
	}
	if containsString(names, "_cryption.json") {
		t.Fatalf("expected config file to remain ignored: %#v", names)
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

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
