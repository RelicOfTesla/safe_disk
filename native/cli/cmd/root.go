package cmd

import (
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "safe-disk",
	Short: "Safe Disk CLI - encrypted file browser",
	Long:  "Safe Disk CLI is a command-line tool for managing encrypted files and directories.",
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(importCmd)
	rootCmd.AddCommand(exportCmd)
}
