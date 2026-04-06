package cmd

import (
	"fmt"
	"os"
	"sync"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	exportRootPath  string
	exportPassword  string
	exportSrcPath   string
	exportDestPath  string
	exportRecursive bool
)

var exportCmd = &cobra.Command{
	Use:   "export [root-path]",
	Short: "Export files from an encrypted root directory",
	Long:  "Export encrypted files to plaintext from an encrypted root directory.",
	Args:  cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) > 0 {
			exportRootPath = args[0]
		}

		if exportRootPath == "" {
			fmt.Println("Error: root path is required")
			os.Exit(1)
		}

		if exportPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}

		if exportSrcPath == "" {
			fmt.Println("Error: source path is required")
			os.Exit(1)
		}

		if exportDestPath == "" {
			fmt.Println("Error: destination path is required")
			os.Exit(1)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRoot(sec_fs.FullStorePath(exportRootPath), exportPassword, nil)
		if err != nil {
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()

		// Create transfer service
		transferService := sec_transfer.NewTransferService()

		// Wait for completion using channel
		var wg sync.WaitGroup
		wg.Add(1)

		var lastStatus sec_transfer.ProgressStatus
		var exportErr error

		callback := func(status sec_transfer.ProgressStatus) {
			lastStatus = status

			// Print progress
			if status.CurrentFile != "" {
				fmt.Printf("\rExporting: %s (%d/%d files, %d/%d bytes)",
					status.CurrentFile,
					status.FilesCompleted,
					status.FilesTotal,
					status.BytesCompleted,
					status.BytesTotal)
			}

			// Check if complete
			if status.IsComplete {
				if status.Error != nil {
					exportErr = status.Error
				}
				wg.Done()
			}
		}

		// Perform export
		var taskID string
		if exportRecursive {
			fmt.Printf("Exporting directory: %s -> %s\n", exportSrcPath, exportDestPath)
			taskID, err = transferService.ExportDirectoryAsync(root, sec_fs.RelativeViewPath(exportSrcPath), sec_transfer.ExternalPath(exportDestPath), nil, callback)
		} else {
			fmt.Printf("Exporting file: %s -> %s\n", exportSrcPath, exportDestPath)
			taskID, err = transferService.ExportFileAsync(root, sec_fs.RelativeViewPath(exportSrcPath), sec_transfer.ExternalPath(exportDestPath), nil, callback)
		}

		if err != nil {
			fmt.Printf("\nError: failed to start export: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Task started: %s\n", taskID)

		// Wait for completion
		wg.Wait()

		// Check result
		if exportErr != nil {
			fmt.Printf("\nError: export failed: %v\n", exportErr)
			os.Exit(1)
		}

		fmt.Println("\nExport successful!")
		fmt.Printf("Files exported: %d\n", lastStatus.FilesCompleted)
		fmt.Printf("Total bytes: %d\n", lastStatus.BytesCompleted)
	},
}

func init() {
	exportCmd.Flags().StringVarP(&exportPassword, "password", "p", "", "Password for encryption")
	exportCmd.Flags().StringVarP(&exportSrcPath, "source", "s", "", "Source path (encrypted)")
	exportCmd.Flags().StringVarP(&exportDestPath, "dest", "d", "", "Destination path (plaintext)")
	exportCmd.Flags().BoolVarP(&exportRecursive, "recursive", "r", false, "Export directory recursively")
}
