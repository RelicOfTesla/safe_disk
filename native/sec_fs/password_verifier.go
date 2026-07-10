package sec_fs

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"

	"safe_disk/native/config"
)

const (
	passwordVerifierVersionKey   = "sec_password_verifier_version"
	passwordVerifierChallengeKey = "sec_password_verifier_challenge"
	passwordVerifierTagKey       = "sec_password_verifier_tag"
	passwordVerifierVersion      = 1
	passwordVerifierChallengeLen = 32
	passwordVerifierDomain       = "safe-disk/password-verifier/v1\x00"
)

func writePasswordVerifier(cfg config.SharedConfig, key []byte) error {
	if cfg == nil || len(key) == 0 {
		return NewConfigError("password_verifier", "configuration and derived key are required", ErrInvalidConfig)
	}

	challenge := make([]byte, passwordVerifierChallengeLen)
	if _, err := rand.Read(challenge); err != nil {
		return NewCryptoError("password_verifier", "failed to generate challenge", err)
	}
	tag := calculatePasswordVerifierTag(key, challenge)

	if err := cfg.SetStr(passwordVerifierChallengeKey, base64.StdEncoding.EncodeToString(challenge)); err != nil {
		return NewConfigError(passwordVerifierChallengeKey, "failed to store challenge", err)
	}
	if err := cfg.SetStr(passwordVerifierTagKey, base64.StdEncoding.EncodeToString(tag)); err != nil {
		return NewConfigError(passwordVerifierTagKey, "failed to store verifier tag", err)
	}
	// Write the version last. Its presence marks a complete verifier record.
	if err := cfg.SetInt(passwordVerifierVersionKey, passwordVerifierVersion); err != nil {
		return NewConfigError(passwordVerifierVersionKey, "failed to commit verifier", err)
	}
	return nil
}

func verifyPassword(cfg config.SharedConfig, key []byte) error {
	if cfg == nil || len(key) == 0 {
		return NewConfigError("password_verifier", "configuration and derived key are required", ErrInvalidConfig)
	}

	version, err := cfg.GetInt(passwordVerifierVersionKey)
	if err != nil {
		return NewConfigError(passwordVerifierVersionKey, "root cannot authenticate passwords; recreate and import the root", ErrPasswordVerifierMissing)
	}
	if version != passwordVerifierVersion {
		return NewConfigError(passwordVerifierVersionKey, fmt.Sprintf("unsupported version %d", version), ErrInvalidConfig)
	}

	challenge, err := readPasswordVerifierBytes(cfg, passwordVerifierChallengeKey, passwordVerifierChallengeLen)
	if err != nil {
		return err
	}
	storedTag, err := readPasswordVerifierBytes(cfg, passwordVerifierTagKey, sha256.Size)
	if err != nil {
		return err
	}
	expectedTag := calculatePasswordVerifierTag(key, challenge)
	if !hmac.Equal(storedTag, expectedTag) {
		return ErrInvalidPassword
	}
	return nil
}

func readPasswordVerifierBytes(cfg config.SharedConfig, key string, requiredLen int) ([]byte, error) {
	encoded, err := cfg.GetStr(key)
	if err != nil {
		return nil, NewConfigError(key, "password verifier record is incomplete", ErrInvalidConfig)
	}
	decoded, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, NewConfigError(key, "password verifier value is not valid base64", ErrInvalidConfig)
	}
	if len(decoded) != requiredLen {
		return nil, NewConfigError(key, fmt.Sprintf("invalid length %d", len(decoded)), ErrInvalidConfig)
	}
	return decoded, nil
}

func calculatePasswordVerifierTag(key, challenge []byte) []byte {
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write([]byte(passwordVerifierDomain))
	_, _ = mac.Write(challenge)
	return mac.Sum(nil)
}
