package sec_transfer_v3

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

const (
	markerVersion = 3
	baseDirName   = ".transfer_v3"
	activeDirName = "active"
)

func activeDir(rootPath string) string {
	return filepath.Join(rootPath, baseDirName, activeDirName)
}

func markerPath(rootPath, opID string) string {
	return filepath.Join(activeDir(rootPath), opID+".json")
}

func validateOpID(opID string) error {
	if opID == "" {
		return fmt.Errorf("operation id is required")
	}
	if strings.ContainsAny(opID, `/\\`) || opID == "." || opID == ".." {
		return fmt.Errorf("invalid operation id: %q", opID)
	}
	for _, char := range opID {
		if (char < 'a' || char > 'z') && (char < 'A' || char > 'Z') &&
			(char < '0' || char > '9') && char != '-' && char != '_' {
			return fmt.Errorf("invalid operation id: %q", opID)
		}
	}
	return nil
}

func writeMarker(rootPath string, marker sec_transfer.OperationMarker) error {
	return New().writeMarker(rootPath, marker)
}

func (m *Manager) writeMarker(rootPath string, marker sec_transfer.OperationMarker) error {
	if err := validateOpID(marker.OpID); err != nil {
		return err
	}
	if marker.Version == 0 {
		marker.Version = markerVersion
	}
	now := time.Now().UTC()
	if marker.CreatedAt.IsZero() {
		marker.CreatedAt = now
	}
	marker.UpdatedAt = now

	if err := os.MkdirAll(activeDir(rootPath), sec_fs.SecureDirMode); err != nil {
		return fmt.Errorf("create transfer marker dir: %w", err)
	}
	for _, path := range []string{filepath.Join(rootPath, baseDirName), activeDir(rootPath)} {
		if err := os.Chmod(path, sec_fs.SecureDirMode); err != nil {
			return fmt.Errorf("protect transfer marker dir: %w", err)
		}
	}

	data, err := json.MarshalIndent(marker, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal marker: %w", err)
	}

	path := markerPath(rootPath, marker.OpID)
	tmp := path + ".tmp"
	file, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, sec_fs.SecureFileMode)
	if err != nil {
		return fmt.Errorf("write marker: %w", err)
	}
	if err := file.Chmod(sec_fs.SecureFileMode); err != nil {
		_ = file.Close()
		_ = os.Remove(tmp)
		return fmt.Errorf("protect marker: %w", err)
	}
	_, writeErr := file.Write(data)
	if writeErr != nil {
		_ = file.Close()
		_ = os.Remove(tmp)
		return fmt.Errorf("write marker: %w", writeErr)
	}
	syncErr := m.syncOSFile(file)
	closeErr := file.Close()
	if syncErr != nil || closeErr != nil {
		_ = os.Remove(tmp)
		if syncErr != nil {
			return fmt.Errorf("sync marker: %w", syncErr)
		}
		return fmt.Errorf("close marker: %w", closeErr)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("commit marker: %w", err)
	}
	if err := m.syncDir(activeDir(rootPath)); err != nil {
		return fmt.Errorf("sync marker directory: %w", err)
	}
	if err := m.syncDir(filepath.Join(rootPath, baseDirName)); err != nil {
		return fmt.Errorf("sync marker base directory: %w", err)
	}
	if err := m.syncDir(rootPath); err != nil {
		return fmt.Errorf("sync marker root directory: %w", err)
	}
	return nil
}

func removeMarker(rootPath, opID string) error {
	return New().removeMarker(rootPath, opID)
}

func (m *Manager) removeMarker(rootPath, opID string) error {
	if err := validateOpID(opID); err != nil {
		return err
	}
	err := os.Remove(markerPath(rootPath, opID))
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := m.syncDir(activeDir(rootPath)); err != nil {
		return fmt.Errorf("sync marker directory: %w", err)
	}
	return nil
}

func readMarker(path string) (sec_transfer.OperationMarker, error) {
	var marker sec_transfer.OperationMarker
	data, err := os.ReadFile(path)
	if err != nil {
		return marker, err
	}
	if err := json.Unmarshal(data, &marker); err != nil {
		return marker, err
	}
	return marker, nil
}

func listMarkers(rootPath string) ([]sec_transfer.OperationMarker, error) {
	entries, err := os.ReadDir(activeDir(rootPath))
	if os.IsNotExist(err) || errors.Is(err, syscall.ENOTDIR) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	markers := make([]sec_transfer.OperationMarker, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		marker, err := readMarker(filepath.Join(activeDir(rootPath), entry.Name()))
		if err != nil {
			continue
		}
		markers = append(markers, marker)
	}
	return markers, nil
}
