package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"safe_disk/native/sec_fs"

	"github.com/spf13/cobra"
	"golang.org/x/term"
)

var (
	passwdRootPath string
	passwdJSON     bool
)

var passwdCmd = &cobra.Command{
	Use:   "passwd",
	Short: "Change root password (interactive only)",
	Long: "Change an encrypted root password via interactive TTY input.\n" +
		"The command prompts for the current password, then for a new password\n" +
		"with confirmation. No password flags are exposed for security.",
	Args: cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if passwdRootPath == "" {
			return fmt.Errorf("root path is required (--root)")
		}
		absPath, err := filepath.Abs(passwdRootPath)
		if err != nil {
			return err
		}
		if _, _, _, err := sec_fs.FindRootConfig(absPath); err != nil {
			return fmt.Errorf("no encrypted root found at %s: %w", absPath, err)
		}
		if !term.IsTerminal(int(os.Stdin.Fd())) {
			return fmt.Errorf("passwd requires an interactive terminal; password flags are not supported for security reasons")
		}
		if err := recoverConvertBeforeOpen(absPath); err != nil {
			return err
		}

		fmt.Fprint(os.Stderr, "Current password: ")
		currentData, err := term.ReadPassword(int(os.Stdin.Fd()))
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return fmt.Errorf("failed to read current password: %w", err)
		}
		if len(currentData) == 0 {
			return fmt.Errorf("current password is required")
		}

		fmt.Fprint(os.Stderr, "New password: ")
		newData, err := term.ReadPassword(int(os.Stdin.Fd()))
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return fmt.Errorf("failed to read new password: %w", err)
		}
		if len(newData) == 0 {
			return fmt.Errorf("new password is required")
		}

		fmt.Fprint(os.Stderr, "Confirm new password: ")
		confirmData, err := term.ReadPassword(int(os.Stdin.Fd()))
		fmt.Fprintln(os.Stderr)
		if err != nil {
			return fmt.Errorf("failed to read confirmation: %w", err)
		}
		if string(newData) != string(confirmData) {
			return fmt.Errorf("passwords do not match")
		}

		if err := sec_fs.ChangeRootPasswordQuick(sec_fs.FullStorePath(absPath), string(currentData), string(newData)); err != nil {
			if passwdJSON {
				writeJSONLine(map[string]interface{}{
					"event": "password_change_failed",
					"error": err.Error(),
				})
			}
			return fmt.Errorf("password change failed: %w", err)
		}

		if passwdJSON {
			writeJSONLine(map[string]interface{}{
				"event":  "password_changed",
				"status": "ok",
			})
		} else {
			fmt.Println("Password changed successfully.")
		}
		return nil
	},
}

func init() {
	passwdCmd.Flags().StringVar(&passwdRootPath, "root", "", "Root directory path (required)")
	passwdCmd.Flags().BoolVar(&passwdJSON, "json", false, "Output as JSON Lines")
	rootCmd.AddCommand(passwdCmd)
}
