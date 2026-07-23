package sec_fs

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

const (
	rootKeyEnvelopeVersionKey    = "sec_key_envelope_version"
	rootKeyEnvelopeNonceKey      = "sec_key_envelope_nonce"
	rootKeyEnvelopeCiphertextKey = "sec_key_envelope_ciphertext"
	rootKeyEnvelopeFormatVersion = 1
	rootKeyEnvelopeDomain        = "safe-disk/root-key-envelope/v1"
	passwordWrappingKeyLength    = 32
)

// ErrPasswordChangeUnsupported means that a legacy root uses its password as
// the content key and therefore cannot change passwords without re-encryption.
var ErrPasswordChangeUnsupported = fmt.Errorf("password change is not supported by this root format: %w", ErrUnsupportedOperation)

// WithPasswordChangeable creates a root whose random content key is wrapped by
// a password-derived key, allowing later password changes without data rewrite.
func WithPasswordChangeable(enabled bool) CreateRootOption {
	return func(o *CreateRootOptions) {
		o.PasswordChangeable = enabled
	}
}

// ChangeRootPasswordQuick re-wraps a password-changeable root's content key.
// It never rewrites encrypted user data. Legacy roots are rejected explicitly.
func ChangeRootPasswordQuick(rootPath FullStorePath, oldPassword, newPassword string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	return ChangeRootPasswordContext(ctx, rootPath, oldPassword, newPassword)
}

// ChangeRootPasswordContext changes a root password while serializing config
// writes across processes. Callers can cancel while another process is changing
// the same root.
func ChangeRootPasswordContext(
	ctx context.Context,
	rootPath FullStorePath,
	oldPassword, newPassword string,
) error {
	if rootPath == "" {
		return ErrInvalidPath
	}
	if oldPassword == "" || newPassword == "" {
		return NewConfigError("password", "current and new passwords are required", ErrInvalidPassword)
	}
	lock, err := acquireRootConfigLock(ctx, string(rootPath))
	if err != nil {
		return NewConfigError("password_change", "another process is changing this directory", err)
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

	version, present, err := rootKeyEnvelopeVersion(cfg)
	if err != nil {
		return err
	}
	if !present {
		return ErrPasswordChangeUnsupported
	}
	if version != rootKeyEnvelopeFormatVersion {
		return NewConfigError(rootKeyEnvelopeVersionKey, fmt.Sprintf("unsupported version %d", version), ErrInvalidConfig)
	}

	oldWrappingKey, err := loadPasswordWrappingKey(cfg, deriverFactory, oldPassword)
	if err != nil {
		return err
	}
	defer oldWrappingKey.Destroy()
	if err := verifyPassword(cfg, oldWrappingKey.GetKey()); err != nil {
		return err
	}
	contentKey, err := unwrapRootKey(cfg, oldWrappingKey.GetKey())
	if err != nil {
		return err
	}
	defer contentKey.Destroy()

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

	stagedDeriver, err := deriverFactory.NewDeriver(stagedCfg)
	if err != nil {
		return NewConfigError("sec_deriver_factory", "failed to create deriver", err)
	}
	newWrappingKey, err := stagedDeriver.NewKey(&crypto_hkdf.MakeKeyParams{
		Password:              newPassword,
		StaticSalt:            false,
		KeyLength:             passwordWrappingKeyLength,
		ReuseStoredParameters: true,
	}, stagedCfg)
	if err != nil {
		return NewConfigError("key_derivation", "failed to derive new password key", err)
	}
	defer newWrappingKey.Destroy()
	if err := writePasswordVerifier(stagedCfg, newWrappingKey.GetKey()); err != nil {
		return err
	}
	if err := writeRootKeyEnvelope(stagedCfg, newWrappingKey.GetKey(), contentKey.GetKey()); err != nil {
		return err
	}
	if err := commitStagedRootConfig(stagedPath, cfgPath); err != nil {
		return err
	}
	committed = true
	return nil
}

func loadRootKeyForOpen(
	cfg config.SharedConfig,
	deriverFactory crypto_hkdf.IDeriverFactory,
	password string,
) (crypto_hkdf.IKeyInfo, error) {
	wrappingKey, err := loadPasswordWrappingKey(cfg, deriverFactory, password)
	if err != nil {
		return nil, err
	}

	version, present, err := rootKeyEnvelopeVersion(cfg)
	if err != nil {
		wrappingKey.Destroy()
		return nil, err
	}
	if !present {
		if err := verifyPassword(cfg, wrappingKey.GetKey()); err != nil {
			wrappingKey.Destroy()
			return nil, err
		}
		return wrappingKey, nil
	}
	if version != rootKeyEnvelopeFormatVersion {
		wrappingKey.Destroy()
		return nil, NewConfigError(rootKeyEnvelopeVersionKey, fmt.Sprintf("unsupported version %d", version), ErrInvalidConfig)
	}
	if err := verifyPassword(cfg, wrappingKey.GetKey()); err != nil {
		wrappingKey.Destroy()
		return nil, err
	}
	contentKey, err := unwrapRootKey(cfg, wrappingKey.GetKey())
	wrappingKey.Destroy()
	return contentKey, err
}

func loadPasswordWrappingKey(
	cfg config.SharedConfig,
	deriverFactory crypto_hkdf.IDeriverFactory,
	password string,
) (crypto_hkdf.IKeyInfo, error) {
	deriver, err := deriverFactory.NewDeriver(cfg)
	if err != nil {
		return nil, NewConfigError("sec_deriver_factory", "failed to create deriver", err)
	}
	key, err := deriver.LoadKey(password, cfg)
	if err != nil {
		return nil, NewConfigError("key_derivation", "failed to derive key", err)
	}
	if key == nil {
		return nil, NewConfigError("key_derivation", "derived key is required", ErrInvalidConfig)
	}
	return key, nil
}

func writeRootKeyEnvelope(cfg config.SharedConfig, wrappingKey, contentKey []byte) error {
	if len(contentKey) == 0 {
		return NewConfigError(rootKeyEnvelopeCiphertextKey, "content key is required", ErrInvalidConfig)
	}
	gcm, err := newRootKeyEnvelopeCipher(wrappingKey)
	if err != nil {
		return err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return NewCryptoError("root_key_envelope", "failed to generate nonce", err)
	}
	ciphertext := gcm.Seal(nil, nonce, contentKey, []byte(rootKeyEnvelopeDomain))
	if err := cfg.SetStr(rootKeyEnvelopeNonceKey, base64.RawStdEncoding.EncodeToString(nonce)); err != nil {
		return NewConfigError(rootKeyEnvelopeNonceKey, "failed to store nonce", err)
	}
	if err := cfg.SetStr(rootKeyEnvelopeCiphertextKey, base64.RawStdEncoding.EncodeToString(ciphertext)); err != nil {
		return NewConfigError(rootKeyEnvelopeCiphertextKey, "failed to store ciphertext", err)
	}
	// Version is written last so a partially created root never advertises a
	// complete envelope record.
	if err := cfg.SetInt(rootKeyEnvelopeVersionKey, rootKeyEnvelopeFormatVersion); err != nil {
		return NewConfigError(rootKeyEnvelopeVersionKey, "failed to store version", err)
	}
	return nil
}

func unwrapRootKey(cfg config.SharedConfig, wrappingKey []byte) (crypto_hkdf.IKeyInfo, error) {
	gcm, err := newRootKeyEnvelopeCipher(wrappingKey)
	if err != nil {
		return nil, err
	}
	nonce, err := readRootKeyEnvelopeValue(cfg, rootKeyEnvelopeNonceKey)
	if err != nil {
		return nil, err
	}
	if len(nonce) != gcm.NonceSize() {
		return nil, NewConfigError(rootKeyEnvelopeNonceKey, "invalid nonce length", ErrInvalidConfig)
	}
	ciphertext, err := readRootKeyEnvelopeValue(cfg, rootKeyEnvelopeCiphertextKey)
	if err != nil {
		return nil, err
	}
	plaintext, err := gcm.Open(nil, nonce, ciphertext, []byte(rootKeyEnvelopeDomain))
	if err != nil {
		return nil, NewConfigError(rootKeyEnvelopeCiphertextKey, "password or encrypted key record is invalid", ErrInvalidPassword)
	}
	defer crypto_hkdf.ClearKey(plaintext)
	if len(plaintext) < passwordWrappingKeyLength {
		return nil, NewConfigError(rootKeyEnvelopeCiphertextKey, "content key is too short", ErrInvalidConfig)
	}
	return crypto_hkdf.NewKeyInfoCopy(plaintext), nil
}

func rootKeyEnvelopeVersion(cfg config.SharedConfig) (int, bool, error) {
	version, err := cfg.GetInt(rootKeyEnvelopeVersionKey)
	if err == nil {
		return version, true, nil
	}
	// A value stored under the wrong type is corrupt, not a legacy root.
	if _, strErr := cfg.GetStr(rootKeyEnvelopeVersionKey); strErr == nil {
		return 0, true, NewConfigError(rootKeyEnvelopeVersionKey, "version must be an integer", ErrInvalidConfig)
	}
	if _, boolErr := cfg.GetBool(rootKeyEnvelopeVersionKey); boolErr == nil {
		return 0, true, NewConfigError(rootKeyEnvelopeVersionKey, "version must be an integer", ErrInvalidConfig)
	}
	return 0, false, nil
}

func readRootKeyEnvelopeValue(cfg config.SharedConfig, key string) ([]byte, error) {
	encoded, err := cfg.GetStr(key)
	if err != nil {
		return nil, NewConfigError(key, "encrypted key record is incomplete", ErrInvalidConfig)
	}
	value, err := base64.RawStdEncoding.DecodeString(encoded)
	if err != nil || len(value) == 0 {
		return nil, NewConfigError(key, "encrypted key record is invalid", ErrInvalidConfig)
	}
	return value, nil
}

func newRootKeyEnvelopeCipher(key []byte) (cipher.AEAD, error) {
	if len(key) < passwordWrappingKeyLength {
		return nil, NewConfigError("key_derivation", "password key is too short", ErrInvalidConfig)
	}
	block, err := aes.NewCipher(key[:passwordWrappingKeyLength])
	if err != nil {
		return nil, NewCryptoError("root_key_envelope", "failed to create cipher", err)
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, NewCryptoError("root_key_envelope", "failed to create cipher mode", err)
	}
	return gcm, nil
}

func newRandomRootKey(length int) (crypto_hkdf.IKeyInfo, error) {
	if length < passwordWrappingKeyLength {
		length = passwordWrappingKeyLength
	}
	key := make([]byte, length)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, NewCryptoError("root_key", "failed to generate content key", err)
	}
	keyInfo := crypto_hkdf.NewKeyInfoCopy(key)
	crypto_hkdf.ClearKey(key)
	return keyInfo, nil
}

func stageRootConfig(cfgPath string) (string, *config.FileConfig, error) {
	contents, err := os.ReadFile(cfgPath)
	if err != nil {
		return "", nil, NewConfigError("config", "failed to read current config", err)
	}
	temp, err := os.CreateTemp(filepath.Dir(cfgPath), ".safe_disk.root-config-*")
	if err != nil {
		return "", nil, NewConfigError("config", "failed to create staged config", err)
	}
	tempPath := temp.Name()
	if err = temp.Chmod(0o600); err == nil {
		_, err = temp.Write(contents)
	}
	if err == nil {
		err = temp.Sync()
	}
	closeErr := temp.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		_ = os.Remove(tempPath)
		return "", nil, NewConfigError("config", "failed to stage current config", err)
	}
	stagedCfg, err := config.NewFileConfig(tempPath)
	if err != nil {
		_ = os.Remove(tempPath)
		return "", nil, NewConfigError("config", "failed to load staged config", err)
	}
	return tempPath, stagedCfg, nil
}

func commitStagedRootConfig(stagedPath, cfgPath string) error {
	staged, err := os.Open(stagedPath)
	if err != nil {
		return NewConfigError("config", "failed to open staged config", err)
	}
	err = staged.Sync()
	closeErr := staged.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return NewConfigError("config", "failed to sync staged config", err)
	}
	if err := os.Rename(stagedPath, cfgPath); err != nil {
		return NewConfigError("config", "failed to replace config", err)
	}
	if directory, err := os.Open(filepath.Dir(cfgPath)); err == nil {
		_ = directory.Sync() // Some platforms do not support directory sync.
		_ = directory.Close()
	}
	return nil
}
