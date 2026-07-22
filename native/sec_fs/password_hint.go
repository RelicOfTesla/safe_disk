package sec_fs

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"time"
	"unicode/utf8"

	"safe_disk/native/config"
)

const (
	passwordHintConfigKey = "sec_password_hint"
	maxPasswordHintBytes  = 256
)

// ReadRootPasswordHint returns public password-reminder metadata. Missing and
// empty values both mean that no hint is configured.
func ReadRootPasswordHint(rootPath FullStorePath) (string, error) {
	if rootPath == "" {
		return "", ErrInvalidPath
	}
	cfg, err := config.NewFileConfig(filepath.Join(string(rootPath), ConfigFileName))
	if err != nil {
		return "", NewConfigError("config", "failed to load config file", err)
	}
	hint, err := cfg.GetStr(passwordHintConfigKey)
	if err != nil {
		var missing config.ErrKeyNotFound
		if errors.As(err, &missing) {
			return "", nil
		}
		return "", NewConfigError(passwordHintConfigKey, "failed to read password hint", err)
	}
	if err := validatePasswordHint(hint); err != nil {
		return "", err
	}
	return hint, nil
}

// UpdateRootPasswordHintQuick verifies the current password before atomically
// replacing the root configuration with updated public hint metadata.
func UpdateRootPasswordHintQuick(rootPath FullStorePath, password, hint string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return UpdateRootPasswordHintContext(ctx, rootPath, password, hint)
}

// UpdateRootPasswordHintContext serializes config changes with password
// changes. Unlike password changes, it supports both legacy and changeable
// root formats because it only verifies the existing password verifier.
func UpdateRootPasswordHintContext(
	ctx context.Context,
	rootPath FullStorePath,
	password, hint string,
) error {
	if rootPath == "" {
		return ErrInvalidPath
	}
	if password == "" {
		return NewConfigError("password", "current password is required", ErrInvalidPassword)
	}
	if err := validatePasswordHint(hint); err != nil {
		return err
	}

	lock, err := acquireRootConfigLock(ctx, string(rootPath))
	if err != nil {
		return NewConfigError("password_hint", "another process is changing this directory", err)
	}
	defer lock.release()

	cfgPath := filepath.Join(string(rootPath), ConfigFileName)
	cfg, err := config.NewFileConfig(cfgPath)
	if err != nil {
		return NewConfigError("config", "failed to load config file", err)
	}
	_, _, deriverFactory, err := getOpenFactories(cfg)
	if err != nil {
		return err
	}
	passwordKey, err := loadPasswordWrappingKey(cfg, deriverFactory, password)
	if err != nil {
		return err
	}
	defer passwordKey.Destroy()
	if err := verifyPassword(cfg, passwordKey.GetKey()); err != nil {
		return err
	}

	stagedPath, stagedCfg, err := stageRootConfig(cfgPath)
	if err != nil {
		return err
	}
	committed := false
	defer func() {
		if !committed {
			_ = os.Remove(stagedPath)
		}
	}()
	if err := setPasswordHint(stagedCfg, hint); err != nil {
		return err
	}
	if err := commitStagedRootConfig(stagedPath, cfgPath); err != nil {
		return err
	}
	committed = true
	return nil
}

func validatePasswordHint(hint string) error {
	if !utf8.ValidString(hint) {
		return NewConfigError(passwordHintConfigKey, "password hint must be valid UTF-8", ErrInvalidConfig)
	}
	if len(hint) > maxPasswordHintBytes {
		return NewConfigError(passwordHintConfigKey, "password hint exceeds 256 bytes", ErrInvalidConfig)
	}
	return nil
}

func writePasswordHint(cfg config.SharedConfig, hint string) error {
	if err := validatePasswordHint(hint); err != nil {
		return err
	}
	if hint == "" {
		return nil
	}
	return setPasswordHint(cfg, hint)
}

func setPasswordHint(cfg config.SharedConfig, hint string) error {
	if err := validatePasswordHint(hint); err != nil {
		return err
	}
	if err := cfg.SetStr(passwordHintConfigKey, hint); err != nil {
		return NewConfigError(passwordHintConfigKey, "failed to store password hint", err)
	}
	return nil
}
