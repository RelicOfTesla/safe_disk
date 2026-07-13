package sec_transfer_v3

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

func TestDurabilityLevelsControlMarkerSync(t *testing.T) {
	for _, test := range []struct {
		name      string
		level     DurabilityLevel
		wantFiles int
		wantDirs  int
	}{
		{name: "none", level: DurabilityNone},
		{name: "data", level: DurabilityData, wantFiles: 1},
		{name: "full", level: DurabilityFull, wantFiles: 1, wantDirs: 3},
	} {
		t.Run(test.name, func(t *testing.T) {
			rootPath := t.TempDir()
			manager := New(WithDurability(test.level))
			fileSyncs := 0
			dirSyncs := 0
			manager.syncOSFileHook = func(*os.File) error {
				fileSyncs++
				return nil
			}
			manager.syncDirHook = func(string) error {
				dirSyncs++
				return nil
			}

			err := manager.writeMarker(rootPath, sec_transfer.OperationMarker{
				OpID: "durability-test",
				Type: sec_transfer.OperationImport,
			})
			if err != nil {
				t.Fatal(err)
			}
			if fileSyncs != test.wantFiles || dirSyncs != test.wantDirs {
				t.Fatalf("unexpected sync counts: files=%d dirs=%d", fileSyncs, dirSyncs)
			}
		})
	}
}

func TestImportDurabilityLevelsControlDataAndMetadataSync(t *testing.T) {
	for _, test := range []struct {
		name          string
		level         DurabilityLevel
		wantFileSyncs int
		wantDirSyncs  bool
	}{
		{name: "none", level: DurabilityNone},
		{name: "data", level: DurabilityData, wantFileSyncs: 1},
		{name: "full", level: DurabilityFull, wantFileSyncs: 1, wantDirSyncs: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, root := openDurabilityTestRoot(t)
			defer root.Close()
			source := filepath.Join(t.TempDir(), "source.txt")
			if err := os.WriteFile(source, []byte("payload"), 0644); err != nil {
				t.Fatal(err)
			}

			manager := New(WithDurability(test.level))
			fileSyncs := 0
			dirSyncs := 0
			manager.syncSecFileHook = func(sec_fs.ISecFile) error {
				fileSyncs++
				return nil
			}
			manager.syncDirHook = func(string) error {
				dirSyncs++
				return nil
			}
			if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
				Source:    sec_fs.FullStorePath(source),
				DestRoot:  root,
				Dest:      "target.txt",
				Overwrite: true,
			}, nil); err != nil {
				t.Fatal(err)
			}
			if fileSyncs != test.wantFileSyncs {
				t.Fatalf("unexpected secure file sync count: got %d want %d", fileSyncs, test.wantFileSyncs)
			}
			if (dirSyncs > 0) != test.wantDirSyncs {
				t.Fatalf("unexpected directory sync count: %d", dirSyncs)
			}
		})
	}
}

func TestRequestDurabilityOverrideDoesNotMutateManagerDefault(t *testing.T) {
	_, root := openDurabilityTestRoot(t)
	defer root.Close()
	source := filepath.Join(t.TempDir(), "source.txt")
	if err := os.WriteFile(source, []byte("payload"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := New()
	fileSyncs := 0
	dirSyncs := 0
	manager.syncSecFileHook = func(sec_fs.ISecFile) error {
		fileSyncs++
		return nil
	}
	manager.syncDirHook = func(string) error {
		dirSyncs++
		return nil
	}
	if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:     sec_fs.FullStorePath(source),
		DestRoot:   root,
		Dest:       "none.txt",
		Overwrite:  true,
		Durability: sec_transfer.DurabilityNone,
	}, nil); err != nil {
		t.Fatal(err)
	}
	if fileSyncs != 0 || dirSyncs != 0 {
		t.Fatalf("request-level none unexpectedly synced: files=%d dirs=%d", fileSyncs, dirSyncs)
	}

	if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(source),
		DestRoot:  root,
		Dest:      "default.txt",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	if fileSyncs == 0 || dirSyncs == 0 {
		t.Fatalf("request override mutated manager default: files=%d dirs=%d", fileSyncs, dirSyncs)
	}
}

func TestFullDurabilitySyncsEveryNewPlainDirectoryLevel(t *testing.T) {
	base := t.TempDir()
	target := filepath.Join(base, "one", "two", "three")
	manager := New()
	synced := make(map[string]bool)
	manager.syncDirHook = func(path string) error {
		synced[filepath.Clean(path)] = true
		return nil
	}
	if err := manager.mkdirAllPath(target, 0755); err != nil {
		t.Fatal(err)
	}
	for _, path := range []string{
		base,
		filepath.Join(base, "one"),
		filepath.Join(base, "one", "two"),
		target,
	} {
		if !synced[filepath.Clean(path)] {
			t.Fatalf("new directory chain was not fully synced: missing %s", path)
		}
	}
}

func TestDurabilityRejectsUnknownLevelBeforeWritingMarker(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	manager := New(WithDurability("invalid"))
	err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:   sec_fs.FullStorePath(filepath.Join(rootPath, "missing-source")),
		DestRoot: root,
		Dest:     "target.txt",
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "unsupported durability level") {
		t.Fatalf("expected invalid durability error, got %v", err)
	}

	if _, statErr := os.Stat(filepath.Join(rootPath, baseDirName)); !os.IsNotExist(statErr) {
		t.Fatalf("invalid durability wrote transfer state: %v", statErr)
	}
}

func TestRequestDurabilityRejectsUnknownLevelBeforeWritingMarker(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	manager := New()
	err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:     sec_fs.FullStorePath(filepath.Join(rootPath, "missing-source")),
		DestRoot:   root,
		Dest:       "target.txt",
		Durability: "invalid",
	}, nil)
	if err == nil || !strings.Contains(err.Error(), "unsupported durability level") {
		t.Fatalf("expected invalid request durability error, got %v", err)
	}
	if _, statErr := os.Stat(filepath.Join(rootPath, baseDirName)); !os.IsNotExist(statErr) {
		t.Fatalf("invalid request durability wrote transfer state: %v", statErr)
	}
}

func TestImportSyncFailureKeepsUnfinishedMarker(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	source := filepath.Join(t.TempDir(), "source.txt")
	if err := os.WriteFile(source, []byte("payload"), 0644); err != nil {
		t.Fatal(err)
	}

	syncFailure := errors.New("injected secure file sync failure")
	manager := New(WithDurability(DurabilityData))
	manager.syncSecFileHook = func(sec_fs.ISecFile) error { return syncFailure }
	err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(source),
		DestRoot:  root,
		Dest:      "target.txt",
		Overwrite: true,
	}, nil)
	if !errors.Is(err, syncFailure) {
		t.Fatalf("expected injected sync error, got %v", err)
	}
	if root.FileExists("target.txt") {
		t.Fatal("destination was committed after temporary file sync failed")
	}
	assertSingleUnfinishedMarker(t, manager, rootPath)
}

func TestExportSyncFailurePreservesDestinationAndMarker(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	plainSource := filepath.Join(t.TempDir(), "source.txt")
	if err := os.WriteFile(plainSource, []byte("new payload"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := New(WithDurability(DurabilityNone)).ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(plainSource),
		DestRoot:  root,
		Dest:      "source.txt",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}

	destination := filepath.Join(t.TempDir(), "destination.txt")
	if err := os.WriteFile(destination, []byte("original"), 0644); err != nil {
		t.Fatal(err)
	}
	syncFailure := errors.New("injected plain file sync failure")
	manager := New(WithDurability(DurabilityData))
	manager.syncOSFileHook = func(file *os.File) error {
		if strings.HasSuffix(file.Name(), tempSuffix) {
			return syncFailure
		}
		return file.Sync()
	}
	err := manager.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
		SourceRoot: root,
		Source:     "source.txt",
		Dest:       sec_fs.FullStorePath(destination),
		Overwrite:  true,
	}, nil)
	if !errors.Is(err, syncFailure) {
		t.Fatalf("expected injected sync error, got %v", err)
	}
	assertFileContent(t, destination, "original")
	if _, statErr := os.Stat(destination + tempSuffix); !os.IsNotExist(statErr) {
		t.Fatalf("temporary export file remains after sync failure: %v", statErr)
	}
	markers, listErr := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if listErr != nil {
		t.Fatal(listErr)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationExport {
		t.Fatalf("expected one unfinished export marker, got %+v", markers)
	}
}

func TestImportDirectorySyncFailureKeepsUnfinishedMarker(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	source := filepath.Join(t.TempDir(), "source.txt")
	if err := os.WriteFile(source, []byte("payload"), 0644); err != nil {
		t.Fatal(err)
	}

	manager := New()
	syncFailure := errors.New("injected directory sync failure")
	rootSyncs := 0
	manager.syncDirHook = func(path string) error {
		cleanPath := filepath.Clean(path)
		if cleanPath == filepath.Clean(rootPath) {
			rootSyncs++
			if rootSyncs == 2 {
				return syncFailure
			}
		}
		return nil
	}
	err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(source),
		DestRoot:  root,
		Dest:      "target.txt",
		Overwrite: true,
	}, nil)
	if !errors.Is(err, syncFailure) {
		t.Fatalf("expected injected directory sync error, got %v", err)
	}
	assertSingleUnfinishedMarker(t, manager, rootPath)
}

func openDurabilityTestRoot(t *testing.T) (string, sec_fs.ISecRoot) {
	t.Helper()
	rootPath := filepath.Join(t.TempDir(), "root")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "password")
	if err != nil {
		t.Fatal(err)
	}
	return rootPath, root
}

func assertSingleUnfinishedMarker(t *testing.T, manager *Manager, rootPath string) {
	t.Helper()
	markers, err := manager.ListUnfinishedOperations(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 1 || markers[0].Type != sec_transfer.OperationImport {
		t.Fatalf("expected one unfinished import marker, got %+v", markers)
	}
}
