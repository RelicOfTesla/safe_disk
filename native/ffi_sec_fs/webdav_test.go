package main

import (
	"io"
	"net/http"
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
