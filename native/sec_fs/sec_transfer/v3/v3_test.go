package sec_transfer_v3

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"safe_disk/native/sec_fs"
	_ "safe_disk/native/sec_fs/crypto_data/algorithm_impl/aes_ctr"
	_ "safe_disk/native/sec_fs/crypto_hkdf/algorithm_impl/argon2"
	_ "safe_disk/native/sec_fs/crypto_name/algorithm_impl/aes_gcm_name"
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

func TestV3ImportExportWithEncryptedNames(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	out := filepath.Join(tmp, "out")
	if err := os.MkdirAll(filepath.Join(plain, "目录"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "目录", "文件.txt"), []byte("encrypted names"), 0644); err != nil {
		t.Fatal(err)
	}

	password := "test-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		password,
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("aes-gcm-name"),
	); err != nil {
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
	if !root.FileExists("目录/文件.txt") {
		t.Fatal("expected imported file to be visible through encrypted name root")
	}
	if containsDiskName(t, rootPath, "目录") || containsDiskName(t, rootPath, "文件.txt") {
		t.Fatal("plain directory or file name leaked to store path")
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
	assertFileContent(t, filepath.Join(out, "目录", "文件.txt"), "encrypted names")
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

func TestV3CancellationKeepsMarkerAndDoesNotCommitPartialFiles(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	sourcePath := filepath.Join(tmp, "source.txt")
	exportPath := filepath.Join(tmp, "export.txt")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(sourcePath, []byte("new content"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exportPath, []byte("original content"), 0644); err != nil {
		t.Fatal(err)
	}

	const password = "cancel-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	manager := New()
	importCtx, cancelImport := context.WithCancel(context.Background())
	callbackCount := 0
	err = manager.ImportFile(importCtx, sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(sourcePath),
		DestRoot:  root,
		Dest:      "cancelled.txt",
		Overwrite: true,
	}, func(event sec_transfer.ProgressEvent) {
		if !event.Complete {
			callbackCount++
			if callbackCount == 2 {
				cancelImport()
			}
		}
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected canceled import, got %v", err)
	}
	if root.FileExists("cancelled.txt") || root.FileExists("cancelled.txt"+tempSuffix) {
		t.Fatal("canceled import committed a destination or left a temp file")
	}

	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationImport {
		t.Fatalf("expected one canceled import marker, got %+v", markers)
	}
	if err := manager.CleanUnfinishedImportExport(context.Background(), rootPath, markers[0].OpID); err != nil {
		t.Fatal(err)
	}

	if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(sourcePath),
		DestRoot:  root,
		Dest:      "source.txt",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}

	exportCtx, cancelExport := context.WithCancel(context.Background())
	err = manager.ExportFile(exportCtx, sec_transfer.ExportFileRequest{
		SourceRoot: root,
		Source:     "source.txt",
		Dest:       sec_fs.FullStorePath(exportPath),
		Overwrite:  true,
	}, func(event sec_transfer.ProgressEvent) {
		if !event.Complete {
			cancelExport()
		}
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected canceled export, got %v", err)
	}
	assertFileContent(t, exportPath, "original content")
	if pathExists(exportPath + tempSuffix) {
		t.Fatal("canceled export left a temp file")
	}

	markers, err = manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationExport {
		t.Fatalf("expected one canceled export marker, got %+v", markers)
	}
}

func TestV3ConvertEncryptKeepsBackupAfterSuccess(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(filepath.Join(rootPath, "plain-dir"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rootPath, "plain-dir", "a.txt"), []byte("plain backup content"), 0644); err != nil {
		t.Fatal(err)
	}

	password := "convert-backup-password"
	manager := New()
	if err := manager.ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind:      sec_transfer.ConvertKindEncrypt,
		RootPath:  rootPath,
		Password:  password,
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}

	matches, err := filepath.Glob(rootPath + ".safe_disk.backup.*")
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected exactly one retained backup directory, got %d: %v", len(matches), matches)
	}
	assertFileContent(t, filepath.Join(matches[0], "plain-dir", "a.txt"), "plain backup content")
	markers, err := listMarkers(matches[0])
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("expected retained backup marker to be cleaned, got %d", len(markers))
	}

	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	file, err := root.OpenFile("plain-dir/a.txt", os.O_RDONLY)
	if err != nil {
		t.Fatal(err)
	}
	buf := make([]byte, len("plain backup content"))
	n, err := file.Read(buf)
	_ = file.Close()
	if err != nil && n == 0 {
		t.Fatal(err)
	}
	if string(buf[:n]) != "plain backup content" {
		t.Fatalf("unexpected encrypted root content: %q", string(buf[:n]))
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

func TestV3RecoverConvertFindsMarkerAfterRootRenamedToBackup(t *testing.T) {
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
	if err := os.WriteFile(filepath.Join(workPath, "payload.txt"), []byte("work"), 0644); err != nil {
		t.Fatal(err)
	}
	marker := sec_transfer.OperationMarker{
		OpID:   "test",
		Type:   sec_transfer.OperationConvertEncrypt,
		Status: "running",
		Phase:  phaseRenamingRootToBackup,
		Root:   rootPath,
		Work:   workPath,
		Backup: backupPath,
	}
	if err := writeMarker(backupPath, marker); err != nil {
		t.Fatal(err)
	}

	result, err := New().RecoverConvert(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if result.Action != sec_transfer.RecoverActionContinueRename {
		t.Fatalf("expected continue rename, got %s: %s", result.Action, result.Message)
	}
	assertFileContent(t, filepath.Join(rootPath, "payload.txt"), "work")
	if pathExists(workPath) {
		t.Fatal("expected work directory to be moved into root path")
	}
	markers, err := listMarkers(backupPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("expected backup marker to be cleaned, got %d", len(markers))
	}
}

func TestV3RecoverConvertReportsNeedsAttentionForAmbiguousRenameState(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	workPath := rootPath + ".safe_disk.work.test"
	backupPath := rootPath + ".safe_disk.backup.test"
	for _, path := range []string{rootPath, workPath, backupPath} {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
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
	if err := writeMarker(rootPath, marker); err != nil {
		t.Fatal(err)
	}

	result, err := New().RecoverConvert(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if result.Action != sec_transfer.RecoverActionNeedsAttention {
		t.Fatalf("expected needs_attention, got %s: %s", result.Action, result.Message)
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
