package sec_transfer_v3

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"

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

func writeMarker(rootPath string, marker sec_transfer.OperationMarker) error {
	if marker.Version == 0 {
		marker.Version = markerVersion
	}
	now := time.Now().UTC()
	if marker.CreatedAt.IsZero() {
		marker.CreatedAt = now
	}
	marker.UpdatedAt = now

	if err := os.MkdirAll(activeDir(rootPath), 0755); err != nil {
		return fmt.Errorf("create transfer marker dir: %w", err)
	}

	data, err := json.MarshalIndent(marker, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal marker: %w", err)
	}

	path := markerPath(rootPath, marker.OpID)
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0644); err != nil {
		return fmt.Errorf("write marker: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return fmt.Errorf("commit marker: %w", err)
	}
	return nil
}

func removeMarker(rootPath, opID string) error {
	err := os.Remove(markerPath(rootPath, opID))
	if os.IsNotExist(err) {
		return nil
	}
	return err
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
