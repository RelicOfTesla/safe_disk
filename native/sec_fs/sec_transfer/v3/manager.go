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

type Manager struct {
	checkpointHook  func(name string, marker sec_transfer.OperationMarker)
	durability      DurabilityLevel
	syncSecFileHook func(sec_fs.ISecFile) error
	syncOSFileHook  func(*os.File) error
	syncDirHook     func(string) error
}

func New(options ...Option) *Manager {
	manager := &Manager{durability: DurabilityFull}
	for _, option := range options {
		option(manager)
	}
	return manager
}

func (m *Manager) checkpoint(name string, marker sec_transfer.OperationMarker) {
	if m.checkpointHook != nil {
		m.checkpointHook(name, marker)
	}
}

func (m *Manager) ListUnfinishedOperations(ctx context.Context, rootPath string) ([]sec_transfer.OperationMarker, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	return listMarkers(rootPath)
}

func (m *Manager) CleanUnfinishedImportExport(ctx context.Context, rootPath string, opID string) error {
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.cleanUnfinishedImportExport(ctx, rootPath, opID)
}

func (m *Manager) cleanUnfinishedImportExport(ctx context.Context, rootPath string, opID string) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	if opID != "" {
		return m.removeMarker(rootPath, opID)
	}
	markers, err := listMarkers(rootPath)
	if err != nil {
		return err
	}
	for _, marker := range markers {
		if marker.Type == sec_transfer.OperationImport || marker.Type == sec_transfer.OperationExport {
			if err := m.removeMarker(rootPath, marker.OpID); err != nil {
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
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.withDurability(req.Durability).importFile(ctx, req, cb)
}

func (m *Manager) importFile(ctx context.Context, req sec_transfer.ImportFileRequest, cb sec_transfer.V3ProgressCallback) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	rootPath := string(req.DestRoot.GetRootPath())
	opID := newOpID("import")
	marker := sec_transfer.OperationMarker{
		OpID:      opID,
		Type:      sec_transfer.OperationImport,
		EntryKind: sec_transfer.EntryKindFile,
		Status:    "running",
		Src:       string(req.Source),
		Dst:       string(req.Dest),
		Root:      rootPath,
	}
	if err := m.writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: 1, CurrentPath: string(req.Source)})
	err := m.importOne(ctx, opID, string(req.Source), req.DestRoot, req.Dest, req.Overwrite, cb, 1, 0)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: 1, DoneFiles: 1, Complete: true})
	return m.removeMarker(rootPath, opID)
}

func (m *Manager) ImportDirectory(ctx context.Context, req sec_transfer.ImportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.DestRoot == nil {
		return fmt.Errorf("dest root is nil")
	}
	rootPath := string(req.DestRoot.GetRootPath())
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.withDurability(req.Durability).importDirectory(ctx, req, cb)
}

func (m *Manager) importDirectory(ctx context.Context, req sec_transfer.ImportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	rootPath := string(req.DestRoot.GetRootPath())
	opID := newOpID("import")
	marker := sec_transfer.OperationMarker{
		OpID:      opID,
		Type:      sec_transfer.OperationImport,
		EntryKind: sec_transfer.EntryKindDirectory,
		Status:    "running",
		Src:       string(req.Source),
		Dst:       string(req.Dest),
		Root:      rootPath,
	}
	if err := m.writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, CurrentPath: string(req.Source)})
	files, dirs, err := collectPlainEntries(ctx, string(req.Source), req.SkipRecursive)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
		return err
	}
	if string(req.Dest) != "" {
		if err := m.mkdirAllRoot(req.DestRoot, req.Dest); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
			return err
		}
	}
	for _, dir := range dirs {
		if err := ctx.Err(); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
			return err
		}
		rel, err := filepath.Rel(string(req.Source), dir)
		if err != nil {
			return err
		}
		if err := m.mkdirAllRoot(req.DestRoot, joinView(req.Dest, rel)); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, Error: err, Complete: true})
			return err
		}
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
	return m.removeMarker(rootPath, opID)
}

func (m *Manager) ExportFile(ctx context.Context, req sec_transfer.ExportFileRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.SourceRoot == nil {
		return fmt.Errorf("source root is nil")
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.withDurability(req.Durability).exportFile(ctx, req, cb)
}

func (m *Manager) exportFile(ctx context.Context, req sec_transfer.ExportFileRequest, cb sec_transfer.V3ProgressCallback) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	opID := newOpID("export")
	marker := sec_transfer.OperationMarker{
		OpID:      opID,
		Type:      sec_transfer.OperationExport,
		EntryKind: sec_transfer.EntryKindFile,
		Status:    "running",
		Src:       string(req.Source),
		Dst:       string(req.Dest),
		Root:      rootPath,
	}
	if err := m.writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: 1, CurrentPath: string(req.Source)})
	err := m.exportOne(ctx, opID, req.SourceRoot, req.Source, string(req.Dest), req.Overwrite)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: 1, DoneFiles: 1, Complete: true})
	return m.removeMarker(rootPath, opID)
}

func (m *Manager) ExportDirectory(ctx context.Context, req sec_transfer.ExportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.SourceRoot == nil {
		return fmt.Errorf("source root is nil")
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.withDurability(req.Durability).exportDirectory(ctx, req, cb)
}

func (m *Manager) exportDirectory(ctx context.Context, req sec_transfer.ExportDirectoryRequest, cb sec_transfer.V3ProgressCallback) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	rootPath := string(req.SourceRoot.GetRootPath())
	opID := newOpID("export")
	marker := sec_transfer.OperationMarker{
		OpID:      opID,
		Type:      sec_transfer.OperationExport,
		EntryKind: sec_transfer.EntryKindDirectory,
		Status:    "running",
		Src:       string(req.Source),
		Dst:       string(req.Dest),
		Root:      rootPath,
	}
	if err := m.writeMarker(rootPath, marker); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, CurrentPath: string(req.Source)})
	files, dirs, err := collectRootEntries(ctx, req.SourceRoot, req.Source, req.SkipRecursive)
	if err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
		return err
	}
	if err := m.mkdirAllPath(string(req.Dest), sec_fs.SecureDirMode); err != nil {
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
		return err
	}
	for _, dir := range dirs {
		if err := ctx.Err(); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
		rel := relativeToViewBase(req.Source, dir)
		if err := m.mkdirAllPath(filepath.Join(string(req.Dest), rel), sec_fs.SecureDirMode); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
	}
	for i, src := range files {
		if err := ctx.Err(); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
		rel := relativeToViewBase(req.Source, src)
		dest := filepath.Join(string(req.Dest), rel)
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(i), CurrentPath: string(src)})
		if err := m.exportOne(ctx, opID, req.SourceRoot, src, dest, req.Overwrite); err != nil {
			report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, Error: err, Complete: true})
			return err
		}
		report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(i + 1), CurrentPath: string(src)})
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationExport, TotalFiles: int64(len(files)), DoneFiles: int64(len(files)), Complete: true})
	return m.removeMarker(rootPath, opID)
}

func (m *Manager) importOne(ctx context.Context, opID string, src string, root sec_fs.ISecRoot, dest sec_fs.RelativeViewPath, overwrite bool, cb sec_transfer.V3ProgressCallback, total int64, done int64) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	report(cb, sec_transfer.ProgressEvent{OpID: opID, Type: sec_transfer.OperationImport, TotalFiles: total, DoneFiles: done, CurrentPath: src})
	if !overwrite && root.FileExists(dest) {
		return fmt.Errorf("destination exists: %s", dest)
	}
	return m.importFileAtomic(ctx, src, root, dest, overwrite)
}

func (m *Manager) importFileAtomic(ctx context.Context, src string, root sec_fs.ISecRoot, dest sec_fs.RelativeViewPath, overwrite bool) error {
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
		if err := m.mkdirAllRoot(root, sec_fs.RelativeViewPath(parent)); err != nil {
			return err
		}
	}
	temp := sec_fs.RelativeViewPath(string(dest) + tempSuffix)
	backup := sec_fs.RelativeViewPath(string(dest) + backupSuffix)
	tempFile, err := root.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		return err
	}
	if err := protectRootEntry(root, temp); err != nil {
		_ = tempFile.Close()
		_ = root.DeleteFile(temp)
		return err
	}
	_, copyErr := io.Copy(tempFile, contextReader{ctx: ctx, reader: srcFile})
	if copyErr != nil {
		_ = tempFile.Close()
		_ = root.DeleteFile(temp)
		return copyErr
	}
	syncErr := m.syncSecFile(tempFile)
	closeErr := tempFile.Close()
	if syncErr != nil {
		_ = root.DeleteFile(temp)
		return syncErr
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
		if err := m.renameRootEntry(root, dest, backup); err != nil {
			_ = root.DeleteFile(temp)
			return err
		}
	}
	if err := m.renameRootEntry(root, temp, dest); err != nil {
		if root.FileExists(backup) {
			_ = m.renameRootEntry(root, backup, dest)
		}
		_ = root.DeleteFile(temp)
		return err
	}
	if root.FileExists(backup) {
		if err := m.deleteRootEntry(root, backup); err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) exportOne(ctx context.Context, opID string, root sec_fs.ISecRoot, src sec_fs.RelativeViewPath, dest string, overwrite bool) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if !overwrite {
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("destination exists: %s", dest)
		}
	}
	return m.exportFileAtomic(ctx, root, src, dest, overwrite)
}

func (m *Manager) exportFileAtomic(ctx context.Context, root sec_fs.ISecRoot, src sec_fs.RelativeViewPath, dest string, overwrite bool) error {
	srcFile, err := root.OpenFile(src, os.O_RDONLY)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	if err := m.mkdirAllPath(filepath.Dir(dest), sec_fs.SecureDirMode); err != nil {
		return err
	}
	temp := dest + tempSuffix
	backup := dest + backupSuffix
	if !overwrite {
		if _, err := os.Stat(dest); err == nil {
			return fmt.Errorf("destination exists: %s", dest)
		}
	}

	tempFile, err := os.OpenFile(temp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, sec_fs.SecureFileMode)
	if err != nil {
		return err
	}
	if err := tempFile.Chmod(sec_fs.SecureFileMode); err != nil {
		_ = tempFile.Close()
		_ = os.Remove(temp)
		return fmt.Errorf("protect export temp: %w", err)
	}
	_, copyErr := io.Copy(tempFile, contextReader{ctx: ctx, reader: srcFile})
	if copyErr != nil {
		_ = tempFile.Close()
		_ = os.Remove(temp)
		return copyErr
	}
	syncErr := m.syncOSFile(tempFile)
	closeErr := tempFile.Close()
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
		if err := m.renamePath(dest, backup); err != nil {
			_ = os.Remove(temp)
			return err
		}
	}
	if err := m.renamePath(temp, dest); err != nil {
		if _, statErr := os.Stat(backup); statErr == nil {
			_ = m.renamePath(backup, dest)
		}
		_ = os.Remove(temp)
		return err
	}
	return m.removePath(backup)
}

func collectPlainEntries(ctx context.Context, root string, skipRecursive bool) (files []string, dirs []string, err error) {
	if err := ctx.Err(); err != nil {
		return nil, nil, err
	}
	if hasRootConfig(root) {
		return nil, nil, fmt.Errorf("source is an encrypted root: %s", root)
	}
	if skipRecursive {
		entries, err := os.ReadDir(root)
		if err != nil {
			return nil, nil, err
		}
		for _, entry := range entries {
			if err := ctx.Err(); err != nil {
				return nil, nil, err
			}
			if shouldSkipPlainName(entry.Name()) {
				continue
			}
			path := filepath.Join(root, entry.Name())
			if entry.Type()&os.ModeSymlink != 0 {
				return nil, nil, fmt.Errorf("symbolic links are not supported: %s", path)
			}
			if entry.IsDir() {
				if hasRootConfig(path) {
					continue
				}
				dirs = append(dirs, path)
			} else {
				files = append(files, path)
			}
		}
		return files, dirs, nil
	}
	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if ctxErr := ctx.Err(); ctxErr != nil {
			return ctxErr
		}
		if err != nil {
			return err
		}
		if path == root {
			return nil
		}
		if shouldSkipPlainName(d.Name()) {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if d.Type()&os.ModeSymlink != 0 {
			return fmt.Errorf("symbolic links are not supported: %s", path)
		}
		if d.IsDir() {
			if hasRootConfig(path) {
				return filepath.SkipDir
			}
			dirs = append(dirs, path)
			return nil
		}
		files = append(files, path)
		return nil
	})
	return files, dirs, err
}

func hasRootConfig(path string) bool {
	info, err := os.Stat(filepath.Join(path, sec_fs.ConfigFileName))
	return err == nil && !info.IsDir()
}

func collectRootEntries(ctx context.Context, root sec_fs.ISecRoot, base sec_fs.RelativeViewPath, skipRecursive bool) (files []sec_fs.RelativeViewPath, dirs []sec_fs.RelativeViewPath, err error) {
	if err := ctx.Err(); err != nil {
		return nil, nil, err
	}
	var opts []sec_fs.WalkOption
	if !skipRecursive {
		opts = append(opts, sec_fs.WithRecursive())
	}
	walker, err := root.WalkDir(base, opts...)
	if err != nil {
		return nil, nil, err
	}
	defer walker.Close()
	for {
		if err := ctx.Err(); err != nil {
			return nil, nil, err
		}
		entry, err := walker.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, nil, err
		}
		if entry.Type()&os.ModeSymlink != 0 {
			return nil, nil, fmt.Errorf("symbolic links are not supported: %s", entry.GetRelativeViewPath())
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
		if entry.IsDir() {
			dirs = append(dirs, rel)
		} else {
			files = append(files, rel)
		}
	}
	return files, dirs, nil
}

func relativeToViewBase(base sec_fs.RelativeViewPath, entry sec_fs.RelativeViewPath) string {
	basePath := strings.TrimSuffix(filepath.ToSlash(string(base)), "/")
	entryPath := filepath.ToSlash(string(entry))
	if basePath == "" {
		return entryPath
	}
	return strings.TrimPrefix(entryPath, basePath+"/")
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
