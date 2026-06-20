package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	importPassword      string
	importPasswordEnv   string
	importPasswordStdin bool
	_importSrcPath      string
	importDestPath      string
	importSkipRecursive bool
	importJSON          bool
)

var importCmd = &cobra.Command{
	Use:   "import",
	Short: "Import files into an encrypted root directory",
	Long:  "Import plaintext files into an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if _importSrcPath == "" {
			return fmt.Errorf("source path is required")
		}
		password, err := readPassword(passwordOptions{
			Password:      importPassword,
			PasswordEnv:   importPasswordEnv,
			PasswordStdin: importPasswordStdin,
		})
		if err != nil {
			return err
		}
		importSrcPath := sec_fs.FullStorePath(_importSrcPath)

		// Check if source exists BEFORE checking destination config
		srcInfo, err := os.Stat(_importSrcPath)
		if err != nil {
			return fmt.Errorf("failed to stat: %w", err)
		}

		if importDestPath == "" {
			return fmt.Errorf("destination path is required")
		}

		opened, cleanup, err := openRootForPathWithPassword(importDestPath, password)
		if err != nil {
			return err
		}
		defer cleanup()
		root := opened.Root
		destRelative := opened.Relative

		transferService := sec_transfer.GetDefaultTransferV3()
		var doneFiles int64
		var totalFiles int64
		var callback sec_transfer.V3ProgressCallback
		var jsonReporter *transferJSONReporter
		if importJSON {
			jsonReporter = newTransferJSONReporter(sec_transfer.OperationImport)
			callback = jsonReporter.Callback()
		} else {
			callback = func(status sec_transfer.ProgressEvent) {
				totalFiles = status.TotalFiles
				doneFiles = status.DoneFiles
				if status.CurrentPath != "" {
					fmt.Printf("\rImporting: %s (%d/%d files)",
						status.CurrentPath,
						status.DoneFiles,
						status.TotalFiles)
				}
			}
		}

		if srcInfo.IsDir() {
			if !importJSON {
				fmt.Printf("Importing directory: %s -> %s\n", importSrcPath, importDestPath)
			}
			err = transferService.ImportDirectory(context.Background(), sec_transfer.ImportDirectoryRequest{
				Source:        importSrcPath,
				DestRoot:      root,
				Dest:          destRelative,
				SkipRecursive: importSkipRecursive,
				Overwrite:     true,
			}, callback)
		} else {
			fileDest := destRelative
			if string(fileDest) == "" {
				fileDest = sec_fs.RelativeViewPath(filepath.Base(_importSrcPath))
			} else if info, statErr := root.Stat(fileDest); statErr == nil && info.IsDir() {
				fileDest = sec_fs.RelativeViewPath(filepath.ToSlash(filepath.Join(string(fileDest), filepath.Base(_importSrcPath))))
			}
			if !importJSON {
				fmt.Printf("Importing file: %s -> %s\n", importSrcPath, importDestPath)
			}
			err = transferService.ImportFile(context.Background(), sec_transfer.ImportFileRequest{
				Source:    importSrcPath,
				DestRoot:  root,
				Dest:      fileDest,
				Overwrite: true,
			}, callback)
		}

		if err != nil {
			if jsonReporter != nil {
				jsonReporter.Failed(err)
			}
			return fmt.Errorf("import failed: %w", err)
		}

		if !importJSON {
			fmt.Println("\nImport successful!")
			if doneFiles == 0 {
				doneFiles = totalFiles
			}
			fmt.Printf("Files imported: %d\n", doneFiles)
		}
		return nil
	},
}

func init() {
	addPasswordFlags(importCmd.Flags(), &importPassword, &importPasswordEnv, &importPasswordStdin)
	importCmd.Flags().StringVarP(&_importSrcPath, "source", "s", "", "Source path (plaintext)")
	importCmd.Flags().StringVarP(&importDestPath, "dest", "d", "", "Destination path (encrypted)")
	importCmd.Flags().BoolVarP(&importSkipRecursive, "skip-recursive", "n", false, "Import directory non-recursively")
	importCmd.Flags().BoolVar(&importJSON, "json", false, "Output JSON Lines progress events")
	importCmd.Flags().StringVar(&unfinishedPolicy, "unfinished", "skip", "Unfinished operation policy: skip, ask, clean, rerun")
}
