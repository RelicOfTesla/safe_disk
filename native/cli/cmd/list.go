package cmd

import (
	"fmt"
	"os"

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
	Run: func(cmd *cobra.Command, args []string) {

		if listPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}
		_, listRoot, listRelative, err := sec_fs.FindRootConfig(listPath)
		if err != nil {
			fmt.Printf("Error: failed to find root config: %v\n", err)
			os.Exit(1)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRootQuick(listRoot, listPassword)
		if err != nil {
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()

		// Get directory info
		info, err := root.Stat(listRelative)
		if err != nil {
			fmt.Printf("Error: failed to get directory info: %v\n", err)
			os.Exit(1)
		}
		if !info.IsDir() {
			fi := info
			fmt.Printf("[%s] %s (%d bytes)\n", "FILE", info.Name(), fi.Size())
			return
		}

		// Walk the directory
		walker, err := root.WalkDir(listRelative)
		if err != nil {
			fmt.Printf("Error: failed to walk directory: %v\n", err)
			os.Exit(1)
		}
		defer walker.Close()

		fmt.Printf("Contents of %s:\n", listPath)
		fmt.Println("=====================================")

		count := 0
		for walker.HasNext() {
			entry, err := walker.Next()
			if err != nil {
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
	},
}

func init() {
	listCmd.Flags().StringVarP(&listPassword, "password", "p", "", "Password for encryption")
	listCmd.Flags().StringVarP(&listPath, "path", "d", "", "Directory path to list (default: root)")
}
