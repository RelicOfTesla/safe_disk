package cmd

import (
	"fmt"
	"os"

	"safe_disk/native/sec_fs"

	"github.com/spf13/cobra"
)

var (
	listRootPath string
	listPassword string
	listPath     string
)

var listCmd = &cobra.Command{
	Use:   "list [root-path]",
	Short: "List files in an encrypted root directory",
	Long:  "List files and directories in an encrypted root directory.",
	Args:  cobra.MaximumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) > 0 {
			listRootPath = args[0]
		}

		if listRootPath == "" {
			fmt.Println("Error: root path is required")
			os.Exit(1)
		}

		if listPassword == "" {
			fmt.Println("Error: password is required")
			os.Exit(1)
		}

		// Open the encrypted root directory
		root, err := sec_fs.OpenRoot(sec_fs.FullStorePath(listRootPath), listPassword, nil)
		if err != nil {
			fmt.Printf("Error: failed to open root: %v\n", err)
			os.Exit(1)
		}
		defer root.Close()

		// Walk the directory
		walker, err := root.WalkDir(sec_fs.RelativeViewPath(listPath))
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
			if entry.IsDir {
				typeStr = "DIR "
			}

			fmt.Printf("[%s] %s (%d bytes)\n", typeStr, entry.Name, entry.Size)
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
