package sec_transfer_v3

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

func TestOperationLockHelperProcess(t *testing.T) {
	rootPath := os.Getenv("SAFE_DISK_LOCK_HELPER_ROOT")
	if rootPath == "" {
		return
	}
	lock, err := acquireOperationLock(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.release()
	fmt.Println("locked")
	releasePath := os.Getenv("SAFE_DISK_LOCK_HELPER_RELEASE")
	for {
		if _, err := os.Stat(releasePath); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestOperationLockCoordinatesAcrossProcesses(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	releasePath := filepath.Join(tmp, "release")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	cleanupOperationLockFile(t, rootPath)

	cmd := exec.Command(os.Args[0], "-test.run=^TestOperationLockHelperProcess$")
	cmd.Env = append(os.Environ(),
		"SAFE_DISK_LOCK_HELPER_ROOT="+rootPath,
		"SAFE_DISK_LOCK_HELPER_RELEASE="+releasePath,
	)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	helperDone := false
	t.Cleanup(func() {
		if !helperDone {
			_ = os.WriteFile(releasePath, nil, 0600)
			_ = cmd.Wait()
		}
	})
	scanner := bufio.NewScanner(stdout)
	if !scanner.Scan() || scanner.Text() != "locked" {
		t.Fatalf("lock helper did not become ready: %q, err=%v", scanner.Text(), scanner.Err())
	}

	waitCtx, cancel := context.WithTimeout(context.Background(), 80*time.Millisecond)
	defer cancel()
	second, err := acquireOperationLock(waitCtx, rootPath)
	if second != nil {
		_ = second.release()
		t.Fatal("second process acquired an already-held operation lock")
	}
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected lock wait deadline, got %v", err)
	}

	if err := os.WriteFile(releasePath, nil, 0600); err != nil {
		t.Fatal(err)
	}
	if err := cmd.Wait(); err != nil {
		t.Fatal(err)
	}
	helperDone = true

	lock, err := acquireOperationLock(context.Background(), rootPath)
	if err != nil {
		t.Fatalf("lock was not released when helper exited: %v", err)
	}
	if err := lock.release(); err != nil {
		t.Fatal(err)
	}
}

func TestOperationLockDoesNotCreateAdjacentLockFile(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	if err := os.MkdirAll(rootPath, sec_fs.SecureDirMode); err != nil {
		t.Fatal(err)
	}
	lockPath, err := operationLockPath(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(lockPath) })
	if filepath.Dir(lockPath) == filepath.Dir(rootPath) {
		t.Fatalf("transfer lock must not be adjacent to root: %q", lockPath)
	}

	lock, err := acquireOperationLock(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := lock.release(); err != nil {
		t.Fatal(err)
	}
	legacyLocks, err := filepath.Glob(filepath.Join(tmp, ".safe_disk.transfer.*.lock"))
	if err != nil {
		t.Fatal(err)
	}
	if len(legacyLocks) != 0 {
		t.Fatalf("transfer created adjacent lock files: %q", legacyLocks)
	}
}

func TestImportDoesNotLeaveLockAdjacentToRoot(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	sourcePath := filepath.Join(tmp, "source.txt")
	if err := os.WriteFile(sourcePath, []byte("content"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(
		sec_fs.FullStorePath(rootPath),
		"pw",
		defaultCreateRootOptions()...,
	); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "pw")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	if err := New().ImportFile(context.Background(), sec_transfer.ImportFileRequest{
		Source:    sec_fs.FullStorePath(sourcePath),
		DestRoot:  root,
		Dest:      "imported.txt",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
	legacyLocks, err := filepath.Glob(filepath.Join(tmp, ".safe_disk.transfer.*.lock"))
	if err != nil {
		t.Fatal(err)
	}
	if len(legacyLocks) != 0 {
		t.Fatalf("import left adjacent lock files: %q", legacyLocks)
	}
	lockPath, err := operationLockPath(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(lockPath) })
}

func TestImportCanceledWhileWaitingForLockWritesNoMarker(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	sourcePath := filepath.Join(tmp, "source.txt")
	if err := os.WriteFile(sourcePath, []byte("content"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "pw", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	cleanupOperationLockFile(t, rootPath)
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "pw")
	if err != nil {
		t.Fatal(err)
	}
	defer root.Close()

	held, err := acquireOperationLock(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer held.release()
	waitCtx, cancel := context.WithTimeout(context.Background(), 60*time.Millisecond)
	defer cancel()
	err = New().ImportFile(waitCtx, sec_transfer.ImportFileRequest{
		Source: sec_fs.FullStorePath(sourcePath), DestRoot: root, Dest: "dest.txt", Overwrite: true,
	}, nil)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("expected canceled lock wait, got %v", err)
	}
	markers, err := listMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("operation waiting for a lock wrote markers: %+v", markers)
	}
}

func TestOperationLockUsesSameKeyForSymlinkAlias(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	aliasPath := filepath.Join(tmp, "alias")
	if err := os.MkdirAll(rootPath, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(rootPath, aliasPath); err != nil {
		t.Skipf("symlink is unavailable: %v", err)
	}
	realLockPath, err := operationLockPath(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	aliasLockPath, err := operationLockPath(aliasPath)
	if err != nil {
		t.Fatal(err)
	}
	if realLockPath != aliasLockPath {
		t.Fatalf("symlink alias bypasses lock key: %q != %q", realLockPath, aliasLockPath)
	}
}

func cleanupOperationLockFile(t *testing.T, rootPath string) {
	t.Helper()
	lockPath, err := operationLockPath(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Remove(lockPath) })
}
