package test_utils

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"safe_disk/native/config"
	"safe_disk/native/sec_fs"
	"testing"
)

// ==================== Mock ISecRoot for Advanced Tests ====================

// mockSecRoot is a mock implementation of ISecRoot for testing edge cases.
type mockSecRoot struct {
	rootPath    string
	files       map[string][]byte
	directories map[string]bool
	failOnOp    string // Operation to fail on
	t           *testing.T
}

var _ sec_fs.ISecRoot = (*mockSecRoot)(nil)

func NewMemMockSecRoot(t *testing.T, rootPath string) *mockSecRoot {
	return &mockSecRoot{
		rootPath:    rootPath,
		files:       make(map[string][]byte),
		directories: make(map[string]bool),
		t:           t,
	}
}

func (m *mockSecRoot) OpenFile(path sec_fs.RelativeViewPath, mode int) (sec_fs.ISecFile, error) {
	if m.failOnOp == "OpenFile" {
		return nil, fmt.Errorf("mock error: OpenFile")
	}
	return &mockSecFile{path: string(path), root: m}, nil
}

func (m *mockSecRoot) Close() error { return nil }

func (m *mockSecRoot) DeleteFile(path sec_fs.RelativeViewPath) error {
	if m.failOnOp == "DeleteFile" {
		return fmt.Errorf("mock error: DeleteFile")
	}
	delete(m.files, string(path))
	return nil
}

func (m *mockSecRoot) FileExists(path sec_fs.RelativeViewPath) bool {
	_, exists := m.files[string(path)]
	return exists
}

func (m *mockSecRoot) MkdirAll(path sec_fs.RelativeViewPath) error {
	m.directories[string(path)] = true
	return nil
}

func (m *mockSecRoot) WalkDir(path sec_fs.RelativeViewPath, opts ...sec_fs.WalkOption) (sec_fs.IDirWalker, error) {
	return &mockWalker{root: m}, nil
}

func (m *mockSecRoot) Rename(oldPath, newPath sec_fs.RelativeViewPath) error {
	if m.failOnOp == "Rename" {
		return fmt.Errorf("mock error: Rename")
	}
	content, exists := m.files[string(oldPath)]
	if exists {
		delete(m.files, string(oldPath))
		m.files[string(newPath)] = content
	}
	return nil
}

func (m *mockSecRoot) RenameByStorePath(oldPath, newPath sec_fs.RelativeStorePath) error {
	if m.failOnOp == "RenameByStorePath" {
		return fmt.Errorf("mock error: RenameByStorePath")
	}
	// For mock, store path is the same as view path
	return m.Rename(sec_fs.RelativeViewPath(oldPath), sec_fs.RelativeViewPath(newPath))
}

func (m *mockSecRoot) GetStorePath(viewPath sec_fs.RelativeViewPath) (sec_fs.RelativeStorePath, error) {
	// For mock, store path is the same as view path
	return sec_fs.RelativeStorePath(viewPath), nil
}

func (m *mockSecRoot) GetRootPath() sec_fs.FullStorePath {
	return sec_fs.FullStorePath(m.rootPath)
}

func (m *mockSecRoot) GetConfig() config.SharedConfig { return nil }

// Open implements [sec_fs.ISecRoot].
func (m *mockSecRoot) Open(name string) (fs.File, error) {
	return nil, fmt.Errorf("not implemented")
}

// ReadDir implements [sec_fs.ISecRoot].
func (m *mockSecRoot) ReadDir(name string) ([]fs.DirEntry, error) {
	return nil, fmt.Errorf("not implemented")
}
func (m *mockSecRoot) Stat(name sec_fs.RelativeViewPath) (os.FileInfo, error) {
	return nil, fmt.Errorf("not implemented")
}

// mockSecFile is a mock implementation of ISecFile.
type mockSecFile struct {
	path   string
	root   *mockSecRoot
	data   []byte
	offset int64
}

var _ sec_fs.ISecFile = (*mockSecFile)(nil)

func (f *mockSecFile) Read(p []byte) (n int, err error) {
	if f.offset >= int64(len(f.data)) {
		return 0, io.EOF
	}
	n = copy(p, f.data[f.offset:])
	f.offset += int64(n)
	return n, nil
}

func (f *mockSecFile) Write(p []byte) (n int, err error) {
	f.data = append(f.data, p...)
	f.root.files[f.path] = f.data
	return len(p), nil
}

func (f *mockSecFile) Seek(offset int64, whence int) (int64, error) {
	return 0, fmt.Errorf("not implemented")
}

func (f *mockSecFile) Close() error { return nil }

func (f *mockSecFile) Stat() (os.FileInfo, error) {
	return nil, fmt.Errorf("not implemented")
}

func (f *mockSecFile) Size() int64 { return int64(len(f.data)) }

func (f *mockSecFile) Truncate(size int64) error {
	f.data = f.data[:size]
	return nil
}

func (f *mockSecFile) Sync() error { return nil }

// mockWalker is a mock implementation of IDirWalker.
type mockWalker struct {
	root  *mockSecRoot
	files []string
	index int
}

var _ sec_fs.IDirWalker = (*mockWalker)(nil)

func (w *mockWalker) Next() (sec_fs.IDirEntry, error) {
	if w.files == nil {
		w.files = make([]string, 0)
		for path := range w.root.files {
			w.files = append(w.files, path)
		}
	}
	if w.index >= len(w.files) {
		return nil, io.EOF
	}
	path := w.files[w.index]
	w.index++
	return &mockEntry{path: path}, nil
}

func (w *mockWalker) NextBatch(batchSize int) ([]sec_fs.IDirEntry, error) {
	return nil, fmt.Errorf("not implemented")
}

func (w *mockWalker) HasNext() bool {
	return w.index < len(w.files)
}

func (w *mockWalker) Close() error { return nil }

// mockEntry is a mock implementation of IDirEntry.
type mockEntry struct {
	path string
}

func (e *mockEntry) Name() string      { return e.path }
func (e *mockEntry) IsDir() bool       { return false }
func (e *mockEntry) Type() os.FileMode { return 0 }
func (e *mockEntry) Info() (os.FileInfo, error) {
	return nil, fmt.Errorf("not implemented")
}
func (e *mockEntry) GetRelativeViewPath() sec_fs.RelativeViewPath {
	return sec_fs.RelativeViewPath(e.path)
}
func (e *mockEntry) GetRelativeStorePath() sec_fs.RelativeStorePath {
	return sec_fs.RelativeStorePath(e.path)
}
func (e *mockEntry) StoreName() string { return e.path }
