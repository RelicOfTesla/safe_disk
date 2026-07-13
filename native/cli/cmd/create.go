package cmd

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"

	"github.com/spf13/cobra"
	"golang.org/x/term"
)

var (
	createPath          string
	createInPlace       bool
	createPassword      string
	createPasswordEnv   string
	createPasswordStdin bool
	createJSON          bool
	createDurability    string
)

var createCmd = &cobra.Command{
	Use:   "create",
	Short: "Create an encrypted root directory",
	Long:  "Create an encrypted root directory. Existing non-empty directories require --in-place.",
	Args:  cobra.MaximumNArgs(0),
	RunE: func(cmd *cobra.Command, args []string) error {
		durability, err := parseDurability(createDurability)
		if err != nil {
			return err
		}
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
			if err := os.MkdirAll(absPath, sec_fs.SecureDirMode); err != nil {
				return err
			}
			return createEmptyRoot(absPath, password)
		}

		if empty {
			return createEmptyRoot(absPath, password)
		}

		if !createInPlace {
			if createJSON {
				return errCreateNonEmptyNeedsInPlace()
			}
			confirmed, err := confirmInPlaceForNonEmptyDir(os.Stdin, os.Stderr, term.IsTerminal(int(os.Stdin.Fd())))
			if err != nil {
				return err
			}
			if !confirmed {
				return errCreateNonEmptyNeedsInPlace()
			}
		}

		if !createJSON {
			fmt.Printf("Encrypting existing directory in place: %s\n", absPath)
		}
		transfer := sec_transfer.GetDefaultTransferV3()
		var callback sec_transfer.V3ProgressCallback
		var jsonReporter *transferJSONReporter
		if createJSON {
			jsonReporter = newTransferJSONReporter(sec_transfer.OperationConvertEncrypt)
			callback = jsonReporter.Callback()
		} else {
			callback = func(progress sec_transfer.ProgressEvent) {
				if progress.CurrentPath != "" {
					fmt.Printf("\rEncrypting: %s (%d/%d)", progress.CurrentPath, progress.DoneFiles, progress.TotalFiles)
				}
			}
		}
		err = transfer.ConvertRoot(context.Background(), sec_transfer.ConvertRequest{
			Kind:       sec_transfer.ConvertKindEncrypt,
			RootPath:   absPath,
			Password:   password,
			Overwrite:  false,
			Durability: durability,
		}, callback)
		if err != nil {
			wrapped := fmt.Errorf("in-place encryption failed: %w", err)
			if jsonReporter != nil {
				return jsonReporter.WrapError(wrapped)
			}
			return wrapped
		}
		if !createJSON {
			fmt.Println("\nCreate successful")
		}
		return nil
	},
}

func init() {
	createCmd.Flags().StringVar(&createPath, "path", "", "Root directory path")
	createCmd.Flags().BoolVar(&createInPlace, "in-place", false, "Encrypt existing non-empty directory")
	createCmd.Flags().StringVarP(&createPassword, "password", "p", "", "Password for encryption")
	createCmd.Flags().StringVar(&createPasswordEnv, "password-env", "", "Read password from environment variable")
	createCmd.Flags().BoolVar(&createPasswordStdin, "password-stdin", false, "Read password from stdin")
	createCmd.Flags().BoolVar(&createJSON, "json", false, "Output JSON Lines progress events for --in-place")
	createCmd.Flags().StringVar(&createDurability, "durability", "full", durabilityFlagUsage)
	rootCmd.AddCommand(createCmd)
}

func createEmptyRoot(path string, password string) error {
	if _, _, err := sec_fs.CreateRootConfigQuick(sec_fs.FullStorePath(path), password, defaultCreateRootOptions()...); err != nil {
		return fmt.Errorf("failed to create root config: %w", err)
	}
	fmt.Printf("Created encrypted root: %s\n", path)
	return nil
}

func confirmInPlaceForNonEmptyDir(reader io.Reader, writer io.Writer, interactive bool) (bool, error) {
	if !interactive {
		return false, errCreateNonEmptyNeedsInPlace()
	}
	if _, err := fmt.Fprint(writer, "Directory is not empty. Encrypt existing contents in place? [y/N] "); err != nil {
		return false, err
	}
	line, err := bufio.NewReader(reader).ReadString('\n')
	if err != nil && len(line) == 0 {
		return false, fmt.Errorf("failed to read in-place confirmation: %w", err)
	}
	answer := strings.ToLower(strings.TrimSpace(line))
	return answer == "y" || answer == "yes", nil
}

func errCreateNonEmptyNeedsInPlace() error {
	return fmt.Errorf("directory is not empty; use --in-place to encrypt existing contents")
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
