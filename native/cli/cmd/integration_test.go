package cmd

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	// Import algorithm implementations to register key derivers and encryptors
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
)

// TestMain builds the binary once for all integration tests
func TestMain(m *testing.M) {
	// Build the binary (we're in cli/cmd, so go up to cli directory)
	cmd := exec.Command("go", "build", "-o", "safe-disk-test", ".")
	cmd.Dir = ".." // cli directory (parent of cmd)
	if err := cmd.Run(); err != nil {
		panic("Failed to build binary: " + err.Error())
	}

	// Run tests
	code := m.Run()

	// Cleanup
	os.Remove("../safe-disk-test")

	os.Exit(code)
}

func TestUnfinishedImportRerunOnOpenRoot(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-rerun-import-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plainDir := filepath.Join(tmpDir, "plain")
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	password := "rerun-import-password"
	if err := os.MkdirAll(plainDir, 0755); err != nil {
		t.Fatalf("Failed to create plain dir: %v", err)
	}
	if err := os.MkdirAll(encryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create encrypted dir: %v", err)
	}
	sourceFile := filepath.Join(plainDir, "source.txt")
	want := []byte("rerun import content")
	if err := os.WriteFile(sourceFile, want, 0644); err != nil {
		t.Fatalf("Failed to write source file: %v", err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password); err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}
	writeTestMarker(t, encryptedDir, sec_transfer.OperationMarker{
		Version:   3,
		OpID:      "test-import-rerun",
		Type:      sec_transfer.OperationImport,
		EntryKind: sec_transfer.EntryKindFile,
		Status:    "running",
		Src:       sourceFile,
		Dst:       "restored.txt",
		Root:      encryptedDir,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	})

	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir,
		"--unfinished", "rerun")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("list --unfinished=rerun failed: %v\nOutput: %s", err, output)
	}

	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to open encrypted root: %v", err)
	}
	defer root.Close()
	file, err := root.OpenFile("restored.txt", os.O_RDONLY)
	if err != nil {
		t.Fatalf("Failed to open rerun imported file: %v", err)
	}
	got := make([]byte, len(want))
	n, err := file.Read(got)
	file.Close()
	if err != nil && n != len(want) {
		t.Fatalf("Failed to read rerun imported file: %v", err)
	}
	if string(got[:n]) != string(want) {
		t.Fatalf("Rerun imported content mismatch: got %q want %q", string(got[:n]), string(want))
	}
	assertNoTestMarker(t, encryptedDir, "test-import-rerun")
}

func TestUnfinishedRerunRejectsLegacyMarkerWithoutEntryKind(t *testing.T) {
	tmpDir := t.TempDir()
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	password := "legacy-marker-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password); err != nil {
		t.Fatal(err)
	}
	sourceFile := filepath.Join(tmpDir, "source.txt")
	if err := os.WriteFile(sourceFile, []byte("must not import"), 0644); err != nil {
		t.Fatal(err)
	}
	const opID = "legacy-import-rerun"
	writeTestMarker(t, encryptedDir, sec_transfer.OperationMarker{
		Version: 3, OpID: opID, Type: sec_transfer.OperationImport,
		Status: "running", Src: sourceFile, Dst: "restored.txt", Root: encryptedDir,
		CreatedAt: time.Now(), UpdatedAt: time.Now(),
	})

	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password, "--path", encryptedDir, "--unfinished", "rerun")
	output, err := cmd.CombinedOutput()
	if err == nil || !strings.Contains(string(output), "entry_kind") {
		t.Fatalf("expected entry_kind rejection, err=%v output=%s", err, output)
	}
	markerPath := filepath.Join(encryptedDir, ".transfer_v3", "active", opID+".json")
	if _, err := os.Stat(markerPath); err != nil {
		t.Fatalf("legacy marker was removed after rejected rerun: %v", err)
	}

	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	if root.FileExists("restored.txt") {
		t.Fatal("legacy marker rerun created a destination")
	}
}

func TestCLIImportExportWithEncryptedNames(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-cli-names-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plainDir := filepath.Join(tmpDir, "plain")
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	outDir := filepath.Join(tmpDir, "out")
	password := "cli-encrypted-names-password"
	if err := os.MkdirAll(filepath.Join(plainDir, "目录"), 0755); err != nil {
		t.Fatalf("Failed to create plain dir: %v", err)
	}
	if err := os.MkdirAll(encryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create encrypted dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(plainDir, "目录", "文件.txt"), []byte("cli encrypted names"), 0644); err != nil {
		t.Fatalf("Failed to write source file: %v", err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(encryptedDir),
		password,
		sec_fs.WithDataFactory("AES-CTR"),
		sec_fs.WithNameFactory("AES-256-GCM"),
	); err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plainDir,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import command failed: %v\nOutput: %s", err, output)
	}
	if containsDiskName(t, encryptedDir, "目录") || containsDiskName(t, encryptedDir, "文件.txt") {
		t.Fatal("plain directory or file name leaked to encrypted store")
	}

	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", outDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export command failed: %v\nOutput: %s", err, output)
	}
	data, err := os.ReadFile(filepath.Join(outDir, "目录", "文件.txt"))
	if err != nil {
		t.Fatalf("Failed to read exported file: %v", err)
	}
	if string(data) != "cli encrypted names" {
		t.Fatalf("unexpected exported content: %q", string(data))
	}
}

func TestCLIImportExportJSONLines(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-cli-json-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plainDir := filepath.Join(tmpDir, "plain")
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	outDir := filepath.Join(tmpDir, "out")
	password := "cli-json-password"
	if err := os.MkdirAll(plainDir, 0755); err != nil {
		t.Fatalf("Failed to create plain dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(plainDir, "a.txt"), []byte("json progress"), 0644); err != nil {
		t.Fatalf("Failed to write source file: %v", err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password); err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	cmd := exec.Command("../safe-disk-test", "import",
		"--json",
		"--password", password,
		"--source", plainDir,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("import --json failed: %v\nOutput: %s", err, output)
	}
	assertJSONEvents(t, output, "import")

	cmd = exec.Command("../safe-disk-test", "export",
		"--json",
		"--password", password,
		"--source", encryptedDir,
		"--dest", outDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("export --json failed: %v\nOutput: %s", err, output)
	}
	assertJSONEvents(t, output, "export")
}

func TestCLIDoesNotLeakPasswordInCommandOutput(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-cli-password-output-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	password := "DO_NOT_LEAK_password_9b67f0b1"
	rootPath := filepath.Join(tmpDir, "root")
	plainPath := filepath.Join(tmpDir, "plain.txt")
	exportPath := filepath.Join(tmpDir, "exported.txt")
	if err := os.WriteFile(plainPath, []byte("password output guard"), 0644); err != nil {
		t.Fatalf("Failed to write source file: %v", err)
	}

	output := runCLIAndRequireSuccess(t, "create",
		"--path", rootPath,
		"--password", password,
		"--durability", "full")
	assertOutputDoesNotContain(t, output, password)

	output = runCLIAndRequireSuccess(t, "import",
		"--json",
		"--password", password,
		"--source", plainPath,
		"--dest", filepath.Join(rootPath, "inside.txt"),
		"--durability", "none")
	assertOutputDoesNotContain(t, output, password)
	assertJSONEvents(t, output, "import")

	output = runCLIAndRequireSuccess(t, "list",
		"--password", password,
		"--path", rootPath)
	assertOutputDoesNotContain(t, output, password)

	output = runCLIAndRequireSuccess(t, "export",
		"--json",
		"--password", password,
		"--source", filepath.Join(rootPath, "inside.txt"),
		"--dest", exportPath,
		"--durability", "data")
	assertOutputDoesNotContain(t, output, password)
	assertJSONEvents(t, output, "export")
}

func TestCLIRejectsInvalidDurabilityBeforeCreatingPath(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "must-not-exist")
	cmd := exec.Command("../safe-disk-test", "create",
		"--path", rootPath,
		"--password", "password",
		"--durability", "invalid")
	output, err := cmd.CombinedOutput()
	if err == nil || !strings.Contains(string(output), "invalid --durability") {
		t.Fatalf("expected invalid durability error, err=%v output=%s", err, output)
	}
	if _, statErr := os.Stat(rootPath); !os.IsNotExist(statErr) {
		t.Fatalf("invalid durability created root path: %v", statErr)
	}
}

func TestParseDurability(t *testing.T) {
	for _, value := range []string{"none", "data", "full"} {
		level, err := parseDurability(value)
		if err != nil || string(level) != value {
			t.Fatalf("parseDurability(%q) = %q, %v", value, level, err)
		}
	}
	if _, err := parseDurability(""); err == nil {
		t.Fatal("expected empty durability to be rejected by CLI")
	}
}

func TestCreateNonEmptyDirectoryRequiresExplicitInPlaceInNonInteractiveMode(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-cli-create-nonempty-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	rootPath := filepath.Join(tmpDir, "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatalf("Failed to create root dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(rootPath, "plain.txt"), []byte("plain content"), 0644); err != nil {
		t.Fatalf("Failed to write plain file: %v", err)
	}

	cmd := exec.Command("../safe-disk-test", "create",
		"--path", rootPath,
		"--password", "noninteractive-password")
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("expected non-interactive create on non-empty dir to fail, output: %s", output)
	}
	if !strings.Contains(string(output), "directory is not empty") {
		t.Fatalf("expected non-empty directory error, got: %s", output)
	}
	if _, err := os.Stat(filepath.Join(rootPath, sec_fs.ConfigFileName)); !os.IsNotExist(err) {
		t.Fatalf("expected no root config after rejected create, stat err: %v", err)
	}
}

func TestCreateNonEmptyDirectoryJSONRequiresExplicitInPlace(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-cli-create-json-nonempty-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	rootPath := filepath.Join(tmpDir, "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatalf("Failed to create root dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(rootPath, "plain.txt"), []byte("plain content"), 0644); err != nil {
		t.Fatalf("Failed to write plain file: %v", err)
	}

	cmd := exec.Command("../safe-disk-test", "create",
		"--json",
		"--path", rootPath,
		"--password", "json-password")
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("expected create --json on non-empty dir without --in-place to fail, output: %s", output)
	}
	outputText := string(output)
	if !strings.Contains(outputText, "directory is not empty") {
		t.Fatalf("expected non-empty directory error, got: %s", output)
	}
	if strings.Contains(outputText, "[y/N]") {
		t.Fatalf("JSON mode should not print an interactive prompt, got: %s", output)
	}
}

func TestJSONStartupErrorIsSingleStructuredEvent(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--json")
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("expected missing source error, output: %s", output)
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) != 1 {
		t.Fatalf("expected one JSON error line, got %d: %s", len(lines), output)
	}
	var event map[string]interface{}
	if err := json.Unmarshal([]byte(lines[0]), &event); err != nil {
		t.Fatalf("error output is not JSON: %v output=%s", err, output)
	}
	if event["event"] != "operation_failed" || !strings.Contains(event["error"].(string), "source path is required") {
		t.Fatalf("unexpected JSON error: %+v", event)
	}
	if strings.Contains(string(output), "Error:") || strings.Contains(string(output), "Usage:") {
		t.Fatalf("JSON error was polluted by Cobra output: %s", output)
	}
}

func TestJSONWrongPasswordIsSingleStructuredEvent(t *testing.T) {
	tmpDir := t.TempDir()
	rootPath := filepath.Join(tmpDir, "root")
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "correct-password"); err != nil {
		t.Fatal(err)
	}
	sourcePath := filepath.Join(tmpDir, "source.txt")
	if err := os.WriteFile(sourcePath, []byte("content"), 0644); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("../safe-disk-test", "import", "--json",
		"--src", sourcePath, "--dest", rootPath, "--password", "wrong-password")
	output, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("expected wrong password error, output: %s", output)
	}
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) != 1 {
		t.Fatalf("expected one JSON error line, got %d: %s", len(lines), output)
	}
	var event map[string]interface{}
	if err := json.Unmarshal([]byte(lines[0]), &event); err != nil {
		t.Fatalf("error output is not JSON: %v output=%s", err, output)
	}
	if event["event"] != "operation_failed" || event["error"] == "" {
		t.Fatalf("unexpected JSON error: %+v", event)
	}
	if strings.Contains(string(output), "Error:") || strings.Contains(string(output), "Usage:") {
		t.Fatalf("JSON error was polluted by Cobra output: %s", output)
	}
}

func TestUnfinishedExportRerunOnOpenRoot(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-rerun-export-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	encryptedDir := filepath.Join(tmpDir, "encrypted")
	exportDir := filepath.Join(tmpDir, "exported")
	password := "rerun-export-password"
	if err := os.MkdirAll(encryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create encrypted dir: %v", err)
	}
	if err := os.MkdirAll(exportDir, 0755); err != nil {
		t.Fatalf("Failed to create export dir: %v", err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password); err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to open encrypted root: %v", err)
	}
	want := []byte("rerun export content")
	file, err := root.OpenFile("inside.txt", os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		t.Fatalf("Failed to create encrypted file: %v", err)
	}
	if _, err := file.Write(want); err != nil {
		t.Fatalf("Failed to write encrypted file: %v", err)
	}
	file.Close()
	root.Close()

	destFile := filepath.Join(exportDir, "inside.txt")
	writeTestMarker(t, encryptedDir, sec_transfer.OperationMarker{
		Version:   3,
		OpID:      "test-export-rerun",
		Type:      sec_transfer.OperationExport,
		EntryKind: sec_transfer.EntryKindFile,
		Status:    "running",
		Src:       "inside.txt",
		Dst:       destFile,
		Root:      encryptedDir,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	})

	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir,
		"--unfinished", "rerun")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("list --unfinished=rerun failed: %v\nOutput: %s", err, output)
	}
	got, err := os.ReadFile(destFile)
	if err != nil {
		t.Fatalf("Failed to read rerun exported file: %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("Rerun exported content mismatch: got %q want %q", string(got), string(want))
	}
	assertNoTestMarker(t, encryptedDir, "test-export-rerun")
}

func TestOpenRootRecoversConvertRenameWindow(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "safe-disk-convert-recover-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	rootPath := filepath.Join(tmpDir, "root")
	opID := "test-convert-recover"
	workPath := rootPath + ".safe_disk.work." + opID
	backupPath := rootPath + ".safe_disk.backup." + opID
	password := "convert-recover-password"
	if err := os.MkdirAll(workPath, 0755); err != nil {
		t.Fatalf("Failed to create work dir: %v", err)
	}
	if err := os.MkdirAll(backupPath, 0755); err != nil {
		t.Fatalf("Failed to create backup dir: %v", err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(workPath), password); err != nil {
		t.Fatalf("Failed to create work root config: %v", err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(workPath), password)
	if err != nil {
		t.Fatalf("Failed to open work root: %v", err)
	}
	file, err := root.OpenFile("after-recover.txt", os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		t.Fatalf("Failed to create work file: %v", err)
	}
	if _, err := file.Write([]byte("after recover")); err != nil {
		t.Fatalf("Failed to write work file: %v", err)
	}
	file.Close()
	root.Close()
	writeTestMarker(t, backupPath, sec_transfer.OperationMarker{
		Version:   3,
		OpID:      opID,
		Type:      sec_transfer.OperationConvertEncrypt,
		Status:    "running",
		Phase:     "renaming_work_to_root",
		Root:      rootPath,
		Work:      workPath,
		Backup:    backupPath,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	})

	cmd := exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", rootPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("list should recover convert rename window: %v\nOutput: %s", err, output)
	}
	if !strings.Contains(string(output), "after-recover.txt") {
		t.Fatalf("expected recovered root listing to include file, got: %s", output)
	}
	if _, err := os.Stat(workPath); !os.IsNotExist(err) {
		t.Fatalf("expected work path to be moved into root, stat err: %v", err)
	}
	assertNoTestMarker(t, backupPath, opID)
}

func TestOpenRootCleansIncompleteConvertWorkBeforeOpening(t *testing.T) {
	tmpDir := t.TempDir()
	rootPath := filepath.Join(tmpDir, "root")
	opID := "test-convert-copy"
	workPath := rootPath + ".safe_disk.work." + opID
	backupPath := rootPath + ".safe_disk.backup." + opID
	password := "convert-copy-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password); err != nil {
		t.Fatalf("Failed to create source root: %v", err)
	}
	if err := os.MkdirAll(workPath, 0755); err != nil {
		t.Fatalf("Failed to create incomplete work: %v", err)
	}
	writeTestMarker(t, rootPath, sec_transfer.OperationMarker{
		Version: 3, OpID: opID, Type: sec_transfer.OperationConvertEncrypt, Status: "running",
		Phase: "copying_to_work", Root: rootPath, Work: workPath, Backup: backupPath,
		CreatedAt: time.Now(), UpdatedAt: time.Now(),
	})

	cmd := exec.Command("../safe-disk-test", "list", "--password", password, "--path", rootPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("list should clean safe incomplete convert state: %v\nOutput: %s", err, output)
	}
	if !strings.Contains(string(output), "Found unfinished convert operation") {
		t.Fatalf("expected recovery notice, got: %s", output)
	}
	if _, err := os.Stat(workPath); !os.IsNotExist(err) {
		t.Fatalf("expected incomplete work to be removed, stat err: %v", err)
	}
	assertNoTestMarker(t, rootPath, opID)
}

func writeTestMarker(t *testing.T, rootPath string, marker sec_transfer.OperationMarker) {
	t.Helper()
	activeDir := filepath.Join(rootPath, ".transfer_v3", "active")
	if err := os.MkdirAll(activeDir, 0755); err != nil {
		t.Fatalf("Failed to create marker dir: %v", err)
	}
	data, err := json.MarshalIndent(marker, "", "  ")
	if err != nil {
		t.Fatalf("Failed to marshal marker: %v", err)
	}
	if err := os.WriteFile(filepath.Join(activeDir, marker.OpID+".json"), data, 0644); err != nil {
		t.Fatalf("Failed to write marker: %v", err)
	}
}

func assertNoTestMarker(t *testing.T, rootPath string, opID string) {
	t.Helper()
	markerPath := filepath.Join(rootPath, ".transfer_v3", "active", opID+".json")
	if _, err := os.Stat(markerPath); !os.IsNotExist(err) {
		t.Fatalf("Expected marker to be removed: %s", markerPath)
	}
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

func assertJSONEvents(t *testing.T, output []byte, wantType string) {
	t.Helper()
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) < 2 {
		t.Fatalf("expected at least 2 JSON lines, got %d: %s", len(lines), output)
	}
	events := make([]map[string]interface{}, 0, len(lines))
	for _, line := range lines {
		var event map[string]interface{}
		if err := json.Unmarshal([]byte(line), &event); err != nil {
			t.Fatalf("invalid JSON line %q: %v\nall output: %s", line, err, output)
		}
		if event["type"] != wantType {
			t.Fatalf("unexpected event type: got %v want %s in %s", event["type"], wantType, line)
		}
		events = append(events, event)
	}
	if events[0]["event"] != "operation_started" {
		t.Fatalf("first event = %v, want operation_started", events[0]["event"])
	}
	if events[len(events)-1]["event"] != "operation_completed" {
		t.Fatalf("last event = %v, want operation_completed", events[len(events)-1]["event"])
	}
	if _, ok := events[0]["op_id"].(string); !ok {
		t.Fatalf("operation_started missing op_id: %#v", events[0])
	}
}

func runCLIAndRequireSuccess(t *testing.T, args ...string) []byte {
	t.Helper()
	cmd := exec.Command("../safe-disk-test", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("safe-disk %s failed: %v\nOutput: %s", strings.Join(args, " "), err, output)
	}
	return output
}

func assertOutputDoesNotContain(t *testing.T, output []byte, secret string) {
	t.Helper()
	if strings.Contains(string(output), secret) {
		t.Fatalf("command output leaked secret %q: %s", secret, output)
	}
}

func TestVersionIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	if !strings.Contains(string(output), "Safe Disk CLI v") {
		t.Errorf("Expected version output, got: %s", output)
	}
}

func TestHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	if !strings.Contains(string(output), "Safe Disk CLI") {
		t.Errorf("Expected help output, got: %s", output)
	}
}

func TestListMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "list", "--path", "/tmp/test")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	// Cobra adds "Error: " prefix to errors
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestImportMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--source", "/tmp/test", "--dest", "/tmp/enc")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestExportMissingPasswordIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--source", "/tmp/enc", "--dest", "/tmp/plain")
	output, err := cmd.CombinedOutput()
	// Should fail because password is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "password is required") {
		t.Errorf("Expected 'password is required' error, got: %s", output)
	}
}

func TestImportMissingSourceIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--password", "test123", "--dest", "/tmp/enc")
	output, err := cmd.CombinedOutput()
	// Should fail because source is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "source path is required") {
		t.Errorf("Expected 'source path is required' error, got: %s", output)
	}
}

func TestExportMissingSourceIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--password", "test123", "--dest", "/tmp/plain")
	output, err := cmd.CombinedOutput()
	// Should fail because source is required
	if err == nil {
		t.Error("Expected command to fail")
	}
	if !strings.Contains(string(output), "source path is required") {
		t.Errorf("Expected 'source path is required' error, got: %s", output)
	}
}

func TestListHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "list", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--path", "-p", "-d"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

func TestImportHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "import", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--source", "--dest", "--skip-recursive"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

func TestExportHelpIntegration(t *testing.T) {
	cmd := exec.Command("../safe-disk-test", "export", "--help")
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Errorf("Command failed: %v", err)
	}
	expectedFlags := []string{"--password", "--source", "--dest", "--skip-recursive"}
	for _, flag := range expectedFlags {
		if !strings.Contains(string(output), flag) {
			t.Errorf("Expected flag %s in help output, got: %s", flag, output)
		}
	}
}

// =============================================================================
// Integration Tests - Test complete workflows
// =============================================================================

// TestFullWorkflow tests the complete import -> list -> export workflow
func TestFullWorkflow(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-integration-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")
	decryptedDir := filepath.Join(tmpDir, "decrypted")

	for _, dir := range []string{plaintextDir, encryptedDir, decryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test directory structure
	testStructure := map[string][]byte{
		"root_file.txt":        []byte("Root level file content"),
		"docs/readme.txt":      []byte("Documentation file"),
		"docs/api/guide.txt":   []byte("API guide"),
		"src/main.go":          []byte("package main\n\nfunc main() {}"),
		"src/utils/helper.txt": []byte("Helper utilities"),
		"data/empty.txt":       []byte(""),
	}

	for relPath, content := range testStructure {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create file %s: %v", relPath, err)
		}
	}

	password := "integration-test-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Step 1: Import directory
	t.Log("Step 1: Import directory")
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Import failed: %v\nOutput: %s", err, output)
	}
	if !strings.Contains(string(output), "Import successful") {
		t.Errorf("Expected 'Import successful' in output, got: %s", output)
	}

	// Step 2: List files
	t.Log("Step 2: List files")
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v\nOutput: %s", err, output)
	}
	listOutput := string(output)
	t.Logf("List output:\n%s", listOutput)

	// Verify all top-level items are listed
	expectedItems := []string{"root_file.txt", "docs", "src", "data"}
	for _, item := range expectedItems {
		if !strings.Contains(listOutput, item) {
			t.Errorf("Expected item '%s' in list output", item)
		}
	}

	// Step 3: Export directory
	t.Log("Step 3: Export directory")
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir)
	output, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Export failed: %v\nOutput: %s", err, output)
	}

	// Step 4: Verify all files exported correctly
	t.Log("Step 4: Verify exported files")
	for relPath, expectedContent := range testStructure {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		decryptedContent, err := os.ReadFile(decryptedPath)
		if err != nil {
			t.Errorf("Failed to read decrypted file %s: %v", relPath, err)
			continue
		}
		if !bytes.Equal(decryptedContent, expectedContent) {
			t.Errorf("Content mismatch for %s\nExpected: %s\nGot: %s",
				relPath, expectedContent, decryptedContent)
		}
	}

	// Step 5: Verify directory structure preserved
	t.Log("Step 5: Verify directory structure")
	for relPath := range testStructure {
		decryptedPath := filepath.Join(decryptedDir, relPath)
		if _, err := os.Stat(decryptedPath); os.IsNotExist(err) {
			t.Errorf("File %s does not exist in decrypted directory", relPath)
		}
	}
}

// TestRoundTripConsistency verifies data integrity after multiple import/export cycles
func TestRoundTripConsistency(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-roundtrip-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file with binary content
	testFile := filepath.Join(plaintextDir, "test.bin")
	testContent := make([]byte, 1024)
	for i := range testContent {
		testContent[i] = byte(i % 256)
	}
	if err := os.WriteFile(testFile, testContent, 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "roundtrip-password"

	// Initialize encrypted root for first cycle
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Perform 5 round trips
	for cycle := 0; cycle < 5; cycle++ {
		t.Logf("Round trip cycle %d", cycle+1)

		// Import
		cmd := exec.Command("../safe-disk-test", "import",
			"--password", password,
			"--source", testFile,
			"--dest", encryptedDir)
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Import failed in cycle %d: %v", cycle+1, err)
		}

		// Export
		exportDir := filepath.Join(tmpDir, "export"+string(rune('0'+cycle)))
		if err := os.MkdirAll(exportDir, 0755); err != nil {
			t.Fatalf("Failed to create export dir: %v", err)
		}

		cmd = exec.Command("../safe-disk-test", "export",
			"--password", password,
			"--source", filepath.Join(encryptedDir, "test.bin"),
			"--dest", filepath.Join(exportDir, "test.bin"))
		if _, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("Export failed in cycle %d: %v", cycle+1, err)
		}

		// Verify content
		exportedContent, err := os.ReadFile(filepath.Join(exportDir, "test.bin"))
		if err != nil {
			t.Fatalf("Failed to read exported file in cycle %d: %v", cycle+1, err)
		}
		if !bytes.Equal(exportedContent, testContent) {
			t.Fatalf("Content mismatch in cycle %d", cycle+1)
		}

		// Clean up encrypted root for next cycle
		os.RemoveAll(encryptedDir)

		// Recreate encrypted root for next cycle
		if cycle < 4 {
			os.MkdirAll(encryptedDir, 0755)
			_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
			if err != nil {
				t.Fatalf("Failed to recreate encrypted root for cycle %d: %v", cycle+2, err)
			}
		}
	}
}

// TestListSpecificFile tests listing a specific file
func TestListSpecificFile(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-list-file-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "specific.txt")
	testContent := "Specific file content"
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password := "list-file-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", testFile,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import failed: %v", err)
	}

	// List specific file
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", filepath.Join(encryptedDir, "specific.txt"))
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List specific file failed: %v\nOutput: %s", err, output)
	}

	// Verify output shows the file
	if !strings.Contains(string(output), "specific.txt") {
		t.Errorf("Expected 'specific.txt' in output, got: %s", output)
	}
	if !strings.Contains(string(output), "FILE") {
		t.Errorf("Expected 'FILE' type in output, got: %s", output)
	}
}

// TestListDirectoryWithNestedStructure tests listing a directory with nested structure
func TestListDirectoryWithNestedStructure(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-list-nested-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	encryptedDir := filepath.Join(tmpDir, "encrypted")

	for _, dir := range []string{plaintextDir, encryptedDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create nested structure
	nestedFiles := map[string][]byte{
		"level1/level2/level3/deep.txt": []byte("Deeply nested file"),
		"level1/level2/mid.txt":         []byte("Mid-level file"),
		"level1/top.txt":                []byte("Top-level file"),
	}

	for relPath, content := range nestedFiles {
		fullPath := filepath.Join(plaintextDir, relPath)
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			t.Fatalf("Failed to create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(fullPath, content, 0644); err != nil {
			t.Fatalf("Failed to create file %s: %v", relPath, err)
		}
	}

	password := "list-nested-password"

	// Initialize encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(encryptedDir), password)
	if err != nil {
		t.Fatalf("Failed to create encrypted root: %v", err)
	}

	// Import
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password,
		"--source", plaintextDir,
		"--dest", encryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import failed: %v", err)
	}

	// List root
	cmd = exec.Command("../safe-disk-test", "list",
		"--password", password,
		"--path", encryptedDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("List failed: %v", err)
	}

	// Verify top-level structure
	outputStr := string(output)
	t.Logf("List output:\n%s", outputStr)
	// Only top-level items should be shown (non-recursive list)
	expectedItems := []string{"level1"}
	for _, item := range expectedItems {
		if !strings.Contains(outputStr, item) {
			t.Errorf("Expected '%s' in list output", item)
		}
	}

	// Verify nested structure by exporting and checking files
	decryptedDir := filepath.Join(tmpDir, "decrypted")
	if err := os.MkdirAll(decryptedDir, 0755); err != nil {
		t.Fatalf("Failed to create decrypted dir: %v", err)
	}

	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password,
		"--source", encryptedDir,
		"--dest", decryptedDir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export failed: %v", err)
	}

	// Verify all nested files exist after export
	expectedFiles := map[string][]byte{
		"level1/level2/level3/deep.txt": []byte("Deeply nested file"),
		"level1/level2/mid.txt":         []byte("Mid-level file"),
		"level1/top.txt":                []byte("Top-level file"),
	}
	for relPath, expectedContent := range expectedFiles {
		fullPath := filepath.Join(decryptedDir, relPath)
		actualContent, err := os.ReadFile(fullPath)
		if err != nil {
			t.Errorf("File %s not found after export: %v", relPath, err)
			continue
		}
		if string(actualContent) != string(expectedContent) {
			t.Errorf("File %s content mismatch: expected %s, got %s", relPath, expectedContent, actualContent)
		}
	}
}

// TestMultipleUsersDifferentPasswords tests multiple encryption roots with different passwords
func TestMultipleUsersDifferentPasswords(t *testing.T) {
	// Setup
	tmpDir, err := os.MkdirTemp("", "safe-disk-multi-user-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	plaintextDir := filepath.Join(tmpDir, "plaintext")
	user1Dir := filepath.Join(tmpDir, "user1")
	user2Dir := filepath.Join(tmpDir, "user2")

	for _, dir := range []string{plaintextDir, user1Dir, user2Dir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatalf("Failed to create dir %s: %v", dir, err)
		}
	}

	// Create test file
	testFile := filepath.Join(plaintextDir, "secret.txt")
	testContent := "Secret content"
	if err := os.WriteFile(testFile, []byte(testContent), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	password1 := "user1-password"
	password2 := "user2-password"

	// Initialize user1's encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(user1Dir), password1)
	if err != nil {
		t.Fatalf("Failed to create user1's encrypted root: %v", err)
	}

	// Initialize user2's encrypted root
	_, _, err = sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(user2Dir), password2)
	if err != nil {
		t.Fatalf("Failed to create user2's encrypted root: %v", err)
	}

	// Import to user1's encrypted root
	cmd := exec.Command("../safe-disk-test", "import",
		"--password", password1,
		"--source", testFile,
		"--dest", user1Dir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import to user1 failed: %v", err)
	}

	// Import to user2's encrypted root
	cmd = exec.Command("../safe-disk-test", "import",
		"--password", password2,
		"--source", testFile,
		"--dest", user2Dir)
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Import to user2 failed: %v", err)
	}

	// Verify user1 can access with password1
	decryptedDir1 := filepath.Join(tmpDir, "decrypted1")
	os.MkdirAll(decryptedDir1, 0755)
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password1,
		"--source", filepath.Join(user1Dir, "secret.txt"),
		"--dest", filepath.Join(decryptedDir1, "secret.txt"))
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export from user1 failed: %v", err)
	}

	// Verify user2 can access with password2
	decryptedDir2 := filepath.Join(tmpDir, "decrypted2")
	os.MkdirAll(decryptedDir2, 0755)
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password2,
		"--source", filepath.Join(user2Dir, "secret.txt"),
		"--dest", filepath.Join(decryptedDir2, "secret.txt"))
	if _, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("Export from user2 failed: %v", err)
	}

	// Verify content from both users
	content1, err := os.ReadFile(filepath.Join(decryptedDir1, "secret.txt"))
	if err != nil {
		t.Fatalf("Failed to read user1's decrypted file: %v", err)
	}
	content2, err := os.ReadFile(filepath.Join(decryptedDir2, "secret.txt"))
	if err != nil {
		t.Fatalf("Failed to read user2's decrypted file: %v", err)
	}

	if string(content1) != testContent || string(content2) != testContent {
		t.Error("Content mismatch between users")
	}

	// Verify cross-password access fails
	cmd = exec.Command("../safe-disk-test", "export",
		"--password", password2,
		"--source", filepath.Join(user1Dir, "secret.txt"),
		"--dest", filepath.Join(tmpDir, "should_fail.txt"))
	if _, err := cmd.CombinedOutput(); err == nil {
		t.Error("Expected export to fail with wrong password")
	}
}

func TestWebDavServeJSONSupportsBearerAndDigest(t *testing.T) {
	tmpDir := t.TempDir()
	rootPath := filepath.Join(tmpDir, "encrypted")
	password := "webdav-cli-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile("note.txt", os.O_CREATE|os.O_RDWR|os.O_TRUNC)
	if err != nil {
		root.Close()
		t.Fatal(err)
	}
	if _, err := file.Write([]byte("cli webdav")); err != nil {
		file.Close()
		root.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		root.Close()
		t.Fatal(err)
	}
	if err := root.Close(); err != nil {
		t.Fatal(err)
	}

	for _, mode := range []string{"bearer", "digest"} {
		t.Run(mode, func(t *testing.T) {
			command := exec.Command("../safe-disk-test", "webdav", "serve",
				"--password", password,
				"--path", filepath.Join(rootPath, "note.txt"),
				"--auth", mode,
				"--json")
			stdout, err := command.StdoutPipe()
			if err != nil {
				t.Fatal(err)
			}
			var stderr bytes.Buffer
			command.Stderr = &stderr
			if err := command.Start(); err != nil {
				t.Fatal(err)
			}
			decoder := json.NewDecoder(bufio.NewReader(stdout))
			var started map[string]interface{}
			if err := decoder.Decode(&started); err != nil {
				command.Process.Kill()
				command.Wait()
				t.Fatalf("decode started event: %v; stderr=%s", err, stderr.String())
			}
			if started["event"] != "webdav_started" {
				t.Fatalf("started event = %#v", started)
			}
			url := started["url"].(string)
			auth := started["auth"].(map[string]interface{})
			request, err := http.NewRequest(http.MethodGet, url, nil)
			if err != nil {
				t.Fatal(err)
			}
			if mode == "bearer" {
				request.Header.Set("Authorization", "Bearer "+auth["token"].(string))
			} else {
				username := auth["username"].(string)
				password := auth["password"].(string)
				realm := auth["realm"].(string)
				nonce := requestDigestNonce(t, url)
				nc := "00000001"
				cnonce := "cli-test"
				uri := request.URL.RequestURI()
				ha1 := cliDigestHash(username + ":" + realm + ":" + password)
				ha2 := cliDigestHash(http.MethodGet + ":" + uri)
				response := cliDigestHash(ha1 + ":" + nonce + ":" + nc + ":" + cnonce + ":auth:" + ha2)
				request.Header.Set("Authorization", fmt.Sprintf(
					`Digest username="%s", realm="%s", nonce="%s", uri="%s", algorithm=SHA-256, qop=auth, nc=%s, cnonce="%s", response="%s"`,
					username, realm, nonce, uri, nc, cnonce, response,
				))
			}
			response, err := http.DefaultClient.Do(request)
			if err != nil {
				t.Fatal(err)
			}
			body, err := io.ReadAll(response.Body)
			response.Body.Close()
			if err != nil || response.StatusCode != http.StatusOK || string(body) != "cli webdav" {
				t.Fatalf("webdav read = status %d body %q err=%v", response.StatusCode, body, err)
			}

			if err := command.Process.Signal(os.Interrupt); err != nil {
				t.Fatal(err)
			}
			var stopped map[string]interface{}
			if err := decoder.Decode(&stopped); err != nil {
				t.Fatalf("decode stopped event: %v; stderr=%s", err, stderr.String())
			}
			if stopped["event"] != "webdav_stopped" {
				t.Fatalf("stopped event = %#v", stopped)
			}
			if value, ok := stopped["unmount_error"]; !ok || value != nil {
				t.Fatalf("unexpected unmount status = %#v", stopped)
			}
			if err := command.Wait(); err != nil {
				t.Fatalf("webdav command exit: %v; stderr=%s", err, stderr.String())
			}
		})
	}
}

func requestDigestNonce(t *testing.T, rawURL string) string {
	t.Helper()
	request, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("digest challenge status = %d", response.StatusCode)
	}
	const marker = `nonce="`
	challenge := response.Header.Get("WWW-Authenticate")
	start := strings.Index(challenge, marker)
	if start < 0 {
		t.Fatalf("digest challenge has no nonce: %q", challenge)
	}
	start += len(marker)
	end := strings.IndexByte(challenge[start:], '"')
	if end < 0 {
		t.Fatalf("digest challenge nonce is malformed: %q", challenge)
	}
	return challenge[start : start+end]
}

func cliDigestHash(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}
