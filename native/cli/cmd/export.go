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
	exportPasswordEnv   string
	exportPasswordStdin bool
	exportSrcPath       string
	_exportDestPath     string
	exportSkipRecursive bool
	exportJSON          bool
	exportDurability    string
)

var exportCmd = &cobra.Command{
	Use:   "export",
	Short: "Export files from an encrypted root directory",
	Long:  "Export encrypted files to plaintext from an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		durability, err := parseDurability(exportDurability)
		if err != nil {
			return err
		}
		if exportSrcPath == "" {
			return fmt.Errorf("source path is required")
		}

		outputStd := _exportDestPath == "" || _exportDestPath == "-"

		exportDestPath := sec_fs.FullStorePath(_exportDestPath)

		opened, cleanup, err := openRootForPath(exportSrcPath, passwordOptions{
			Password:      exportPassword,
			PasswordEnv:   exportPasswordEnv,
			PasswordStdin: exportPasswordStdin,
		}, durability)
		if err != nil {
			return err
		}
		defer cleanup()
		root := opened.Root
		fromRelative := opened.Relative
		targetInfo, err := root.Stat(fromRelative)
		if err != nil {
			return fmt.Errorf("failed to stat: %w", err)
		}

		transferService := sec_transfer.GetDefaultTransferV3()
		var doneFiles int64
		var totalFiles int64
		var callback sec_transfer.V3ProgressCallback
		var jsonReporter *transferJSONReporter
		if exportJSON {
			jsonReporter = newTransferJSONReporter(sec_transfer.OperationExport)
			callback = jsonReporter.Callback()
		} else {
			callback = func(status sec_transfer.ProgressEvent) {
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
		}

		if targetInfo.IsDir() {
			if outputStd {
				return fmt.Errorf("stdout export not yet implemented")
			}
			if !exportJSON {
				fmt.Printf("Exporting directory: %s -> %s\n", exportSrcPath, exportDestPath)
			}
			err = transferService.ExportDirectory(context.Background(), sec_transfer.ExportDirectoryRequest{
				SourceRoot:    root,
				Source:        fromRelative,
				Dest:          exportDestPath,
				SkipRecursive: exportSkipRecursive,
				Overwrite:     true,
				Durability:    durability,
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
				if !exportJSON {
					fmt.Printf("Exporting file: %s -> %s\n", exportSrcPath, exportDestPath)
				}
				err = transferService.ExportFile(context.Background(), sec_transfer.ExportFileRequest{
					SourceRoot: root,
					Source:     fromRelative,
					Dest:       exportDestPath,
					Overwrite:  true,
					Durability: durability,
				}, callback)
			}
		}

		if err != nil {
			wrapped := fmt.Errorf("export failed: %w", err)
			if jsonReporter != nil {
				return jsonReporter.WrapError(wrapped)
			}
			return wrapped
		}

		if !outputStd && !exportJSON {
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
	addPasswordFlags(exportCmd.Flags(), &exportPassword, &exportPasswordEnv, &exportPasswordStdin)
	exportCmd.Flags().StringVarP(&exportSrcPath, "source", "s", "", "Source path (encrypted)")
	exportCmd.Flags().StringVarP(&_exportDestPath, "dest", "d", "", "Destination path (plaintext)")
	exportCmd.Flags().BoolVarP(&exportSkipRecursive, "skip-recursive", "n", false, "Export directory non-recursively")
	exportCmd.Flags().BoolVar(&exportJSON, "json", false, "Output JSON Lines progress events")
	exportCmd.Flags().StringVar(&exportDurability, "durability", "full", durabilityFlagUsage)
	exportCmd.Flags().StringVar(&unfinishedPolicy, "unfinished", "skip", "Unfinished operation policy: skip, ask, clean, rerun")
}
