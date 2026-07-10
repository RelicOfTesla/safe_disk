// Package sec_fs provides a secure file system implementation with encryption support.
// This file contains factory functions for creating and opening secure roots.
package sec_fs

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"sync"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
	"safe_disk/native/sec_fs/sec_utils"
)

// ==================== Constants ====================

const (
	// ConfigFileName is the name of the configuration file in the root directory.
	ConfigFileName = "_cryption.json"

	// Defaults are explicit so registry map iteration can never select security
	// algorithms nondeterministically.
	DefaultDataFactoryName    = "aes-ctr"
	DefaultNameFactoryName    = "none"
	DefaultDeriverFactoryName = "argon2id"
)

// ==================== CreateRootOptions ====================

// CreateRootOptions holds configuration options for creating a new secure root.
type CreateRootOptions struct {
	// DataFactoryName specifies the data encryption factory to use.
	DataFactoryName string

	// NameFactoryName specifies the name encryption factory to use.
	NameFactoryName string

	// DeriverFactoryName specifies the key deriver factory to use.
	DeriverFactoryName string

	// KeyStrengthMs specifies the target key derivation time in milliseconds.
	// Higher values mean stronger security but slower performance.
	// Default: 100ms if not specified.
	KeyStrengthMs int

	// ConfigFileName specifies the name of the configuration file.
	// Default: "_cryption.json" if not specified.
	ConfigFileName string
}

// CreateRootOption is a functional option for configuring CreateRootConfig.
type CreateRootOption func(*CreateRootOptions)

// WithDataFactory sets the data encryption factory by name.
func WithDataFactory(name string) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.DataFactoryName = name
	}
}

// WithNameFactory sets the name encryption factory by name.
func WithNameFactory(name string) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.NameFactoryName = name
	}
}

// WithDeriverFactory sets the key deriver factory by name.
func WithDeriverFactory(name string) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.DeriverFactoryName = name
	}
}

// WithKeyStrengthMs sets the target key derivation time in milliseconds.
// Higher values mean stronger security but slower performance.
func WithKeyStrengthMs(ms int) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.KeyStrengthMs = ms
	}
}

// WithConfigFileName sets the configuration file name.
// Default: "_cryption.json" if not specified.
func WithConfigFileName(name string) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.ConfigFileName = name
	}
}

// applyCreateOptions applies the given options to CreateRootOptions and returns the result.
func applyCreateOptions(options ...CreateRootOption) *CreateRootOptions {
	opts := &CreateRootOptions{
		KeyStrengthMs:  100,            // Default: 100ms
		ConfigFileName: ConfigFileName, // Default: "_cryption.json"
	}
	for _, option := range options {
		option(opts)
	}
	return opts
}

// ==================== Error Helpers ====================

// IsNoEncryptionErr returns true if the error indicates the path is not encrypted.
// This can be used to detect when a new root needs to be created.
//
// Example:
//
//	root, err := sec_fs.OpenRootQuick("/path/to/root", "password")
//	if sec_fs.IsNoEncryptionErr(err) {
//	    // Need to create new root
//	    cfg, err := sec_fs.CreateRootConfigQuick("/path/to/root", "password")
//	    root, err = sec_fs.OpenRootQuick("/path/to/root", "password")
//	}
func IsNoEncryptionErr(err error) bool {
	return errors.Is(err, ErrNotConfigFile) || errors.Is(err, ErrNotEncrypted)
}

// ==================== Default Ignore Matcher ====================

// defaultIgnoreMatcher is the default ignore matcher that ignores config files.
type defaultIgnoreMatcher struct {
	configFileName string
}

// ShouldIgnore1 checks if the file should be ignored BEFORE name decryption.
// For the default ignore matcher, this checks the encrypted/store name.
// Since config files are not encrypted, we check the raw name here.
func (d *defaultIgnoreMatcher) ShouldIgnore1(encryptedName string, isDir bool) bool {
	if isDir {
		return false
	}
	return encryptedName == d.configFileName
}

// ShouldIgnore2 checks if the file should be ignored AFTER name decryption.
// For the default ignore matcher, this checks the decrypted/view name.
// Since config files are not encrypted, this is typically not needed,
// but we keep it for consistency with the interface.
func (d *defaultIgnoreMatcher) ShouldIgnore2(decryptedName string, isDir bool) bool {
	if isDir {
		return false
	}
	return decryptedName == d.configFileName
}

// newDefaultIgnoreMatcher creates a new default ignore matcher with the given config file name.
func newDefaultIgnoreMatcher(configFileName string) IIgnoreMatcher {
	if configFileName == "" {
		configFileName = ConfigFileName
	}
	return &defaultIgnoreMatcher{configFileName: configFileName}
}

// ==================== OpenOptions ====================

// OpenOptions holds configuration options for opening a secure root.
type OpenOptions struct {
	// IgnoreMatcher is used to skip certain files/directories during operations.
	ignoreMatcher IIgnoreMatcher

	// ConfigFileName specifies the name of the configuration file.
	// Default: "_cryption.json" if not specified.
	configFileName string
}

// OpenOption is a functional option for configuring OpenRoot operations.
type OpenOption func(*OpenOptions)

// WithIgnoreMatcher sets the ignore matcher for the root.
// The ignore matcher is used to skip certain files/directories during operations.
func WithIgnoreMatcher(matcher IIgnoreMatcher) OpenOption {
	return func(o *OpenOptions) {
		o.ignoreMatcher = matcher
	}
}

// WithOpenConfigFileName sets the configuration file name for opening.
// Default: "_cryption.json" if not specified.
func WithOpenConfigFileName(name string) OpenOption {
	return func(o *OpenOptions) {
		o.configFileName = name
	}
}

// applyOpenOptions applies the given options to OpenOptions and returns the result.
func applyOpenOptions(options ...OpenOption) *OpenOptions {
	opts := &OpenOptions{
		configFileName: ConfigFileName, // Default: "_cryption.json"
	}
	for _, option := range options {
		option(opts)
	}
	return opts
}

// ==================== FindRootConfig ====================

// FindRootConfig searches for a configuration file starting from the given path,
// walking up the directory tree until a config file is found or root is reached.
// This is similar to how Git finds the .git directory.
//
// Parameters:
//   - startPath: the path to start searching from (can be a file or directory)
//   - options: functional options for configuring the search (optional)
//
// Returns:
//   - config.SharedConfig: the loaded configuration
//   - FullStorePath: the path where the config file was found (the root path)
//   - error: any error that occurred (ErrNotConfigFile if not found)
//
// Available options:
//   - WithOpenConfigFileName(name): custom config file name
//
// Example:
//
//	cfg, rootPath, relativePath, err := sec_fs.FindRootConfig("/path/to/subdir/file.txt")
//	if err == nil {
//	    fmt.Printf("Found config at: %s\n", rootPath)
//	}
func FindRootConfig(startPath string, options ...OpenOption) (config.SharedConfig, FullStorePath, RelativeViewPath, error) {
	// Apply options
	opts := applyOpenOptions(options...)

	// Get absolute path
	absPath, err := filepath.Abs(string(startPath))
	if err != nil {
		return nil, "", "", NewFullStorePathError("abs", FullStorePath(startPath), err)
	}

	// If startPath doesn't exist or is a file, start from its directory
	originalPath := absPath // Save the original path for later use
	info, err := os.Stat(absPath)
	if err != nil {
		// Path doesn't exist - this could be a view path (decrypted name)
		// Try to find config from parent directory
		absPath = filepath.Dir(absPath)
	} else if !info.IsDir() {
		absPath = filepath.Dir(absPath)
	}

	// Walk up the directory tree
	currentPath := absPath
	relativeList := []string{}
	for {
		// Check if config file exists in current directory
		cfgPath := filepath.Join(currentPath, opts.configFileName)
		if _, err := os.Stat(cfgPath); err == nil {
			// Found! Load the config
			cfg, err := config.NewFileConfig(cfgPath)
			if err != nil {
				return nil, "", "", NewConfigError("config", "failed to load config file: "+cfgPath, err)
			}
			slices.Reverse(relativeList)
			relativePath := filepath.Join(relativeList...)

			// If original path was different (e.g., a non-existent file),
			// compute the relative path from the found root to the original path
			if originalPath != string(currentPath) {
				relFromRoot, err := filepath.Rel(string(currentPath), originalPath)
				if err == nil {
					relativePath = relFromRoot
				}
			}

			return cfg, FullStorePath(currentPath), RelativeViewPath(relativePath), nil
		}

		// Move to parent
		relativeList = append(relativeList, filepath.Base(currentPath))
		parentPath := filepath.Dir(currentPath)
		if parentPath == currentPath {
			// Reached root directory, config not found
			return nil, "", "", ErrNotConfigFile
		}
		currentPath = parentPath
	}
}

// ==================== createRootConfig (internal) ====================

// createRootConfig creates a new configuration for a secure root.
// This is an internal function that requires keyInfo to be pre-derived.
// For most use cases, use CreateRootConfig instead.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - keyInfo: key information for encryption/decryption (must be created by caller)
//   - options: functional options for configuring the root (optional)
//
// Returns:
//   - config.SharedConfig: the created configuration
//   - error: any error that occurred
//
// Available options:
//   - WithDataFactory(name): set data encryption factory
//   - WithNameFactory(name): set name encryption factory
//   - WithDeriverFactory(name): set key deriver factory
//   - WithKeyStrengthMs(ms): set key derivation strength
//
// Example:
//
//	cfg, err := createRootConfig("/path/to/root", keyInfo,
//	    WithDataFactory("aes-ctr"),
//	    WithNameFactory("aes-gcm-name"),
//	    WithKeyStrengthMs(200),
//	)
func createRootConfig(rootPath FullStorePath, keyInfo crypto_hkdf.IKeyInfo, options ...CreateRootOption) (config.SharedConfig, error) {
	// Apply options
	opts := applyCreateOptions(options...)

	// Validate parameters
	if rootPath == "" {
		return nil, ErrInvalidPath
	}
	if keyInfo == nil {
		return nil, NewConfigError("keyInfo", "keyInfo is required", nil)
	}

	// Ensure root directory exists
	if err := os.MkdirAll(string(rootPath), 0755); err != nil {
		return nil, NewFullStorePathError("mkdir", rootPath, err)
	}

	// Create config file path
	cfgPath := filepath.Join(string(rootPath), opts.ConfigFileName)

	// Create file config
	cfg, err := config.NewFileConfig(cfgPath)
	if err != nil {
		return nil, NewConfigError("config", "failed to create config file", err)
	}

	// Get factories (respecting option overrides)
	dataFactory, nameFactory, deriverFactory, err := getCreateFactories(cfg, opts)
	if err != nil {
		return nil, err
	}

	// Store factory names in config
	if opts.DataFactoryName != "" || dataFactory != nil {
		factoryName := opts.DataFactoryName
		if factoryName == "" && dataFactory != nil {
			factoryName = dataFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_fs_factory", factoryName)
		}
	}

	if opts.NameFactoryName != "" || nameFactory != nil {
		factoryName := opts.NameFactoryName
		if factoryName == "" && nameFactory != nil {
			factoryName = nameFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_name_factory", factoryName)
		}
	}

	if opts.DeriverFactoryName != "" || deriverFactory != nil {
		factoryName := opts.DeriverFactoryName
		if factoryName == "" && deriverFactory != nil {
			factoryName = deriverFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_deriver_factory", factoryName)
		}
	}

	// Save deriver parameters to config if available
	if deriverFactory != nil {
		deriver, err := deriverFactory.NewDeriver(cfg)
		if err == nil {
			// Create a new key to generate and save parameters
			_, err = deriver.NewKey(&crypto_hkdf.MakeKeyParams{
				Password:      "", // Empty password for parameter generation
				StaticSalt:    true,
				KeyStrengthMs: opts.KeyStrengthMs,
			}, cfg)
			if err != nil {
				// Non-fatal: parameters may already exist
			}
		}
	}

	// Create nameCryptor and save its parameters if available
	if nameFactory != nil {
		_, err = nameFactory.NewContext(keyInfo, cfg)
		if err != nil {
			// Non-fatal: name encryption may work with defaults
		}
	}

	if err := writePasswordVerifier(cfg, keyInfo.GetKey()); err != nil {
		return nil, err
	}

	return cfg, nil
}

// CreateRootConfigQuick creates a new configuration for a secure root with password.
// This function handles key derivation automatically using the provided password.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - password: the password for encryption/decryption
//   - options: functional options for configuring the root (optional)
//
// Returns:
//   - config.SharedConfig: the created configuration
//   - FullStorePath: the root path where config was created
//   - error: any error that occurred
//
// Available options:
//   - WithDataFactory(name): set data encryption factory
//   - WithNameFactory(name): set name encryption factory
//   - WithDeriverFactory(name): set key deriver factory
//
// Example:
//
//	cfg, rootPath, err := sec_fs.CreateRootConfigQuick("/path/to/root", "my-password",
//	    sec_fs.WithDataFactory("aes-ctr"),
//	)
func CreateRootConfigQuick(rootPath FullStorePath, password string, options ...CreateRootOption) (config.SharedConfig, FullStorePath, error) {
	// Apply options
	opts := applyCreateOptions(options...)

	// Validate parameters
	if rootPath == "" {
		return nil, "", ErrInvalidPath
	}

	// Ensure root directory exists
	if err := os.MkdirAll(string(rootPath), 0755); err != nil {
		return nil, "", NewFullStorePathError("mkdir", rootPath, err)
	}

	// Create config file path
	cfgPath := filepath.Join(string(rootPath), opts.ConfigFileName)

	// Create file config
	cfg, err := config.NewFileConfig(cfgPath)
	if err != nil {
		return nil, "", NewConfigError("config", "failed to create config file", err)
	}

	// Get factories (respecting option overrides)
	dataFactory, nameFactory, deriverFactory, err := getCreateFactories(cfg, opts)
	if err != nil {
		return nil, "", err
	}

	// Store factory names in config
	if opts.DataFactoryName != "" || dataFactory != nil {
		factoryName := opts.DataFactoryName
		if factoryName == "" && dataFactory != nil {
			factoryName = dataFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_fs_factory", factoryName)
		}
	}

	if opts.NameFactoryName != "" || nameFactory != nil {
		factoryName := opts.NameFactoryName
		if factoryName == "" && nameFactory != nil {
			factoryName = nameFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_name_factory", factoryName)
		}
	}

	if opts.DeriverFactoryName != "" || deriverFactory != nil {
		factoryName := opts.DeriverFactoryName
		if factoryName == "" && deriverFactory != nil {
			factoryName = deriverFactory.GetName()
		}
		if factoryName != "" {
			cfg.SetStr("sec_deriver_factory", factoryName)
		}
	}

	// Determine required key length from data factory and name factory
	// For data factory, use GetRequireMinKeyLength
	// For name factory, we need to check if it requires a specific key length
	// Currently, only aes-gcm-name requires 32-byte key
	requiredKeyLength := 0
	if dataFactory != nil {
		requiredKeyLength = dataFactory.GetRequireMinKeyLength()
	}
	// Check name factory key requirement
	if nameFactory != nil && nameFactory.GetName() == "aes-gcm-name" {
		// aes-gcm-name requires 32-byte key
		if requiredKeyLength < 32 {
			requiredKeyLength = 32
		}
	}

	deriver, err := deriverFactory.NewDeriver(cfg)
	if err != nil {
		return nil, "", NewConfigError("sec_deriver_factory", "failed to create deriver", err)
	}
	keyInfo, err := deriver.NewKey(&crypto_hkdf.MakeKeyParams{
		Password:      password,
		StaticSalt:    false,
		KeyStrengthMs: opts.KeyStrengthMs,
		KeyLength:     requiredKeyLength,
	}, cfg)
	if err != nil {
		return nil, "", NewConfigError("key_derivation", "failed to create key", err)
	}

	// Create nameCryptor and save its parameters if available
	if nameFactory != nil && keyInfo != nil {
		_, err = nameFactory.NewContext(keyInfo, cfg)
		if err != nil {
			// Non-fatal: name encryption may work with defaults
		}
	}

	if keyInfo == nil {
		return nil, "", NewConfigError("key_derivation", "derived key is required", ErrInvalidConfig)
	}
	if err := writePasswordVerifier(cfg, keyInfo.GetKey()); err != nil {
		return nil, "", err
	}

	return cfg, rootPath, nil
}

// ==================== Quick Functions ====================

// OpenRootQuick opens an existing secure root with password.
// This is a convenience function that handles key derivation automatically.
// It uses the configured key deriver to derive keyInfo from password.
//
// Parameters:
//   - rootPath: the full storage path of the root directory
//   - inputPassword: the password for encryption/decryption
//   - options: functional options for configuring the root (optional)
//
// Returns:
//   - ISecRoot: the opened secure root
//   - error: any error that occurred
//
// Available options:
//   - WithIgnoreMatcher(matcher): set ignore matcher for skipping files
//   - WithOpenConfigFileName(name): custom config file name
//
// Example:
//
//	root, err := sec_fs.OpenRootQuick("/path/to/root", "my-password")
//	if err != nil {
//	    log.Fatal(err)
//	}
//	defer root.Close()
func OpenRootQuick(rootPath FullStorePath, inputPassword string, options ...OpenOption) (ISecRoot, error) {
	// Apply options
	opts := applyOpenOptions(options...)

	// Load config to get key derivation parameters
	cfgPath := filepath.Join(string(rootPath), opts.configFileName)
	cfg, err := config.NewFileConfig(cfgPath)
	if err != nil {
		return nil, NewConfigError("config", "failed to load config", err)
	}

	// Get deriver factory
	_, _, deriverFactory, err := getOpenFactories(cfg)
	if err != nil {
		return nil, err
	}

	keyDeriver, err := deriverFactory.NewDeriver(cfg)
	if err != nil {
		return nil, NewConfigError("sec_deriver_factory", "failed to create deriver", err)
	}

	// Derive key from password
	keyInfo, err := keyDeriver.LoadKey(inputPassword, cfg)
	if err != nil {
		return nil, NewConfigError("key_derivation", "failed to derive key", err)
	}
	if err := verifyPassword(cfg, keyInfo.GetKey()); err != nil {
		return nil, err
	}

	// Open root with derived keyInfo
	return openRoot(rootPath, keyInfo, cfg, options...)
}

// openRoot opens a secure root with pre-derived keyInfo.
// This is an internal function that requires keyInfo to be pre-derived.
func openRoot(rootPath FullStorePath, keyInfo crypto_hkdf.IKeyInfo, cfg config.SharedConfig, options ...OpenOption) (ISecRoot, error) {
	// Apply options
	opts := applyOpenOptions(options...)

	// Auto-load config from file if cfg is nil
	if cfg == nil {
		cfgPath := filepath.Join(string(rootPath), opts.configFileName)
		if _, err := os.Stat(cfgPath); os.IsNotExist(err) {
			return nil, ErrNotConfigFile
		}
		fileCfg, err := config.NewFileConfig(cfgPath)
		if err != nil {
			return nil, NewConfigError("config", "failed to load config file", err)
		}
		cfg = fileCfg
	}

	// Get factories from config
	dataFactory, nameFactory, _, err := getOpenFactories(cfg)
	if err != nil {
		return nil, err
	}

	// Create nameCryptor from factory
	var nameCryptor crypto_name.INameCryptorContext
	if nameFactory != nil {
		nameCryptor, err = nameFactory.NewContext(keyInfo, cfg)
		if err != nil {
			return nil, NewConfigError("sec_name_factory", "failed to create name cryptor", err)
		}
	}

	// Create root using newRoot
	return newRoot(rootPath, keyInfo, nameCryptor, dataFactory, cfg, opts.ignoreMatcher)
}

// newRoot creates a new ISecRoot with explicitly provided components.
// This is an internal constructor that gives full control over all dependencies.
func newRoot(
	rootPath FullStorePath,
	keyInfo crypto_hkdf.IKeyInfo,
	nameCryptor crypto_name.INameCryptorContext,
	factory crypto_data.ICryptoDataFactory,
	cfg config.SharedConfig,
	ignoreMatcher IIgnoreMatcher,
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

	// Set default ignore matcher if not provided
	if ignoreMatcher == nil {
		ignoreMatcher = newDefaultIgnoreMatcher(ConfigFileName)
	}

	// Create and return the root
	root := &secRootImpl{
		fileDataFactory: factory,
		keyInfo:         keyInfo,
		cfg:             cfg,
		closed:          false,
		mu:              sync.RWMutex{},
		nameCryptor:     nameCryptor,
		ignoreMatcher:   ignoreMatcher,
	}
	var err error
	root.rootPathInfo, err = sec_utils.ParsePathInfo(string(rootPath))
	if err != nil {
		return nil, NewFullStorePathError("parse path info", rootPath, err)
	}

	// Ensure root directory exists
	if err := os.MkdirAll(string(rootPath), 0755); err != nil {
		return nil, NewFullStorePathError("mkdir", rootPath, err)
	}

	return root, nil
}

// ==================== Factory Helper Functions ====================

// getCreateFactories retrieves factories for creating a new root.
func getCreateFactories(cfg config.SharedConfig, opts *CreateRootOptions) (
	crypto_data.ICryptoDataFactory,
	crypto_name.ICryptoNameFactory,
	crypto_hkdf.IDeriverFactory,
	error,
) {
	// Get file data factory (option overrides config)
	var dataFactory crypto_data.ICryptoDataFactory
	if opts.DataFactoryName != "" {
		dataFactory = crypto_data.GetFactory(opts.DataFactoryName)
		if dataFactory == nil {
			return nil, nil, nil, NewConfigError("sec_fs_factory", "data factory not found: "+opts.DataFactoryName, nil)
		}
	} else {
		factoryName, err := cfg.GetStr("sec_fs_factory")
		if err == nil && factoryName != "" {
			dataFactory = crypto_data.GetFactory(factoryName)
		}
		if dataFactory == nil {
			dataFactory = crypto_data.GetFactory(DefaultDataFactoryName)
			if dataFactory == nil {
				factoryNames := crypto_data.ListFactories()
				if len(factoryNames) == 1 {
					dataFactory = crypto_data.GetFactory(factoryNames[0])
				}
			}
		}
	}

	// Get name factory (option overrides config)
	var nameFactory crypto_name.ICryptoNameFactory
	if opts.NameFactoryName != "" {
		nameFactory = crypto_name.GetNameFactory(opts.NameFactoryName)
		if nameFactory == nil {
			return nil, nil, nil, NewConfigError("sec_name_factory", "name factory not found: "+opts.NameFactoryName, nil)
		}
	} else {
		factoryName, err := cfg.GetStr("sec_name_factory")
		if err == nil && factoryName != "" {
			nameFactory = crypto_name.GetNameFactory(factoryName)
		}
		if nameFactory == nil {
			nameFactory = crypto_name.GetNameFactory(DefaultNameFactoryName)
			if nameFactory == nil {
				factoryNames := crypto_name.ListNameFactories()
				if len(factoryNames) == 1 {
					nameFactory = crypto_name.GetNameFactory(factoryNames[0])
				}
			}
		}
	}

	// Get deriver factory (option overrides config)
	var deriverFactory crypto_hkdf.IDeriverFactory
	if opts.DeriverFactoryName != "" {
		deriverFactory = crypto_hkdf.GetDeriverFactory(opts.DeriverFactoryName)
		if deriverFactory == nil {
			return nil, nil, nil, NewConfigError("sec_deriver_factory", "deriver factory not found: "+opts.DeriverFactoryName, nil)
		}
	} else {
		factoryName, err := cfg.GetStr("sec_deriver_factory")
		if err == nil && factoryName != "" {
			deriverFactory = crypto_hkdf.GetDeriverFactory(factoryName)
		}
		if deriverFactory == nil {
			deriverFactory = crypto_hkdf.GetDeriverFactory(DefaultDeriverFactoryName)
			if deriverFactory == nil {
				factoryNames := crypto_hkdf.ListDeriverFactories()
				if len(factoryNames) == 1 {
					deriverFactory = crypto_hkdf.GetDeriverFactory(factoryNames[0])
				}
			}
		}
	}

	if dataFactory == nil {
		return nil, nil, nil, NewConfigError("sec_fs_factory", "default data factory is not registered", ErrInvalidConfig)
	}
	if nameFactory == nil {
		return nil, nil, nil, NewConfigError("sec_name_factory", "default name factory is not registered", ErrInvalidConfig)
	}
	if deriverFactory == nil {
		return nil, nil, nil, NewConfigError("sec_deriver_factory", "default key deriver is not registered", ErrInvalidConfig)
	}
	return dataFactory, nameFactory, deriverFactory, nil
}

// getOpenFactories retrieves factories from config for opening an existing root.
func getOpenFactories(cfg config.SharedConfig) (
	crypto_data.ICryptoDataFactory,
	crypto_name.ICryptoNameFactory,
	crypto_hkdf.IDeriverFactory,
	error,
) {
	factoryName, err := cfg.GetStr("sec_fs_factory")
	if err != nil || factoryName == "" {
		return nil, nil, nil, NewConfigError("sec_fs_factory", "data factory is missing", ErrInvalidConfig)
	}
	dataFactory := crypto_data.GetFactory(factoryName)
	if dataFactory == nil {
		return nil, nil, nil, NewConfigError("sec_fs_factory", "data factory is not registered: "+factoryName, ErrInvalidConfig)
	}

	nameFactoryName, err := cfg.GetStr("sec_name_factory")
	if err != nil || nameFactoryName == "" {
		return nil, nil, nil, NewConfigError("sec_name_factory", "name factory is missing", ErrInvalidConfig)
	}
	nameFactory := crypto_name.GetNameFactory(nameFactoryName)
	if nameFactory == nil {
		return nil, nil, nil, NewConfigError("sec_name_factory", "name factory is not registered: "+nameFactoryName, ErrInvalidConfig)
	}

	deriverFactoryName, err := cfg.GetStr("sec_deriver_factory")
	if err != nil || deriverFactoryName == "" {
		return nil, nil, nil, NewConfigError("sec_deriver_factory", "key deriver is missing", ErrInvalidConfig)
	}
	deriverFactory := crypto_hkdf.GetDeriverFactory(deriverFactoryName)
	if deriverFactory == nil {
		return nil, nil, nil, NewConfigError("sec_deriver_factory", "key deriver is not registered: "+deriverFactoryName, ErrInvalidConfig)
	}

	return dataFactory, nameFactory, deriverFactory, nil
}

// ==================== Root Operations ====================

// MoveRoot moves the root directory to a new location.
// This function renames the underlying directory and updates the root's internal path.
// The root remains open after the move operation.
//
// Parameters:
//   - root: the secure root to move
//   - targetPath: the new location for the root directory
//
// Returns an error if:
//   - root is nil
//   - root is closed
//   - the underlying directory rename fails
func MoveRoot(root ISecRoot, targetPath FullStorePath) error {
	if root == nil {
		return ErrRootIsNil
	}

	// Type assertion to access internal fields
	impl, ok := root.(*secRootImpl)
	if !ok {
		return fmt.Errorf("MoveRoot: unsupported root type")
	}

	impl.mu.Lock()
	defer impl.mu.Unlock()

	if impl.closed {
		return ErrRootClosed
	}

	// Get current path
	currentPath := impl.rootPathInfo.Encode()

	// Rename the underlying directory
	if err := os.Rename(currentPath, string(targetPath)); err != nil {
		return fmt.Errorf("failed to rename root directory: %w", err)
	}

	// Update rootPathInfo to the new path
	impl.rootPathInfo = sec_utils.ParsePathInfoMust(string(targetPath))

	return nil
}

// CloneRootShallow creates a shallow clone of the root object.
// This function creates a new root object pointing to the same directory,
// but does not modify the original root's path.
//
// This is useful for operations that need to access the same root directory
// with a different root object instance (e.g., for concurrent access).
//
// Parameters:
//   - root: the secure root to clone
//
// Returns:
//   - ISecRoot: the cloned root object (opened)
//   - error: any error that occurred
//
// Note: The cloned root shares the same underlying directory and configuration.
// Closing or modifying one root does not affect the other.
func CloneRootShallow(root ISecRoot) (ISecRoot, error) {
	if root == nil {
		return nil, ErrRootIsNil
	}

	// Type assertion to access internal fields
	impl, ok := root.(*secRootImpl)
	if !ok {
		return nil, fmt.Errorf("CloneRootShallow: unsupported root type")
	}

	impl.mu.RLock()
	defer impl.mu.RUnlock()

	if impl.closed {
		return nil, ErrRootClosed
	}

	// Create a new root object with the same configuration
	// This is a shallow clone - the same directory, same configuration
	cloned := &secRootImpl{
		fileDataFactory: impl.fileDataFactory,
		rootPathInfo:    impl.rootPathInfo,
		keyInfo:         impl.keyInfo,
		cfg:             impl.cfg,
		closed:          false,
		nameCryptor:     impl.nameCryptor,
		ignoreMatcher:   impl.ignoreMatcher,
	}

	return cloned, nil
}

// CloneRoot creates a clone of the root at the target path.
// This function creates a new root directory with the same configuration and files.
//
// Parameters:
//   - root: the secure root to clone
//   - targetPath: the path for the cloned root
//   - password: the password for the cloned root
//
// Returns:
//   - ISecRoot: the cloned root (opened)
//   - error: any error that occurred
//
// Note: This function copies the root's configuration and all files.
// The cloned root will have the same password and encryption settings.
func CloneRoot(root ISecRoot, targetPath FullStorePath, password string) (ISecRoot, error) {
	if root == nil {
		return nil, ErrRootIsNil
	}

	// Type assertion to access internal fields
	impl, ok := root.(*secRootImpl)
	if !ok {
		return nil, fmt.Errorf("CloneRoot: unsupported root type")
	}

	impl.mu.RLock()
	defer impl.mu.RUnlock()

	if impl.closed {
		return nil, ErrRootClosed
	}

	// Get current root path
	srcPath := impl.rootPathInfo.Encode()

	// Create target directory
	if err := os.MkdirAll(string(targetPath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create target directory: %w", err)
	}

	// Copy config file
	srcConfigPath := filepath.Join(srcPath, ConfigFileName)
	destConfigPath := filepath.Join(string(targetPath), ConfigFileName)
	if err := copyFile(srcConfigPath, destConfigPath); err != nil {
		os.RemoveAll(string(targetPath))
		return nil, fmt.Errorf("failed to copy config file: %w", err)
	}

	// Open the cloned root
	clonedRoot, err := OpenRootQuick(targetPath, password)
	if err != nil {
		os.RemoveAll(string(targetPath))
		return nil, fmt.Errorf("failed to open cloned root: %w", err)
	}

	// Walk the source root and copy all files
	walker, err := root.WalkDir(RelativeViewPath(""))
	if err != nil {
		clonedRoot.Close()
		os.RemoveAll(string(targetPath))
		return nil, fmt.Errorf("failed to walk source root: %w", err)
	}
	defer walker.Close()

	for {
		entry, err := walker.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			clonedRoot.Close()
			os.RemoveAll(string(targetPath))
			return nil, fmt.Errorf("failed to read entry: %w", err)
		}

		if !entry.IsDir() {
			// Copy file content
			relPath := entry.GetRelativeViewPath()
			if err := copyFileContent(root, clonedRoot, relPath); err != nil {
				clonedRoot.Close()
				os.RemoveAll(string(targetPath))
				return nil, fmt.Errorf("failed to copy file %s: %w", relPath, err)
			}
		}
	}

	return clonedRoot, nil
}

// copyFile copies a file from src to dst.
func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	return err
}

// copyFileContent copies file content from src root to dest root.
func copyFileContent(srcRoot, destRoot ISecRoot, relPath RelativeViewPath) error {
	// Open source file
	srcFile, err := srcRoot.OpenFile(relPath, os.O_RDONLY)
	if err != nil {
		return err
	}
	defer srcFile.Close()

	// Create destination file
	destFile, err := destRoot.OpenFile(relPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC)
	if err != nil {
		return err
	}
	defer destFile.Close()

	// Copy content
	_, err = io.Copy(destFile, srcFile)
	return err
}
