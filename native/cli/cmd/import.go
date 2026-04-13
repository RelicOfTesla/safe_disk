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
	importPassword      string
	_importSrcPath      string
	importDestPath      string
	importSkipRecursive bool
)

var importCmd = &cobra.Command{
	Use:   "import",
	Short: "Import files into an encrypted root directory",
	Long:  "Import plaintext files into an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	Run: func(cmd *cobra.Command, args []string) {

		if importPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}

		if _importSrcPath == "" {
			fmt.Println("Error: source path is required")
			os.Exit(1)
		}
		importSrcPath := sec_fs.FullStorePath(_importSrcPath)

		_, destRoot, destRelative, err := sec_fs.FindRootConfig(importDestPath)
		if err != nil {
			if err == sec_fs.ErrNotConfigFile {
				// TODO: CreateDir
			}
			fmt.Printf("Error: failed to find root config: %v\n", err)
			os.Exit(1)
		}

		if importDestPath == "" {
			fmt.Println("Error: destination path is required")
			os.Exit(1)
		}

		// Open or create the encrypted root directory
		root, err := sec_fs.OpenRootQuick(destRoot, importPassword)
		if err != nil {
			if err == sec_fs.ErrNotConfigFile {
				// TODO: CreateDir
			}
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()

		// Create transfer service
		transferService := sec_transfer.GetDefaultTransferManager()

		// Wait for completion using channel
		var wg sync.WaitGroup
		wg.Add(1)

		var importErr error

		callback := func(status sec_transfer.ITransferProgress) {
			// Print progress
			if status.GetCurrentFile() != "" {
				fmt.Printf("\rImporting: %s (%d/%d files)",
					status.GetCurrentFile(),
					status.GetCompleted(),
					status.GetTotal())
			}

			// Check if complete
			if status.IsComplete() {
				if err := status.GetError(); err != nil {
					importErr = err
				}
				wg.Done()
			}
		}

		srcInfo, err := os.Stat(_importSrcPath)
		if err != nil {
			fmt.Printf("Error: failed to stat: %v\n", err)
			os.Exit(1)
		}

		// Perform import
		var taskInfo sec_transfer.ITask
		if srcInfo.IsDir() {
			fmt.Printf("Importing directory: %s -> %s\n", importSrcPath, importDestPath)
			var opt *sec_transfer.TransferOptions
			if importSkipRecursive {
				opt = &sec_transfer.TransferOptions{
					SkipRecursive: true,
				}
			}

			taskInfo, err = transferService.ImportDirectoryAsync(importSrcPath, root, destRelative, callback, opt)
		} else {
			fmt.Printf("Importing file: %s -> %s\n", importSrcPath, importDestPath)
			taskInfo, err = transferService.ImportFileAsync(importSrcPath, root, destRelative, callback, nil)
		}

		if err != nil {
			fmt.Printf("\nError: failed to start import: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Task started: %s\n", taskInfo.GetTaskID())

		// Wait for completion
		wg.Wait()

		// Check result
		if importErr != nil {
			fmt.Printf("\nError: import failed: %v\n", importErr)
			os.Exit(1)
		}

		fmt.Println("\nImport successful!")
		totalFiles, totalBytes := taskInfo.GetTotalProgress()
		fmt.Printf("Files imported: %d\n", totalFiles)
		fmt.Printf("Total bytes: %d\n", totalBytes)
	},
}

func init() {
	importCmd.Flags().StringVarP(&importPassword, "password", "p", "", "Password for encryption")
	importCmd.Flags().StringVarP(&_importSrcPath, "source", "s", "", "Source path (plaintext)")
	importCmd.Flags().StringVarP(&importDestPath, "dest", "d", "", "Destination path (encrypted)")
	importCmd.Flags().BoolVarP(&importSkipRecursive, "skip-recursive", "n", false, "Import directory non-recursively")
}
