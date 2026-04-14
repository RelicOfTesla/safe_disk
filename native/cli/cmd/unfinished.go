package cmd

import (
	"context"
	"fmt"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

var unfinishedPolicy string

func handleUnfinished(rootPath sec_fs.FullStorePath) error {
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
		for _, marker := range markers {
			if marker.Type == sec_transfer.OperationImport || marker.Type == sec_transfer.OperationExport {
				if err := manager.CleanUnfinishedImportExport(context.Background(), string(rootPath), marker.OpID); err != nil {
					return fmt.Errorf("failed to clean unfinished operation %s: %w", marker.OpID, err)
				}
			}
		}
		fmt.Printf("Cleaned unfinished import/export markers: %d\n", len(markers))
		return nil
	case "ask":
		printUnfinished(markers)
		return fmt.Errorf("unfinished operations found; use --unfinished=clean to clear import/export markers or --unfinished=skip to ignore")
	case "rerun":
		printUnfinished(markers)
		return fmt.Errorf("--unfinished=rerun is not implemented yet")
	default:
		return fmt.Errorf("invalid --unfinished policy: %s", unfinishedPolicy)
	}
}

func printUnfinished(markers []sec_transfer.OperationMarker) {
	fmt.Println("Unfinished operations:")
	for _, marker := range markers {
		fmt.Printf("- %s type=%s status=%s phase=%s src=%s dst=%s root=%s\n",
			marker.OpID, marker.Type, marker.Status, marker.Phase, marker.Src, marker.Dst, marker.Root)
	}
}
