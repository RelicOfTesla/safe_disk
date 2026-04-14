package cmd

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
)

var (
	createPath          string
	createInPlace       bool
	createPassword      string
	createPasswordEnv   string
	createPasswordStdin bool
)

var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create an encrypted root directory",
	Long:  "Create an encrypted root directory. Existing non-empty directories require --in-place.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		if createPath == "" {
			return fmt.Errorf("path is required")
		}
		absPath, err := filepath.Abs(createPath)
		if err != nil {
			return err
		}
		password, err := readPassword(passwordOptions{
			Password:      createPassword,
			PasswordEnv:   createPasswordEnv,
			PasswordStdin: createPasswordStdin,
		})
		if err != nil {
			return err
		}

		configPath := filepath.Join(absPath, sec_fs.ConfigFileName)
		if _, err := os.Stat(configPath); err == nil {
			return fmt.Errorf("encrypted root already exists: %s", configPath)
		}

		exists, empty, err := dirState(absPath)
		if err != nil {
			return err
		}

		if !exists {
			if err := os.MkdirAll(absPath, 0755); err != nil {
				return err
			}
			return createEmptyRoot(absPath, password)
		}

		if empty {
			return createEmptyRoot(absPath, password)
		}

		if !createInPlace {
			return fmt.Errorf("directory is not empty; use --in-place to encrypt existing contents")
		}

		fmt.Printf("Encrypting existing directory in place: %s\n", absPath)
		transfer := sec_transfer.GetDefaultTransferV3()
		err = transfer.ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
			Kind:      sec_transfer.ConvertKindEncrypt,
			RootPath:  absPath,
			Password:  password,
			Overwrite: false,
		}, func(progress sec_transfer.ProgressEvent) {
			if progress.CurrentPath != "" {
				fmt.Printf("\rEncrypting: %s (%d/%d)", progress.CurrentPath, progress.DoneFiles, progress.TotalFiles)
			}
		})
		if err != nil {
			return fmt.Errorf("in-place encryption failed: %w", err)
		}
		fmt.Println("\nCreate successful")
		return nil
	},
}

func init() {
	createCmd.Flags().StringVar(&createPath, "path", "", "Root directory path")
	createCmd.Flags().BoolVar(&createInPlace, "in-place", false, "Encrypt existing non-empty directory")
	createCmd.Flags().StringVarP(&createPassword, "password", "p", "", "Password for encryption")
	createCmd.Flags().StringVar(&createPasswordEnv, "password-env", "", "Read password from environment variable")
	createCmd.Flags().BoolVar(&createPasswordStdin, "password-stdin", false, "Read password from stdin")
	rootCmd.AddCommand(createCmd)
}

func createEmptyRoot(path string, password string) error {
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(path), password, defaultCreateRootOptions()...); err != nil {
		return fmt.Errorf("failed to create root config: %w", err)
	}
	fmt.Printf("Created encrypted root: %s\n", path)
	return nil
}

func defaultCreateRootOptions() []sec_fs.CreateRootOption {
	return []sec_fs.CreateRootOption{
		sec_fs.WithDataFactory("aes-ctr"),
		sec_fs.WithNameFactory("none"),
	}
}

func dirState(path string) (exists bool, empty bool, err error) {
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		return false, false, nil
	}
	if err != nil {
		return false, false, err
	}
	if !info.IsDir() {
		return true, false, fmt.Errorf("path exists and is not a directory: %s", path)
	}
	entries, err := os.ReadDir(path)
	if err != nil {
		return true, false, err
	}
	return true, len(entries) == 0, nil
}
