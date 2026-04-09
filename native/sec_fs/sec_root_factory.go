// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains factory functions for creating and opening secure roots.
package sec_fs

import (
	"os"
	"path/filepath"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)

// ==================== Constants ====================

// ConfigFileName is the name of the configuration file in the root directory.
const ConfigFileName = "_cryption.json"

// ==================== Helper Functions ====================

// createNameCryptorFromConfig creates a name cryptor from config or uses default.
// If a factory name is specified in config, it uses that factory.
// Otherwise, it uses the first available factory.
func createNameCryptorFromConfig(keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (crypto_name.INameCryptorContext, error) {
	var nameCryptor crypto_name.INameCryptorContext
	
	// Try to use factory from config
	nameFactoryName, err := cfg.GetStr("sec_name_factory")
	if err == nil && nameFactoryName != "" {
		nameFactory := crypto_name.GetNameFactory(nameFactoryName)
		if nameFactory != nil {
			nameCryptor, err = nameFactory.NewContext(keyInfo, cfg)
			if err != nil {
				return nil, NewConfigError("sec_name_factory", "failed to create name cryptor", err)
			}
		}
	}
	
	// If no nameCryptor created, try to use default (first available)
	if nameCryptor == nil {
		nameFactoryNames := crypto_name.ListNameFactories()
		if len(nameFactoryNames) > 0 {
			nameFactory := crypto_name.GetNameFactory(nameFactoryNames[0])
			if nameFactory != nil {
				nameCryptor, err = nameFactory.NewContext(keyInfo, cfg)
				if err != nil {
					return nil, NewConfigError("sec_name_factory", "failed to create default name cryptor", err)
				}
			}
		}
	}
	
	return nameCryptor, nil
}

// getFactoryFromConfig gets a crypto data factory from config or uses default.
// If a factory name is specified in config, it uses that factory.
// Otherwise, it uses the first available factory.
func getFactoryFromConfig(cfg config.SharedConfig) (crypto_data.ICryptoDataFactory, error) {
	factoryName, err := cfg.GetStr("sec_fs_factory")
	if err == nil && factoryName != "" {
		factory := crypto_data.GetFactory(factoryName)
		if factory == nil {
			return nil, NewConfigError("sec_fs_factory", "factory not found in registry", nil)
		}
		return factory, nil
	}
	
	// Use default factory (first available)
	names := crypto_data.ListFactories()
	if len(names) == 0 {
		return nil, NewConfigError("Factory", "no cryptor factory registered", nil)
	}
	return crypto_data.GetFactory(names[0]), nil
}

// ==================== OpenRoot Factory Function ====================

// OpenRoot opens a secure root directory with the given configuration.
// It returns an ISecRoot interface for managing encrypted files.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - keyInfo: key information for encryption/decryption (created by caller using crypto_key package)
//   - cfg: configuration for the secure root (can be nil to auto-load from <rootPath>/_cryption.json)
//
// The config parameter should be a SharedConfig with appropriate key prefixes:
//   - "sec_fs_factory": factory name for data encryption (string, optional - uses default if not set)
//   - "sec_name_factory": factory name for name encryption (string, optional - uses default if not set)
//   - Other module-specific configs (crypto_data_, crypto_key_, etc.)
//
// If cfg is nil, it will automatically load configuration from <rootPath>/_cryption.json.
// If the config file doesn't exist, it returns an error.
//
// Note: Key derivation must be done by the caller before calling OpenRoot.
// The caller should use crypto_key package to derive the key from password.
func OpenRoot(rootPath FullStorePath, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (ISecRoot, error) {
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

	// Get factory from config
	factory, err := getFactoryFromConfig(cfg)
	if err != nil {
		return nil, err
	}

	// Create nameCryptor from config
	nameCryptor, err := createNameCryptorFromConfig(keyInfo, cfg)
	if err != nil {
		return nil, err
	}

	// Create root using NewRoot
	return NewRoot(rootPath, keyInfo, nameCryptor, factory, cfg)
}

// ==================== OpenOrCreateRoot Factory Function ====================

// OpenOrCreateRoot opens an existing secure root or creates a new one if it doesn't exist.
// It returns an ISecRoot interface for managing encrypted files.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - keyInfo: key information for encryption/decryption (created by caller using crypto_key package)
//   - cfg: configuration for the secure root (can be nil to auto-load/create)
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
func OpenOrCreateRoot(rootPath FullStorePath, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig) (ISecRoot, error) {
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

	// Get factory from config
	factory, err := getFactoryFromConfig(cfg)
	if err != nil {
		return nil, err
	}

	// Create nameCryptor from config
	nameCryptor, err := createNameCryptorFromConfig(keyInfo, cfg)
	if err != nil {
		return nil, err
	}

	// Create root using NewRoot
	return NewRoot(rootPath, keyInfo, nameCryptor, factory, cfg)
}

// ==================== Quick Functions ====================

// OpenRootQuick opens an existing secure root with password.
// This is a convenience function that handles key derivation automatically.
// It uses the default key deriver to derive keyInfo from password.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - inputPassword: the password for encryption/decryption
//
// Returns:
//   - ISecRoot: the secure root interface
//   - error: any error that occurred
//
// Note: This function loads the config from <rootPath>/_cryption.json.
// The config must contain key derivation parameters.
func OpenRootQuick(rootPath FullStorePath, inputPassword string) (ISecRoot, error) {
	// Get default key deriver
	deriverNames := crypto_hkdf.ListKeyDerivers()
	if len(deriverNames) == 0 {
		return nil, NewConfigError("key_deriver", "no key deriver registered", nil)
	}
	keyDeriver := crypto_hkdf.GetKeyDeriver(deriverNames[0])

	// Load config to get key derivation parameters
	cfgPath := filepath.Join(string(rootPath), "_cryption.json")
	cfg, err := config.NewFileConfig(cfgPath)
	if err != nil {
		return nil, NewConfigError("config", "failed to load config", err)
	}

	// Derive key from password
	keyInfo, err := keyDeriver.LoadKey(inputPassword, cfg)
	if err != nil {
		return nil, NewConfigError("key_derivation", "failed to derive key", err)
	}

	// Open root with derived keyInfo
	return OpenRoot(rootPath, keyInfo, cfg)
}

// OpenOrCreateRootQuick opens an existing secure root or creates a new one with password.
// This is a convenience function that handles key derivation automatically.
// It uses the default key deriver to derive keyInfo from password.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - inputPassword: the password for encryption/decryption
//
// Returns:
//   - ISecRoot: the secure root interface
//   - error: any error that occurred
//
// For existing roots:
//   - Loads config from <rootPath>/_cryption.json
//   - Uses existing key derivation parameters
//
// For new roots:
//   - Creates default config
//   - Uses static salt for deterministic key derivation
func OpenOrCreateRootQuick(rootPath FullStorePath, inputPassword string) (ISecRoot, error) {
	// Get default key deriver
	deriverNames := crypto_hkdf.ListKeyDerivers()
	if len(deriverNames) == 0 {
		return nil, NewConfigError("key_deriver", "no key deriver registered", nil)
	}
	keyDeriver := crypto_hkdf.GetKeyDeriver(deriverNames[0])

	// Check if root exists
	cfgPath := filepath.Join(string(rootPath), "_cryption.json")
	var cfg config.SharedConfig
	var keyInfo crypto_hkdf.IKeyInfo
	var err error

	if _, err = os.Stat(cfgPath); os.IsNotExist(err) {
		// New root - create config with default settings
		cfg = config.NewMemoryConfig()

		// Create new key with static salt for deterministic derivation
		keyInfo, err = keyDeriver.NewKey(&crypto_hkdf.MakeKeyParams{
			Password:      inputPassword,
			StaticSalt:    true, // Use static salt for deterministic derivation
			KeyStrengthMs: 100,  // Default key strength
		}, cfg)
		if err != nil {
			return nil, NewConfigError("key_derivation", "failed to create key", err)
		}
	} else {
		// Existing root - load config
		cfg, err = config.NewFileConfig(cfgPath)
		if err != nil {
			return nil, NewConfigError("config", "failed to load config", err)
		}

		// Load key from password
		keyInfo, err = keyDeriver.LoadKey(inputPassword, cfg)
		if err != nil {
			return nil, NewConfigError("key_derivation", "failed to derive key", err)
		}
	}

	// Open or create root with derived keyInfo
	return OpenOrCreateRoot(rootPath, keyInfo, cfg)
}

// ==================== Low-level Constructor ====================

// NewRoot creates a new ISecRoot with explicitly provided components.
// This is a low-level constructor that gives full control over all dependencies.
// It does not read from config or create any components automatically.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - keyInfo: the key information for encryption/decryption
//   - nameCryptor: the name encryptor for filename encryption (can be nil)
//   - factory: the crypto data factory for file content encryption
//   - cfg: the shared configuration
//
// Returns:
//   - ISecRoot: the secure root interface
//   - error: any error that occurred
//
// Use this function when you need full control over all components,
// such as in testing or when using custom implementations.
// For normal usage, prefer OpenRootQuick or OpenOrCreateRootQuick.
func NewRoot(
	rootPath FullStorePath,
	keyInfo crypto_hkdf.IKeyInfo,
	nameCryptor crypto_name.INameCryptorContext,
	factory crypto_data.ICryptoDataFactory,
	cfg config.SharedConfig,
) (ISecRoot, error) {
	// Validate parameters
	if rootPath == "" {
		return nil, ErrInvalidPath
	}
	if keyInfo == nil {
		return nil, NewConfigError("keyInfo", "keyInfo is required", nil)
	}
	if factory == nil {
		return nil, NewConfigError("factory", "factory is required", nil)
	}
	if cfg == nil {
		return nil, NewConfigError("cfg", "cfg is required", nil)
	}

	// Ensure root directory exists
	if err := os.MkdirAll(string(rootPath), 0755); err != nil {
		return nil, NewPathError("mkdir", string(rootPath), err)
	}

	// Create and return the root
	root := &secRootImpl{
		fileDataFactory: factory,
		rootPath:      rootPath,
		keyInfo:       keyInfo,
		cfg:           cfg,
		closed:        false,
		mu:            sync.RWMutex{},
		nameCryptor:   nameCryptor,
		ignoreMatcher: nil, // Can be set later if needed
	}

	return root, nil
}

// ==================== GetSuitFromConfig ====================

// GetSuitFromConfig retrieves all encryption component factories from config.
// This is a convenience function that returns factories for all components needed
// to work with encrypted data.
//
// Parameters:
//   - cfg: configuration containing factory names
//
// Returns:
//   - ICryptoDataFactory: factory for file content encryption
//   - ICryptoNameFactory: factory for filename encryption
//   - IDeriverFactory: factory for key derivation
//   - error: any error that occurred
//
// If a factory name is not specified in config, the default (first available) is used.
// If no factories are registered, an error is returned.
func GetSuitFromConfig(cfg config.SharedConfig) (
	crypto_data.ICryptoDataFactory,
	crypto_name.ICryptoNameFactory,
	crypto_hkdf.IDeriverFactory,
	error,
) {
	// Get file data factory
	dataFactory, err := getFactoryFromConfig(cfg)
	if err != nil {
		return nil, nil, nil, err
	}

	// Get name factory
	nameFactoryName, err := cfg.GetStr("sec_name_factory")
	var nameFactory crypto_name.ICryptoNameFactory
	if err == nil && nameFactoryName != "" {
		nameFactory = crypto_name.GetNameFactory(nameFactoryName)
		if nameFactory == nil {
			return nil, nil, nil, NewConfigError("sec_name_factory", "name factory not found in registry", nil)
		}
	} else {
		// Use default (first available)
		nameFactoryNames := crypto_name.ListNameFactories()
		if len(nameFactoryNames) > 0 {
			nameFactory = crypto_name.GetNameFactory(nameFactoryNames[0])
		}
	}

	// Get deriver factory
	deriverFactoryName, err := cfg.GetStr("sec_deriver_factory")
	var deriverFactory crypto_hkdf.IDeriverFactory
	if err == nil && deriverFactoryName != "" {
		deriverFactory = crypto_hkdf.GetDeriverFactory(deriverFactoryName)
		if deriverFactory == nil {
			return nil, nil, nil, NewConfigError("sec_deriver_factory", "deriver factory not found in registry", nil)
		}
	} else {
		// Use default (first available)
		deriverFactoryNames := crypto_hkdf.ListDeriverFactories()
		if len(deriverFactoryNames) > 0 {
			deriverFactory = crypto_hkdf.GetDeriverFactory(deriverFactoryNames[0])
		}
	}

	return dataFactory, nameFactory, deriverFactory, nil
}
