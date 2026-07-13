package cmd

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:           "safe-disk",
	Short:         "Safe Disk CLI - encrypted file browser",
	Long:          "Safe Disk CLI is a command-line tool for managing encrypted files and directories.",
	SilenceErrors: true,
	SilenceUsage:  true,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		if jsonOutputRequested(os.Args[1:]) {
			var reported jsonReportedError
			if !errors.As(err, &reported) {
				writeJSONLine(map[string]interface{}{
					"event": "operation_failed",
					"error": err.Error(),
				})
			}
		} else {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		}
		os.Exit(1)
	}
}

func jsonOutputRequested(args []string) bool {
	for _, arg := range args {
		if arg == "--json" || arg == "--json=true" {
			return true
		}
		if strings.HasPrefix(arg, "--json=") {
			continue
		}
	}
	return false
}

func init() {
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(importCmd)
	rootCmd.AddCommand(exportCmd)
}
