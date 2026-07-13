package cmd

import (
	"context"
	"fmt"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

var unfinishedPolicy string

func handleUnfinished(rootPath sec_fs.FullStorePath, root sec_fs.ISecRoot, durability sec_transfer.DurabilityLevel) error {
	if unfinishedPolicy == "" || unfinishedPolicy == "skip" {
		return nil
	}
	manager := sec_transfer.GetDefaultTransferV3()
	markers, err := manager.ListUnfinishedOperations(context.Background(), string(rootPath))
	if err != nil {
		return fmt.Errorf("failed to list unfinished operations: %w", err)
	}
	if len(markers) == 0 {
		return nil
	}

	switch unfinishedPolicy {
	case "clean":
		cleaned := 0
		for _, marker := range markers {
			if marker.Type == sec_transfer.OperationImport || marker.Type == sec_transfer.OperationExport {
				if err := manager.CleanUnfinishedImportExport(context.Background(), string(rootPath), marker.OpID); err != nil {
					return fmt.Errorf("failed to clean unfinished operation %s: %w", marker.OpID, err)
				}
				cleaned++
			}
		}
		fmt.Printf("Cleaned unfinished import/export markers: %d\n", cleaned)
		return nil
	case "ask":
		printUnfinished(markers)
		return fmt.Errorf("unfinished operations found; use --unfinished=clean to clear import/export markers or --unfinished=skip to ignore")
	case "rerun":
		printUnfinished(markers)
		for _, marker := range markers {
			if marker.Type != sec_transfer.OperationImport && marker.Type != sec_transfer.OperationExport {
				return fmt.Errorf("cannot rerun unfinished %s operation automatically; use convert recovery", marker.Type)
			}
			if err := rerunImportExportMarker(manager, rootPath, root, marker, durability); err != nil {
				return err
			}
		}
		return nil
	default:
		return fmt.Errorf("invalid --unfinished policy: %s", unfinishedPolicy)
	}
}

func rerunImportExportMarker(manager sec_transfer.V3Transfer, rootPath sec_fs.FullStorePath, root sec_fs.ISecRoot, marker sec_transfer.OperationMarker, durability sec_transfer.DurabilityLevel) error {
	if marker.EntryKind != sec_transfer.EntryKindFile && marker.EntryKind != sec_transfer.EntryKindDirectory {
		return fmt.Errorf("unfinished operation %s cannot rerun without a valid entry_kind", marker.OpID)
	}
	if marker.Type == sec_transfer.OperationImport && marker.Src == "" {
		return fmt.Errorf("unfinished import %s cannot rerun without src", marker.OpID)
	}
	if marker.Type == sec_transfer.OperationExport && marker.Dst == "" {
		return fmt.Errorf("unfinished export %s cannot rerun without dst", marker.OpID)
	}
	if marker.EntryKind == sec_transfer.EntryKindFile && marker.Dst == "" {
		return fmt.Errorf("unfinished file operation %s cannot rerun without dst", marker.OpID)
	}
	fmt.Printf("Rerunning unfinished operation: %s type=%s entry_kind=%s\n", marker.OpID, marker.Type, marker.EntryKind)
	if err := manager.CleanUnfinishedImportExport(context.Background(), string(rootPath), marker.OpID); err != nil {
		return fmt.Errorf("failed to clean stale marker before rerun %s: %w", marker.OpID, err)
	}
	var err error
	switch marker.Type {
	case sec_transfer.OperationImport:
		if marker.EntryKind == sec_transfer.EntryKindDirectory {
			err = manager.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
				Source:     sec_fs.FullStorePath(marker.Src),
				DestRoot:   root,
				Dest:       sec_fs.RelativeViewPath(marker.Dst),
				Overwrite:  true,
				Durability: durability,
			}, progressPrinter("Importing"))
		} else {
			err = manager.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
				Source:     sec_fs.FullStorePath(marker.Src),
				DestRoot:   root,
				Dest:       sec_fs.RelativeViewPath(marker.Dst),
				Overwrite:  true,
				Durability: durability,
			}, progressPrinter("Importing"))
		}
		if err != nil {
			return fmt.Errorf("failed to rerun import %s: %w", marker.OpID, err)
		}
	case sec_transfer.OperationExport:
		if marker.EntryKind == sec_transfer.EntryKindDirectory {
			err = manager.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
				SourceRoot: root,
				Source:     sec_fs.RelativeViewPath(marker.Src),
				Dest:       sec_fs.FullStorePath(marker.Dst),
				Overwrite:  true,
				Durability: durability,
			}, progressPrinter("Exporting"))
		} else {
			err = manager.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
				SourceRoot: root,
				Source:     sec_fs.RelativeViewPath(marker.Src),
				Dest:       sec_fs.FullStorePath(marker.Dst),
				Overwrite:  true,
				Durability: durability,
			}, progressPrinter("Exporting"))
		}
		if err != nil {
			return fmt.Errorf("failed to rerun export %s: %w", marker.OpID, err)
		}
	default:
		return fmt.Errorf("unsupported unfinished operation type: %s", marker.Type)
	}
	fmt.Printf("\nRerun completed: %s\n", marker.OpID)
	return nil
}

func progressPrinter(label string) sec_transfer.V3ProgressCallback {
	return func(progress sec_transfer.ProgressEvent) {
		if progress.CurrentPath == "" {
			return
		}
		fmt.Printf("\r%s: %s (%d/%d files)", label, progress.CurrentPath, progress.DoneFiles, progress.TotalFiles)
	}
}

func printUnfinished(markers []sec_transfer.OperationMarker) {
	fmt.Println("Unfinished operations:")
	for _, marker := range markers {
		fmt.Printf("- %s type=%s status=%s phase=%s src=%s dst=%s root=%s\n",
			marker.OpID, marker.Type, marker.Status, marker.Phase, marker.Src, marker.Dst, marker.Root)
	}
}
