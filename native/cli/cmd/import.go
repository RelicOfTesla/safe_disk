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
	importRootPath  string
	importPassword  string
	importSrcPath   string
	importDestPath  string
	importRecursive bool
)

var importCmd = &cobra.Command{
	Use:   "import [root-path]",
	Short: "Import files into an encrypted root directory",
	Long:  "Import plaintext files into an encrypted root directory.",
	Args:  cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) > 0 {
			importRootPath = args[0]
		}

		if importRootPath == "" {
			fmt.Println("Error: root path is required")
			os.Exit(1)
		}

		if importPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}

		if importSrcPath == "" {
			fmt.Println("Error: source path is required")
			os.Exit(1)
		}

		if importDestPath == "" {
			fmt.Println("Error: destination path is required")
			os.Exit(1)
		}

		// Open or create the encrypted root directory
		root, err := sec_fs.OpenOrCreateRoot(sec_fs.FullStorePath(importRootPath), importPassword, nil)
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
		var importErr error

		callback := func(status sec_transfer.ProgressStatus) {
			lastStatus = status

			// Print progress
			if status.CurrentFile != "" {
				fmt.Printf("\rImporting: %s (%d/%d files, %d/%d bytes)",
					status.CurrentFile,
					status.FilesCompleted,
					status.FilesTotal,
					status.BytesCompleted,
					status.BytesTotal)
			}

			// Check if complete
			if status.IsComplete {
				if status.Error != nil {
					importErr = status.Error
				}
				wg.Done()
			}
		}

		// Perform import
		var taskID string
		if importRecursive {
			fmt.Printf("Importing directory: %s -> %s\n", importSrcPath, importDestPath)
			taskID, err = transferService.ImportDirectoryAsync(root, nil, importSrcPath, sec_fs.RelativeViewPath(importDestPath), nil, callback)
		} else {
			fmt.Printf("Importing file: %s -> %s\n", importSrcPath, importDestPath)
			taskID, err = transferService.ImportFileAsync(root, nil, importSrcPath, sec_fs.RelativeViewPath(importDestPath), nil, callback)
		}

		if err != nil {
			fmt.Printf("\nError: failed to start import: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Task started: %s\n", taskID)

		// Wait for completion
		wg.Wait()

		// Check result
		if importErr != nil {
			fmt.Printf("\nError: import failed: %v\n", importErr)
			os.Exit(1)
		}

		fmt.Println("\nImport successful!")
		fmt.Printf("Files imported: %d\n", lastStatus.FilesCompleted)
		fmt.Printf("Total bytes: %d\n", lastStatus.BytesCompleted)
	},
}

func init() {
	importCmd.Flags().StringVarP(&importPassword, "password", "p", "", "Password for encryption")
	importCmd.Flags().StringVarP(&importSrcPath, "source", "s", "", "Source path (plaintext)")
	importCmd.Flags().StringVarP(&importDestPath, "dest", "d", "", "Destination path (encrypted)")
	importCmd.Flags().BoolVarP(&importRecursive, "recursive", "r", false, "Import directory recursively")
}
