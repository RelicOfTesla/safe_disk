package sec_transfer_v3

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

const (
	phaseCreatingWork         = "creating_work"
	phaseCopyingToWork        = "copying_to_work"
	phaseVerifyingWork        = "verifying_work"
	phaseRenamingRootToBackup = "renaming_root_to_backup"
	phaseRenamingWorkToRoot   = "renaming_work_to_root"
	phaseCompleted            = "completed"
	phaseNeedsAttention       = "needs_attention"

	checkpointCopyingWork      = "copying_work"
	checkpointVerifyingWork    = "verifying_work"
	checkpointBeforeRootRename = "before_root_rename"
	checkpointAfterRootRename  = "after_root_rename"
	checkpointAfterWorkRename  = "after_work_rename"
	checkpointCompletedMarker  = "completed_marker"
)

func (m *Manager) ConvertRoot(ctx context.Context, req sec_transfer.ConvertRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.RootPath == "" {
		return fmt.Errorf("root path is required")
	}
	if req.Password == "" {
		return fmt.Errorf("password is required")
	}
	if req.Kind != sec_transfer.ConvertKindEncrypt && req.Kind != sec_transfer.ConvertKindDecrypt {
		return fmt.Errorf("unsupported convert kind: %s", req.Kind)
	}
	rootPath, err := filepath.Abs(req.RootPath)
	if err != nil {
		return err
	}
	lock, err := acquireOperationLock(ctx, rootPath)
	if err != nil {
		return err
	}
	defer lock.release()
	return m.withDurability(req.Durability).convertRoot(ctx, rootPath, req, cb)
}

func (m *Manager) convertRoot(ctx context.Context, rootPath string, req sec_transfer.ConvertRequest, cb sec_transfer.V3ProgressCallback) error {
	if err := m.validateDurability(); err != nil {
		return err
	}
	opID := newOpID(string(req.Kind))
	work := rootPath + ".safe_disk.work." + opID
	backup := rootPath + ".safe_disk.backup." + opID
	markerType := sec_transfer.OperationConvertEncrypt
	if req.Kind == sec_transfer.ConvertKindDecrypt {
		markerType = sec_transfer.OperationConvertDecrypt
	}

	marker := sec_transfer.OperationMarker{
		OpID:   opID,
		Type:   markerType,
		Status: "running",
		Phase:  phaseCreatingWork,
		Root:   rootPath,
		Work:   work,
		Backup: backup,
	}
	if err := m.writeMarker(rootPath, marker); err != nil {
		return err
	}

	switch req.Kind {
	case sec_transfer.ConvertKindEncrypt:
		return m.convertEncrypt(ctx, marker, req.Password, req.Overwrite, cb)
	case sec_transfer.ConvertKindDecrypt:
		return m.convertDecrypt(ctx, marker, req.Password, req.Overwrite, cb)
	}
	return nil
}

func (m *Manager) convertEncrypt(ctx context.Context, marker sec_transfer.OperationMarker, password string, overwrite bool, cb sec_transfer.V3ProgressCallback) error {
	if err := m.mkdirAllPath(marker.Work, sec_fs.SecureDirMode); err != nil {
		return err
	}
	if err := os.Chmod(marker.Work, sec_fs.SecureDirMode); err != nil {
		return fmt.Errorf("protect convert work: %w", err)
	}
	marker.Phase = phaseCopyingToWork
	if err := m.writeMarker(marker.Root, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointCopyingWork, marker)
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(marker.Work), password, defaultCreateRootOptions()...); err != nil {
		return err
	}
	workRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Work), password)
	if err != nil {
		return err
	}
	if err := m.importDirectory(ctx, sec_transfer.ImportDirectoryRequest{
		Source:    sec_fs.FullStorePath(marker.Root),
		DestRoot:  workRoot,
		Dest:      "",
		Overwrite: overwrite,
	}, cb); err != nil {
		_ = workRoot.Close()
		return err
	}
	if err := workRoot.Close(); err != nil {
		return err
	}
	marker.Phase = phaseVerifyingWork
	if err := m.writeMarker(marker.Root, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointVerifyingWork, marker)
	verifyRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Work), password)
	if err != nil {
		return fmt.Errorf("verify work root: %w", err)
	}
	if err := verifyPlainAndRoot(ctx, marker.Root, verifyRoot); err != nil {
		_ = verifyRoot.Close()
		return fmt.Errorf("verify work tree: %w", err)
	}
	if err := verifyRoot.Close(); err != nil {
		return err
	}
	return m.commitConvertRename(marker)
}

func (m *Manager) convertDecrypt(ctx context.Context, marker sec_transfer.OperationMarker, password string, overwrite bool, cb sec_transfer.V3ProgressCallback) error {
	if err := m.mkdirAllPath(marker.Work, sec_fs.SecureDirMode); err != nil {
		return err
	}
	if err := os.Chmod(marker.Work, sec_fs.SecureDirMode); err != nil {
		return fmt.Errorf("protect convert work: %w", err)
	}
	marker.Phase = phaseCopyingToWork
	if err := m.writeMarker(marker.Root, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointCopyingWork, marker)
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Root), password)
	if err != nil {
		return err
	}
	if err := m.exportDirectory(ctx, sec_transfer.ExportDirectoryRequest{
		SourceRoot: root,
		Source:     "",
		Dest:       sec_fs.FullStorePath(marker.Work),
		Overwrite:  overwrite,
	}, cb); err != nil {
		_ = root.Close()
		return err
	}
	marker.Phase = phaseVerifyingWork
	if err := m.writeMarker(marker.Root, marker); err != nil {
		_ = root.Close()
		return err
	}
	m.checkpoint(checkpointVerifyingWork, marker)
	if err := verifyRootAndPlain(ctx, root, marker.Work); err != nil {
		_ = root.Close()
		return fmt.Errorf("verify work tree: %w", err)
	}
	if err := root.Close(); err != nil {
		return err
	}
	return m.commitConvertRename(marker)
}

func (m *Manager) commitConvertRename(marker sec_transfer.OperationMarker) error {
	marker.Phase = phaseRenamingRootToBackup
	if err := m.writeMarker(marker.Root, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointBeforeRootRename, marker)
	if err := m.renamePath(marker.Root, marker.Backup); err != nil {
		return err
	}
	if err := m.writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointAfterRootRename, marker)
	marker.Phase = phaseRenamingWorkToRoot
	if err := m.writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	if err := m.renamePath(marker.Work, marker.Root); err != nil {
		return err
	}
	m.checkpoint(checkpointAfterWorkRename, marker)
	marker.Phase = phaseCompleted
	marker.Status = "completed"
	if err := m.writeMarker(marker.Root, marker); err != nil {
		return err
	}
	m.checkpoint(checkpointCompletedMarker, marker)
	_ = m.removeMarker(marker.Root, marker.OpID)
	_ = m.removeMarker(marker.Backup, marker.OpID)
	return nil
}

func (m *Manager) RecoverConvert(ctx context.Context, rootPath string) (sec_transfer.RecoverResult, error) {
	if err := ctx.Err(); err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	absRootPath, err := filepath.Abs(rootPath)
	if err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	lock, err := acquireOperationLock(ctx, absRootPath)
	if err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	defer lock.release()
	return m.recoverConvert(ctx, absRootPath)
}

func (m *Manager) recoverConvert(ctx context.Context, absRootPath string) (sec_transfer.RecoverResult, error) {
	if err := m.validateDurability(); err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	markers, err := findConvertMarkers(absRootPath)
	if err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	if len(markers) == 0 {
		return sec_transfer.RecoverResult{Action: sec_transfer.RecoverActionNone, Message: "no convert marker found"}, nil
	}
	opIDs := make(map[string]struct{}, len(markers))
	for _, marker := range markers {
		opIDs[marker.OpID] = struct{}{}
	}
	if len(opIDs) > 1 {
		return sec_transfer.RecoverResult{
			Action:  sec_transfer.RecoverActionNeedsAttention,
			Message: "multiple unfinished convert operations found; refusing to choose one automatically",
		}, nil
	}
	for _, marker := range markers {
		if marker.Type != sec_transfer.OperationConvertEncrypt && marker.Type != sec_transfer.OperationConvertDecrypt {
			continue
		}
		return m.recoverFromMarker(absRootPath, marker)
	}
	return sec_transfer.RecoverResult{Action: sec_transfer.RecoverActionNone, Message: "no convert marker found"}, nil
}

func findConvertMarkers(rootPath string) ([]sec_transfer.OperationMarker, error) {
	candidates := []string{rootPath}
	for _, pattern := range []string{
		rootPath + ".safe_disk.backup.*",
		rootPath + ".safe_disk.work.*",
	} {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			return nil, err
		}
		sort.Strings(matches)
		candidates = append(candidates, matches...)
	}

	var markers []sec_transfer.OperationMarker
	seen := map[string]struct{}{}
	for _, candidate := range candidates {
		found, err := listMarkers(candidate)
		if err != nil {
			return nil, err
		}
		for _, marker := range found {
			if marker.Type != sec_transfer.OperationConvertEncrypt && marker.Type != sec_transfer.OperationConvertDecrypt {
				continue
			}
			key := marker.OpID + "\x00" + marker.Phase + "\x00" + marker.Root + "\x00" + marker.Work + "\x00" + marker.Backup
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			markers = append(markers, marker)
		}
	}
	return markers, nil
}

func (m *Manager) recoverFromMarker(rootPath string, marker sec_transfer.OperationMarker) (sec_transfer.RecoverResult, error) {
	result := sec_transfer.RecoverResult{
		Marker:       marker,
		RootExists:   pathExists(marker.Root),
		WorkExists:   pathExists(marker.Work),
		BackupExists: pathExists(marker.Backup),
	}
	if err := validateConvertMarker(rootPath, marker); err != nil {
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = err.Error()
		return result, nil
	}
	switch marker.Phase {
	case phaseCreatingWork, phaseCopyingToWork, phaseVerifyingWork:
		if !result.RootExists || result.BackupExists {
			result.Action = sec_transfer.RecoverActionNeedsAttention
			result.Message = "cannot safely discard convert work because source root is missing or backup already exists"
			return result, nil
		}
		if result.WorkExists {
			if err := m.removeAllPath(marker.Work); err != nil {
				result.Action = sec_transfer.RecoverActionNeedsAttention
				result.Message = fmt.Sprintf("remove incomplete convert work: %v", err)
				return result, nil
			}
		}
		if err := m.removeMarker(marker.Root, marker.OpID); err != nil {
			result.Action = sec_transfer.RecoverActionNeedsAttention
			result.Message = fmt.Sprintf("remove incomplete convert marker: %v", err)
			return result, nil
		}
		result.Action = sec_transfer.RecoverActionRerun
		result.Message = "incomplete work and marker were removed; rerun convert from the source root"
	case phaseRenamingRootToBackup:
		if result.RootExists && result.WorkExists && !result.BackupExists {
			if err := m.renamePath(marker.Root, marker.Backup); err != nil {
				result.Action = sec_transfer.RecoverActionNeedsAttention
				result.Message = err.Error()
				return result, nil
			}
			marker.Phase = phaseRenamingWorkToRoot
			if err := m.writeMarker(marker.Backup, marker); err != nil {
				result.Action = sec_transfer.RecoverActionNeedsAttention
				result.Message = err.Error()
				return result, nil
			}
			return m.finishRecoveredWorkRename(marker, result)
		}
		fallthrough
	case phaseRenamingWorkToRoot:
		if !result.RootExists && result.WorkExists && result.BackupExists {
			return m.finishRecoveredWorkRename(marker, result)
		}
		if result.RootExists && !result.WorkExists && result.BackupExists {
			_ = m.removeMarker(marker.Root, marker.OpID)
			_ = m.removeMarker(marker.Backup, marker.OpID)
			result.Action = sec_transfer.RecoverActionCompleted
			result.Message = "root exists and backup is preserved"
			return result, nil
		}
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = "cannot determine safe rename recovery"
	case phaseCompleted:
		_ = m.removeMarker(marker.Root, marker.OpID)
		_ = m.removeMarker(marker.Backup, marker.OpID)
		result.Action = sec_transfer.RecoverActionCompleted
		result.Message = "convert already completed; stale markers were cleaned"
	default:
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = "unknown convert phase"
	}
	return result, nil
}

func (m *Manager) finishRecoveredWorkRename(marker sec_transfer.OperationMarker, result sec_transfer.RecoverResult) (sec_transfer.RecoverResult, error) {
	if err := m.renamePath(marker.Work, marker.Root); err != nil {
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = err.Error()
		return result, nil
	}
	_ = m.removeMarker(marker.Root, marker.OpID)
	_ = m.removeMarker(marker.Backup, marker.OpID)
	result.Action = sec_transfer.RecoverActionContinueRename
	result.Message = "pending convert renames completed; backup is preserved"
	return result, nil
}

func validateConvertMarker(rootPath string, marker sec_transfer.OperationMarker) error {
	if err := validateOpID(marker.OpID); err != nil {
		return fmt.Errorf("unsafe convert marker: %w", err)
	}
	expectedRoot := filepath.Clean(rootPath)
	if filepath.Clean(marker.Root) != expectedRoot {
		return fmt.Errorf("unsafe convert marker: root path does not match recovery root")
	}
	expectedWork := expectedRoot + ".safe_disk.work." + marker.OpID
	expectedBackup := expectedRoot + ".safe_disk.backup." + marker.OpID
	if filepath.Clean(marker.Work) != expectedWork || filepath.Clean(marker.Backup) != expectedBackup {
		return fmt.Errorf("unsafe convert marker: work or backup path is not derived from root and operation id")
	}
	return nil
}

func pathExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func defaultCreateRootOptions() []sec_fs.CreateRootOption {
	return []sec_fs.CreateRootOption{
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("none"),
	}
}
