package cmd

import (
	"context"
	"fmt"
	"io"
	"os"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	exportPassword      string
	exportSrcPath       string
	_exportDestPath     string
	exportSkipRecursive bool
)

var exportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export files from an encrypted root directory",
	Long:  "Export encrypted files to plaintext from an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if exportPassword == "" {
			return fmt.Errorf("password is required")
		}

		if exportSrcPath == "" {
			return fmt.Errorf("source path is required")
		}

		outputStd := _exportDestPath == "" || _exportDestPath == "-"

		exportDestPath := sec_fs.FullStorePath(_exportDestPath)

		_, fromRoot, fromRelative, err := sec_fs.FindRootConfig(exportSrcPath)
		if err != nil {
			return fmt.Errorf("failed to find root config: %w", err)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRootQuick(fromRoot, exportPassword)
		if err != nil {
			return fmt.Errorf("failed to open root: %w", err)
		}
		defer root.Close()
		if err := handleUnfinished(fromRoot); err != nil {
			return err
		}
		targetInfo, err := root.Stat(fromRelative)
		if err != nil {
			return fmt.Errorf("failed to stat: %w", err)
		}

		transferService := sec_transfer.GetDefaultTransferV3()
		var doneFiles int64
		var totalFiles int64
		callback := func(status sec_transfer.ProgressEvent) {
			totalFiles = status.TotalFiles
			doneFiles = status.DoneFiles
			if !outputStd {
				if currFile := status.CurrentPath; currFile != "" {
					fmt.Printf("\rExporting: %s (%d/%d files)",
						currFile,
						status.DoneFiles,
						status.TotalFiles)
				}
			}
		}

		if targetInfo.IsDir() {
			if outputStd {
				return fmt.Errorf("stdout export not yet implemented")
			}
			fmt.Printf("Exporting directory: %s -> %s\n", exportSrcPath, exportDestPath)
			err = transferService.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
				SourceRoot:    root,
				Source:        fromRelative,
				Dest:          exportDestPath,
				SkipRecursive: exportSkipRecursive,
				Overwrite:     true,
			}, callback)
		} else {
			if outputStd {
				fp, err := root.OpenFile(fromRelative, os.O_RDONLY)
				if err != nil {
					return fmt.Errorf("failed to open file: %w", err)
				}
				defer fp.Close()
				_, err = io.Copy(os.Stdout, fp)
				if err != nil {
					return fmt.Errorf("failed to copy file: %w", err)
				}
				return nil
			} else {
				fmt.Printf("Exporting file: %s -> %s\n", exportSrcPath, exportDestPath)
				err = transferService.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
					SourceRoot: root,
					Source:     fromRelative,
					Dest:       exportDestPath,
					Overwrite:  true,
				}, callback)
			}
		}

		if err != nil {
			return fmt.Errorf("export failed: %w", err)
		}

		if !outputStd {
			fmt.Println("\nExport successful!")
			if doneFiles == 0 {
				doneFiles = totalFiles
			}
			fmt.Printf("Files exported: %d\n", doneFiles)
		}
		return nil
	},
}

func init() {
	exportCmd.Flags().StringVarP(&exportPassword, "password", "p", "", "Password for encryption")
	exportCmd.Flags().StringVarP(&exportSrcPath, "source", "s", "", "Source path (encrypted)")
	exportCmd.Flags().StringVarP(&_exportDestPath, "dest", "d", "", "Destination path (plaintext)")
	exportCmd.Flags().BoolVarP(&exportSkipRecursive, "skip-recursive", "n", false, "Export directory non-recursively")
	exportCmd.Flags().StringVar(&unfinishedPolicy, "unfinished", "skip", "Unfinished operation policy: skip, ask, clean, rerun")
}
