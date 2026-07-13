package sec_transfer_v3

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"safe_disk/native/sec_fs"
)

const operationLockPollInterval = 20 * time.Millisecond

type operationLock struct {
	file *os.File
}

func acquireOperationLock(ctx context.Context, rootPath string) (*operationLock, error) {
	lockPath, err := operationLockPath(rootPath)
	if err != nil {
		return nil, err
	}
	file, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, sec_fs.SecureFileMode)
	if err != nil {
		return nil, fmt.Errorf("open transfer operation lock: %w", err)
	}
	if err := file.Chmod(sec_fs.SecureFileMode); err != nil {
		_ = file.Close()
		return nil, fmt.Errorf("protect transfer operation lock: %w", err)
	}
	for {
		locked, err := tryLockFile(file)
		if err != nil {
			_ = file.Close()
			return nil, fmt.Errorf("lock transfer operation: %w", err)
		}
		if locked {
			return &operationLock{file: file}, nil
		}

		timer := time.NewTimer(operationLockPollInterval)
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

func (l *operationLock) release() error {
	if l == nil || l.file == nil {
		return nil
	}
	unlockErr := unlockFile(l.file)
	closeErr := l.file.Close()
	l.file = nil
	if unlockErr != nil {
		return fmt.Errorf("unlock transfer operation: %w", unlockErr)
	}
	return closeErr
}

func operationLockPath(rootPath string) (string, error) {
	absPath, err := filepath.Abs(rootPath)
	if err != nil {
		return "", err
	}
	canonicalPath := filepath.Clean(absPath)
	if resolved, resolveErr := filepath.EvalSymlinks(canonicalPath); resolveErr == nil {
		canonicalPath = resolved
	} else {
		parent := filepath.Dir(canonicalPath)
		if resolvedParent, parentErr := filepath.EvalSymlinks(parent); parentErr == nil {
			canonicalPath = filepath.Join(resolvedParent, filepath.Base(canonicalPath))
		}
	}
	digest := sha256.Sum256([]byte(canonicalPath))
	name := ".safe_disk.transfer." + hex.EncodeToString(digest[:8]) + ".lock"
	return filepath.Join(filepath.Dir(canonicalPath), name), nil
}
