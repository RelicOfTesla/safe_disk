package sec_webdav

import (
	"bytes"
	"sort"
	"time"
	"context"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"net/http"
	"os"
	"strings"
	"testing"
	"testing/fstest"
)

func TestListReportsGoOwnedMonitoringWithoutToken(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}}
	session, err := manager.Open("root-1", "Note", "note.txt", provider)
	if err != nil {
		t.Fatal(err)
	}

	statuses := manager.List("root-1")
	if len(statuses) != 1 || statuses[0].LastAccessedAt != nil ||
		statuses[0].ActiveRequests != 0 || !statuses[0].ReadOnly {
		t.Fatalf("initial status = %#v", statuses)
	}
	encoded, err := json.Marshal(statuses[0])
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), session.Token) ||
		strings.Contains(string(encoded), "token") {
		t.Fatalf("status leaked token: %s", encoded)
	}
	if got := manager.List("other-root"); len(got) != 0 {
		t.Fatalf("other root status = %#v", got)
	}

	response, err := http.DefaultClient.Do(
		authenticatedRequest(t, http.MethodGet, session.URL, session.Token),
	)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("read status = %d", response.StatusCode)
	}

	statuses = manager.List("root-1")
	if len(statuses) != 1 || statuses[0].LastAccessedAt == nil ||
		statuses[0].ActiveRequests != 0 {
		t.Fatalf("updated status = %#v", statuses)
	}
}

func TestCredentialVisibilityControlsRevealWithoutLeakingStatus(t *testing.T) {
	provider := mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}}
	manager := NewManager()
	defer manager.Close()

	once, err := manager.OpenWithOptions("root-once", "Note", "note.txt", provider, OpenOptions{
		AuthMode:             AuthModeBearer,
		CredentialVisibility: CredentialVisibilityOnce,
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Reveal(once.ID); !errors.Is(err, ErrCredentialsNotRevealable) {
		t.Fatalf("one-time reveal error = %v", err)
	}

	persistent, err := manager.OpenWithOptions("root-persistent", "Note", "note.txt", provider, OpenOptions{
		AuthMode:             AuthModeDigest,
		CredentialVisibility: CredentialVisibilityPersistent,
	})
	if err != nil {
		t.Fatal(err)
	}
	revealed, err := manager.Reveal(persistent.ID)
	if err != nil {
		t.Fatal(err)
	}
	if revealed.Password != persistent.Password ||
		revealed.CredentialVisibility != CredentialVisibilityPersistent {
		t.Fatalf("revealed session = %#v", revealed)
	}
	statusJSON, err := json.Marshal(manager.List("root-persistent")[0])
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{persistent.Username, persistent.Password, persistent.Realm} {
		if strings.Contains(string(statusJSON), secret) {
			t.Fatalf("status leaked credential %q: %s", secret, statusJSON)
		}
	}
}

func TestPersistentSessionRestoresWithStableIDPortAndCredentials(t *testing.T) {
	provider := mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}}
	store := &memoryPersistentStore{}
	manager := NewManagerWithPersistentStore(store)
	defer manager.Close()

	opened, err := manager.OpenWithOptions(
		"root-persistent", "Note", "note.txt", provider,
		OpenOptions{
			AuthMode:             AuthModeBearer,
			CredentialVisibility: CredentialVisibilityPersistent,
			SessionLifetime:      SessionLifetimePersistent,
		},
	)
	if err != nil {
		t.Fatal(err)
	}
	if opened.Port == 0 || len(store.records) != 1 {
		t.Fatalf("opened=%#v records=%#v", opened, store.records)
	}

	manager.RevokeRoot("root-persistent")
	if got := manager.List("root-persistent"); len(got) != 0 {
		t.Fatalf("sessions after root close = %#v", got)
	}
	if errors := manager.RestorePersistent("root-persistent", provider); len(errors) != 0 {
		t.Fatalf("restore errors = %v", errors)
	}
	statuses := manager.List("root-persistent")
	if len(statuses) != 1 || statuses[0].ID != opened.ID ||
		statuses[0].Port != opened.Port || statuses[0].SessionLifetime != SessionLifetimePersistent {
		t.Fatalf("restored statuses = %#v", statuses)
	}
	revealed, err := manager.Reveal(opened.ID)
	if err != nil || revealed.Token != opened.Token {
		t.Fatalf("restored credentials = %#v err=%v", revealed, err)
	}

	manager.Revoke(opened.ID)
	if len(store.records) != 0 {
		t.Fatalf("records after revoke = %#v", store.records)
	}
}

type memoryPersistentStore struct {
	records []PersistentSession
}

func (s *memoryPersistentStore) Load(string) ([]PersistentSession, error) {
	return append([]PersistentSession(nil), s.records...), nil
}

func (s *memoryPersistentStore) Save(_ string, records []PersistentSession) error {
	s.records = append([]PersistentSession(nil), records...)
	return nil
}

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

func TestThirdPartyHandlerPreservesReadOnlyContract(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"docs/readme.txt":      &fstest.MapFile{Data: []byte("hello")},
		"docs/nested/data.bin": &fstest.MapFile{Data: []byte{1, 2, 3}},
	}}
	session, err := manager.Open("root-1", "Documents", "docs", provider)
	if err != nil {
		t.Fatal(err)
	}

	options := authenticatedRequest(t, http.MethodOptions, session.URL, session.Token)
	response, err := http.DefaultClient.Do(options)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("options status = %d", response.StatusCode)
	}
	if response.Header.Get("DAV") != "1" || response.Header.Get("Allow") != methodAllowReadOnly {
		t.Fatalf("options headers = DAV %q Allow %q", response.Header.Get("DAV"), response.Header.Get("Allow"))
	}

	propfind := authenticatedRequest(t, "PROPFIND", session.URL, session.Token)
	propfind.Header.Set("Depth", "infinity")
	response, err = http.DefaultClient.Do(propfind)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusMultiStatus || !containsAll(string(body), "readme.txt", "nested", "data.bin") {
		t.Fatalf("infinite propfind response = %d %q", response.StatusCode, body)
	}

	for _, method := range []string{
		http.MethodPost,
		http.MethodPut,
		http.MethodDelete,
		"MKCOL",
		"COPY",
		"MOVE",
		"LOCK",
		"UNLOCK",
		"PROPPATCH",
	} {
		request := authenticatedRequest(t, method, session.URL+"readme.txt", session.Token)
		response, err := http.DefaultClient.Do(request)
		if err != nil {
			t.Fatalf("%s request: %v", method, err)
		}
		response.Body.Close()
		if response.StatusCode != http.StatusForbidden {
			t.Fatalf("%s status = %d", method, response.StatusCode)
		}
	}
}

func TestDavfsPropfindRequestShapeListsEscapedEntries(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"docs/中文 name.txt":      &fstest.MapFile{Data: []byte("hello")},
		"docs/sub dir/data.bin": &fstest.MapFile{Data: []byte{1, 2, 3}},
	}}
	session, err := manager.Open("root-davfs", "Documents", "docs", provider)
	if err != nil {
		t.Fatal(err)
	}

	options := authenticatedRequest(t, http.MethodOptions, session.URL, session.Token)
	options.Header.Set("User-Agent", "davfs2/1.7.0 neon/0.33")
	response, err := http.DefaultClient.Do(options)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusOK || response.Header.Get("DAV") != "1" {
		t.Fatalf("davfs options = status %d DAV %q", response.StatusCode, response.Header.Get("DAV"))
	}

	body := strings.NewReader(`<propfind xmlns="DAV:"><allprop/></propfind>`)
	propfind := authenticatedRequest(t, "PROPFIND", session.URL, session.Token)
	propfind.Body = io.NopCloser(body)
	propfind.ContentLength = int64(body.Len())
	propfind.Header.Set("Content-Type", "application/xml")
	propfind.Header.Set("Depth", "1")
	propfind.Header.Set("User-Agent", "davfs2/1.7.0 neon/0.33")
	response, err = http.DefaultClient.Do(propfind)
	if err != nil {
		t.Fatal(err)
	}
	data, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusMultiStatus {
		t.Fatalf("davfs propfind status = %d body = %q", response.StatusCode, data)
	}
	if !containsAll(string(data), "%E4%B8%AD%E6%96%87%20name.txt", "sub%20dir") {
		t.Fatalf("davfs propfind hrefs are not escaped: %s", data)
	}
}

func TestSecureFileSystemDirectoryAdapterUsesProviderEntries(t *testing.T) {
	provider := mapProvider{files: fstest.MapFS{
		"docs/readme.txt": &fstest.MapFile{Data: []byte("hello")},
	}}
	fileSystem := newSecureFileSystem(provider, "docs", WritePolicyReadOnly)
	file, err := fileSystem.OpenFile(context.Background(), "/", os.O_RDONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	entries, err := file.Readdir(-1)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Name() != "readme.txt" {
		t.Fatalf("directory entries = %#v", entries)
	}
	if _, err := fileSystem.OpenFile(context.Background(), "/readme.txt", os.O_RDWR, 0); err != errWebDAVReadOnly {
		t.Fatalf("write open error = %v", err)
	}
	if _, err := fileSystem.Stat(context.Background(), "/../outside"); err != ErrInvalidPath {
		t.Fatalf("escape stat error = %v", err)
	}
}

func TestDigestAuthenticationUsesSHA256AndRejectsReplay(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	provider := mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}}
	session, err := manager.OpenWithOptions(
		"root-1",
		"Note",
		"note.txt",
		provider,
		OpenOptions{AuthMode: AuthModeDigest},
	)
	if err != nil {
		t.Fatal(err)
	}
	if session.AuthMode != AuthModeDigest || session.Token != "" || session.Username == "" || session.Password == "" || session.Realm == "" {
		t.Fatalf("digest session credentials = %#v", session)
	}

	request := authenticatedRequest(t, http.MethodGet, session.URL, "wrong-token")
	request.Header.Del("Authorization")
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("digest challenge status = %d", response.StatusCode)
	}
	challenge, err := parseDigestAuthorization(response.Header.Get("WWW-Authenticate"))
	if err != nil {
		t.Fatal(err)
	}
	if challenge["algorithm"] != "SHA-256" || challenge["qop"] != "auth" || challenge["realm"] != session.Realm {
		t.Fatalf("digest challenge = %#v", challenge)
	}

	request = newDigestRequest(t, http.MethodGet, session.URL, session, challenge["nonce"], "00000001", "client-1")
	response, err = http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	response.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK || string(body) != "private" {
		t.Fatalf("digest read response = %d %q", response.StatusCode, body)
	}

	request = newDigestRequest(t, http.MethodGet, session.URL, session, challenge["nonce"], "00000001", "client-1")
	response, err = http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("replayed digest status = %d", response.StatusCode)
	}

	request = newDigestRequest(t, http.MethodGet, session.URL, session, challenge["nonce"], "00000002", "client-1")
	request.Header.Set("Authorization", strings.Replace(request.Header.Get("Authorization"), "algorithm=SHA-256", "algorithm=MD5", 1))
	response, err = http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusUnauthorized {
		t.Fatalf("md5 digest status = %d", response.StatusCode)
	}

	encoded, err := json.Marshal(manager.List("root-1")[0])
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{session.Username, session.Password, session.Realm, challenge["nonce"]} {
		if strings.Contains(string(encoded), secret) {
			t.Fatalf("digest status leaked %q: %s", secret, encoded)
		}
	}
}

func TestBearerSystemMountIsRejectedWithoutACompatibleCredentialAdapter(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	session, err := manager.Open("root-1", "Note", "note.txt", mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Mount(context.Background(), session.ID); !errors.Is(err, ErrMountUnsupported) {
		t.Fatalf("bearer mount error = %v", err)
	}
	if status := manager.List("root-1")[0]; status.Mounted {
		t.Fatalf("failed mount reported as mounted: %#v", status)
	}
}

func TestManagerUnmountDetachesSuccessfulMount(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	session, err := manager.Open("root-1", "Note", "note.txt", mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}})
	if err != nil {
		t.Fatal(err)
	}
	called := false
	mounted := &MountedSession{
		path: "/tmp/test-webdav-mount",
		unmount: func(context.Context) error {
			called = true
			return nil
		},
	}
	manager.mu.Lock()
	active := manager.sessions[session.ID]
	active.mounted = mounted
	manager.sessions[session.ID] = active
	manager.mu.Unlock()

	if err := manager.Unmount(context.Background(), session.ID); err != nil {
		t.Fatal(err)
	}
	if !called {
		t.Fatal("mount was not unmounted")
	}
	if status := manager.List("root-1")[0]; status.Mounted {
		t.Fatalf("successful unmount remained mounted: %#v", status)
	}
}

func TestManagerUnmountKeepsFailedMountVisible(t *testing.T) {
	manager := NewManager()
	defer manager.Close()
	session, err := manager.Open("root-1", "Note", "note.txt", mapProvider{files: fstest.MapFS{
		"note.txt": &fstest.MapFile{Data: []byte("private")},
	}})
	if err != nil {
		t.Fatal(err)
	}
	mounted := &MountedSession{
		path: "/tmp/test-webdav-mount",
		unmount: func(context.Context) error {
			return ErrMountFailed
		},
	}
	manager.mu.Lock()
	active := manager.sessions[session.ID]
	active.mounted = mounted
	manager.sessions[session.ID] = active
	manager.mu.Unlock()

	if err := manager.Unmount(context.Background(), session.ID); !errors.Is(err, ErrMountFailed) {
		t.Fatalf("unmount error = %v", err)
	}
	if status := manager.List("root-1")[0]; !status.Mounted {
		t.Fatalf("failed unmount was hidden: %#v", status)
	}
}

func newDigestRequest(t *testing.T, method, rawURL string, session Session, nonce, nonceCount, cnonce string) *http.Request {
	t.Helper()
	request, err := http.NewRequest(method, rawURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	uri := request.URL.RequestURI()
	ha1 := digestHash(session.Username + ":" + session.Realm + ":" + session.Password)
	ha2 := digestHash(method + ":" + uri)
	response := digestHash(ha1 + ":" + nonce + ":" + nonceCount + ":" + cnonce + ":auth:" + ha2)
	request.Header.Set("Authorization", `Digest username="`+session.Username+`", realm="`+session.Realm+`", nonce="`+nonce+`", uri="`+uri+`", algorithm=SHA-256, qop=auth, nc=`+nonceCount+`, cnonce="`+cnonce+`", response="`+response+`"`)
	return request
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

func (p mapProvider) Mkdir(path string) error {
	return errors.New("mapProvider Mkdir not implemented in test")
}

func (p mapProvider) Create(path string) (io.WriteCloser, error) {
	return nil, errors.New("mapProvider Create not implemented in test")
}

func (p mapProvider) RemoveAll(path string) error {
	return errors.New("mapProvider RemoveAll not implemented in test")
}

func (p mapProvider) Rename(oldPath, newPath string) error {
	return errors.New("mapProvider Rename not implemented in test")
}

// ── Write-operation test provider ──────────────────────────────────

// rwMapProvider supports read/write for testing WebDAV write operations.
type rwMapProvider struct {
	files map[string][]byte
	dirs  map[string]bool
}

func newRWMapProvider() *rwMapProvider {
	return &rwMapProvider{
		files: map[string][]byte{},
		dirs:  map[string]bool{".": true},
	}
}

func (p *rwMapProvider) Stat(path string) (fs.FileInfo, error) {
	content, ok := p.files[path]
	if ok {
		return &rwFileInfo{name: path, size: int64(len(content)), isDir: false}, nil
	}
	if p.dirs[path] {
		return &rwFileInfo{name: path, size: 0, isDir: true}, nil
	}
	return nil, os.ErrNotExist
}

func (p *rwMapProvider) ReadDir(path string) ([]fs.DirEntry, error) {
	if !p.dirs[path] {
		return nil, os.ErrInvalid
	}
	prefix := path
	if prefix != "." {
		prefix += "/"
	} else {
		prefix = ""
	}
	var entries []fs.DirEntry
	seen := map[string]bool{}
	for name := range p.files {
		if strings.HasPrefix(name, prefix) {
			suffix := name[len(prefix):]
			if strings.Contains(suffix, "/") {
				continue
			}
			if seen[suffix] {
				continue
			}
			seen[suffix] = true
			entries = append(entries, &rwDirEntry{name: suffix, isDir: false})
		}
	}
	for name := range p.dirs {
		if name == path {
			continue
		}
		if strings.HasPrefix(name, prefix) {
			suffix := name[len(prefix):]
			if strings.Contains(suffix, "/") {
				continue
			}
			if seen[suffix] {
				continue
			}
			seen[suffix] = true
			entries = append(entries, &rwDirEntry{name: suffix, isDir: true})
		}
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	return entries, nil
}

func (p *rwMapProvider) Open(path string) (io.ReadCloser, fs.FileInfo, error) {
	content, ok := p.files[path]
	if !ok {
		return nil, nil, os.ErrNotExist
	}
	return io.NopCloser(bytes.NewReader(content)), &rwFileInfo{name: path, size: int64(len(content)), isDir: false}, nil
}

func (p *rwMapProvider) Mkdir(path string) error {
	if _, ok := p.files[path]; ok {
		return os.ErrExist
	}
	p.dirs[path] = true
	return nil
}

func (p *rwMapProvider) Create(path string) (io.WriteCloser, error) {
	if p.dirs[path] {
		return nil, os.ErrExist
	}
	buf := &bytes.Buffer{}
	p.files[path] = nil
	return &writeCloser{buf: buf, onClose: func() { p.files[path] = buf.Bytes() }}, nil
}

func (p *rwMapProvider) RemoveAll(path string) error {
	delete(p.files, path)
	delete(p.dirs, path)
	for name := range p.files {
		if strings.HasPrefix(name, path+"/") {
			delete(p.files, name)
		}
	}
	for name := range p.dirs {
		if strings.HasPrefix(name, path+"/") {
			delete(p.dirs, name)
		}
	}
	return nil
}

func (p *rwMapProvider) Rename(oldPath, newPath string) error {
	if content, ok := p.files[oldPath]; ok {
		p.files[newPath] = content
		delete(p.files, oldPath)
		return nil
	}
	if p.dirs[oldPath] {
		p.dirs[newPath] = true
		delete(p.dirs, oldPath)
		return nil
	}
	return os.ErrNotExist
}

type rwFileInfo struct {
	name  string
	size  int64
	isDir bool
}

func (f *rwFileInfo) Name() string       { return f.name }
func (f *rwFileInfo) Size() int64        { return f.size }
func (f *rwFileInfo) Mode() os.FileMode  { return 0o644 }
func (f *rwFileInfo) ModTime() time.Time { return time.Time{} }
func (f *rwFileInfo) IsDir() bool        { return f.isDir }
func (f *rwFileInfo) Sys() interface{}   { return nil }

type rwDirEntry struct {
	name  string
	isDir bool
}

func (e *rwDirEntry) Name() string              { return e.name }
func (e *rwDirEntry) IsDir() bool               { return e.isDir }
func (e *rwDirEntry) Type() os.FileMode         { return 0 }
func (e *rwDirEntry) Info() (fs.FileInfo, error) { return nil, nil }

type writeCloser struct {
	buf     *bytes.Buffer
	onClose func()
}

func (w *writeCloser) Write(p []byte) (int, error) { return w.buf.Write(p) }
func (w *writeCloser) Close() error                 { w.onClose(); return nil }

// ── Write operation tests ──────────────────────────────────────────

func TestWritePolicyReadOnlyRejectsMkdir(t *testing.T) {
	provider := newRWMapProvider()
	fs := newSecureFileSystem(provider, "", WritePolicyReadOnly)
	if err := fs.Mkdir(context.Background(), "/newdir", 0); err != errWebDAVReadOnly {
		t.Fatalf("Mkdir error = %v, want %v", err, errWebDAVReadOnly)
	}
}

func TestWritePolicyReadOnlyRejectsCreate(t *testing.T) {
	provider := newRWMapProvider()
	fs := newSecureFileSystem(provider, "", WritePolicyReadOnly)
	_, err := fs.OpenFile(context.Background(), "/newfile", os.O_RDWR|os.O_CREATE, 0)
	if err != errWebDAVReadOnly {
		t.Fatalf("OpenFile(CREATE) error = %v, want %v", err, errWebDAVReadOnly)
	}
}

func TestWritePolicyReadOnlyRejectsRemoveAll(t *testing.T) {
	provider := newRWMapProvider()
	_ = provider.Mkdir("existing")
	fs := newSecureFileSystem(provider, "", WritePolicyReadOnly)
	if err := fs.RemoveAll(context.Background(), "/existing"); err != errWebDAVReadOnly {
		t.Fatalf("RemoveAll error = %v, want %v", err, errWebDAVReadOnly)
	}
}

func TestWritePolicyReadOnlyRejectsRename(t *testing.T) {
	provider := newRWMapProvider()
	_ = provider.Mkdir("old")
	fs := newSecureFileSystem(provider, "", WritePolicyReadOnly)
	if err := fs.Rename(context.Background(), "/old", "/new"); err != errWebDAVReadOnly {
		t.Fatalf("Rename error = %v, want %v", err, errWebDAVReadOnly)
	}
}
