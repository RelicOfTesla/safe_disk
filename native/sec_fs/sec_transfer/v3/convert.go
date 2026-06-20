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
)

func (m *Manager) ConvertRoot(ctx context.Context, req sec_transfer.ConvertRequest, cb sec_transfer.V3ProgressCallback) error {
	if req.RootPath == "" {
		return fmt.Errorf("root path is required")
	}
	if req.Password == "" {
		return fmt.Errorf("password is required")
	}
	rootPath, err := filepath.Abs(req.RootPath)
	if err != nil {
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
	if err := writeMarker(rootPath, marker); err != nil {
		return err
	}

	switch req.Kind {
	case sec_transfer.ConvertKindEncrypt:
		return m.convertEncrypt(ctx, marker, req.Password, req.Overwrite, cb)
	case sec_transfer.ConvertKindDecrypt:
		return m.convertDecrypt(ctx, marker, req.Password, req.Overwrite, cb)
	default:
		return fmt.Errorf("unsupported convert kind: %s", req.Kind)
	}
}

func (m *Manager) convertEncrypt(ctx context.Context, marker sec_transfer.OperationMarker, password string, overwrite bool, cb sec_transfer.V3ProgressCallback) error {
	if err := os.MkdirAll(marker.Work, 0755); err != nil {
		return err
	}
	marker.Phase = phaseCopyingToWork
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(marker.Work), password, defaultCreateRootOptions()...); err != nil {
		return err
	}
	workRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Work), password)
	if err != nil {
		return err
	}
	if err := m.ImportDirectory(ctx, sec_transfer.ImportDirectoryRequest{
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
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	verifyRoot, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Work), password)
	if err != nil {
		return fmt.Errorf("verify work root: %w", err)
	}
	if err := verifyRoot.Close(); err != nil {
		return err
	}
	marker.Phase = phaseRenamingRootToBackup
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	if err := os.Rename(marker.Root, marker.Backup); err != nil {
		return err
	}
	if err := writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	marker.Phase = phaseRenamingWorkToRoot
	if err := writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	if err := os.Rename(marker.Work, marker.Root); err != nil {
		return err
	}
	marker.Phase = phaseCompleted
	marker.Status = "completed"
	_ = writeMarker(marker.Root, marker)
	_ = removeMarker(marker.Root, marker.OpID)
	_ = removeMarker(marker.Backup, marker.OpID)
	return nil
}

func (m *Manager) convertDecrypt(ctx context.Context, marker sec_transfer.OperationMarker, password string, overwrite bool, cb sec_transfer.V3ProgressCallback) error {
	if err := os.MkdirAll(marker.Work, 0755); err != nil {
		return err
	}
	marker.Phase = phaseCopyingToWork
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(marker.Root), password)
	if err != nil {
		return err
	}
	if err := m.ExportDirectory(ctx, sec_transfer.ExportDirectoryRequest{
		SourceRoot: root,
		Source:     "",
		Dest:       sec_fs.FullStorePath(marker.Work),
		Overwrite:  overwrite,
	}, cb); err != nil {
		_ = root.Close()
		return err
	}
	if err := root.Close(); err != nil {
		return err
	}
	marker.Phase = phaseVerifyingWork
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	marker.Phase = phaseRenamingRootToBackup
	if err := writeMarker(marker.Root, marker); err != nil {
		return err
	}
	if err := os.Rename(marker.Root, marker.Backup); err != nil {
		return err
	}
	if err := writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	marker.Phase = phaseRenamingWorkToRoot
	if err := writeMarker(marker.Backup, marker); err != nil {
		return err
	}
	if err := os.Rename(marker.Work, marker.Root); err != nil {
		return err
	}
	marker.Phase = phaseCompleted
	marker.Status = "completed"
	_ = writeMarker(marker.Root, marker)
	_ = removeMarker(marker.Root, marker.OpID)
	_ = removeMarker(marker.Backup, marker.OpID)
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
	markers, err := findConvertMarkers(absRootPath)
	if err != nil {
		return sec_transfer.RecoverResult{}, err
	}
	if len(markers) == 0 {
		return sec_transfer.RecoverResult{Action: sec_transfer.RecoverActionNone, Message: "no convert marker found"}, nil
	}
	for _, marker := range markers {
		if marker.Type != sec_transfer.OperationConvertEncrypt && marker.Type != sec_transfer.OperationConvertDecrypt {
			continue
		}
		return recoverFromMarker(marker)
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

func recoverFromMarker(marker sec_transfer.OperationMarker) (sec_transfer.RecoverResult, error) {
	result := sec_transfer.RecoverResult{
		Marker:       marker,
		RootExists:   pathExists(marker.Root),
		WorkExists:   pathExists(marker.Work),
		BackupExists: pathExists(marker.Backup),
	}
	switch marker.Phase {
	case phaseCreatingWork, phaseCopyingToWork, phaseVerifyingWork:
		result.Action = sec_transfer.RecoverActionRerun
		result.Message = "root still owns source state; remove work directory and rerun convert"
	case phaseRenamingRootToBackup, phaseRenamingWorkToRoot:
		if !result.RootExists && result.WorkExists && result.BackupExists {
			if err := os.Rename(marker.Work, marker.Root); err != nil {
				result.Action = sec_transfer.RecoverActionNeedsAttention
				result.Message = err.Error()
				return result, nil
			}
			_ = removeMarker(marker.Root, marker.OpID)
			_ = removeMarker(marker.Backup, marker.OpID)
			result.Action = sec_transfer.RecoverActionContinueRename
			result.Message = "work directory moved into root path"
			return result, nil
		}
		if result.RootExists && !result.WorkExists && result.BackupExists {
			_ = removeMarker(marker.Root, marker.OpID)
			_ = removeMarker(marker.Backup, marker.OpID)
			result.Action = sec_transfer.RecoverActionCompleted
			result.Message = "root exists and backup is preserved"
			return result, nil
		}
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = "cannot determine safe rename recovery"
	case phaseCompleted:
		result.Action = sec_transfer.RecoverActionCompleted
		result.Message = "convert already completed"
	default:
		result.Action = sec_transfer.RecoverActionNeedsAttention
		result.Message = "unknown convert phase"
	}
	return result, nil
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
