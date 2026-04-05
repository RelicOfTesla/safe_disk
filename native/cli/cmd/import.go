package cmd

import (
	"fmt"
	"os"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	importRootPath   string
	importPassword   string
	importSrcPath    string
	importDestPath   string
	importRecursive  bool
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

		// Open the encrypted root directory
		root, err := sec_fs.OpenRoot(sec_fs.FullStorePath(importRootPath), importPassword, nil)
		if err != nil {
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()

		// Create transfer service
		transferService := sec_transfer.NewTransferService()

		// Perform import
		var result *sec_transfer.TransferResult
		if importRecursive {
			fmt.Printf("Importing directory: %s -> %s\n", importSrcPath, importDestPath)
			result, err = transferService.ImportDirectory(root, importSrcPath, importDestPath)
		} else {
			fmt.Printf("Importing file: %s -> %s\n", importSrcPath, importDestPath)
			result, err = transferService.ImportFile(root, importSrcPath, importDestPath)
		}

		if err != nil {
			fmt.Printf("Error: import failed: %v\n", err)
			os.Exit(1)
		}

		if !result.Success {
			fmt.Printf("Error: import failed: %s\n", result.ErrorMessage)
			os.Exit(1)
		}

		fmt.Println("Import successful!")
		fmt.Printf("Files imported: %d\n", result.FilesCount)
		fmt.Printf("Total bytes: %d\n", result.TotalBytes)
	},
}

func init() {
	importCmd.Flags().StringVarP(&importPassword, "password", "p", "", "Password for encryption")
	importCmd.Flags().StringVarP(&importSrcPath, "source", "s", "", "Source path (plaintext)")
	importCmd.Flags().StringVarP(&importDestPath, "dest", "d", "", "Destination path (encrypted)")
	importCmd.Flags().BoolVarP(&importRecursive, "recursive", "r", false, "Import directory recursively")
}
