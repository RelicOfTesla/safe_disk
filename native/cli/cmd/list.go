package cmd

import (
	"fmt"

	"safe_disk/native/sec_fs"

	"github.com/spf13/cobra"
)

var (
	listPassword string
	listPath     string
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List files in an encrypted root directory",
	Long:  "List files and directories in an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if listPassword == "" {
			return fmt.Errorf("password is required")
		}
		_, listRoot, listRelative, err := sec_fs.FindRootConfig(listPath)
		if err != nil {
			return fmt.Errorf("failed to find root config: %w", err)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRootQuick(listRoot, listPassword)
		if err != nil {
			return fmt.Errorf("failed to open root: %w", err)
		}
		defer root.Close()
		if err := handleUnfinished(listRoot); err != nil {
			return err
		}

		// Get directory info
		info, err := root.Stat(listRelative)
		if err != nil {
			return fmt.Errorf("failed to get directory info: %w", err)
		}
		if !info.IsDir() {
			fi := info
			fmt.Printf("[%s] %s (%d bytes)\n", "FILE", info.Name(), fi.Size())
			return nil
		}

		// Walk the directory
		walker, err := root.WalkDir(listRelative)
		if err != nil {
			return fmt.Errorf("failed to walk directory: %w", err)
		}
		defer walker.Close()

		fmt.Printf("Contents of %s:\n", listPath)
		fmt.Println("=====================================")

		count := 0
		var firstError error
		for walker.HasNext() {
			entry, err := walker.Next()
			if err != nil {
				if firstError == nil {
					firstError = err
				}
				fmt.Printf("Error reading entry: %v\n", err)
				break
			}

			typeStr := "FILE"
			if entry.IsDir() {
				typeStr = "DIR "
			}
			fi, err := entry.Info()
			if err != nil {
				fmt.Printf("Error getting file info: %v\n", err)
				continue
			}

			fmt.Printf("[%s] %s (%d bytes)\n", typeStr, entry.Name(), fi.Size())
			count++
		}

		fmt.Println("=====================================")
		fmt.Printf("Total: %d items\n", count)

		// Return error if there was an error reading entries
		// This helps detect issues like wrong password
		if firstError != nil && count == 0 {
			return fmt.Errorf("failed to read directory entries: %w (this may indicate wrong password)", firstError)
		}

		return nil
	},
}

func init() {
	listCmd.Flags().StringVarP(&listPassword, "password", "p", "", "Password for encryption")
	listCmd.Flags().StringVarP(&listPath, "path", "d", "", "Directory path to list (default: root)")
	listCmd.Flags().StringVar(&unfinishedPolicy, "unfinished", "skip", "Unfinished operation policy: skip, ask, clean, rerun")
}
