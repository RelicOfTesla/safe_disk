package cmd

import (
	"fmt"
	"io"
	"os"
	"sync"

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
	Run: func(cmd *cobra.Command, args []string) {
		if exportPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}

		if exportSrcPath == "" {
			fmt.Println("Error: source path is required")
			os.Exit(1)
		}

		outputStd := _exportDestPath == "" || _exportDestPath == "-"

		exportDestPath := sec_fs.FullStorePath(_exportDestPath)

		_, fromRoot, fromRelative, err := sec_fs.FindRootConfig(exportSrcPath)
		if err != nil {
			fmt.Printf("Error: failed to find root config: %v\n", err)
			os.Exit(1)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRootQuick(fromRoot, exportPassword)
		if err != nil {
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()
		targetInfo, err := root.Stat(sec_fs.RelativeViewPath(exportSrcPath))
		if err != nil {
			fmt.Printf("Error: failed to stat: %v\n", err)
			os.Exit(1)
		}

		// Create transfer service
		transferService := sec_transfer.GetDefaultTransferManager()

		// Wait for completion using channel
		var wg sync.WaitGroup
		wg.Add(1)

		var lastExportErr error

		callback := func(status sec_transfer.ITransferProgress) {

			if !outputStd {
				// Print progress
				if currFile := status.GetCurrentFile(); currFile != "" {
					fmt.Printf("\rExporting: %s (%d/%d files)",
						currFile,
						status.GetCompleted(),
						status.GetTotal())
				}
			}

			// Check if complete
			if status.IsComplete() {
				if err := status.GetError(); err != nil {
					lastExportErr = err
				}
				wg.Done()
			}
		}

		// Perform export
		var task sec_transfer.ITask
		if targetInfo.IsDir() {
			if outputStd {
				fmt.Println("Error: stdout export not yet implemented")
				os.Exit(1)
			}
			fmt.Printf("Exporting directory: %s -> %s\n", exportSrcPath, exportDestPath)
			var opt *sec_transfer.TransferOptions
			if exportSkipRecursive {
				opt = &sec_transfer.TransferOptions{
					SkipRecursive: true,
				}
			}

			task, err = transferService.ExportDirectoryAsync(root, fromRelative, exportDestPath, callback, opt)
		} else {
			if outputStd {
				fp, err := root.OpenFile(fromRelative, os.O_RDONLY)
				if err != nil {
					fmt.Printf("Error: failed to open file: %v\n", err)
					os.Exit(1)
				}
				defer fp.Close()
				_, err = io.Copy(os.Stdout, fp)
				if err != nil {
					fmt.Printf("Error: failed to copy file: %v\n", err)
					os.Exit(1)
				}
				return
			} else {
				fmt.Printf("Exporting file: %s -> %s\n", exportSrcPath, exportDestPath)
				task, err = transferService.ExportFileAsync(root, fromRelative, exportDestPath, callback, nil)
			}
		}

		if err != nil {
			fmt.Printf("\nError: failed to start export: %v\n", err)
			os.Exit(1)
		}

		if !outputStd {
			fmt.Printf("Task started: %s\n", task.GetTaskID())
		}

		// Wait for completion
		wg.Wait()

		// Check result
		if lastExportErr != nil {
			fmt.Printf("\nError: export failed: %v\n", lastExportErr)
			os.Exit(1)
		}

		if !outputStd {
			fmt.Println("\nExport successful!")
			_, total := task.GetTotalProgress()
			fmt.Printf("Files exported: %d\n", total)
		}
	},
}

func init() {
	exportCmd.Flags().StringVarP(&exportPassword, "password", "p", "", "Password for encryption")
	exportCmd.Flags().StringVarP(&exportSrcPath, "source", "s", "", "Source path (encrypted)")
	exportCmd.Flags().StringVarP(&_exportDestPath, "dest", "d", "", "Destination path (plaintext)")
	exportCmd.Flags().BoolVarP(&exportSkipRecursive, "skip-recursive", "n", false, "Export directory non-recursively")
}
