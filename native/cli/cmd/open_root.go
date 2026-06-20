package cmd

import (
	"context"
	"fmt"
	"path/filepath"

	"safe_disk/native/sec_fs"
	"safe_disk/native/sec_fs/sec_transfer"
)

type openedRoot struct {
	RootPath sec_fs.FullStorePath
	Relative sec_fs.RelativeViewPath
	Root     sec_fs.ISecRoot
}

func openRootForPath(path string, opts passwordOptions) (*openedRoot, func(), error) {
	password, err := readPassword(opts)
	if err != nil {
		return nil, nil, err
	}
	return openRootForPathWithPassword(path, password)
}

func openRootForPathWithPassword(path string, password string) (*openedRoot, func(), error) {
	if path == "" {
		return nil, nil, fmt.Errorf("path is required")
	}
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, nil, err
	}
	if err := recoverConvertBeforeOpen(absPath); err != nil {
		return nil, nil, err
	}
	_, rootPath, relative, err := sec_fs.FindRootConfig(absPath)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to find root config: %w", err)
	}
	if string(rootPath) != absPath {
		if err := recoverConvertBeforeOpen(string(rootPath)); err != nil {
			return nil, nil, err
		}
	}
	root, err := sec_fs.OpenRootQuick(rootPath, password)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to open root: %w", err)
	}
	cleanup := func() {
		_ = root.Close()
	}
	if err := handleUnfinished(rootPath, root); err != nil {
		cleanup()
		return nil, nil, err
	}
	return &openedRoot{
		RootPath: rootPath,
		Relative: relative,
		Root:     root,
	}, cleanup, nil
}

func recoverConvertBeforeOpen(absPath string) error {
	manager := sec_transfer.GetDefaultTransferV3()
	result, err := manager.RecoverConvert(context.Background(), absPath)
	if err != nil {
		return fmt.Errorf("failed to inspect convert recovery state: %w", err)
	}
	switch result.Action {
	case sec_transfer.RecoverActionNone:
		return nil
	case sec_transfer.RecoverActionContinueRename, sec_transfer.RecoverActionCompleted:
		fmt.Printf("Recovered convert state: %s\n", result.Message)
		return nil
	case sec_transfer.RecoverActionRerun:
		fmt.Printf("Found unfinished convert operation: %s\n", result.Message)
		return nil
	case sec_transfer.RecoverActionNeedsAttention:
		return fmt.Errorf("unfinished convert operation needs attention: %s", result.Message)
	default:
		return fmt.Errorf("unknown convert recovery action: %s", result.Action)
	}
}

func addPasswordFlags(cmd flagBinder, password *string, passwordEnv *string, passwordStdin *bool) {
	cmd.StringVarP(password, "password", "p", "", "Password for encryption")
	cmd.StringVar(passwordEnv, "password-env", "", "Read password from environment variable")
	cmd.BoolVar(passwordStdin, "password-stdin", false, "Read password from stdin")
}

type flagBinder interface {
	StringVarP(p *string, name string, shorthand string, value string, usage string)
	StringVar(p *string, name string, value string, usage string)
	BoolVar(p *bool, name string, value bool, usage string)
}
