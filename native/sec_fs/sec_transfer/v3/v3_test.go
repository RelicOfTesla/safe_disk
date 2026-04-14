package sec_transfer_v3

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/none"
	"safe_disk/native/sec_fs/sec_transfer"
)

func TestV3ImportExportRoundTrip(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	out := filepath.Join(tmp, "out")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "a.txt"), []byte("hello"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(plain, "dir"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "dir", "b.txt"), []byte("world"), 0644); err != nil {
		t.Fatal(err)
	}

	password := "test-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	manager := New()
	if err := manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(plain),
		DestRoot:  root,
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	if err := manager.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
		SourceRoot: root,
		Dest:       sec_fs.FullStorePath(out),
		Overwrite:  true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	if err := root.Close(); err != nil {
		t.Fatal(err)
	}

	assertFileContent(t, filepath.Join(out, "a.txt"), "hello")
	assertFileContent(t, filepath.Join(out, "dir", "b.txt"), "world")
	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("expected no unfinished markers, got %d", len(markers))
	}
}

func TestV3ImportFailureLeavesMarkerAndCleanRemovesIt(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	password := "test-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	manager := New()
	err = manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:   sec_fs.FullStorePath(filepath.Join(tmp, "missing.txt")),
		DestRoot: root,
		Dest:     "missing.txt",
	}, nil)
	if err == nil {
		t.Fatal("expected import failure")
	}

	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 {
		t.Fatalf("expected 1 unfinished marker, got %d", len(markers))
	}
	if markers[0].Type != sec_transfer.OperationImport {
		t.Fatalf("unexpected marker type: %s", markers[0].Type)
	}
	if err := manager.CleanUnfinishedImportExport(context.Background(), rootPath, markers[0].OpID); err != nil {
		t.Fatal(err)
	}
	markers, err = manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("expected markers to be cleaned, got %d", len(markers))
	}
}

func TestV3RecoverConvertContinuesRenameWindow(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	workPath := rootPath + ".safe_disk.work.test"
	backupPath := rootPath + ".safe_disk.backup.test"
	if err := os.MkdirAll(workPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(backupPath, 0755); err != nil {
		t.Fatal(err)
	}
	marker := sec_transfer.OperationMarker{
		OpID:   "test",
		Type:   sec_transfer.OperationConvertEncrypt,
		Status: "running",
		Phase:  phaseRenamingWorkToRoot,
		Root:   rootPath,
		Work:   workPath,
		Backup: backupPath,
	}
	if err := writeMarker(backupPath, marker); err != nil {
		t.Fatal(err)
	}

	result, err := recoverFromMarker(marker)
	if err != nil {
		t.Fatal(err)
	}
	if result.Action != sec_transfer.RecoverActionContinueRename {
		t.Fatalf("expected continue rename, got %s: %s", result.Action, result.Message)
	}
	if !pathExists(rootPath) {
		t.Fatal("expected work directory to be moved into root path")
	}
	if pathExists(workPath) {
		t.Fatal("expected work directory to be moved away")
	}
}

func assertFileContent(t *testing.T, path string, want string) {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != want {
		t.Fatalf("unexpected content for %s: got %q want %q", path, string(data), want)
	}
}
