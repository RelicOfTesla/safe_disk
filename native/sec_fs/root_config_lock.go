package sec_fs

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

const rootConfigLockPollInterval = 20 * time.Millisecond

type rootConfigLock struct {
	file *os.File
}

func acquireRootConfigLock(ctx context.Context, rootPath string) (*rootConfigLock, error) {
	lockPath, err := rootConfigLockPath(rootPath)
	if err != nil {
		return nil, err
	}
	file, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, SecureFileMode)
	if err != nil {
		return nil, fmt.Errorf("open root config lock: %w", err)
	}
	if err := file.Chmod(SecureFileMode); err != nil {
		_ = file.Close()
		return nil, fmt.Errorf("protect root config lock: %w", err)
	}
	for {
		locked, err := tryLockRootConfigFile(file)
		if err != nil {
			_ = file.Close()
			return nil, fmt.Errorf("lock root config: %w", err)
		}
		if locked {
			return &rootConfigLock{file: file}, nil
		}
		timer := time.NewTimer(rootConfigLockPollInterval)
		select {
		case <-ctx.Done():
			if !timer.Stop() {
				<-timer.C
			}
			_ = file.Close()
			return nil, ctx.Err()
		case <-timer.C:
		}
	}
}

func (l *rootConfigLock) release() error {
	if l == nil || l.file == nil {
		return nil
	}
	unlockErr := unlockRootConfigFile(l.file)
	closeErr := l.file.Close()
	l.file = nil
	if unlockErr != nil {
		return fmt.Errorf("unlock root config: %w", unlockErr)
	}
	return closeErr
}

func rootConfigLockPath(rootPath string) (string, error) {
	absPath, err := filepath.Abs(rootPath)
	if err != nil {
		return "", err
	}
	canonicalPath := filepath.Clean(absPath)
	if resolved, resolveErr := filepath.EvalSymlinks(canonicalPath); resolveErr == nil {
		canonicalPath = resolved
	} else if parent, parentErr := filepath.EvalSymlinks(filepath.Dir(canonicalPath)); parentErr == nil {
		canonicalPath = filepath.Join(parent, filepath.Base(canonicalPath))
	}
	digest := sha256.Sum256([]byte(canonicalPath))
	cacheDir, err := os.UserCacheDir()
	if err != nil {
		return "", fmt.Errorf("resolve root config lock cache directory: %w", err)
	}
	lockDir := filepath.Join(cacheDir, "safe_disk", "root-config-locks")
	if err := os.MkdirAll(lockDir, SecureDirMode); err != nil {
		return "", fmt.Errorf("create root config lock cache directory: %w", err)
	}
	if err := os.Chmod(lockDir, SecureDirMode); err != nil {
		return "", fmt.Errorf("protect root config lock cache directory: %w", err)
	}
	return filepath.Join(lockDir, ".safe_disk.root-config."+hex.EncodeToString(digest[:8])+".lock"), nil
}
