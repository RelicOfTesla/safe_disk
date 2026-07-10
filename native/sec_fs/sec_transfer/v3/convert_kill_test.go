package sec_transfer_v3

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

func TestConvertKillHelperProcess(t *testing.T) {
	rootPath := os.Getenv("SAFE_DISK_CONVERT_KILL_ROOT")
	checkpointName := os.Getenv("SAFE_DISK_CONVERT_KILL_CHECKPOINT")
	readyPath := os.Getenv("SAFE_DISK_CONVERT_KILL_READY")
	if rootPath == "" || checkpointName == "" || readyPath == "" {
		return
	}
	manager := New()
	manager.checkpointHook = func(name string, _ sec_transfer.OperationMarker) {
		if name != checkpointName {
			return
		}
		if err := os.WriteFile(readyPath, []byte(name), 0600); err != nil {
			panic(err)
		}
		select {}
	}
	kind := sec_transfer.ConvertKind(os.Getenv("SAFE_DISK_CONVERT_KILL_KIND"))
	if kind == "" {
		kind = sec_transfer.ConvertKindEncrypt
	}
	if err := manager.ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
		Kind:      kind,
		RootPath:  rootPath,
		Password:  "kill-test-password",
		Overwrite: true,
	}, nil); err != nil {
		t.Fatal(err)
	}
}

func TestConvertRecoversAfterRealProcessKillAtEveryCheckpoint(t *testing.T) {
	tests := []struct {
		checkpoint string
		action     sec_transfer.RecoverAction
		converted  bool
	}{
		{checkpointCopyingWork, sec_transfer.RecoverActionRerun, false},
		{checkpointVerifyingWork, sec_transfer.RecoverActionRerun, false},
		{checkpointBeforeRootRename, sec_transfer.RecoverActionContinueRename, true},
		{checkpointAfterRootRename, sec_transfer.RecoverActionContinueRename, true},
		{checkpointAfterWorkRename, sec_transfer.RecoverActionCompleted, true},
		{checkpointCompletedMarker, sec_transfer.RecoverActionCompleted, true},
	}
	for _, tt := range tests {
		t.Run(tt.checkpoint, func(t *testing.T) {
			tmp := t.TempDir()
			rootPath := filepath.Join(tmp, "root")
			readyPath := filepath.Join(tmp, "ready")
			if err := os.MkdirAll(filepath.Join(rootPath, "empty-dir"), 0755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(rootPath, "payload.txt"), []byte("kill recovery payload"), 0644); err != nil {
				t.Fatal(err)
			}

			var output bytes.Buffer
			cmd := exec.Command(os.Args[0], "-test.run=^TestConvertKillHelperProcess$")
			cmd.Env = append(os.Environ(),
				"SAFE_DISK_CONVERT_KILL_ROOT="+rootPath,
				"SAFE_DISK_CONVERT_KILL_CHECKPOINT="+tt.checkpoint,
				"SAFE_DISK_CONVERT_KILL_READY="+readyPath,
				"SAFE_DISK_CONVERT_KILL_KIND="+string(sec_transfer.ConvertKindEncrypt),
			)
			cmd.Stdout = &output
			cmd.Stderr = &output
			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}
			stopped := false
			t.Cleanup(func() {
				if !stopped {
					_ = cmd.Process.Kill()
					_ = cmd.Wait()
				}
			})
			waitForFile(t, readyPath, 10*time.Second)
			if err := cmd.Process.Kill(); err != nil {
				t.Fatalf("kill convert helper: %v", err)
			}
			if err := cmd.Wait(); err == nil {
				t.Fatal("killed convert helper exited successfully")
			}
			stopped = true

			recoverCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			result, err := New().RecoverConvert(recoverCtx, rootPath)
			if err != nil {
				t.Fatalf("recover after kill: %v\nhelper output: %s", err, output.String())
			}
			if result.Action != tt.action {
				t.Fatalf("recovery action=%s want=%s: %s", result.Action, tt.action, result.Message)
			}
			if tt.converted {
				assertRecoveredEncryptedRoot(t, rootPath)
			} else {
				assertFileContent(t, filepath.Join(rootPath, "payload.txt"), "kill recovery payload")
				if pathExists(filepath.Join(rootPath, sec_fs.ConfigFileName)) {
					t.Fatal("early kill replaced plain source root")
				}
				assertNoConvertArtifacts(t, rootPath)
			}
		})
	}
}

func TestConvertDecryptRecoversAfterRealProcessKillAtEveryCheckpoint(t *testing.T) {
	tests := []struct {
		checkpoint string
		action     sec_transfer.RecoverAction
		converted  bool
	}{
		{checkpointCopyingWork, sec_transfer.RecoverActionRerun, false},
		{checkpointVerifyingWork, sec_transfer.RecoverActionRerun, false},
		{checkpointBeforeRootRename, sec_transfer.RecoverActionContinueRename, true},
		{checkpointAfterRootRename, sec_transfer.RecoverActionContinueRename, true},
		{checkpointAfterWorkRename, sec_transfer.RecoverActionCompleted, true},
		{checkpointCompletedMarker, sec_transfer.RecoverActionCompleted, true},
	}
	for _, tt := range tests {
		t.Run(tt.checkpoint, func(t *testing.T) {
			tmp := t.TempDir()
			rootPath := filepath.Join(tmp, "root")
			readyPath := filepath.Join(tmp, "ready")
			createKillTestEncryptedRoot(t, rootPath)

			var output bytes.Buffer
			cmd := exec.Command(os.Args[0], "-test.run=^TestConvertKillHelperProcess$")
			cmd.Env = append(os.Environ(),
				"SAFE_DISK_CONVERT_KILL_ROOT="+rootPath,
				"SAFE_DISK_CONVERT_KILL_CHECKPOINT="+tt.checkpoint,
				"SAFE_DISK_CONVERT_KILL_READY="+readyPath,
				"SAFE_DISK_CONVERT_KILL_KIND="+string(sec_transfer.ConvertKindDecrypt),
			)
			cmd.Stdout = &output
			cmd.Stderr = &output
			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}
			stopped := false
			t.Cleanup(func() {
				if !stopped {
					_ = cmd.Process.Kill()
					_ = cmd.Wait()
				}
			})
			waitForFile(t, readyPath, 10*time.Second)
			if err := cmd.Process.Kill(); err != nil {
				t.Fatalf("kill convert helper: %v", err)
			}
			if err := cmd.Wait(); err == nil {
				t.Fatal("killed convert helper exited successfully")
			}
			stopped = true

			recoverCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			result, err := New().RecoverConvert(recoverCtx, rootPath)
			if err != nil {
				t.Fatalf("recover after decrypt kill: %v\nhelper output: %s", err, output.String())
			}
			if result.Action != tt.action {
				t.Fatalf("recovery action=%s want=%s: %s", result.Action, tt.action, result.Message)
			}
			if tt.converted {
				assertRecoveredPlainRoot(t, rootPath)
			} else {
				assertEncryptedRootContent(t, rootPath)
				assertNoConvertArtifacts(t, rootPath)
			}
		})
	}
}

func waitForFile(t *testing.T, path string, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for convert checkpoint %s", path)
}

func assertRecoveredEncryptedRoot(t *testing.T, rootPath string) {
	t.Helper()
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "kill-test-password")
	if err != nil {
		t.Fatalf("recovered root is not encrypted: %v", err)
	}
	file, err := root.OpenFile("payload.txt", os.O_RDONLY)
	if err != nil {
		_ = root.Close()
		t.Fatal(err)
	}
	data, err := os.ReadFile(filepath.Join(rootPath, "payload.txt"))
	if err == nil && string(data) == "kill recovery payload" {
		_ = file.Close()
		_ = root.Close()
		t.Fatal("recovered store contains plaintext payload")
	}
	buffer := make([]byte, len("kill recovery payload"))
	n, readErr := file.Read(buffer)
	_ = file.Close()
	_ = root.Close()
	if readErr != nil && n == 0 {
		t.Fatal(readErr)
	}
	if string(buffer[:n]) != "kill recovery payload" {
		t.Fatalf("unexpected recovered content: %q", string(buffer[:n]))
	}
	backups, err := filepath.Glob(rootPath + ".safe_disk.backup.*")
	if err != nil || len(backups) != 1 {
		t.Fatalf("expected preserved backup, got %v err=%v", backups, err)
	}
	markers, err := findConvertMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("recovery left convert markers: %+v", markers)
	}
}

func createKillTestEncryptedRoot(t *testing.T, rootPath string) {
	t.Helper()
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(rootPath), "kill-test-password", defaultCreateRootOptions()...); err != nil {
		t.Fatal(err)
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "kill-test-password")
	if err != nil {
		t.Fatal(err)
	}
	file, err := root.OpenFile("payload.txt", os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
	if err != nil {
		_ = root.Close()
		t.Fatal(err)
	}
	if _, err := file.Write([]byte("kill recovery payload")); err != nil {
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	if err := root.MkdirAll("empty-dir"); err != nil {
		t.Fatal(err)
	}
	if err := root.Close(); err != nil {
		t.Fatal(err)
	}
}

func assertEncryptedRootContent(t *testing.T, rootPath string) {
	t.Helper()
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(rootPath), "kill-test-password")
	if err != nil {
		t.Fatalf("expected encrypted source root: %v", err)
	}
	file, err := root.OpenFile("payload.txt", os.O_RDONLY)
	if err != nil {
		_ = root.Close()
		t.Fatal(err)
	}
	buffer := make([]byte, len("kill recovery payload"))
	n, readErr := file.Read(buffer)
	_ = file.Close()
	_ = root.Close()
	if readErr != nil && n == 0 {
		t.Fatal(readErr)
	}
	if string(buffer[:n]) != "kill recovery payload" {
		t.Fatalf("unexpected encrypted root content: %q", string(buffer[:n]))
	}
}

func assertRecoveredPlainRoot(t *testing.T, rootPath string) {
	t.Helper()
	assertFileContent(t, filepath.Join(rootPath, "payload.txt"), "kill recovery payload")
	if pathExists(filepath.Join(rootPath, sec_fs.ConfigFileName)) {
		t.Fatal("recovered plain root still contains encryption config")
	}
	backups, err := filepath.Glob(rootPath + ".safe_disk.backup.*")
	if err != nil || len(backups) != 1 {
		t.Fatalf("expected encrypted backup, got %v err=%v", backups, err)
	}
	assertEncryptedRootContent(t, backups[0])
	markers, err := findConvertMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(markers) != 0 {
		t.Fatalf("recovery left convert markers: %+v", markers)
	}
}

func assertNoConvertArtifacts(t *testing.T, rootPath string) {
	t.Helper()
	works, _ := filepath.Glob(rootPath + ".safe_disk.work.*")
	backups, _ := filepath.Glob(rootPath + ".safe_disk.backup.*")
	markers, err := findConvertMarkers(rootPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(works) != 0 || len(backups) != 0 || len(markers) != 0 {
		t.Fatalf("early recovery left artifacts: work=%v backup=%v markers=%+v", works, backups, markers)
	}
}
