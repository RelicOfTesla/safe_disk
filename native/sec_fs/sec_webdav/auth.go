package sec_webdav

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type AuthMode string

const (
	AuthModeBearer AuthMode = "bearer"
	AuthModeDigest AuthMode = "digest"
)

type OpenOptions struct {
	AuthMode AuthMode `json:"auth_mode"`
}

func ParseOpenOptions(optionsJSON string) (OpenOptions, error) {
	if strings.TrimSpace(optionsJSON) == "" {
		return OpenOptions{AuthMode: AuthModeBearer}, nil
	}
	var options OpenOptions
	decoder := json.NewDecoder(strings.NewReader(optionsJSON))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&options); err != nil {
		return OpenOptions{}, fmt.Errorf("invalid webdav options: %w", err)
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		return OpenOptions{}, errors.New("invalid webdav options: trailing data")
	}
	if options.AuthMode == "" {
		options.AuthMode = AuthModeBearer
	}
	if options.AuthMode != AuthModeBearer && options.AuthMode != AuthModeDigest {
		return OpenOptions{}, fmt.Errorf("unsupported webdav auth mode: %q", options.AuthMode)
	}
	return options, nil
}

type authState struct {
	mode     AuthMode
	token    string
	username string
	password string
	realm    string
	digest   *digestState
}

func (m *Manager) newAuthLocked(mode AuthMode) (authState, error) {
	if mode == "" {
		mode = AuthModeBearer
	}
	switch mode {
	case AuthModeBearer:
		token, err := m.newValueLocked(32)
		if err != nil {
			return authState{}, err
		}
		return authState{mode: AuthModeBearer, token: token}, nil
	case AuthModeDigest:
		username, err := m.newValueLocked(12)
		if err != nil {
			return authState{}, err
		}
		password, err := m.newValueLocked(24)
		if err != nil {
			return authState{}, err
		}
		realm, err := m.newValueLocked(12)
		if err != nil {
			return authState{}, err
		}
		key := make([]byte, 32)
		if _, err := io.ReadFull(m.random, key); err != nil {
			return authState{}, err
		}
		return authState{
			mode:     AuthModeDigest,
			username: username,
			password: password,
			realm:    realm,
			digest: &digestState{
				username: username,
				password: password,
				realm:    realm,
				key:      key,
				maxNC:    make(map[string]uint32),
			},
		}, nil
	default:
		return authState{}, fmt.Errorf("unsupported webdav auth mode: %q", mode)
	}
}

func (m *Manager) authenticateLocked(active *activeSession, request *http.Request) (string, bool) {
	switch active.auth.mode {
	case AuthModeBearer:
		if bearerAuthorized(request, active.auth.token) {
			return "", true
		}
		return `Bearer realm="safe-disk"`, false
	case AuthModeDigest:
		if active.auth.digest == nil {
			return "", false
		}
		ok, stale := active.auth.digest.verify(request)
		return m.digestChallengeLocked(active.auth.digest, stale), ok
	default:
		return "", false
	}
}

func (m *Manager) digestChallengeLocked(auth *digestState, stale bool) string {
	nonce, err := auth.newNonce(time.Now().UTC(), m.random)
	if err != nil {
		return ""
	}
	challenge := `Digest realm="` + auth.realm + `", nonce="` + nonce + `", algorithm=SHA-256, qop="auth"`
	if stale {
		challenge += ", stale=true"
	}
	return challenge
}

func bearerAuthorized(r *http.Request, token string) bool {
	value := r.Header.Get("Authorization")
	expected := "Bearer " + token
	return len(value) == len(expected) && subtle.ConstantTimeCompare([]byte(value), []byte(expected)) == 1
}

const (
	digestNonceLifetime = 5 * time.Minute
	digestClockSkew     = 30 * time.Second
)

type digestState struct {
	username string
	password string
	realm    string
	key      []byte
	maxNC    map[string]uint32
}

func (d *digestState) newNonce(now time.Time, random io.Reader) (string, error) {
	payload := make([]byte, 24)
	binary.BigEndian.PutUint64(payload[:8], uint64(now.Unix()))
	if _, err := io.ReadFull(random, payload[8:]); err != nil {
		return "", err
	}
	mac := hmac.New(sha256.New, d.key)
	_, _ = mac.Write(payload)
	payload = append(payload, mac.Sum(nil)...)
	return base64.RawURLEncoding.EncodeToString(payload), nil
}

func (d *digestState) verify(request *http.Request) (bool, bool) {
	fields, err := parseDigestAuthorization(request.Header.Get("Authorization"))
	if err != nil {
		return false, false
	}
	if !strings.EqualFold(fields["algorithm"], "SHA-256") || fields["qop"] != "auth" {
		return false, false
	}
	if !constantStringEqual(fields["username"], d.username) ||
		!constantStringEqual(fields["realm"], d.realm) {
		return false, false
	}
	if fields["uri"] != request.URL.RequestURI() {
		return false, false
	}
	validNonce, stale := d.validNonce(fields["nonce"], time.Now().UTC())
	if !validNonce {
		return false, stale
	}
	if len(fields["nc"]) != 8 {
		return false, false
	}
	ncValue, err := strconv.ParseUint(fields["nc"], 16, 32)
	if err != nil || ncValue == 0 || fields["cnonce"] == "" {
		return false, false
	}
	if !isLowerHex(fields["response"], sha256.Size*2) {
		return false, false
	}

	ha1 := digestHash(d.username + ":" + d.realm + ":" + d.password)
	ha2 := digestHash(request.Method + ":" + fields["uri"])
	expected := digestHash(ha1 + ":" + fields["nonce"] + ":" + fields["nc"] + ":" + fields["cnonce"] + ":auth:" + ha2)
	if subtle.ConstantTimeCompare([]byte(expected), []byte(fields["response"])) != 1 {
		return false, false
	}

	key := fields["nonce"] + "\x00" + fields["username"] + "\x00" + fields["cnonce"]
	if previous, exists := d.maxNC[key]; exists && uint32(ncValue) <= previous {
		return false, false
	}
	d.maxNC[key] = uint32(ncValue)
	return true, false
}

func (d *digestState) validNonce(value string, now time.Time) (bool, bool) {
	payload, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil || len(payload) != 56 {
		return false, false
	}
	mac := hmac.New(sha256.New, d.key)
	_, _ = mac.Write(payload[:24])
	if subtle.ConstantTimeCompare(payload[24:], mac.Sum(nil)) != 1 {
		return false, false
	}
	issuedAt := time.Unix(int64(binary.BigEndian.Uint64(payload[:8])), 0)
	if issuedAt.After(now.Add(digestClockSkew)) {
		return false, false
	}
	if now.Sub(issuedAt) > digestNonceLifetime {
		return false, true
	}
	return true, false
}

func parseDigestAuthorization(value string) (map[string]string, error) {
	if !strings.HasPrefix(value, "Digest ") {
		return nil, errors.New("webdav authorization is not digest")
	}
	value = strings.TrimSpace(strings.TrimPrefix(value, "Digest "))
	if value == "" {
		return nil, errors.New("webdav digest authorization is empty")
	}
	fields := make(map[string]string)
	for value != "" {
		equal := strings.IndexByte(value, '=')
		if equal <= 0 {
			return nil, errors.New("webdav digest authorization field is invalid")
		}
		name := strings.TrimSpace(value[:equal])
		if name == "" {
			return nil, errors.New("webdav digest authorization field name is empty")
		}
		value = strings.TrimSpace(value[equal+1:])
		parsed, rest, err := parseDigestValue(value)
		if err != nil {
			return nil, err
		}
		if _, exists := fields[name]; exists {
			return nil, errors.New("webdav digest authorization field is duplicated")
		}
		fields[name] = parsed
		value = strings.TrimSpace(rest)
		if value == "" {
			break
		}
		if value[0] != ',' {
			return nil, errors.New("webdav digest authorization separator is invalid")
		}
		value = strings.TrimSpace(value[1:])
	}
	return fields, nil
}

func parseDigestValue(value string) (string, string, error) {
	if value == "" {
		return "", "", errors.New("webdav digest authorization value is empty")
	}
	if value[0] != '"' {
		if comma := strings.IndexByte(value, ','); comma >= 0 {
			return strings.TrimSpace(value[:comma]), value[comma:], nil
		}
		return strings.TrimSpace(value), "", nil
	}
	var builder strings.Builder
	for index := 1; index < len(value); index++ {
		switch value[index] {
		case '\\':
			index++
			if index >= len(value) {
				return "", "", errors.New("webdav digest quoted value is truncated")
			}
			builder.WriteByte(value[index])
		case '"':
			return builder.String(), value[index+1:], nil
		default:
			builder.WriteByte(value[index])
		}
	}
	return "", "", errors.New("webdav digest quoted value is unterminated")
}

func digestHash(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func isLowerHex(value string, length int) bool {
	if len(value) != length {
		return false
	}
	for _, char := range value {
		if !(char >= '0' && char <= '9') && !(char >= 'a' && char <= 'f') {
			return false
		}
	}
	return true
}

func constantStringEqual(left, right string) bool {
	if len(left) != len(right) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(left), []byte(right)) == 1
}
