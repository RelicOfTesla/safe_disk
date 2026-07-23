package main

import (
	"context"
	"fmt"
	"io"
	"io/fs"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_webdav"
)

func WebDavOpen_FFI(rootID int64, exposedPath, displayName string) string {
	return WebDavOpenWithOptions_FFI(rootID, exposedPath, displayName, `{"auth_mode":"bearer"}`)
}

func WebDavOpenWithOptions_FFI(rootID int64, exposedPath, displayName, optionsJSON string) string {
	entry, ok := RootStore.Get(rootID)
	if !ok {
		return ErrorWithCode("root session not found", ErrorCodeRootSessionNotFound)
	}
	options, err := sec_webdav.ParseOpenOptions(optionsJSON)
	if err != nil {
		return errorResponse(err)
	}
	session, err := WebDavManager.OpenWithOptions(
		rootKey(rootID), displayName, exposedPath, rootResourceProvider{root: entry.Root}, options,
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

func WebDavList_FFI(rootID int64) string {
	if _, ok := RootStore.Get(rootID); !ok {
		return ErrorWithCode("root session not found", ErrorCodeRootSessionNotFound)
	}
	return successResponse(WebDavManager.List(rootKey(rootID)))
}

func WebDavMount_FFI(sessionID string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	mounted, err := WebDavManager.Mount(ctx, sessionID)
	if err != nil {
		return errorResponse(err)
	}
	return successResponse(map[string]interface{}{
		"mounted":    true,
		"mount_path": mounted.Path(),
	})
}

func WebDavUnmount_FFI(sessionID string) string {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := WebDavManager.Unmount(ctx, sessionID); err != nil {
		return errorResponse(err)
	}
	return successResponse(map[string]interface{}{"mounted": false})
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
