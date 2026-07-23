package sec_webdav

import (
	"context"
	"errors"
	"io"
	"os"

	"golang.org/x/net/webdav"
)

var errWebDAVReadOnly = errors.New("webdav session is read-only")

// secureFileSystem adapts a selected secure subtree to x/net/webdav without
// exposing the native storage path or allowing the handler to write through it.
type secureFileSystem struct {
	provider ResourceProvider
	base     string
}

func newSecureFileSystem(provider ResourceProvider, base string) *secureFileSystem {
	return &secureFileSystem{provider: provider, base: base}
}

func (f *secureFileSystem) resolve(name string) (string, error) {
	relative, err := cleanRelativePath(name)
	if err != nil {
		return "", err
	}
	return joinSecurePath(f.base, relative), nil
}

func (f *secureFileSystem) Mkdir(context.Context, string, os.FileMode) error {
	return errWebDAVReadOnly
}

func (f *secureFileSystem) OpenFile(_ context.Context, name string, flag int, _ os.FileMode) (webdav.File, error) {
	if flag != os.O_RDONLY {
		return nil, errWebDAVReadOnly
	}
	resolved, err := f.resolve(name)
	if err != nil {
		return nil, err
	}
	info, err := f.provider.Stat(resolved)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		entries, err := f.provider.ReadDir(resolved)
		if err != nil {
			return nil, err
		}
		infos := make([]os.FileInfo, 0, len(entries))
		for _, entry := range entries {
			entryInfo, err := entry.Info()
			if err != nil {
				return nil, err
			}
			infos = append(infos, entryInfo)
		}
		return &secureWebDAVFile{info: info, entries: infos}, nil
	}

	file, openedInfo, err := f.provider.Open(resolved)
	if err != nil {
		return nil, err
	}
	reader, ok := file.(io.ReadSeeker)
	if !ok {
		_ = file.Close()
		return nil, errors.New("webdav secure file is not seekable")
	}
	if openedInfo == nil {
		openedInfo = info
	}
	return &secureWebDAVFile{
		reader: reader,
		closer: file,
		info:   openedInfo,
	}, nil
}

func (f *secureFileSystem) RemoveAll(context.Context, string) error {
	return errWebDAVReadOnly
}

func (f *secureFileSystem) Rename(context.Context, string, string) error {
	return errWebDAVReadOnly
}

func (f *secureFileSystem) Stat(_ context.Context, name string) (os.FileInfo, error) {
	resolved, err := f.resolve(name)
	if err != nil {
		return nil, err
	}
	return f.provider.Stat(resolved)
}

type secureWebDAVFile struct {
	reader  io.ReadSeeker
	closer  io.Closer
	info    os.FileInfo
	entries []os.FileInfo
	offset  int
}

func (f *secureWebDAVFile) Close() error {
	if f.closer == nil {
		return nil
	}
	return f.closer.Close()
}

func (f *secureWebDAVFile) Read(p []byte) (int, error) {
	if f.reader == nil {
		return 0, os.ErrInvalid
	}
	return f.reader.Read(p)
}

func (f *secureWebDAVFile) Seek(offset int64, whence int) (int64, error) {
	if f.reader == nil {
		return 0, os.ErrInvalid
	}
	return f.reader.Seek(offset, whence)
}

func (f *secureWebDAVFile) Readdir(count int) ([]os.FileInfo, error) {
	if f.entries == nil {
		return nil, os.ErrInvalid
	}
	remaining := len(f.entries) - f.offset
	if remaining == 0 && count > 0 {
		return nil, io.EOF
	}
	if count > 0 && remaining > count {
		remaining = count
	}
	result := append([]os.FileInfo(nil), f.entries[f.offset:f.offset+remaining]...)
	f.offset += remaining
	return result, nil
}

func (f *secureWebDAVFile) Stat() (os.FileInfo, error) {
	if f.info == nil {
		return nil, os.ErrInvalid
	}
	return f.info, nil
}

func (f *secureWebDAVFile) Write([]byte) (int, error) {
	return 0, errWebDAVReadOnly
}
