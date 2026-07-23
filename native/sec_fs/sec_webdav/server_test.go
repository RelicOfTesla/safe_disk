package sec_webdav

import (
	"io"
	"io/fs"
	"net/http"
	"strings"
	"testing"
	"testing/fstest"
)

func TestReadOnlySessionScopesAndRevokesAccess(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"docs/readme.txt":      &fstest.MapFile{Data: []byte("hello")},
		"docs/nested/data.bin": &fstest.MapFile{Data: []byte{1, 2, 3}},
		"secret.txt":           &fstest.MapFile{Data: []byte("outside")},
	}}
	session, err := manager.Open("root-1", "Documents", "docs", provider)
	if err != nil {
		t.Fatal(err)
	}

	client := &http.Client{}
	request, err := http.NewRequest(http.MethodGet, session.URL+"readme.txt", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusUnauthorized {
		response.Body.Close()
		t.Fatalf("unauthorized status = %d", response.StatusCode)
	}
	response.Body.Close()

	request = authenticatedRequest(t, http.MethodGet, session.URL+"readme.txt", session.Token)
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	data, readErr := io.ReadAll(response.Body)
	response.Body.Close()
	if readErr != nil {
		t.Fatal(readErr)
	}
	if response.StatusCode != http.StatusOK || string(data) != "hello" {
		t.Fatalf("read response = %d %q", response.StatusCode, data)
	}

	request = authenticatedRequest(t, "PROPFIND", session.URL, session.Token)
	request.Header.Set("Depth", "1")
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	body, readErr := io.ReadAll(response.Body)
	response.Body.Close()
	if readErr != nil {
		t.Fatal(readErr)
	}
	if response.StatusCode != 207 || string(body) == "" {
		t.Fatalf("propfind response = %d %q", response.StatusCode, body)
	}
	if string(body) == "" || !containsAll(string(body), "readme.txt", "nested") {
		t.Fatalf("propfind body does not list scoped entries: %s", body)
	}

	request = authenticatedRequest(t, http.MethodGet, session.URL+"../secret.txt", session.Token)
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusBadRequest {
		t.Fatalf("traversal status = %d", response.StatusCode)
	}

	request = authenticatedRequest(t, http.MethodPut, session.URL+"readme.txt", session.Token)
	response, err = client.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusForbidden {
		t.Fatalf("write status = %d", response.StatusCode)
	}

	manager.RevokeRoot("root-1")
	request = authenticatedRequest(t, http.MethodGet, session.URL+"readme.txt", session.Token)
	response, err = client.Do(request)
	if err != nil {
		// The manager closes its idle listener, so a connection failure is also
		// an acceptable revocation result.
		return
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("revoked status = %d", response.StatusCode)
	}
}

func TestOpenRejectsInvalidScope(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"docs/readme.txt": &fstest.MapFile{Data: []byte("hello")},
	}}
	for _, scope := range []string{"../docs", "docs/../secret", `docs\\secret`} {
		if _, err := manager.Open("root-1", "", scope, provider); err != ErrInvalidPath {
			t.Fatalf("scope %q error = %v", scope, err)
		}
	}
}

func authenticatedRequest(t *testing.T, method, rawURL, token string) *http.Request {
	t.Helper()
	request, err := http.NewRequest(method, rawURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Authorization", "Bearer "+token)
	return request
}

func containsAll(value string, parts ...string) bool {
	for _, part := range parts {
		if !strings.Contains(value, part) {
			return false
		}
	}
	return true
}

type mapProvider struct {
	files fstest.MapFS
}

func (p mapProvider) Stat(path string) (fs.FileInfo, error) {
	if path == "" {
		path = "."
	}
	return fs.Stat(p.files, path)
}

func (p mapProvider) ReadDir(path string) ([]fs.DirEntry, error) {
	if path == "" {
		path = "."
	}
	return fs.ReadDir(p.files, path)
}

func (p mapProvider) Open(path string) (io.ReadCloser, fs.FileInfo, error) {
	if path == "" {
		path = "."
	}
	file, err := p.files.Open(path)
	if err != nil {
		return nil, nil, err
	}
	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, nil, err
	}
	return file, info, nil
}
