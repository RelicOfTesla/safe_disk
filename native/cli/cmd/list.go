package cmd

import (
	"fmt"
	"io"

	"github.com/spf13/cobra"
)

var (
	listPassword      string
	listPasswordEnv   string
	listPasswordStdin bool
	listPath          string
)

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List files in an encrypted root directory",
	Long:  "List files and directories in an encrypted root directory.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		opened, cleanup, err := openRootForPath(listPath, passwordOptions{
			Password:      listPassword,
			PasswordEnv:   listPasswordEnv,
			PasswordStdin: listPasswordStdin,
		})
		if err != nil {
			return err
		}
		defer cleanup()
		root := opened.Root
		listRelative := opened.Relative

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
		for {
			entry, err := walker.Next()
			if err != nil {
				if err == io.EOF {
					break
				}
				return fmt.Errorf("failed to read directory entries: %w", err)
			}

			typeStr := "FILE"
			if entry.IsDir() {
				typeStr = "DIR "
			}
			fi, err := entry.Info()
			if err != nil {
				return fmt.Errorf("failed to read directory entry metadata: %w", err)
			}

			fmt.Printf("[%s] %s (%d bytes)\n", typeStr, entry.Name(), fi.Size())
			count++
		}

		fmt.Println("=====================================")
		fmt.Printf("Total: %d items\n", count)

		return nil
	},
}

func init() {
	addPasswordFlags(listCmd.Flags(), &listPassword, &listPasswordEnv, &listPasswordStdin)
	listCmd.Flags().StringVarP(&listPath, "path", "d", "", "Directory path to list (default: root)")
	listCmd.Flags().StringVar(&unfinishedPolicy, "unfinished", "skip", "Unfinished operation policy: skip, ask, clean, rerun")
}
