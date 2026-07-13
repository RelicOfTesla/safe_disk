//go:build !windows

package sec_transfer_v3

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

func TestMarkerAndExportUsePrivateModes(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	manager := New()
	marker := sec_transfer.OperationMarker{
		OpID: "private-mode-marker",
		Type: sec_transfer.OperationImport,
	}
	if err := os.MkdirAll(activeDir(rootPath), 0755); err != nil {
		t.Fatal(err)
	}
	tmpPath := markerPath(rootPath, marker.OpID) + ".tmp"
	if err := os.WriteFile(tmpPath, []byte("old"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := manager.writeMarker(rootPath, marker); err != nil {
		t.Fatal(err)
	}
	assertTransferPerm(t, filepath.Join(rootPath, baseDirName), sec_fs.SecureDirMode)
	assertTransferPerm(t, activeDir(rootPath), sec_fs.SecureDirMode)
	assertTransferPerm(t, markerPath(rootPath, marker.OpID), sec_fs.SecureFileMode)

	plainSource := filepath.Join(t.TempDir(), "source.txt")
	if err := os.WriteFile(plainSource, []byte("secret"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source: sec_fs.FullStorePath(plainSource), DestRoot: root, Dest: "source.txt", Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	exportDir := filepath.Join(t.TempDir(), "private", "nested")
	exportPath := filepath.Join(exportDir, "exported.txt")
	if err := os.MkdirAll(exportDir, sec_fs.SecureDirMode); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(exportPath+tempSuffix, []byte("stale"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := manager.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
		SourceRoot: root, Source: "source.txt", Dest: sec_fs.FullStorePath(exportPath), Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	assertTransferPerm(t, exportDir, sec_fs.SecureDirMode)
	assertTransferPerm(t, exportPath, sec_fs.SecureFileMode)
}

func TestTransferNormalizesSourceModeAndMtime(t *testing.T) {
	rootPath, root := openDurabilityTestRoot(t)
	defer root.Close()
	manager := New()
	source := filepath.Join(t.TempDir(), "executable.sh")
	if err := os.WriteFile(source, []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}
	sourceTime := time.Unix(946684800, 0)
	if err := os.Chtimes(source, sourceTime, sourceTime); err != nil {
		t.Fatal(err)
	}
	if err := manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source: sec_fs.FullStorePath(source), DestRoot: root, Dest: "script.sh", Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	storePath, err := root.GetStorePath("script.sh")
	if err != nil {
		t.Fatal(err)
	}
	storeInfo := assertTransferPerm(t, filepath.Join(rootPath, filepath.FromSlash(string(storePath))), sec_fs.SecureFileMode)
	if storeInfo.ModTime().Equal(sourceTime) {
		t.Fatal("import leaked source mtime to encrypted backing file")
	}

	exportPath := filepath.Join(t.TempDir(), "exported.sh")
	if err := manager.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
		SourceRoot: root, Source: "script.sh", Dest: sec_fs.FullStorePath(exportPath), Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	exportInfo := assertTransferPerm(t, exportPath, sec_fs.SecureFileMode)
	if exportInfo.ModTime().Equal(sourceTime) {
		t.Fatal("export restored source mtime without encrypted metadata")
	}
}

func TestOperationLockProtectsExistingLockFile(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	if err := os.Mkdir(rootPath, sec_fs.SecureDirMode); err != nil {
		t.Fatal(err)
	}
	lockPath, err := operationLockPath(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(lockPath, nil, 0644); err != nil {
		t.Fatal(err)
	}
	lock, err := acquireOperationLock(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := lock.release(); err != nil {
		t.Fatal(err)
	}
	assertTransferPerm(t, lockPath, sec_fs.SecureFileMode)
}

func assertTransferPerm(t *testing.T, path string, want os.FileMode) os.FileInfo {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != want.Perm() {
		t.Fatalf("%s mode = %o, want %o", path, info.Mode().Perm(), want.Perm())
	}
	return info
}
