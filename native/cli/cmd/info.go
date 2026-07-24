package cmd

import (
	"fmt"
	"path/filepath"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	infoPassword      string
	infoPasswordEnv   string
	infoPasswordStdin bool
	infoJSON          bool
	infoRootPath      string
)

var infoCmd = &cobra.Command{
	Use:   "info",
	Short: "Show encrypted root metadata",
	Long:  "Display encryption algorithm, KDF, name encryption mode and other root-level metadata.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if infoRootPath == "" {
			return fmt.Errorf("root path is required (--root)")
		}
		password, err := readPassword(passwordOptions{
			Password:      infoPassword,
			PasswordEnv:   infoPasswordEnv,
			PasswordStdin: infoPasswordStdin,
		})
		if err != nil {
			return err
		}

		absPath, err := filepath.Abs(infoRootPath)
		if err != nil {
			return err
		}

		if err := recoverConvertBeforeOpen(absPath); err != nil {
			return err
		}

		root, err := sec_fs.OpenRootQuick(sec_fs.FullStorePath(absPath), password)
		if err != nil {
			return fmt.Errorf("failed to open root: %w", err)
		}
		defer root.Close()

		cfg := root.GetConfig()
		rootPath := string(root.GetRootPath())

		dataFactory, _ := cfg.GetStr("sec_fs_factory")
		nameFactory, _ := cfg.GetStr("sec_name_factory")
		deriverFactory, _ := cfg.GetStr("sec_deriver_factory")
		passwordHint, _ := cfg.GetStr("sec_password_hint")

		// Detect password-changeable from the presence of a root-key envelope
		passwordChangeable := false
		if ver, err := cfg.GetInt("sec_key_envelope_version"); err == nil && ver > 0 {
			passwordChangeable = true
		}

		if infoJSON {
			writeJSONLine(map[string]interface{}{
				"event":               "root_info",
				"root_path":           rootPath,
				"data_factory":        dataFactory,
				"name_factory":        nameFactory,
				"deriver_factory":     deriverFactory,
				"password_changeable": passwordChangeable,
				"password_hint":       passwordHint,
			})
			return nil
		}

		fmt.Printf("Root Path:           %s\n", rootPath)
		fmt.Printf("Data Encryption:     %s\n", dataFactory)
		fmt.Printf("Name Encryption:     %s\n", nameFactory)
		fmt.Printf("Key Derivation:      %s\n", deriverFactory)
		fmt.Printf("Password Changeable: %v\n", passwordChangeable)
		if passwordHint != "" {
			fmt.Printf("Password Hint:       %s\n", passwordHint)
		}

		markers, err := sec_transfer.GetDefaultTransferV3().ListUnfinishedOperations(cmd.Context(), rootPath)
		if err == nil && len(markers) > 0 {
			fmt.Printf("\nUnfinished Operations: %d\n", len(markers))
			for _, m := range markers {
				fmt.Printf("  - %s (%s) status=%s created=%s\n",
					m.OpID, m.Type, m.Status,
					m.CreatedAt.Format("2006-01-02 15:04:05"))
			}
		}

		return nil
	},
}

func init() {
	infoCmd.Flags().StringVar(&infoRootPath, "root", "", "Root directory path (required)")
	infoCmd.Flags().StringVarP(&infoPassword, "password", "p", "", "Password for encryption")
	infoCmd.Flags().StringVar(&infoPasswordEnv, "password-env", "", "Read password from environment variable")
	infoCmd.Flags().BoolVar(&infoPasswordStdin, "password-stdin", false, "Read password from stdin")
	infoCmd.Flags().BoolVar(&infoJSON, "json", false, "Output as JSON Lines")
	rootCmd.AddCommand(infoCmd)
}
