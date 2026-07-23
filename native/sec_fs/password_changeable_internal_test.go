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

func TestRootConfigCommitKillHelperProcess(t *testing.T) {
	rootPath := os.Getenv("SAFE_DISK_ROOT_CONFIG_COMMIT_KILL_ROOT")
	point := rootConfigCommitPoint(os.Getenv("SAFE_DISK_ROOT_CONFIG_COMMIT_KILL_POINT"))
	if rootPath == "" || point == "" {
		return
	}
	rootConfigCommitHook = func(current rootConfigCommitPoint) {
		if current != point {
			return
		}
		fmt.Println(current)
		for {
			time.Sleep(time.Second)
		}
	}
	defer func() { rootConfigCommitHook = nil }()
	if err := ChangeRootPasswordQuick(FullStorePath(rootPath), "old-password", "new-password"); err != nil {
		t.Fatal(err)
	}
}

func TestRootConfigCommitSurvivesProcessKillAtRenameBoundaries(t *testing.T) {
	for _, point := range []rootConfigCommitPoint{
		rootConfigCommitBeforeRename,
		rootConfigCommitAfterRename,
	} {
		t.Run(string(point), func(t *testing.T) {
			rootPath := FullStorePath(filepath.Join(t.TempDir(), "root"))
			_, _, err := CreateRootConfigQuick(
				rootPath,
				"old-password",
				WithDataFactory("AES-CTR"),
				WithNameFactory("AES-256-GCM"),
				WithDeriverFactory("PBKDF2"),
				WithKeyStrengthMs(1),
				WithPasswordChangeable(true),
			)
			require.NoError(t, err)
			configPath := filepath.Join(string(rootPath), ConfigFileName)
			original, err := os.ReadFile(configPath)
			require.NoError(t, err)

			cmd := exec.Command(os.Args[0], "-test.run=^TestRootConfigCommitKillHelperProcess$")
			cmd.Env = append(os.Environ(),
				"SAFE_DISK_ROOT_CONFIG_COMMIT_KILL_ROOT="+string(rootPath),
				"SAFE_DISK_ROOT_CONFIG_COMMIT_KILL_POINT="+string(point),
			)
			stdout, err := cmd.StdoutPipe()
			require.NoError(t, err)
			cmd.Stderr = os.Stderr
			require.NoError(t, cmd.Start())
			helperDone := false
			t.Cleanup(func() {
				if !helperDone && cmd.Process != nil {
					_ = cmd.Process.Kill()
					_ = cmd.Wait()
				}
			})
			scanner := bufio.NewScanner(stdout)
			require.True(t, scanner.Scan(), "commit helper did not reach %s", point)
			require.Equal(t, string(point), scanner.Text())
			require.NoError(t, cmd.Process.Kill())
			require.Error(t, cmd.Wait())
			helperDone = true

			if point == rootConfigCommitBeforeRename {
				current, readErr := os.ReadFile(configPath)
				require.NoError(t, readErr)
				require.True(t, bytes.Equal(original, current), "config changed before rename")
				requireRootPasswordWorks(t, rootPath, "old-password")
				requireRootPasswordFails(t, rootPath, "new-password")
				return
			}
			requireRootPasswordFails(t, rootPath, "old-password")
			requireRootPasswordWorks(t, rootPath, "new-password")
		})
	}
}

func requireRootPasswordWorks(t *testing.T, rootPath FullStorePath, password string) {
	t.Helper()
	root, err := OpenRootQuick(rootPath, password)
	require.NoError(t, err)
	require.NoError(t, root.Close())
}

func requireRootPasswordFails(t *testing.T, rootPath FullStorePath, password string) {
	t.Helper()
	root, err := OpenRootQuick(rootPath, password)
	require.Nil(t, root)
	require.ErrorIs(t, err, ErrInvalidPassword)
}
