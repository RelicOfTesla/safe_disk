package main

import (
	"fmt"
	"io"
	"io/fs"

	"safe_disk/native/sec_fs"
)

func WebDavOpen_FFI(rootID int64, exposedPath, displayName string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return ErrorWithCode("root session not found", ErrorCodeRootSessionNotFound)
	}
	session, err := WebDavManager.Open(
		rootKey(rootID),
		displayName,
		exposedPath,
		rootResourceProvider{root: entry.Root},
	)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(session)
}

func WebDavClose_FFI(sessionID string) string {
	WebDavManager.Revoke(sessionID)
	return Success()
}

type rootResourceProvider struct {
	root sec_fs.ISecRoot
}

func (p rootResourceProvider) Stat(path string) (fs.FileInfo, error) {
	return p.root.Stat(sec_fs.RelativeViewPath(path))
}

func (p rootResourceProvider) ReadDir(path string) ([]fs.DirEntry, error) {
	return p.root.ReadDir(path)
}

func (p rootResourceProvider) Open(path string) (io.ReadCloser, fs.FileInfo, error) {
	file, err := p.root.Open(path)
	if err != nil {
		return nil, nil, err
	}
	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, nil, err
	}
	return file, info, nil
}

func rootKey(rootID int64) string {
	return fmt.Sprintf("root:%d", rootID)
}
