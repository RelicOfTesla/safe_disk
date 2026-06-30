package sec_transfer_v3

import (
	"context"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

const (
	tempSuffix   = ".tmp.safe_disk"
	backupSuffix = ".raw.safe_disk"
)

type Manager struct{}

func New() *Manager {
	return &Manager{}
}

func (m *Manager) ListUnfinishedOperations(ctx context.Context, rootPath string) ([]sec_transfer.OperationMarker, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return listMarkers(rootPath)
}

func (m *Manager) CleanUnfinishedImportExport(ctx context.Context, rootPath string, opID string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if opID != "" {
		return removeMarker(rootPath, opID)
	}
	markers, err := listMarkers(rootPath)
	if err != nil {
		return err
	}
	for _, marker := range markers {
		if marker.Type == sec_transfer.OperationImport || marker.Type == sec_transfer.OperationExport {
			if err := removeMarker(rootPath, marker.OpID); err != nil {
				return err
			}
		}
	}
	return nil
}

func (m *Manager) ImportFile(ctx context.Context, req sec_transfer.ImportFileRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.DestRoot == nil {
		return fmt.Errorf("dest root is nil")
	}
	rootPath := string(req.DestRoot.GetRootPath())
	opID := newOpID("import")
	marker := sec_transfer.OperationMarker{
		OpID:   opID,
		Type:   sec_transfer.OperationImport,
		Status: "running",
		Src:    string(req.Source),
		Dst:    string(req.Dest),
		Root:   rootPath,
	}
	if err := writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: 1, CurrentPath: string(req.Source)})
	err := m.importOne(ctx, opID, string(req.Source), req.DestRoot, req.Dest, req.Overwrite, cb, 1, 0)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: 1, DoneFiles: 1, Complete: true})
	return removeMarker(rootPath, opID)
}

func (m *Manager) ImportDirectory(ctx context.Context, req sec_transfer.ImportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.DestRoot == nil {
		return fmt.Errorf("dest root is nil")
	}
	rootPath := string(req.DestRoot.GetRootPath())
	opID := newOpID("import")
	marker := sec_transfer.OperationMarker{
		OpID:   opID,
		Type:   sec_transfer.OperationImport,
		Status: "running",
		Src:    string(req.Source),
		Dst:    string(req.Dest),
		Root:   rootPath,
	}
	if err := writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, CurrentPath: string(req.Source)})
	files, err := collectPlainFiles(ctx, string(req.Source), req.SkipRecursive)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
		return err
	}
	for i, file := range files {
		if err := ctx.Err(); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
			return err
		}
		rel, err := filepath.Rel(string(req.Source), file)
		if err != nil {
			return err
		}
		dest := joinView(req.Dest, rel)
		if err := m.importOne(ctx, opID, file, req.DestRoot, dest, req.Overwrite, cb, int64(len(files)), int64(i)); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
			return err
		}
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: int64(len(files)), DoneFiles: int64(i + 1), CurrentPath: file})
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: int64(len(files)), DoneFiles: int64(len(files)), Complete: true})
	return removeMarker(rootPath, opID)
}

func (m *Manager) ExportFile(ctx context.Context, req sec_transfer.ExportFileRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.SourceRoot == nil {
		return fmt.Errorf("source root is nil")
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	opID := newOpID("export")
	marker := sec_transfer.OperationMarker{
		OpID:   opID,
		Type:   sec_transfer.OperationExport,
		Status: "running",
		Src:    string(req.Source),
		Dst:    string(req.Dest),
		Root:   rootPath,
	}
	if err := writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: 1, CurrentPath: string(req.Source)})
	err := exportOne(ctx, opID, req.SourceRoot, req.Source, string(req.Dest), req.Overwrite)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: 1, DoneFiles: 1, Complete: true})
	return removeMarker(rootPath, opID)
}

func (m *Manager) ExportDirectory(ctx context.Context, req sec_transfer.ExportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.SourceRoot == nil {
		return fmt.Errorf("source root is nil")
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	opID := newOpID("export")
	marker := sec_transfer.OperationMarker{
		OpID:   opID,
		Type:   sec_transfer.OperationExport,
		Status: "running",
		Src:    string(req.Source),
		Dst:    string(req.Dest),
		Root:   rootPath,
	}
	if err := writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, CurrentPath: string(req.Source)})
	files, err := collectRootFiles(ctx, req.SourceRoot, req.Source, req.SkipRecursive)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
		return err
	}
	for i, src := range files {
		if err := ctx.Err(); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
		rel := strings.TrimPrefix(string(src), strings.TrimSuffix(string(req.Source), "/")+"/")
		if string(req.Source) == "" {
			rel = string(src)
		}
		dest := filepath.Join(string(req.Dest), rel)
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(i), CurrentPath: string(src)})
		if err := exportOne(ctx, opID, req.SourceRoot, src, dest, req.Overwrite); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(i + 1), CurrentPath: string(src)})
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(len(files)), Complete: true})
	return removeMarker(rootPath, opID)
}

func (m *Manager) importOne(ctx context.Context, opID string, src string, root sec_fs.ISecRoot, dest sec_fs.RelativeViewPath, overwrite bool, cb sec_transfer.V3ProgressCallback, total int64, done int64) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: total, DoneFiles: done, CurrentPath: src})
	if !overwrite && root.FileExists(dest) {
		return fmt.Errorf("destination exists: %s", dest)
	}
	return importFileAtomic(ctx, src, root, dest, overwrite)
}

func importFileAtomic(ctx context.Context, src string, root sec_fs.ISecRoot, dest sec_fs.RelativeViewPath, overwrite bool) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	if !overwrite && root.FileExists(dest) {
		return fmt.Errorf("destination exists: %s", dest)
	}
	parent := filepath.Dir(string(dest))
	if parent != "." && parent != "" {
		if err := root.MkdirAll(sec_fs.RelativeViewPath(parent)); err != nil {
			return err
		}
	}
	temp := sec_fs.RelativeViewPath(string(dest) + tempSuffix)
	backup := sec_fs.RelativeViewPath(string(dest) + backupSuffix)
	tempFile, err := root.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(tempFile, contextReader{ctx: ctx, reader: srcFile})
	closeErr := tempFile.Close()
	if copyErr != nil {
		_ = root.DeleteFile(temp)
		return copyErr
	}
	if closeErr != nil {
		_ = root.DeleteFile(temp)
		return closeErr
	}
	if err := ctx.Err(); err != nil {
		_ = root.DeleteFile(temp)
		return err
	}
	if root.FileExists(dest) {
		if err := root.Rename(dest, backup); err != nil {
			_ = root.DeleteFile(temp)
			return err
		}
	}
	if err := root.Rename(temp, dest); err != nil {
		if root.FileExists(backup) {
			_ = root.Rename(backup, dest)
		}
		_ = root.DeleteFile(temp)
		return err
	}
	if root.FileExists(backup) {
		_ = root.DeleteFile(backup)
	}
	return nil
}

func exportOne(ctx context.Context, opID string, root sec_fs.ISecRoot, src sec_fs.RelativeViewPath, dest string, overwrite bool) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if !overwrite {
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("destination exists: %s", dest)
		}
	}
	return exportFileAtomic(ctx, root, src, dest, overwrite)
}

func exportFileAtomic(ctx context.Context, root sec_fs.ISecRoot, src sec_fs.RelativeViewPath, dest string, overwrite bool) error {
	srcFile, err := root.OpenFile(src, os.O_RDONLY)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	if err := os.MkdirAll(filepath.Dir(dest), 0755); err != nil {
		return err
	}
	temp := dest + tempSuffix
	backup := dest + backupSuffix
	if !overwrite {
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("destination exists: %s", dest)
		}
	}

	tempFile, err := os.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return err
	}
	_, copyErr := io.Copy(tempFile, contextReader{ctx: ctx, reader: srcFile})
	syncErr := tempFile.Sync()
	closeErr := tempFile.Close()
	if copyErr != nil {
		_ = os.Remove(temp)
		return copyErr
	}
	if syncErr != nil {
		_ = os.Remove(temp)
		return syncErr
	}
	if closeErr != nil {
		_ = os.Remove(temp)
		return closeErr
	}
	if err := ctx.Err(); err != nil {
		_ = os.Remove(temp)
		return err
	}
	if _, err := os.Stat(dest); err == nil {
		if err := os.Rename(dest, backup); err != nil {
			_ = os.Remove(temp)
			return err
		}
	}
	if err := os.Rename(temp, dest); err != nil {
		if _, statErr := os.Stat(backup); statErr == nil {
			_ = os.Rename(backup, dest)
		}
		_ = os.Remove(temp)
		return err
	}
	_ = os.Remove(backup)
	return nil
}

func collectPlainFiles(ctx context.Context, root string, skipRecursive bool) ([]string, error) {
	var files []string
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if skipRecursive {
		entries, err := os.ReadDir(root)
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			if entry.IsDir() || shouldSkipPlainName(entry.Name()) {
				continue
			}
			files = append(files, filepath.Join(root, entry.Name()))
		}
		return files, nil
	}
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if ctxErr := ctx.Err(); ctxErr != nil {
			return ctxErr
		}
		if err != nil {
			return err
		}
		if path == root {
			return nil
		}
		if d.IsDir() {
			if shouldSkipPlainName(d.Name()) {
				return filepath.SkipDir
			}
			return nil
		}
		if shouldSkipPlainName(d.Name()) {
			return nil
		}
		files = append(files, path)
		return nil
	})
	return files, err
}

func collectRootFiles(ctx context.Context, root sec_fs.ISecRoot, base sec_fs.RelativeViewPath, skipRecursive bool) ([]sec_fs.RelativeViewPath, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	var opts []sec_fs.WalkOption
	if !skipRecursive {
		opts = append(opts, sec_fs.WithRecursive())
	}
	walker, err := root.WalkDir(base, opts...)
	if err != nil {
		return nil, err
	}
	defer walker.Close()
	var files []sec_fs.RelativeViewPath
	for {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		entry, err := walker.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if entry.IsDir() {
			continue
		}
		rel := entry.GetRelativeViewPath()
		baseDir := strings.TrimSuffix(string(base), "/")
		entryDir := filepath.Dir(string(rel))
		if baseDir == "" {
			baseDir = "."
		}
		if skipRecursive && entryDir != baseDir {
			continue
		}
		files = append(files, rel)
	}
	return files, nil
}

type contextReader struct {
	ctx    context.Context
	reader io.Reader
}

func (r contextReader) Read(p []byte) (int, error) {
	if err := r.ctx.Err(); err != nil {
		return 0, err
	}
	return r.reader.Read(p)
}

func shouldSkipPlainName(name string) bool {
	return name == baseDirName ||
		name == sec_fs.ConfigFileName ||
		strings.Contains(name, ".safe_disk.work.") ||
		strings.Contains(name, ".safe_disk.backup.")
}

func joinView(base sec_fs.RelativeViewPath, rel string) sec_fs.RelativeViewPath {
	if string(base) == "" || string(base) == "." {
		return sec_fs.RelativeViewPath(filepath.ToSlash(rel))
	}
	return sec_fs.RelativeViewPath(filepath.ToSlash(filepath.Join(string(base), rel)))
}

func newOpID(prefix string) string {
	return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
}

func report(cb sec_transfer.V3ProgressCallback, event sec_transfer.ProgressEvent) {
	if cb != nil {
		cb(event)
	}
}
