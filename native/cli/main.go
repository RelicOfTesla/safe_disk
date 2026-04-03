package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	// Version information
	Version = "1.0.0"
)

func main() {
	var rootCmd = &cobra.Command{
		Use:     "safedisk-cli",
		Short:   "Safe Disk command-line encryption tool",
		Long:    "Safe Disk CLI is a command-line tool for encrypting and decrypting directories",
		Version: Version,
	}

	// Session management commands
	rootCmd.AddCommand(cmdOpen())
	rootCmd.AddCommand(cmdClose())
	rootCmd.AddCommand(cmdListSessions())

	// File operation commands (session-based)
	rootCmd.AddCommand(cmdLs())
	rootCmd.AddCommand(cmdRead())
	rootCmd.AddCommand(cmdWrite())
	rootCmd.AddCommand(cmdStat())
	rootCmd.AddCommand(cmdDelete())
	rootCmd.AddCommand(cmdMkdir())

	// Quick operation commands (no session needed)
	rootCmd.AddCommand(cmdQuickRead())
	rootCmd.AddCommand(cmdQuickWrite())

	// Directory encryption/decryption commands
	rootCmd.AddCommand(cmdEncrypt())
	rootCmd.AddCommand(cmdDecrypt())

	// Transfer commands (session-based)
	rootCmd.AddCommand(cmdTransferEncrypt())
	rootCmd.AddCommand(cmdTransferDecrypt())

	// Legacy commands (kept for backward compatibility)
	rootCmd.AddCommand(cmdVerify())
	rootCmd.AddCommand(cmdChangepass())
	rootCmd.AddCommand(cmdExport())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
