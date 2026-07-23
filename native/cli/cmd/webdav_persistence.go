package cmd

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_webdav"
)

const cliWebDavPersistentStatePath = ".safe_disk.webdav.sessions.json"

type cliWebDavPersistentStore struct {
	root sec_fs.ISecRoot
}

func (s cliWebDavPersistentStore) Load(string) ([]sec_webdav.PersistentSession, error) {
	if !s.root.FileExists(cliWebDavPersistentStatePath) {
		return nil, nil
	}
	file, err := s.root.OpenFile(cliWebDavPersistentStatePath, os.O_RDONLY)
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
		return nil, err
	}
	return records, nil
}

func (s cliWebDavPersistentStore) Save(_ string, records []sec_webdav.PersistentSession) error {
	if len(records) == 0 {
		if !s.root.FileExists(cliWebDavPersistentStatePath) {
			return nil
		}
		return s.root.DeleteFile(cliWebDavPersistentStatePath)
	}
	data, err := json.Marshal(records)
	if err != nil {
		return err
	}
	file, err := s.root.OpenFile(
		cliWebDavPersistentStatePath,
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

func cliWebDavRootKey(rootPath string) string {
	return "root-path:" + filepath.Clean(rootPath)
}
