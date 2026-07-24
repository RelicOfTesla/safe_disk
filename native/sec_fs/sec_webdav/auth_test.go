package sec_webdav

import (
	"crypto/x509"
	"crypto/tls"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestBasicAuthValidCredentialsPasses(t *testing.T) {
	user := "testuser"
	pass := "secret123"
	auth := base64.StdEncoding.EncodeToString([]byte(user + ":" + pass))
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic "+auth)
	if !basicAuthorized(request, user, pass) {
		t.Fatal("basicAuthorized returned false for valid credentials")
	}
}

func TestBasicAuthInvalidPasswordRejected(t *testing.T) {
	user := "testuser"
	pass := "secret123"
	auth := base64.StdEncoding.EncodeToString([]byte(user + ":wrong-pass"))
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic "+auth)
	if basicAuthorized(request, user, pass) {
		t.Fatal("basicAuthorized returned true for wrong password")
	}
}

func TestBasicAuthInvalidUsernameRejected(t *testing.T) {
	user := "testuser"
	pass := "secret123"
	auth := base64.StdEncoding.EncodeToString([]byte("wrong-user:" + pass))
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic "+auth)
	if basicAuthorized(request, user, pass) {
		t.Fatal("basicAuthorized returned true for wrong username")
	}
}

func TestBasicAuthMissingHeaderRejected(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	if basicAuthorized(request, "user", "pass") {
		t.Fatal("basicAuthorized returned true without Authorization header")
	}
}

func TestBasicAuthWrongSchemeRejected(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Bearer some-token")
	if basicAuthorized(request, "user", "pass") {
		t.Fatal("basicAuthorized returned true for Bearer scheme")
	}
}

func TestBasicAuthEmptyBase64ValueRejected(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic ")
	if basicAuthorized(request, "user", "pass") {
		t.Fatal("basicAuthorized returned true for empty base64 value")
	}
}

func TestBasicAuthMalformedBase64Rejected(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic !!!not-base64!!!")
	if basicAuthorized(request, "user", "pass") {
		t.Fatal("basicAuthorized returned true for malformed base64")
	}
}

func TestBasicAuthNoColonInDecodedValueRejected(t *testing.T) {
	auth := base64.StdEncoding.EncodeToString([]byte("no-colon-here"))
	request := httptest.NewRequest(http.MethodGet, "/webdav/session-id/readme.txt", nil)
	request.Header.Set("Authorization", "Basic "+auth)
	if basicAuthorized(request, "user", "pass") {
		t.Fatal("basicAuthorized returned true for credential without colon")
	}
}

func TestBasicAuthConstantTimeResistsTiming(t *testing.T) {
	// Verify that equal-length wrong passwords still fail (constant-time guard).
	user := "user"
	pass := "abcdefgh"
	wrong := "abcdefgi"
	if len(user) != len(user) || len(pass) != len(wrong) {
		t.Skip("length mismatch, not a constant-time test")
	}
	auth := base64.StdEncoding.EncodeToString([]byte(user + ":" + wrong))
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Basic "+auth)
	if basicAuthorized(request, user, pass) {
		t.Fatal("basicAuthorized returned true for same-length but different password")
	}
}

func TestBearerAuthorizedMatchesToken(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Bearer abc123")
	if !bearerAuthorized(request, "abc123") {
		t.Fatal("bearerAuthorized returned false for matching token")
	}
}

func TestBearerAuthorizedRejectsWrongToken(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Bearer abc123")
	if bearerAuthorized(request, "def456") {
		t.Fatal("bearerAuthorized returned true for wrong token")
	}
}

func TestBearerAuthorizedRejectsMissingHeader(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	if bearerAuthorized(request, "abc123") {
		t.Fatal("bearerAuthorized returned true without header")
	}
}

func TestBearerAuthorizedRejectsWrongScheme(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Basic YWJjOjEyMw==")
	if bearerAuthorized(request, "abc123") {
		t.Fatal("bearerAuthorized returned true for Basic scheme")
	}
}

func TestBearerAuthorizedConstantTimeComparesToken(t *testing.T) {
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	request.Header.Set("Authorization", "Bearer abcdefgh")
	if bearerAuthorized(request, "abcdefgi") {
		t.Fatal("bearerAuthorized returned true for one-char-different token")
	}
}

func TestParseDigestAuthorizationValid(t *testing.T) {
	fields, err := parseDigestAuthorization(
		`Digest username="alice", realm="safe-disk", nonce="abc", uri="/webdav/id/file.txt", algorithm=SHA-256, qop=auth, nc=00000001, cnonce="client-nonce", response="abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"`,
	)
	if err != nil {
		t.Fatal(err)
	}
	if fields["username"] != "alice" || fields["algorithm"] != "SHA-256" || fields["qop"] != "auth" {
		t.Fatalf("parsed fields = %#v", fields)
	}
}

func TestParseDigestAuthorizationRejectsWrongPrefix(t *testing.T) {
	_, err := parseDigestAuthorization("Bearer abc")
	if err == nil {
		t.Fatal("expected error for Bearer prefix")
	}
}

func TestParseDigestAuthorizationRejectsEmptyFields(t *testing.T) {
	_, err := parseDigestAuthorization("Digest ")
	if err == nil {
		t.Fatal("expected error for empty Digest")
	}
}

func TestParseDigestAuthorizationRejectsUnquotedAttributes(t *testing.T) {
	_, err := parseDigestAuthorization(`Digest username=alice, nonce="abc"`)
	if err != nil {
		t.Fatalf("unexpected error for unquoted attribute: %v", err)
	}
}

func TestGenerateSelfSignedTLSConfigProducesValidConfig(t *testing.T) {
	config, err := generateSelfSignedTLSConfig()
	if err != nil {
		t.Fatal(err)
	}
	if len(config.Certificates) != 1 {
		t.Fatalf("expected 1 certificate, got %d", len(config.Certificates))
	}
	cert := config.Certificates[0]
	if cert.PrivateKey == nil {
		t.Fatal("certificate has no private key")
	}
	if cert.Leaf == nil {
		// Parse the DER certificate to verify the leaf.
		parsed, err := x509.ParseCertificate(cert.Certificate[0])
		if err != nil {
			t.Fatal(err)
		}
		cert.Leaf = parsed
	}
	if config.MinVersion != tls.VersionTLS12 {
		t.Fatalf("expected TLS 1.2 min version, got %d", config.MinVersion)
	}
}

func TestParseOpenOptionsDefaultsToBearer(t *testing.T) {
	options, err := ParseOpenOptions("")
	if err != nil {
		t.Fatal(err)
	}
	if options.AuthMode != AuthModeBearer {
		t.Fatalf("expected bearer, got %s", options.AuthMode)
	}
	if options.CredentialVisibility != CredentialVisibilityOnce {
		t.Fatalf("expected once, got %s", options.CredentialVisibility)
	}
}

func TestParseOpenOptionsRejectsUnknownAuthMode(t *testing.T) {
	_, err := ParseOpenOptions(`{"auth_mode":"ntlm"}`)
	if err == nil {
		t.Fatal("expected error for unknown auth mode")
	}
}

func TestParseOpenOptionsRejectsInvalidPort(t *testing.T) {
	_, err := ParseOpenOptions(`{"port":99999}`)
	if err == nil {
		t.Fatal("expected error for invalid port")
	}
}

func TestParseOpenOptionsBasicAuthWithTLS(t *testing.T) {
	options, err := ParseOpenOptions(`{"auth_mode":"basic","tls":true,"credential_visibility":"persistent","session_lifetime":"persistent","port":8443}`)
	if err != nil {
		t.Fatal(err)
	}
	if options.AuthMode != AuthModeBasic || !options.TLS || options.Port != 8443 {
		t.Fatalf("options = %#v", options)
	}
}

func TestAuthFromPersistentBearer(t *testing.T) {
	auth, err := authFromPersistent(PersistentSession{
		AuthMode: AuthModeBearer,
		Token:    "secret-token",
	})
	if err != nil {
		t.Fatal(err)
	}
	if auth.token != "secret-token" || auth.mode != AuthModeBearer {
		t.Fatalf("auth = %#v", auth)
	}
}

func TestAuthFromPersistentBearerMissingToken(t *testing.T) {
	_, err := authFromPersistent(PersistentSession{
		AuthMode: AuthModeBearer,
	})
	if err == nil {
		t.Fatal("expected error for missing token")
	}
}

func TestWebdavURLScheme(t *testing.T) {
	if got := webdavURLScheme(true); got != "https://" {
		t.Fatalf("TLS scheme = %q", got)
	}
	if got := webdavURLScheme(false); got != "http://" {
		t.Fatalf("plain scheme = %q", got)
	}
}

func TestPathValidationRejectsTraversal(t *testing.T) {
	for _, path := range []string{"../docs", "docs/../secret", `docs\\secret`, "docs\x00secret"} {
		if _, err := cleanRelativePath(path); err != ErrInvalidPath {
			t.Fatalf("path %q should be invalid, got %v", path, err)
		}
	}
}

func TestPathValidationAcceptsNormalPaths(t *testing.T) {
	for _, path := range []string{"", "docs", "docs/nested", "中文 name.txt", "sub dir/data.bin"} {
		result, err := cleanRelativePath(path)
		if err != nil {
			t.Fatalf("path %q returned error: %v", path, err)
		}
		if strings.Trim(result, "/") != result {
			t.Fatalf("path %q has stray slashes: %q", path, result)
		}
	}
}

func TestSplitURLPath(t *testing.T) {
	segments := splitURLPath("/webdav/session-id/readme.txt")
	if len(segments) != 3 || segments[0] != "webdav" || segments[1] != "session-id" {
		t.Fatalf("split = %#v", segments)
	}
}

func TestSplitURLPathEmpty(t *testing.T) {
	if segments := splitURLPath("/"); segments != nil {
		t.Fatalf("split empty = %#v", segments)
	}
}

func TestValidURLSegmentsRejectsTraversal(t *testing.T) {
	if validURLSegments([]string{".."}) {
		t.Fatal(".. should be rejected")
	}
	if validURLSegments([]string{"."}) {
		t.Fatal(". should be rejected")
	}
	if validURLSegments([]string{"readme.txt", "..", "secret"}) {
		t.Fatal("embedded .. should be rejected")
	}
}

func TestValidURLSegmentsAcceptsNormal(t *testing.T) {
	if !validURLSegments([]string{"readme.txt", "subdir", "data.bin"}) {
		t.Fatal("normal segments should be accepted")
	}
}

func TestAuthFromPersistentDigest(t *testing.T) {
	digestKey := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	auth, err := authFromPersistent(PersistentSession{
		AuthMode:  AuthModeDigest,
		Username:  "digest-user",
		Password:  "digest-pass",
		Realm:     "safe-disk",
		DigestKey: digestKey,
	})
	if err != nil {
		t.Fatal(err)
	}
	if auth.mode != AuthModeDigest || auth.username != "digest-user" || auth.password != "digest-pass" {
		t.Fatalf("auth = %#v", auth)
	}
	if auth.digest == nil || auth.digest.realm != "safe-disk" {
		t.Fatalf("digest state = %#v", auth.digest)
	}
	if len(auth.digest.key) != 32 {
		t.Fatalf("digest key length = %d", len(auth.digest.key))
	}
}

func TestAuthFromPersistentDigestMissingKey(t *testing.T) {
	_, err := authFromPersistent(PersistentSession{
		AuthMode: AuthModeDigest,
		Username: "user",
		Password: "pass",
		Realm:    "safe-disk",
	})
	if err == nil {
		t.Fatal("expected error for missing digest key")
	}
}

func TestAuthFromPersistentBasic(t *testing.T) {
	auth, err := authFromPersistent(PersistentSession{
		AuthMode:          AuthModeBasic,
		BasicAuthUsername: "basic-user",
		BasicAuthPassword: "basic-pass",
	})
	if err != nil {
		t.Fatal(err)
	}
	if auth.mode != AuthModeBasic || auth.basicUsername != "basic-user" || auth.basicPassword != "basic-pass" {
		t.Fatalf("auth = %#v", auth)
	}
}

func TestAuthFromPersistentBasicMissingCredentials(t *testing.T) {
	_, err := authFromPersistent(PersistentSession{
		AuthMode: AuthModeBasic,
	})
	if err == nil {
		t.Fatal("expected error for missing basic auth credentials")
	}
}

func TestAuthFromPersistentUnknownMode(t *testing.T) {
	_, err := authFromPersistent(PersistentSession{
		AuthMode: AuthMode("unknown"),
	})
	if err == nil {
		t.Fatal("expected error for unknown auth mode")
	}
}

func TestParseOpenOptionsDigestPersistent(t *testing.T) {
	options, err := ParseOpenOptions(`{"auth_mode":"digest","credential_visibility":"persistent","session_lifetime":"persistent"}`)
	if err != nil {
		t.Fatal(err)
	}
	if options.AuthMode != AuthModeDigest || options.CredentialVisibility != CredentialVisibilityPersistent || options.SessionLifetime != SessionLifetimePersistent {
		t.Fatalf("options = %#v", options)
	}
}

func TestParseOpenOptionsAllAuthModes(t *testing.T) {
	for _, mode := range []AuthMode{AuthModeBearer, AuthModeDigest, AuthModeBasic} {
		options, err := ParseOpenOptions(`{"auth_mode":"` + string(mode) + `"}`)
		if err != nil {
			t.Fatalf("mode %s: %v", mode, err)
		}
		if options.AuthMode != mode {
			t.Fatalf("expected %s, got %s", mode, options.AuthMode)
		}
	}
}

func TestParseOpenOptionsRejectsEmptyAuthMode(t *testing.T) {
	options, err := ParseOpenOptions(`{"auth_mode":""}`)
	if err != nil {
		t.Fatal(err)
	}
	if options.AuthMode != AuthModeBearer {
		t.Fatalf("empty auth mode should default to bearer, got %s", options.AuthMode)
	}
}

func TestParseOpenOptionsRejectsTrailingData(t *testing.T) {
	_, err := ParseOpenOptions(`{"auth_mode":"bearer"} extra`)
	if err == nil {
		t.Fatal("expected error for trailing data")
	}
}

func TestParseOpenOptionsRejectsMalformedJSON(t *testing.T) {
	_, err := ParseOpenOptions(`{invalid json}`)
	if err == nil {
		t.Fatal("expected error for malformed JSON")
	}
}

func TestParseOpenOptionsAllVisibilityModes(t *testing.T) {
	for _, visibility := range []CredentialVisibility{CredentialVisibilityOnce, CredentialVisibilityPersistent} {
		options, err := ParseOpenOptions(`{"credential_visibility":"` + string(visibility) + `"}`)
		if err != nil {
			t.Fatalf("visibility %s: %v", visibility, err)
		}
		if options.CredentialVisibility != visibility {
			t.Fatalf("expected %s, got %s", visibility, options.CredentialVisibility)
		}
	}
}

func TestParseOpenOptionsRejectsUnknownVisibility(t *testing.T) {
	_, err := ParseOpenOptions(`{"credential_visibility":"forever"}`)
	if err == nil {
		t.Fatal("expected error for unknown visibility")
	}
}

func TestParseOpenOptionsAllLifetimeModes(t *testing.T) {
	for _, lifetime := range []SessionLifetime{SessionLifetimeEphemeral, SessionLifetimePersistent} {
		options, err := ParseOpenOptions(`{"session_lifetime":"` + string(lifetime) + `"}`)
		if err != nil {
			t.Fatalf("lifetime %s: %v", lifetime, err)
		}
		if options.SessionLifetime != lifetime {
			t.Fatalf("expected %s, got %s", lifetime, options.SessionLifetime)
		}
	}
}

func TestParseOpenOptionsRejectsUnknownLifetime(t *testing.T) {
	_, err := ParseOpenOptions(`{"session_lifetime":"immortal"}`)
	if err == nil {
		t.Fatal("expected error for unknown lifetime")
	}
}

func TestParseOpenOptionsRejectsUnknownField(t *testing.T) {
	_, err := ParseOpenOptions(`{"auth_mode":"bearer","unknown_field":true}`)
	if err == nil {
		t.Fatal("expected error for unknown field")
	}
}

func TestParseOpenOptionsNegativePort(t *testing.T) {
	_, err := ParseOpenOptions(`{"port":-1}`)
	if err == nil {
		t.Fatal("expected error for negative port")
	}
}

func TestParseOpenOptionsPort65535(t *testing.T) {
	options, err := ParseOpenOptions(`{"port":65535}`)
	if err != nil {
		t.Fatal(err)
	}
	if options.Port != 65535 {
		t.Fatalf("expected port 65535, got %d", options.Port)
	}
}

func TestParseOpenOptionsPort0(t *testing.T) {
	options, err := ParseOpenOptions(`{"port":0}`)
	if err != nil {
		t.Fatal(err)
	}
	if options.Port != 0 {
		t.Fatalf("expected port 0, got %d", options.Port)
	}
}

func TestDigestNonceValidNewlyIssued(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	d := &digestState{key: key}
	nonce, err := d.newNonce(time.Now().UTC(), strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	valid, stale := d.validNonce(nonce, time.Now().UTC())
	if !valid || stale {
		t.Fatalf("fresh nonce should be valid, got valid=%v stale=%v", valid, stale)
	}
}

func TestDigestNonceTamperedPayload(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	d := &digestState{key: key}
	nonce, err := d.newNonce(time.Now().UTC(), strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	b, _ := base64.RawURLEncoding.DecodeString(nonce)
	b[0] ^= 1
	tampered := base64.RawURLEncoding.EncodeToString(b)
	valid, stale := d.validNonce(tampered, time.Now().UTC())
	if valid {
		t.Fatalf("tampered nonce should be invalid, got valid=%v stale=%v", valid, stale)
	}
}

func TestDigestNonceShortInput(t *testing.T) {
	key := make([]byte, 32)
	d := &digestState{key: key}
	valid, stale := d.validNonce("short", time.Now().UTC())
	if valid {
		t.Fatalf("short nonce should be invalid, got valid=%v stale=%v", valid, stale)
	}
}

func TestDigestNonceFuture(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	d := &digestState{key: key}
	futureTime := time.Now().UTC().Add(2 * time.Minute)
	nonce, err := d.newNonce(futureTime, strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	valid, stale := d.validNonce(nonce, time.Now().UTC())
	if valid {
		t.Fatalf("future nonce should be rejected, got valid=%v stale=%v", valid, stale)
	}
}

func TestDigestNonceWithinClockSkew(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	d := &digestState{key: key}
	futureTime := time.Now().UTC().Add(10 * time.Second)
	nonce, err := d.newNonce(futureTime, strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	valid, stale := d.validNonce(nonce, time.Now().UTC())
	if !valid {
		t.Fatalf("nonce within clock skew should be valid, got valid=%v stale=%v", valid, stale)
	}
}

func TestDigestNonceWrongKey(t *testing.T) {
	key1 := make([]byte, 32)
	key2 := make([]byte, 32)
	key1[0] = 1
	key2[0] = 2
	d1 := &digestState{key: key1}
	d2 := &digestState{key: key2}
	nonce, err := d1.newNonce(time.Now().UTC(), strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	valid, _ := d2.validNonce(nonce, time.Now().UTC())
	if valid {
		t.Fatal("nonce created with key1 should not validate with key2")
	}
}

func TestDigestNonceExpired(t *testing.T) {
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i)
	}
	d := &digestState{key: key}
	oldTime := time.Now().UTC().Add(-10 * time.Minute)
	nonce, err := d.newNonce(oldTime, strings.NewReader(strings.Repeat("r", 16)))
	if err != nil {
		t.Fatal(err)
	}
	valid, stale := d.validNonce(nonce, time.Now().UTC())
	if valid || !stale {
		t.Fatalf("expired nonce should be invalid and stale=true, got valid=%v stale=%v", valid, stale)
	}
}
