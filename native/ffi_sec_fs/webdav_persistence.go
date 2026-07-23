package main

import (
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_webdav"
)

const webDavPersistentStatePath = ".safe_disk.webdav.sessions.json"

type webDavPersistentStore struct{}

func (webDavPersistentStore) root(rootKey string) (sec_fs.ISecRoot, error) {
	if !strings.HasPrefix(rootKey, "root-path:") {
		return nil, sec_webdav.ErrPersistentRecordInvalid
	}
	rootPath := filepath.Clean(strings.TrimPrefix(rootKey, "root-path:"))
	entry, ok := RootStore.Find(func(entry RootEntry) bool {
		return filepath.Clean(entry.RootPath) == rootPath
	})
	if !ok || entry.Root == nil {
		return nil, sec_webdav.ErrPersistentStoreUnavailable
	}
	return entry.Root, nil
}

func (s webDavPersistentStore) Load(rootKey string) ([]sec_webdav.PersistentSession, error) {
	root, err := s.root(rootKey)
	if err != nil {
		return nil, err
	}
	if !root.FileExists(webDavPersistentStatePath) {
		return nil, nil
	}
	file, err := root.OpenFile(webDavPersistentStatePath, os.O_RDONLY)
	if err != nil {
		return nil, err
	}
	data, readErr := io.ReadAll(file)
	closeErr := file.Close()
	if readErr != nil {
		return nil, readErr
	}
	if closeErr != nil {
		return nil, closeErr
	}
	if len(data) == 0 {
		return nil, nil
	}
	var records []sec_webdav.PersistentSession
	if err := json.Unmarshal(data, &records); err != nil {
		return nil, errors.Join(sec_webdav.ErrPersistentRecordInvalid, err)
	}
	return records, nil
}

func (s webDavPersistentStore) Save(rootKey string, records []sec_webdav.PersistentSession) error {
	root, err := s.root(rootKey)
	if err != nil {
		return err
	}
	if len(records) == 0 {
		if !root.FileExists(webDavPersistentStatePath) {
			return nil
		}
		return root.DeleteFile(webDavPersistentStatePath)
	}
	data, err := json.Marshal(records)
	if err != nil {
		return err
	}
	file, err := root.OpenFile(
		webDavPersistentStatePath,
		os.O_WRONLY|os.O_CREATE|os.O_TRUNC,
	)
	if err != nil {
		return err
	}
	if _, err := file.Write(data); err != nil {
		_ = file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return err
	}
	return file.Close()
}
