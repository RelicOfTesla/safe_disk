package main

import (
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

	options := `{"dataFactory":"AES-CTR","nameFactory":"None"}`
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", options))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	assertSuccess(t, TransferV3ImportDirectory_FFI(rootID, plain, ""))
	directoryResponse := assertSuccess(t, ReadDir_FFI(rootID, ""))
	directoryEntries := directoryResponse["data"].(map[string]interface{})["entries"].([]interface{})
	if len(directoryEntries) != 1 {
		t.Fatalf("expected one imported entry, got %d", len(directoryEntries))
	}
	modTime := int64(directoryEntries[0].(map[string]interface{})["mod_time"].(float64))
	if modTime <= 0 || modTime > time.Now().Add(time.Minute).Unix() {
		t.Fatalf("mod_time must use Unix seconds, got %d", modTime)
	}
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

func TestRenameFFIRenamesEncryptedEntriesWithoutReplacing(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	assertSuccess(t, CreateRootConfig_FFI(
		rootPath,
		"pw",
		`{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`,
	))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	assertSuccess(t, QuickWriteFile_FFI(rootID, "原文件.txt", []byte("source")))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "目标.txt", []byte("target")))
	if response := Rename_FFI(rootID, "原文件.txt", "目标.txt"); jsonSuccess(response) {
		t.Fatalf("rename unexpectedly replaced its target: %s", response)
	}
	assertSuccess(t, Rename_FFI(rootID, "原文件.txt", "新文件.txt"))
	if jsonSuccess(QuickReadFile_FFI(rootID, "原文件.txt")) {
		t.Fatal("old view path still exists after rename")
	}
	renamed := assertSuccess(t, QuickReadFile_FFI(rootID, "新文件.txt"))
	encoded := renamed["data"].(map[string]interface{})["data"].(string)
	if encoded == "" {
		t.Fatal("renamed file returned empty data")
	}
}

func TestCopyEntryFFICopiesAcrossEncryptedRootsAndRequiresOverwrite(t *testing.T) {
	openRoot := func(path, password string) int64 {
		t.Helper()
		assertSuccess(t, CreateRootConfig_FFI(
			path,
			password,
			`{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`,
		))
		response := assertSuccess(t, OpenRoot_FFI(path, password, ""))
		return int64(response["data"].(map[string]interface{})["root_id"].(float64))
	}

	tmp := t.TempDir()
	sourceID := openRoot(filepath.Join(tmp, "source"), "source-password")
	destinationID := openRoot(filepath.Join(tmp, "destination"), "destination-password")
	defer CloseRoot_FFI(sourceID)
	defer CloseRoot_FFI(destinationID)

	assertSuccess(t, QuickWriteFile_FFI(sourceID, "目录/中文.txt", []byte("new")))
	assertSuccess(t, QuickWriteFile_FFI(destinationID, "副本/中文.txt", []byte("old")))
	if response := CopyEntry_FFI(sourceID, "目录", destinationID, "副本", false); jsonSuccess(response) {
		t.Fatalf("copy unexpectedly replaced a destination: %s", response)
	}
	assertSuccess(t, CopyEntry_FFI(sourceID, "目录", destinationID, "副本", true))
	response := assertSuccess(t, QuickReadFile_FFI(destinationID, "副本/中文.txt"))
	if response["data"].(map[string]interface{})["data"].(string) == "" {
		t.Fatal("copied encrypted file returned empty data")
	}
}

func TestCreateEntryFFICreatesEncryptedNamesWithoutReplacing(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`))
	rootResponse := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResponse["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	assertSuccess(t, CreateDirectory_FFI(rootID, "新目录"))
	assertSuccess(t, CreateEmptyFile_FFI(rootID, "新目录/空文件.txt"))
	if response := CreateDirectory_FFI(rootID, "新目录"); jsonSuccess(response) {
		t.Fatalf("directory collision unexpectedly succeeded: %s", response)
	}
	if response := CreateEmptyFile_FFI(rootID, "新目录/空文件.txt"); jsonSuccess(response) {
		t.Fatalf("file collision unexpectedly succeeded: %s", response)
	}
	response := assertSuccess(t, ReadDir_FFI(rootID, "新目录"))
	entries := response["data"].(map[string]interface{})["entries"].([]interface{})
	if len(entries) != 1 || entries[0].(map[string]interface{})["name"] != "空文件.txt" {
		t.Fatalf("unexpected created entries: %#v", entries)
	}
}

func TestTransferV3ImportFFIRequiresExplicitOverwrite(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	sourcePath := filepath.Join(tmp, "source.txt")
	if err := os.WriteFile(sourcePath, []byte("new"), 0600); err != nil {
		t.Fatal(err)
	}
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`))
	rootResponse := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResponse["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)
	assertSuccess(t, QuickWriteFile_FFI(rootID, "冲突.txt", []byte("old")))

	if response := transferV3ImportFileWithPolicy(context.Background(), rootID, sourcePath, "冲突.txt", false, nil); jsonSuccess(response) {
		t.Fatalf("import unexpectedly replaced destination: %s", response)
	}
	assertSuccess(t, transferV3ImportFileWithPolicy(context.Background(), rootID, sourcePath, "冲突.txt", true, nil))
}

func TestTransferV3FFICleanRejectsPathTraversalOperationID(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	response := TransferV3CleanUnfinished_FFI(rootID, "../../outside")
	if jsonSuccess(response) {
		t.Fatalf("path traversal operation id unexpectedly succeeded: %s", response)
	}
	if !strings.Contains(response, "invalid operation id") {
		t.Fatalf("path traversal returned an unclear error: %s", response)
	}
}

func TestFFIRootAndTransferRejectPathTraversal(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	sourcePath := filepath.Join(tmp, "source.txt")
	if err := os.WriteFile(sourcePath, []byte("must stay inside root"), 0644); err != nil {
		t.Fatal(err)
	}
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	for name, response := range map[string]string{
		"quick write": QuickWriteFile_FFI(rootID, "../quick-escape.txt", []byte("escape")),
		"transfer":    TransferV3ImportFile_FFI(rootID, sourcePath, "../transfer-escape.txt"),
	} {
		if jsonSuccess(response) {
			t.Fatalf("%s path traversal unexpectedly succeeded: %s", name, response)
		}
		if !strings.Contains(response, "path traversal") {
			t.Fatalf("%s returned an unclear error: %s", name, response)
		}
	}
	for _, name := range []string{"quick-escape.txt", "transfer-escape.txt"} {
		if _, err := os.Stat(filepath.Join(tmp, name)); !os.IsNotExist(err) {
			t.Fatalf("FFI operation escaped root and created %s", name)
		}
	}
}

func TestOpenRootFFIRejectsWrongPasswordWithoutRegisteringRoot(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	assertSuccess(t, CreateRootConfig_FFI(
		rootPath,
		"correct-password",
		`{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM","deriverFactory":"PBKDF2"}`,
	))

	before := RootStore.Len()
	response := OpenRoot_FFI(rootPath, "wrong-password", "")
	if jsonSuccess(response) {
		t.Fatalf("wrong password unexpectedly opened root: %s", response)
	}
	if !strings.Contains(response, "invalid password") {
		t.Fatalf("wrong password returned an unclear error: %s", response)
	}
	if got := RootStore.Len(); got != before {
		t.Fatalf("failed open leaked a root handle: before=%d after=%d", before, got)
	}

	rootResponse := assertSuccess(t, OpenRoot_FFI(rootPath, "correct-password", ""))
	rootID := int64(rootResponse["data"].(map[string]interface{})["root_id"].(float64))
	assertSuccess(t, CloseRoot_FFI(rootID))
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

	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	var events []sec_transfer.ProgressEvent
	assertSuccess(t, transferV3ImportDirectory(context.Background(), rootID, plain, "", func(event sec_transfer.ProgressEvent) {
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

	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
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
			false,
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

func TestTransferV3FFICancelWhileWaitingForRootLock(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	firstSource := filepath.Join(tmp, "first.txt")
	secondSource := filepath.Join(tmp, "second.txt")
	for path, content := range map[string]string{firstSource: "first", secondSource: "second"} {
		if err := os.WriteFile(path, []byte(content), 0644); err != nil {
			t.Fatal(err)
		}
	}
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
	rootResp := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(rootResp["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)

	firstStarted := make(chan struct{})
	releaseFirst := make(chan struct{})
	firstResult := make(chan string, 1)
	var once sync.Once
	go func() {
		firstResult <- TransferV3ImportFileWithOperation_FFI(
			"ffi-lock-holder", rootID, firstSource, "first.txt",
			false,
			func(event sec_transfer.ProgressEvent) {
				if !event.Complete {
					once.Do(func() { close(firstStarted) })
					<-releaseFirst
				}
			},
		)
	}()
	select {
	case <-firstStarted:
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for lock holder")
	}

	secondResult := make(chan string, 1)
	go func() {
		secondResult <- TransferV3ImportFileWithOperation_FFI(
			"ffi-lock-waiter", rootID, secondSource, "second.txt", false, nil,
		)
	}()
	deadline := time.Now().Add(5 * time.Second)
	for {
		response := assertSuccess(t, TransferV3Cancel_FFI("ffi-lock-waiter"))
		if response["data"].(map[string]interface{})["active"].(bool) {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("timed out waiting for lock waiter registration")
		}
		time.Sleep(10 * time.Millisecond)
	}
	select {
	case result := <-secondResult:
		if jsonSuccess(result) || !strings.Contains(result, "context canceled") {
			t.Fatalf("lock waiter did not return cancellation: %s", result)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for canceled lock waiter")
	}
	close(releaseFirst)
	select {
	case result := <-firstResult:
		assertSuccess(t, result)
	case <-time.After(5 * time.Second):
		t.Fatal("timed out waiting for lock holder completion")
	}
	if raw := QuickReadFile_FFI(rootID, "second.txt"); jsonSuccess(raw) {
		t.Fatal("canceled lock waiter committed its destination")
	}
	unfinished := assertSuccess(t, TransferV3ListUnfinished_FFI(rootID))
	if got := unfinished["data"].(map[string]interface{})["count"].(float64); got != 0 {
		t.Fatalf("lock waiter wrote an unfinished marker, count=%.0f", got)
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

	options := `{"dataFactory":"AES-CTR","nameFactory":"AES-256-GCM"}`
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
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
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
	assertSuccess(t, CreateRootConfig_FFI(ffiRoot, password, `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
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
