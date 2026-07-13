package sec_transfer_v3

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

// DurabilityLevel controls which transfer commit points are explicitly synced.
type DurabilityLevel = sec_transfer.DurabilityLevel

const (
	DurabilityNone = sec_transfer.DurabilityNone
	DurabilityData = sec_transfer.DurabilityData
	DurabilityFull = sec_transfer.DurabilityFull
)

// Option configures a transfer manager.
type Option func(*Manager)

// WithDurability selects the transfer durability policy. The default is full.
func WithDurability(level DurabilityLevel) Option {
	return func(manager *Manager) {
		manager.durability = level
	}
}

func (m *Manager) withDurability(level sec_transfer.DurabilityLevel) *Manager {
	if level == "" || level == m.durability {
		return m
	}
	operationManager := *m
	operationManager.durability = level
	return &operationManager
}

func (m *Manager) validateDurability() error {
	switch m.durability {
	case DurabilityNone, DurabilityData, DurabilityFull:
		return nil
	default:
		return fmt.Errorf("unsupported durability level: %q", m.durability)
	}
}

func (m *Manager) syncSecFile(file sec_fs.ISecFile) error {
	if m.durability == DurabilityNone {
		return nil
	}
	if m.syncSecFileHook != nil {
		return m.syncSecFileHook(file)
	}
	return file.Sync()
}

func (m *Manager) syncOSFile(file *os.File) error {
	if m.durability == DurabilityNone {
		return nil
	}
	if m.syncOSFileHook != nil {
		return m.syncOSFileHook(file)
	}
	return file.Sync()
}

func (m *Manager) syncDir(path string) error {
	if m.durability != DurabilityFull {
		return nil
	}
	if m.syncDirHook != nil {
		return m.syncDirHook(path)
	}
	return syncDirectory(path)
}

func (m *Manager) syncRootEntryParent(root sec_fs.ISecRoot, viewPath sec_fs.RelativeViewPath) error {
	if m.durability != DurabilityFull {
		return nil
	}
	storePath, err := root.GetStorePath(viewPath)
	if err != nil {
		return fmt.Errorf("resolve secure destination for sync: %w", err)
	}
	fullPath := filepath.Join(string(root.GetRootPath()), filepath.FromSlash(string(storePath)))
	return m.syncDir(filepath.Dir(fullPath))
}

func protectRootEntry(root sec_fs.ISecRoot, viewPath sec_fs.RelativeViewPath) error {
	storePath, err := root.GetStorePath(viewPath)
	if err != nil {
		return fmt.Errorf("resolve secure entry for chmod: %w", err)
	}
	fullPath := filepath.Join(string(root.GetRootPath()), filepath.FromSlash(string(storePath)))
	if err := os.Chmod(fullPath, sec_fs.SecureFileMode); err != nil {
		return fmt.Errorf("protect secure entry: %w", err)
	}
	return nil
}

func (m *Manager) renameRootEntry(root sec_fs.ISecRoot, oldPath, newPath sec_fs.RelativeViewPath) error {
	if err := root.Rename(oldPath, newPath); err != nil {
		return err
	}
	if err := m.syncRootEntryParent(root, newPath); err != nil {
		return fmt.Errorf("sync secure rename parent: %w", err)
	}
	return nil
}

func (m *Manager) deleteRootEntry(root sec_fs.ISecRoot, path sec_fs.RelativeViewPath) error {
	if err := root.DeleteFile(path); err != nil {
		return err
	}
	if err := m.syncRootEntryParent(root, path); err != nil {
		return fmt.Errorf("sync secure delete parent: %w", err)
	}
	return nil
}

func (m *Manager) mkdirAllRoot(root sec_fs.ISecRoot, path sec_fs.RelativeViewPath) error {
	if err := root.MkdirAll(path); err != nil {
		return err
	}
	if m.durability != DurabilityFull || path == "" {
		return nil
	}
	parts := strings.FieldsFunc(filepath.ToSlash(string(path)), func(char rune) bool { return char == '/' })
	for index := range parts {
		viewPath := sec_fs.RelativeViewPath(strings.Join(parts[:index+1], "/"))
		storePath, err := root.GetStorePath(viewPath)
		if err != nil {
			return fmt.Errorf("resolve secure directory for sync: %w", err)
		}
		fullPath := filepath.Join(string(root.GetRootPath()), filepath.FromSlash(string(storePath)))
		if err := m.syncDir(fullPath); err != nil {
			return fmt.Errorf("sync secure directory: %w", err)
		}
		if err := m.syncDir(filepath.Dir(fullPath)); err != nil {
			return fmt.Errorf("sync secure directory parent: %w", err)
		}
	}
	return nil
}

func (m *Manager) mkdirAllPath(path string, mode os.FileMode) error {
	cleanPath := filepath.Clean(path)
	missing := make([]string, 0)
	for current := cleanPath; ; current = filepath.Dir(current) {
		_, err := os.Stat(current)
		if err == nil {
			break
		}
		if !os.IsNotExist(err) {
			return err
		}
		missing = append(missing, current)
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
	}
	if err := os.MkdirAll(path, mode); err != nil {
		return err
	}
	if m.durability != DurabilityFull {
		return nil
	}
	for _, directory := range missing {
		if err := m.syncDir(directory); err != nil {
			return fmt.Errorf("sync directory: %w", err)
		}
		if err := m.syncDir(filepath.Dir(directory)); err != nil {
			return fmt.Errorf("sync directory parent: %w", err)
		}
	}
	return nil
}

func (m *Manager) renamePath(oldPath, newPath string) error {
	if err := os.Rename(oldPath, newPath); err != nil {
		return err
	}
	if err := m.syncDir(filepath.Dir(newPath)); err != nil {
		return fmt.Errorf("sync rename parent: %w", err)
	}
	return nil
}

func (m *Manager) removePath(path string) error {
	err := os.Remove(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := m.syncDir(filepath.Dir(path)); err != nil {
		return fmt.Errorf("sync remove parent: %w", err)
	}
	return nil
}

func (m *Manager) removeAllPath(path string) error {
	if err := os.RemoveAll(path); err != nil {
		return err
	}
	if err := m.syncDir(filepath.Dir(path)); err != nil {
		return fmt.Errorf("sync remove-all parent: %w", err)
	}
	return nil
}
