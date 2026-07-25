package sec_webdav

import (
	"context"
	"errors"
	"io"
	"os"

	"golang.org/x/net/webdav"
)

var errWebDAVReadOnly = errors.New("webdav session is read-only")

// secureFileSystem adapts a selected secure subtree to x/net/webdav.
type secureFileSystem struct {
	provider    ResourceProvider
	base        string
	writePolicy WritePolicy
}

func newSecureFileSystem(provider ResourceProvider, base string, writePolicy WritePolicy) *secureFileSystem {
	return &secureFileSystem{provider: provider, base: base, writePolicy: writePolicy}
}

func (f *secureFileSystem) resolve(name string) (string, error) {
	relative, err := cleanRelativePath(name)
	if err != nil {
		return "", err
	}
	return joinSecurePath(f.base, relative), nil
}

func (f *secureFileSystem) Mkdir(_ context.Context, name string, _ os.FileMode) error {
	if f.writePolicy == WritePolicyReadOnly {
		return errWebDAVReadOnly
	}
	resolved, err := f.resolve(name)
	if err != nil {
		return err
	}
	return f.provider.Mkdir(resolved)
}

func (f *secureFileSystem) OpenFile(_ context.Context, name string, flag int, _ os.FileMode) (webdav.File, error) {
	isWrite := flag&(os.O_WRONLY|os.O_RDWR|os.O_CREATE|os.O_TRUNC) != 0
	if isWrite && f.writePolicy == WritePolicyReadOnly {
		return nil, errWebDAVReadOnly
	}

	resolved, err := f.resolve(name)
	if err != nil {
		return nil, err
	}

	if isWrite {
		w, err := f.provider.Create(resolved)
		if err != nil {
			return nil, err
		}
		return &secureWebDAVFile{
			writer: w,
		}, nil
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

func (f *secureFileSystem) RemoveAll(_ context.Context, name string) error {
	if f.writePolicy == WritePolicyReadOnly {
		return errWebDAVReadOnly
	}
	resolved, err := f.resolve(name)
	if err != nil {
		return err
	}
	return f.provider.RemoveAll(resolved)
}

func (f *secureFileSystem) Rename(_ context.Context, oldName, newName string) error {
	if f.writePolicy == WritePolicyReadOnly {
		return errWebDAVReadOnly
	}
	oldResolved, err := f.resolve(oldName)
	if err != nil {
		return err
	}
	newResolved, err := f.resolve(newName)
	if err != nil {
		return err
	}
	return f.provider.Rename(oldResolved, newResolved)
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
	writer  io.WriteCloser
	closer  io.Closer
	info    os.FileInfo
	entries []os.FileInfo
	offset  int
}

func (f *secureWebDAVFile) Close() error {
	if f.writer != nil {
		return f.writer.Close()
	}
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

func (f *secureWebDAVFile) Write(p []byte) (int, error) {
	if f.writer == nil {
		return 0, errWebDAVReadOnly
	}
	return f.writer.Write(p)
}
