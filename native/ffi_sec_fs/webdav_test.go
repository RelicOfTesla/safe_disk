package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
)

func TestWebDavFFIExposesAndRevokesOpenedRoot(t *testing.T) {
	rootPath := t.TempDir() + "/root"
	assertSuccess(t, CreateRootConfig_FFI(
		rootPath,
		"pw",
		`{"dataFactory":"AES-CTR","nameFactory":"None"}`,
	))
	opened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(opened["data"].(map[string]interface{})["root_id"].(float64))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "hello.txt", []byte("hello from ffi")))

	session := assertSuccess(t, WebDavOpen_FFI(rootID, "", "root"))
	data := session["data"].(map[string]interface{})
	request, err := http.NewRequest(http.MethodGet, data["url"].(string)+"hello.txt", nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer "+data["token"].(string))
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK || string(body) != "hello from ffi" {
		t.Fatalf("webdav response = %d %q", response.StatusCode, body)
	}

	assertSuccess(t, CloseRoot_FFI(rootID))
	request, err = http.NewRequest(http.MethodGet, data["url"].(string)+"hello.txt", nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer "+data["token"].(string))
	if response, err := http.DefaultClient.Do(request); err == nil {
		response.Body.Close()
		t.Fatalf("revoked WebDAV request unexpectedly succeeded with %d", response.StatusCode)
	}
}

func TestWebDavFFIListsTokenFreeRootScopedState(t *testing.T) {
	rootPath := t.TempDir() + "/root"
	assertSuccess(t, CreateRootConfig_FFI(
		rootPath,
		"pw",
		`{"dataFactory":"AES-CTR","nameFactory":"None"}`,
	))
	opened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(opened["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)
	assertSuccess(t, QuickWriteFile_FFI(rootID, "note.txt", []byte("content")))
	openedSession := assertSuccess(t, WebDavOpen_FFI(rootID, "note.txt", "Note"))
	token := openedSession["data"].(map[string]interface{})["token"].(string)

	listed := assertSuccess(t, WebDavList_FFI(rootID))
	entries := listed["data"].([]interface{})
	if len(entries) != 1 {
		t.Fatalf("listed sessions = %#v", entries)
	}
	entry := entries[0].(map[string]interface{})
	if _, found := entry["token"]; found {
		t.Fatalf("list leaked token: %#v", entry)
	}
	if entry["read_only"] != true || entry["exposed_path"] != "note.txt" {
		t.Fatalf("listed session = %#v", entry)
	}
	if token == "" {
		t.Fatal("open did not return token")
	}
}

func TestWebDavFFIOpensDigestSession(t *testing.T) {
	rootPath := t.TempDir() + "/root"
	assertSuccess(t, CreateRootConfig_FFI(
		rootPath,
		"pw",
		`{"dataFactory":"AES-CTR","nameFactory":"None"}`,
	))
	opened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(opened["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)
	assertSuccess(t, QuickWriteFile_FFI(rootID, "note.txt", []byte("digest ffi")))

	openedSession := assertSuccess(t, WebDavOpenWithOptions_FFI(rootID, "note.txt", "Note", `{"auth_mode":"digest"}`))
	data := openedSession["data"].(map[string]interface{})
	if data["auth_mode"] != "digest" || data["token"] != nil {
		t.Fatalf("unexpected digest session = %#v", data)
	}
	url := data["url"].(string)
	request, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("digest challenge status = %d", response.StatusCode)
	}
	nonce := digestChallengeValue(response.Header.Get("WWW-Authenticate"), "nonce")
	realm := digestChallengeValue(response.Header.Get("WWW-Authenticate"), "realm")
	username := data["username"].(string)
	password := data["password"].(string)
	uri := request.URL.RequestURI()
	nc := "00000001"
	cnonce := "ffi-client"
	ha1 := testDigestHash(username + ":" + realm + ":" + password)
	ha2 := testDigestHash(http.MethodGet + ":" + uri)
	digestResponse := testDigestHash(ha1 + ":" + nonce + ":" + nc + ":" + cnonce + ":auth:" + ha2)
	request.Header.Set("Authorization", `Digest username="`+username+`", realm="`+realm+`", nonce="`+nonce+`", uri="`+uri+`", algorithm=SHA-256, qop=auth, nc=`+nc+`, cnonce="`+cnonce+`", response="`+digestResponse+`"`)
	response, err = http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK || string(body) != "digest ffi" {
		t.Fatalf("digest ffi response = %d %q", response.StatusCode, body)
	}

	listed := assertSuccess(t, WebDavList_FFI(rootID))
	entry := listed["data"].([]interface{})[0].(map[string]interface{})
	if entry["auth_mode"] != "digest" {
		t.Fatalf("digest status = %#v", entry)
	}
	for _, secret := range []string{username, password, realm, nonce} {
		if strings.Contains(stringifyForTest(entry), secret) {
			t.Fatalf("digest status leaked %q: %#v", secret, entry)
		}
	}
}

func TestWebDavFFIRevealsOnlyPersistentCredentials(t *testing.T) {
	rootPath := t.TempDir() + "/root"
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
	opened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(opened["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(rootID)
	assertSuccess(t, QuickWriteFile_FFI(rootID, "note.txt", []byte("persistent credentials")))

	once := assertSuccess(t, WebDavOpenWithOptions_FFI(rootID, "note.txt", "Once", `{"auth_mode":"bearer","credential_visibility":"once"}`))
	onceID := once["data"].(map[string]interface{})["id"].(string)
	if response := WebDavReveal_FFI(onceID); jsonSuccess(response) {
		t.Fatal("one-time credentials were revealed")
	}

	persistent := assertSuccess(t, WebDavOpenWithOptions_FFI(rootID, "note.txt", "Persistent", `{"auth_mode":"digest","credential_visibility":"persistent"}`))
	persistentID := persistent["data"].(map[string]interface{})["id"].(string)
	revealed := assertSuccess(t, WebDavReveal_FFI(persistentID))["data"].(map[string]interface{})
	if revealed["password"] != persistent["data"].(map[string]interface{})["password"] {
		t.Fatalf("revealed credentials mismatch: %#v", revealed)
	}
	status := assertSuccess(t, WebDavList_FFI(rootID))["data"].([]interface{})
	if strings.Contains(stringifyForTest(status), persistent["data"].(map[string]interface{})["password"].(string)) {
		t.Fatal("status leaked persistent password")
	}
}

func TestWebDavFFIPersistentSessionSurvivesRootReopen(t *testing.T) {
	rootPath := t.TempDir() + "/root"
	assertSuccess(t, CreateRootConfig_FFI(rootPath, "pw", `{"dataFactory":"AES-CTR","nameFactory":"None"}`))
	opened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	rootID := int64(opened["data"].(map[string]interface{})["root_id"].(float64))
	assertSuccess(t, QuickWriteFile_FFI(rootID, "note.txt", []byte("persistent")))
	first := assertSuccess(t, WebDavOpenWithOptions_FFI(
		rootID,
		"note.txt",
		"Persistent note",
		`{"auth_mode":"bearer","credential_visibility":"persistent","session_lifetime":"persistent"}`,
	))
	firstData := first["data"].(map[string]interface{})
	firstID := firstData["id"].(string)
	firstURL := firstData["url"].(string)
	assertSuccess(t, CloseRoot_FFI(rootID))

	reopened := assertSuccess(t, OpenRoot_FFI(rootPath, "pw", ""))
	newRootID := int64(reopened["data"].(map[string]interface{})["root_id"].(float64))
	defer CloseRoot_FFI(newRootID)
	if warnings := reopened["data"].(map[string]interface{})["webdav_restore_errors"]; warnings != nil {
		t.Fatalf("persistent restore warnings = %#v", warnings)
	}
	listed := assertSuccess(t, WebDavList_FFI(newRootID))["data"].([]interface{})
	if len(listed) != 1 {
		t.Fatalf("restored sessions = %#v", listed)
	}
	restored := listed[0].(map[string]interface{})
	if restored["id"] != firstID || restored["url"] != firstURL || restored["session_lifetime"] != "persistent" {
		t.Fatalf("restored session = %#v, original=%#v", restored, firstData)
	}
	revealed := assertSuccess(t, WebDavReveal_FFI(firstID))["data"].(map[string]interface{})
	if revealed["token"] != firstData["token"] {
		t.Fatalf("restored token = %#v, original=%#v", revealed["token"], firstData["token"])
	}
	assertSuccess(t, WebDavClose_FFI(firstID))
	if sessions := assertSuccess(t, WebDavList_FFI(newRootID))["data"].([]interface{}); len(sessions) != 0 {
		t.Fatalf("sessions after explicit revoke = %#v", sessions)
	}
}

func digestChallengeValue(challenge, key string) string {
	marker := key + `="`
	start := strings.Index(challenge, marker)
	if start < 0 {
		return ""
	}
	start += len(marker)
	end := strings.IndexByte(challenge[start:], '"')
	if end < 0 {
		return ""
	}
	return challenge[start : start+end]
}

func testDigestHash(value string) string {
	sum := sha256.Sum256([]byte(value))
	return hex.EncodeToString(sum[:])
}

func stringifyForTest(value interface{}) string {
	return fmt.Sprintf("%#v", value)
}
