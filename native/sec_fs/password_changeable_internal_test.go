package sec_fs

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCommitStagedRootConfigKeepsOriginalWhenReplaceFails(t *testing.T) {
	rootPath := filepath.Join(t.TempDir(), "root")
	require.NoError(t, os.Mkdir(rootPath, SecureDirMode))
	configPath := filepath.Join(rootPath, ConfigFileName)
	original := []byte(`{"sec_key_envelope_version":1,"value":"old"}`)
	require.NoError(t, os.WriteFile(configPath, original, 0o600))

	stagedPath, _, err := stageRootConfig(configPath)
	require.NoError(t, err)
	defer os.Remove(stagedPath)

	require.NoError(t, os.Chmod(rootPath, 0o500))
	err = commitStagedRootConfig(stagedPath, configPath)
	require.Error(t, err)
	require.NoError(t, os.Chmod(rootPath, SecureDirMode))

	current, err := os.ReadFile(configPath)
	require.NoError(t, err)
	require.True(t, bytes.Equal(original, current), "failed replace changed config")
}

func TestRootConfigLockHelperProcess(t *testing.T) {
	rootPath := os.Getenv("SAFE_DISK_ROOT_CONFIG_LOCK_HELPER_ROOT")
	if rootPath == "" {
		return
	}
	lock, err := acquireRootConfigLock(context.Background(), rootPath)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.release()
	fmt.Println("locked")
	releasePath := os.Getenv("SAFE_DISK_ROOT_CONFIG_LOCK_HELPER_RELEASE")
	for {
		if _, err := os.Stat(releasePath); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func TestRootConfigLockCoordinatesAcrossProcesses(t *testing.T) {
	tmp := t.TempDir()
	rootPath := filepath.Join(tmp, "root")
	releasePath := filepath.Join(tmp, "release")
	require.NoError(t, os.Mkdir(rootPath, SecureDirMode))
	lockPath, err := rootConfigLockPath(rootPath)
	require.NoError(t, err)
	defer os.Remove(lockPath)

	cmd := exec.Command(os.Args[0], "-test.run=^TestRootConfigLockHelperProcess$")
	cmd.Env = append(os.Environ(),
		"SAFE_DISK_ROOT_CONFIG_LOCK_HELPER_ROOT="+rootPath,
		"SAFE_DISK_ROOT_CONFIG_LOCK_HELPER_RELEASE="+releasePath,
	)
	stdout, err := cmd.StdoutPipe()
	require.NoError(t, err)
	cmd.Stderr = os.Stderr
	require.NoError(t, cmd.Start())
	helperDone := false
	t.Cleanup(func() {
		if !helperDone {
			_ = os.WriteFile(releasePath, nil, SecureFileMode)
			_ = cmd.Wait()
		}
	})
	scanner := bufio.NewScanner(stdout)
	require.True(t, scanner.Scan(), "lock helper did not become ready")
	require.Equal(t, "locked", scanner.Text())

	waitCtx, cancel := context.WithTimeout(context.Background(), 80*time.Millisecond)
	defer cancel()
	second, err := acquireRootConfigLock(waitCtx, rootPath)
	if second != nil {
		_ = second.release()
		t.Fatal("second process acquired an already-held root config lock")
	}
	require.True(t, errors.Is(err, context.DeadlineExceeded), "unexpected lock wait error: %v", err)

	require.NoError(t, os.WriteFile(releasePath, nil, SecureFileMode))
	require.NoError(t, cmd.Wait())
	helperDone = true

	lock, err := acquireRootConfigLock(context.Background(), rootPath)
	require.NoError(t, err)
	require.NoError(t, lock.release())
	require.NotEqual(t, filepath.Dir(lockPath), filepath.Dir(rootPath))
}
