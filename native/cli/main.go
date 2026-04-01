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

	// Add commands
	rootCmd.AddCommand(cmdEncrypt())
	rootCmd.AddCommand(cmdDecrypt())
	rootCmd.AddCommand(cmdVerify())
	rootCmd.AddCommand(cmdChangepass())
	rootCmd.AddCommand(cmdExport())

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
