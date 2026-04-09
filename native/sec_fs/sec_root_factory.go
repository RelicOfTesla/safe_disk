// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains factory functions for creating and opening secure roots.
package sec_fs

import (
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
)

// ==================== Constants ====================

// ConfigFileName is the name of the configuration file in the root directory.
const ConfigFileName = "_cryption.json"

// ==================== OpenRoot Factory Function ====================

// OpenRoot opens a secure root directory with the given configuration.
// It returns an ISecRoot interface for managing encrypted files.
//
// The config parameter should be a SharedConfig with appropriate key prefixes:
//   - "sec_fs_factory": factory name (string, optional - uses default if not set)
//   - "sec_fs_key_deriver": key deriver name (string, optional)
//   - Other module-specific configs (crypto_data_, crypto_key_, etc.)
//
// If cfg is nil, it will automatically load configuration from <rootPath>/_cryption.json.
// If the config file doesn't exist, it returns an error.
//
// Note: Key derivation must be done by the caller before calling OpenRoot.
// The caller should use crypto_key package to derive the key from password.
func OpenRoot(rootPath FullStorePath, password string, cfg config.SharedConfig) (ISecRoot, error) {
	var factory crypto_data.ICryptoDataFactory

	// Auto-load config from file if cfg is nil
	if cfg == nil {
		cfgPath := filepath.Join(string(rootPath), ConfigFileName)
		if _, err := os.Stat(cfgPath); os.IsNotExist(err) {
			return nil, NewConfigError("config", "config file not found: "+cfgPath, err)
		}
		fileCfg, err := config.NewFileConfig(cfgPath)
		if err != nil {
			return nil, NewConfigError("config", "failed to load config file", err)
		}
		cfg = fileCfg
	}

	// Get factory name from config (optional)
	factoryName, err := cfg.GetStr("sec_fs_factory")
	if err == nil && factoryName != "" {
		// Use specified factory
		factory = crypto_data.GetFactory(factoryName)
		if factory == nil {
			return nil, NewConfigError("sec_fs_factory", "factory not found in registry", nil)
		}
	} else {
		// Use default factory (first available)
		names := crypto_data.ListFactories()
		if len(names) == 0 {
			return nil, NewConfigError("Factory", "no cryptor factory registered", nil)
		}
		factory = crypto_data.GetFactory(names[0])
	}

	// Validate root path
	if rootPath == "" {
		return nil, ErrInvalidPath
	}

	// Ensure root directory exists
	err = os.MkdirAll(string(rootPath), 0755)
	if err != nil {
		return nil, NewPathError("mkdir", string(rootPath), err)
	}

	// Create and return the root
	// Note: keyInfo should be created by caller using crypto_key package
	root := &secRootImpl{
		factory:  factory,
		rootPath: rootPath,
		keyInfo:  nil, // TODO: accept keyInfo as parameter
		cfg:      cfg,
		closed:   false,
		mu:       sync.RWMutex{},
	
		nameCryptor: nil, /* TODO: create from config */
}

	return root, nil
}

// ==================== OpenOrCreateRoot Factory Function ====================

// OpenOrCreateRoot opens an existing secure root or creates a new one if it doesn't exist.
// It returns an ISecRoot interface for managing encrypted files.
//
// If the root directory doesn't exist, it creates the directory and initializes a new config file.
// If the root directory exists but has no config file, it initializes a new config file.
// If the root directory exists and has a config file, it opens the existing root.
//
// If cfg is nil, it will:
//   - For existing roots: load configuration from <rootPath>/_cryption.json
//   - For new roots: create a default configuration
//
// Note: Key derivation must be done by the caller before calling OpenOrCreateRoot.
// The caller should use crypto_key package to derive the key from password.
func OpenOrCreateRoot(rootPath FullStorePath, password string, cfg config.SharedConfig) (ISecRoot, error) {
	var factory crypto_data.ICryptoDataFactory

	// Check if config file exists
	cfgPath := filepath.Join(string(rootPath), ConfigFileName)
	configExists := false
	if _, err := os.Stat(cfgPath); err == nil {
		configExists = true
	}

	// Handle config
	if cfg == nil {
		if configExists {
			// Load existing config
			fileCfg, err := config.NewFileConfig(cfgPath)
			if err != nil {
				return nil, NewConfigError("config", "failed to load config file", err)
			}
			cfg = fileCfg
		} else {
			// Create default config
			fileCfg, err := config.NewFileConfig(cfgPath)
			if err != nil {
				return nil, NewConfigError("config", "failed to create config file", err)
			}
			cfg = fileCfg
			// TODO: Set default config values
		}
	}

	// Get factory name from config (optional)
	factoryName, err := cfg.GetStr("sec_fs_factory")
	if err == nil && factoryName != "" {
		factory = crypto_data.GetFactory(factoryName)
		if factory == nil {
			return nil, NewConfigError("sec_fs_factory", "factory not found in registry", nil)
		}
	} else {
		names := crypto_data.ListFactories()
		if len(names) == 0 {
			return nil, NewConfigError("Factory", "no cryptor factory registered", nil)
		}
		factory = crypto_data.GetFactory(names[0])
	}

	// Validate root path
	if rootPath == "" {
		return nil, ErrInvalidPath
	}

	// Ensure root directory exists
	err = os.MkdirAll(string(rootPath), 0755)
	if err != nil {
		return nil, NewPathError("mkdir", string(rootPath), err)
	}

	// Create and return the root
	root := &secRootImpl{
		factory:  factory,
		rootPath: rootPath,
		keyInfo:  nil, // TODO: accept keyInfo as parameter
		cfg:      cfg,
		closed:   false,
		mu:       sync.RWMutex{},
	}

	return root, nil
}
