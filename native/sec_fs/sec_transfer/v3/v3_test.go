package sec_transfer_v3

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
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
	if err := os.MkdirAll(filepath.Join(plain, ".隐藏目录"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, ".env"), []byte("hidden file"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, ".隐藏目录", ".秘密"), []byte("hidden nested file"), 0644); err != nil {
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
	if !root.FileExists(".env") || !root.FileExists(".隐藏目录/.秘密") {
		t.Fatal("expected hidden imported files to be visible through encrypted name root")
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
	assertFileContent(t, filepath.Join(out, ".env"), "hidden file")
	assertFileContent(t, filepath.Join(out, ".隐藏目录", ".秘密"), "hidden nested file")
}

func TestV3ImportDirectoryCancellationDuringCountDoesNotCreateDestination(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "a.txt"), []byte("content"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "password")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	ctx, cancel := context.WithCancel(context.Background())
	err = New().ImportDirectory(ctx, sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(plain),
		DestRoot:  root,
		Dest:      "not-created",
		Overwrite: true,
	}, func(event sec_transfer.ProgressEvent) {
		if event.DoneFiles == 0 && event.TotalFiles == 0 && !event.Complete {
			cancel()
		}
	})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("expected count pass cancellation, got %v", err)
	}
	if _, statErr := root.Stat("not-created"); !os.IsNotExist(statErr) {
		t.Fatalf("count pass created destination: %v", statErr)
	}
	markers, listErr := New().ListUnfinishedOperations(context.Background(), rootPath)
	if listErr != nil {
		t.Fatal(listErr)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationImport {
		t.Fatalf("expected canceled import marker, got %+v", markers)
	}
}

func TestV3ImportExportPreservesEmptyEncryptedDirectories(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	out := filepath.Join(tmp, "out")
	if err := os.MkdirAll(filepath.Join(plain, "目录", "空目录"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}

	const password = "empty-dir-password"
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
	defer root.Close()

	manager := New()
	if err := manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(plain),
		DestRoot:  root,
		Dest:      "导入",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	info, err := root.Stat("导入/目录/空目录")
	if err != nil {
		t.Fatal(err)
	}
	if !info.IsDir() {
		t.Fatal("expected imported empty path to remain a directory")
	}
	for _, plainName := range []string{"导入", "目录", "空目录"} {
		if containsDiskName(t, rootPath, plainName) {
			t.Fatalf("plain directory name leaked to store path: %s", plainName)
		}
	}

	if err := manager.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
		SourceRoot: root,
		Source:     "导入",
		Dest:       sec_fs.FullStorePath(out),
		Overwrite:  true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	exported, err := os.Stat(filepath.Join(out, "目录", "空目录"))
	if err != nil {
		t.Fatal(err)
	}
	if !exported.IsDir() {
		t.Fatal("expected exported empty directory")
	}
}

func TestV3ImportDirectoryRejectsSymbolicLinks(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(plain, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(tmp, "outside.txt")
	if err := os.WriteFile(target, []byte("outside"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, filepath.Join(plain, "link.txt")); err != nil {
		t.Skipf("symbolic links unavailable: %v", err)
	}

	const password = "symlink-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	manager := New()
	err = manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(plain),
		DestRoot:  root,
		Dest:      "blocked",
		Overwrite: true,
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "symbolic links are not supported") {
		t.Fatalf("expected symbolic link rejection, got %v", err)
	}
	if root.FileExists("blocked/link.txt") {
		t.Fatal("symbolic link target was imported")
	}
	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationImport {
		t.Fatalf("expected failed import marker, got %+v", markers)
	}
}

func TestV3ImportDirectoryRejectsSourceRootAndSkipsNestedRoots(t *testing.T) {
	tmp := t.TempDir()
	plain := filepath.Join(tmp, "plain")
	nestedRootPath := filepath.Join(plain, "nested-root")
	destRootPath := filepath.Join(tmp, "dest-root")
	if err := os.MkdirAll(nestedRootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(destRootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plain, "visible.txt"), []byte("visible"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(nestedRootPath), "nested-password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(destRootPath), "dest-password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	destRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(destRootPath), "dest-password")
	if err != nil {
		t.Fatal(err)
	}
	defer destRoot.Close()

	manager := New()
	if err := manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(plain),
		DestRoot:  destRoot,
		Dest:      "imported",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	if !destRoot.FileExists("imported/visible.txt") {
		t.Fatal("expected ordinary file to be imported")
	}
	if _, err := destRoot.Stat("imported/nested-root"); err == nil {
		t.Fatal("nested encrypted root should be excluded entirely")
	}

	err = manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(nestedRootPath),
		DestRoot:  destRoot,
		Dest:      "rejected",
		Overwrite: true,
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "source is an encrypted root") {
		t.Fatalf("expected encrypted source root rejection, got %v", err)
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
	if markers[0].EntryKind != sec_transfer.EntryKindFile {
		t.Fatalf("unexpected marker entry kind: %s", markers[0].EntryKind)
	}
	if markers[0].DestinationInitiallyExisted == nil || *markers[0].DestinationInitiallyExisted {
		t.Fatalf("marker lost initially-absent destination state: %#v", markers[0])
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

func TestV3ImportDirectoryRejectsExistingEmptyDestinationWithoutOverwrite(t *testing.T) {
	tmp := t.TempDir()
	sourcePath := filepath.Join(tmp, "source")
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(sourcePath, 0755); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		"directory-conflict-password",
		defaultCreateRootOptions()...,
	); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(
		sec_fs.FullStorePath(rootPath),
		"directory-conflict-password",
	)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	if err := root.MkdirAll("existing"); err != nil {
		t.Fatal(err)
	}

	err = New().ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:   sec_fs.FullStorePath(sourcePath),
		DestRoot: root,
		Dest:     "existing",
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "destination exists") {
		t.Fatalf("existing empty directory error = %v", err)
	}
	markers, markerErr := New().ListUnfinishedOperations(context.Background(), rootPath)
	if markerErr != nil {
		t.Fatal(markerErr)
	}
	if len(markers) != 1 || markers[0].DestinationInitiallyExisted == nil || !*markers[0].DestinationInitiallyExisted {
		t.Fatalf("marker lost initially-existing destination state: %#v", markers)
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
	if markers[0].EntryKind != sec_transfer.EntryKindFile {
		t.Fatalf("unexpected export marker entry kind: %s", markers[0].EntryKind)
	}
}

func TestV3DirectoryMarkersRecordEntryKind(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	password := "marker-kind-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	manager := New()
	err = manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
		Source:   sec_fs.FullStorePath(filepath.Join(tmp, "missing-source")),
		DestRoot: root,
		Dest:     "imported",
	}, nil)
	if err == nil {
		t.Fatal("expected directory import failure")
	}
	assertSingleMarkerKind(t, manager, rootPath, sec_transfer.OperationImport, sec_transfer.EntryKindDirectory)

	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := manager.CleanUnfinishedImportExport(context.Background(), rootPath, markers[0].OpID); err != nil {
		t.Fatal(err)
	}

	err = manager.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
		SourceRoot: root,
		Source:     "missing-directory",
		Dest:       sec_fs.FullStorePath(filepath.Join(tmp, "exported")),
	}, nil)
	if err == nil {
		t.Fatal("expected directory export failure")
	}
	assertSingleMarkerKind(t, manager, rootPath, sec_transfer.OperationExport, sec_transfer.EntryKindDirectory)
}

func assertSingleMarkerKind(t *testing.T, manager *Manager, rootPath string, operationType sec_transfer.OperationType, entryKind sec_transfer.EntryKind) {
	t.Helper()
	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Type != operationType || markers[0].EntryKind != entryKind {
		t.Fatalf("unexpected unfinished marker: %+v", markers)
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

func TestV3ConvertDecryptKeepsEncryptedBackupAfterSuccess(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	password := "convert-decrypt-password"
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), password, defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), password)
	if err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile("plain-dir/a.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := file.Write([]byte("decrypted content")); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := root.Close(); err != nil {
		t.Fatal(err)
	}

	if err := New().ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind: sec_transfer.ConvertKindDecrypt, RootPath: rootPath, Password: password, Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	assertFileContent(t, filepath.Join(rootPath, "plain-dir", "a.txt"), "decrypted content")
	if pathExists(filepath.Join(rootPath, sec_fs.ConfigFileName)) {
		t.Fatal("decrypted root still contains an encryption config")
	}
	matches, err := filepath.Glob(rootPath + ".safe_disk.backup.*")
	if err != nil {
		t.Fatal(err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected one encrypted backup, got %v", matches)
	}
	backupRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(matches[0]), password)
	if err != nil {
		t.Fatalf("retained backup is not an encrypted root: %v", err)
	}
	if err := backupRoot.Close(); err != nil {
		t.Fatal(err)
	}
}

func TestV3ConvertVerificationStopsRenameWhenSourceChanges(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	filePath := filepath.Join(rootPath, "a.txt")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filePath, []byte("copied content"), 0644); err != nil {
		t.Fatal(err)
	}
	var mutateErr error
	var once sync.Once
	err := New().ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind: sec_transfer.ConvertKindEncrypt, RootPath: rootPath, Password: "verify-password", Overwrite: true,
	}, func(event sec_transfer.ProgressEvent) {
		if event.Type == sec_transfer.OperationImport && event.Complete {
			once.Do(func() {
				mutateErr = os.WriteFile(filePath, []byte("changed after copy"), 0644)
			})
		}
	})
	if mutateErr != nil {
		t.Fatal(mutateErr)
	}
	if err == nil || !strings.Contains(err.Error(), "file digest mismatch: a.txt") {
		t.Fatalf("expected digest verification failure, got %v", err)
	}
	assertFileContent(t, filePath, "changed after copy")
	if pathExists(filepath.Join(rootPath, sec_fs.ConfigFileName)) {
		t.Fatal("verification failure replaced the plain source root")
	}
	backups, err := filepath.Glob(rootPath + ".safe_disk.backup.*")
	if err != nil {
		t.Fatal(err)
	}
	if len(backups) != 0 {
		t.Fatalf("verification failure created a backup: %v", backups)
	}
	works, err := filepath.Glob(rootPath + ".safe_disk.work.*")
	if err != nil {
		t.Fatal(err)
	}
	if len(works) != 1 {
		t.Fatalf("expected failed verification work to remain, got %v", works)
	}
	markers, err := listMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Phase != phaseNeedsAttention || markers[0].Status != "failed" {
		t.Fatalf("expected failed needs_attention marker, got %+v", markers)
	}
	if markers[0].Verification == nil || markers[0].Verification.DigestMismatchCount != 1 ||
		len(markers[0].Verification.DigestMismatches) != 1 || markers[0].Verification.DigestMismatches[0] != "a.txt" {
		t.Fatalf("verification report was not persisted: %+v", markers[0].Verification)
	}
	result, recoverErr := New().RecoverConvert(context.Background(), rootPath)
	if recoverErr != nil {
		t.Fatal(recoverErr)
	}
	if result.Action != sec_transfer.RecoverActionNeedsAttention || !strings.Contains(result.Message, "digest_mismatches=1") ||
		!strings.Contains(result.Message, "digest_mismatch=a.txt") {
		t.Fatalf("unexpected verification recovery result: %+v", result)
	}
	if !pathExists(works[0]) {
		t.Fatal("recovery deleted work for a verification failure")
	}
	markers, err = listMarkers(rootPath)
	if err != nil || len(markers) != 1 {
		t.Fatalf("recovery removed verification marker: markers=%+v err=%v", markers, err)
	}
}

func TestVerificationDifferenceSamplesRemainBoundedAndSorted(t *testing.T) {
	var samples []string
	count := 0
	for index := verificationPathSampleLimit + 9; index >= 0; index-- {
		addVerificationDifference(&samples, &count, fmt.Sprintf("path-%02d", index))
	}
	if count != verificationPathSampleLimit+10 {
		t.Fatalf("unexpected difference count: %d", count)
	}
	if len(samples) != verificationPathSampleLimit {
		t.Fatalf("samples are not bounded: %d", len(samples))
	}
	for index, path := range samples {
		expected := fmt.Sprintf("path-%02d", index)
		if path != expected {
			t.Fatalf("samples are not stable and sorted: got %q at %d, want %q", path, index, expected)
		}
	}
}

func TestStreamingVerificationReportsBoundedUnexpectedTree(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	plainPath := filepath.Join(tmp, "plain")
	if err := os.MkdirAll(plainPath, 0755); err != nil {
		t.Fatal(err)
	}
	for index := verificationPathSampleLimit + 3; index >= 0; index-- {
		if err := os.MkdirAll(filepath.Join(plainPath, fmt.Sprintf("dir-%02d", index)), 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(plainPath, fmt.Sprintf("file-%02d", index)), []byte("extra"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "password")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	err = verifyRootAndPlain(context.Background(), root, plainPath)
	var mismatch *treeVerificationError
	if !errors.As(err, &mismatch) {
		t.Fatalf("expected tree verification error, got %v", err)
	}
	report := mismatch.Report()
	if report.UnexpectedDirectoryCount != verificationPathSampleLimit+4 ||
		report.UnexpectedFileCount != verificationPathSampleLimit+4 || !report.Truncated {
		t.Fatalf("unexpected streaming verification report: %+v", report)
	}
	if len(report.UnexpectedDirectories) != verificationPathSampleLimit ||
		len(report.UnexpectedFiles) != verificationPathSampleLimit {
		t.Fatalf("streaming report samples are not bounded: %+v", report)
	}
	for index := 0; index < verificationPathSampleLimit; index++ {
		if report.UnexpectedDirectories[index] != fmt.Sprintf("dir-%02d", index) ||
			report.UnexpectedFiles[index] != fmt.Sprintf("file-%02d", index) {
			t.Fatalf("streaming report samples are not stable: %+v", report)
		}
	}
}

func TestVerifyRootAndPlainDetectsTreeAndContentMismatch(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	plainPath := filepath.Join(tmp, "plain")
	if err := os.MkdirAll(filepath.Join(plainPath, "empty"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(plainPath, "a.txt"), []byte("plain"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "pw", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "pw")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()
	file, err := root.OpenFile("a.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := file.Write([]byte("encrypted source")); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}

	err = verifyRootAndPlain(context.Background(), root, plainPath)
	if err == nil || !strings.Contains(err.Error(), "unexpected directory in work tree: empty") {
		t.Fatalf("expected unexpected directory mismatch, got %v", err)
	}
	if err := root.MkdirAll("empty"); err != nil {
		t.Fatal(err)
	}
	err = verifyRootAndPlain(context.Background(), root, plainPath)
	if err == nil || !strings.Contains(err.Error(), "file digest mismatch: a.txt") {
		t.Fatalf("expected digest mismatch, got %v", err)
	}
	if err := os.WriteFile(filepath.Join(plainPath, "extra.txt"), []byte("extra"), 0644); err != nil {
		t.Fatal(err)
	}
	err = verifyRootAndPlain(context.Background(), root, plainPath)
	if err == nil || !strings.Contains(err.Error(), "unexpected file") {
		t.Fatalf("expected unexpected file mismatch, got %v", err)
	}
}

func TestV3ConvertRejectsInvalidKindBeforeWritingMarker(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}

	err := New().ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind:     sec_transfer.ConvertKind("invalid"),
		RootPath: rootPath,
		Password: "password",
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "unsupported convert kind") {
		t.Fatalf("expected unsupported kind error, got %v", err)
	}
	markers, listErr := listMarkers(rootPath)
	if listErr != nil {
		t.Fatal(listErr)
	}
	if len(markers) != 0 {
		t.Fatalf("invalid request wrote markers: %+v", markers)
	}
}

func TestV3RecoverConvertCleansSafeIncompleteWork(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	opID := "convert_encrypt-test"
	workPath := rootPath + ".safe_disk.work." + opID
	backupPath := rootPath + ".safe_disk.backup." + opID
	for _, path := range []string{rootPath, workPath} {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
	}
	marker := sec_transfer.OperationMarker{
		OpID: opID, Type: sec_transfer.OperationConvertEncrypt, Status: "running",
		Phase: phaseCopyingToWork, Root: rootPath, Work: workPath, Backup: backupPath,
	}
	if err := writeMarker(rootPath, marker); err != nil {
		t.Fatal(err)
	}

	result, err := New().RecoverConvert(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if result.Action != sec_transfer.RecoverActionRerun {
		t.Fatalf("expected rerun, got %s: %s", result.Action, result.Message)
	}
	if pathExists(workPath) {
		t.Fatal("incomplete work directory was not removed")
	}
	markers, err := listMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("incomplete marker was not removed: %+v", markers)
	}
}

func TestV3RecoverConvertRejectsInjectedPaths(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	opID := "convert_encrypt-test"
	workPath := filepath.Join(tmp, "unrelated-work")
	backupPath := rootPath + ".safe_disk.backup." + opID
	for _, path := range []string{rootPath, workPath} {
		if err := os.MkdirAll(path, 0755); err != nil {
			t.Fatal(err)
		}
	}
	marker := sec_transfer.OperationMarker{
		OpID: opID, Type: sec_transfer.OperationConvertEncrypt, Status: "running",
		Phase: phaseCopyingToWork, Root: rootPath, Work: workPath, Backup: backupPath,
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
	if !pathExists(workPath) {
		t.Fatal("recovery removed an untrusted marker path")
	}
}

func TestV3RecoverConvertRejectsMultipleOperations(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	for _, opID := range []string{"convert_encrypt-one", "convert_encrypt-two"} {
		marker := sec_transfer.OperationMarker{
			OpID: opID, Type: sec_transfer.OperationConvertEncrypt, Status: "running",
			Phase: phaseCreatingWork, Root: rootPath,
			Work: rootPath + ".safe_disk.work." + opID, Backup: rootPath + ".safe_disk.backup." + opID,
		}
		if err := writeMarker(rootPath, marker); err != nil {
			t.Fatal(err)
		}
	}

	result, err := New().RecoverConvert(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if result.Action != sec_transfer.RecoverActionNeedsAttention {
		t.Fatalf("expected needs_attention, got %s: %s", result.Action, result.Message)
	}
}

func TestV3CleanUnfinishedRejectsPathTraversalOperationID(t *testing.T) {
	rootPath := t.TempDir()
	err := New().CleanUnfinishedImportExport(context.Background(), rootPath, "../../outside")
	if err == nil || !strings.Contains(err.Error(), "invalid operation id") {
		t.Fatalf("expected invalid operation id error, got %v", err)
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

	result, err := New().recoverFromMarker(rootPath, marker)
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
