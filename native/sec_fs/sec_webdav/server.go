// Package sec_webdav exposes an explicitly selected secure subtree through a
// revocable, read-only loopback WebDAV session.
package sec_webdav

import (
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"path"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/webdav"
)

var (
	ErrInvalidRootKey             = errors.New("webdav root key is empty")
	ErrInvalidPath                = errors.New("webdav path is invalid")
	ErrSessionClosed              = errors.New("webdav session is closed")
	ErrPersistentStoreUnavailable = errors.New("webdav persistent store is unavailable")
	ErrPersistentRecordInvalid    = errors.New("webdav persistent record is invalid")
	ErrPersistentPortConflict     = errors.New("webdav persistent port conflicts with the active server")
)

const methodAllowReadOnly = "OPTIONS, GET, HEAD, PROPFIND"
const methodAllowReadWrite = "OPTIONS, GET, HEAD, PROPFIND, PUT, DELETE, MKCOL, MOVE, COPY"

// ResourceProvider is deliberately smaller than sec_fs.ISecRoot. The FFI
// layer adapts an already-open secure root to this interface.
type ResourceProvider interface {
	Stat(path string) (fs.FileInfo, error)
	ReadDir(path string) ([]fs.DirEntry, error)
	Open(path string) (io.ReadCloser, fs.FileInfo, error)

	// Write methods for WebDAV PUT/DELETE/MKCOL/MOVE support.
	Mkdir(path string) error
	Create(path string) (io.WriteCloser, error)
	RemoveAll(path string) error
	Rename(oldPath, newPath string) error
}

type Session struct {
	ID                   string               `json:"id"`
	RootKey              string               `json:"-"`
	Token                string               `json:"token,omitempty"`
	AuthMode             AuthMode             `json:"auth_mode"`
	Username             string               `json:"username,omitempty"`
	Password             string               `json:"password,omitempty"`
	Realm                string               `json:"realm,omitempty"`
	URL                  string               `json:"url"`
	DisplayName          string               `json:"display_name"`
	ExposedPath          string               `json:"exposed_path"`
	ReadOnly             bool                 `json:"read_only,omitempty"`
	WritePolicy          WritePolicy          `json:"write_policy,omitempty"`
	CredentialVisibility CredentialVisibility `json:"credential_visibility"`
	SessionLifetime      SessionLifetime      `json:"session_lifetime"`
	Port                 int                  `json:"port"`
	TLS                  bool                 `json:"tls"`
}

// PersistentSession is stored inside an already encrypted root. It never
// contains the root password; DigestKey only preserves the WebDAV nonce key.
type PersistentSession struct {
	Version              int                  `json:"version"`
	ID                   string               `json:"id"`
	RootKey              string               `json:"root_key"`
	Token                string               `json:"token,omitempty"`
	AuthMode             AuthMode             `json:"auth_mode"`
	Username             string               `json:"username,omitempty"`
	Password             string               `json:"password,omitempty"`
	Realm                string               `json:"realm,omitempty"`
	DigestKey            string               `json:"digest_key,omitempty"`
	BasicAuthUsername    string               `json:"basic_auth_username,omitempty"`
	BasicAuthPassword    string               `json:"basic_auth_password,omitempty"`
	DisplayName          string               `json:"display_name"`
	ExposedPath          string               `json:"exposed_path"`
	CredentialVisibility CredentialVisibility `json:"credential_visibility"`
	SessionLifetime      SessionLifetime      `json:"session_lifetime"`
	Port                 int                  `json:"port"`
	TLS                  bool                 `json:"tls"`
	ReadOnly             bool                 `json:"read_only,omitempty"`
	WritePolicy          WritePolicy          `json:"write_policy,omitempty"`
}

type PersistentStore interface {
	Load(rootKey string) ([]PersistentSession, error)
	Save(rootKey string, sessions []PersistentSession) error
}

type activeSession struct {
	session        Session
	provider       ResourceProvider
	handler        *webdav.Handler
	auth           authState
	mounted        *MountedSession
	lastAccessedAt *time.Time
	activeRequests int
}

// SessionStatus is safe to render outside the native process. It deliberately
// excludes the bearer token, which is returned only when a session is opened.
type SessionStatus struct {
	ID                   string               `json:"id"`
	DisplayName          string               `json:"display_name"`
	ExposedPath          string               `json:"exposed_path"`
	URL                  string               `json:"url"`
	ReadOnly             bool                 `json:"read_only,omitempty"`
	WritePolicy          WritePolicy          `json:"write_policy,omitempty"`
	AuthMode             AuthMode             `json:"auth_mode"`
	LastAccessedAt       *time.Time           `json:"last_accessed_at"`
	ActiveRequests       int                  `json:"active_requests"`
	Mounted              bool                 `json:"mounted"`
	MountPath            string               `json:"mount_path,omitempty"`
	CredentialVisibility CredentialVisibility `json:"credential_visibility"`
	SessionLifetime      SessionLifetime      `json:"session_lifetime"`
	Port                 int                  `json:"port"`
	TLS                  bool                 `json:"tls"`
}

// listenerState holds an HTTP server for one scheme (HTTP or HTTPS).
// HTTP and HTTPS sessions share the same handler (Manager.handle) but run on
// independent listeners so that the TLS checkbox in the UI actually controls
// the URL scheme instead of being silently overridden by a shared state.
type listenerState struct {
	server    *http.Server
	listener  net.Listener
	serveDone chan struct{}
	port      int
}

type Manager struct {
	mu              sync.Mutex
	random          io.Reader
	httpState       *listenerState
	httpsState      *listenerState
	sessions        map[string]activeSession
	persistentStore PersistentStore
}

func NewManager() *Manager {
	return &Manager{
		random:   rand.Reader,
		sessions: make(map[string]activeSession),
	}
}

func NewManagerWithPersistentStore(store PersistentStore) *Manager {
	manager := NewManager()
	manager.persistentStore = store
	return manager
}

func (m *Manager) Open(rootKey, displayName, exposedPath string, provider ResourceProvider) (Session, error) {
	return m.OpenWithOptions(rootKey, displayName, exposedPath, provider, OpenOptions{AuthMode: AuthModeBearer})
}

func (m *Manager) OpenWithOptions(rootKey, displayName, exposedPath string, provider ResourceProvider, options OpenOptions) (Session, error) {
	var err error
	options, err = normalizeOpenOptions(options)
	if err != nil {
		return Session{}, err
	}
	if strings.TrimSpace(rootKey) == "" {
		return Session{}, ErrInvalidRootKey
	}
	if provider == nil {
		return Session{}, errors.New("webdav provider is nil")
	}
	cleanPath, err := cleanRelativePath(exposedPath)
	if err != nil {
		return Session{}, err
	}
	if _, err := provider.Stat(cleanPath); err != nil {
		return Session{}, err
	}

	m.mu.Lock()
	defer m.mu.Unlock()
	if options.SessionLifetime == SessionLifetimePersistent && m.persistentStore == nil {
		return Session{}, ErrPersistentStoreUnavailable
	}
	state, err := m.ensureServerLocked(options.TLS, options.Port)
	if err != nil {
		return Session{}, err
	}
	id, err := m.newValueLocked(18)
	if err != nil {
		return Session{}, err
	}
	auth, err := m.newAuthLocked(options.AuthMode)
	if err != nil {
		return Session{}, err
	}
	session := Session{
		ID:                   id,
		RootKey:              rootKey,
		Token:                auth.token,
		AuthMode:             auth.mode,
		Username:             auth.username,
		Password:             auth.password,
		Realm:                auth.realm,
		URL:                  webdavURLScheme(options.TLS) + state.listener.Addr().String() + "/webdav/" + id + "/",
		DisplayName:          displayName,
		ExposedPath:          cleanPath,
		ReadOnly:             options.WritePolicy == WritePolicyReadOnly,
		CredentialVisibility: options.CredentialVisibility,
		SessionLifetime:      options.SessionLifetime,
		Port:                 state.port,
		TLS:                  options.TLS,
	}
	active := m.newActiveSession(session, auth, provider)
	if options.SessionLifetime == SessionLifetimePersistent {
		if err := m.savePersistentLocked(active); err != nil {
			m.stopIfIdleLocked()
			return Session{}, err
		}
	}
	m.sessions[id] = active
	return session, nil
}

func (m *Manager) newActiveSession(session Session, auth authState, provider ResourceProvider) activeSession {
	return activeSession{
		session:  session,
		auth:     auth,
		provider: provider,
		handler: &webdav.Handler{
			Prefix:     "/webdav/" + session.ID,
			FileSystem: newSecureFileSystem(provider, session.ExposedPath, session.WritePolicy),
			LockSystem: webdav.NewMemLS(),
		},
	}
}

func persistentRecordFromActive(active activeSession) PersistentSession {
	record := PersistentSession{
		Version:              1,
		ID:                   active.session.ID,
		RootKey:              active.session.RootKey,
		Token:                active.session.Token,
		AuthMode:             active.session.AuthMode,
		Username:             active.session.Username,
		Password:             active.session.Password,
		Realm:                active.session.Realm,
		DisplayName:          active.session.DisplayName,
		ExposedPath:          active.session.ExposedPath,
		CredentialVisibility: active.session.CredentialVisibility,
		SessionLifetime:      active.session.SessionLifetime,
		Port:                 active.session.Port,
		TLS:                  active.session.TLS,
	}
	if active.auth.digest != nil {
		record.DigestKey = hex.EncodeToString(active.auth.digest.key)
	}
	if active.auth.mode == AuthModeBasic {
		record.BasicAuthUsername = active.auth.basicUsername
		record.BasicAuthPassword = active.auth.basicPassword
	}
	return record
}

func (m *Manager) savePersistentLocked(active activeSession) error {
	if m.persistentStore == nil {
		return ErrPersistentStoreUnavailable
	}
	record := persistentRecordFromActive(active)
	records, err := m.persistentStore.Load(record.RootKey)
	if err != nil {
		return err
	}
	replaced := false
	for index := range records {
		if records[index].ID == record.ID {
			records[index] = record
			replaced = true
			break
		}
	}
	if !replaced {
		records = append(records, record)
	}
	return m.persistentStore.Save(record.RootKey, records)
}

func (m *Manager) deletePersistentLocked(rootKey, id string) error {
	if m.persistentStore == nil {
		return ErrPersistentStoreUnavailable
	}
	records, err := m.persistentStore.Load(rootKey)
	if err != nil {
		return err
	}
	filtered := records[:0]
	for _, record := range records {
		if record.ID != id {
			filtered = append(filtered, record)
		}
	}
	return m.persistentStore.Save(rootKey, filtered)
}

func (m *Manager) RestorePersistent(rootKey string, provider ResourceProvider) []error {
	if m.persistentStore == nil {
		return []error{ErrPersistentStoreUnavailable}
	}
	records, err := m.persistentStore.Load(rootKey)
	if err != nil {
		return []error{err}
	}
	errorsFound := make([]error, 0)
	for _, record := range records {
		if err := m.restorePersistent(rootKey, provider, record); err != nil {
			errorsFound = append(errorsFound, err)
		}
	}
	return errorsFound
}

func (m *Manager) restorePersistent(rootKey string, provider ResourceProvider, record PersistentSession) error {
	if record.Version != 1 || record.RootKey != rootKey || record.ID == "" ||
		record.SessionLifetime != SessionLifetimePersistent || record.Port <= 0 {
		return ErrPersistentRecordInvalid
	}
	if _, err := provider.Stat(record.ExposedPath); err != nil {
		return err
	}
	auth, err := authFromPersistent(record)
	if err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, exists := m.sessions[record.ID]; exists {
		return ErrPersistentRecordInvalid
	}
	state, err := m.ensureServerLocked(record.TLS, record.Port)
	if err != nil {
		return err
	}
	session := Session{
		ID: record.ID, RootKey: rootKey, Token: record.Token,
		AuthMode: record.AuthMode, Username: record.Username,
		Password: record.Password, Realm: record.Realm,
		URL:         webdavURLScheme(record.TLS) + state.listener.Addr().String() + "/webdav/" + record.ID + "/",
		DisplayName: record.DisplayName, ExposedPath: record.ExposedPath,
		ReadOnly: record.ReadOnly, WritePolicy: record.WritePolicy, CredentialVisibility: record.CredentialVisibility,
		SessionLifetime: SessionLifetimePersistent, Port: record.Port,
		TLS: record.TLS,
	}
	m.sessions[record.ID] = m.newActiveSession(session, auth, provider)
	return nil
}

// Reveal returns credentials only for sessions created with persistent
// credential visibility. It never changes the token-free status snapshot.
func (m *Manager) Reveal(id string) (Session, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	active, ok := m.sessions[id]
	if !ok {
		return Session{}, ErrSessionClosed
	}
	if active.session.CredentialVisibility != CredentialVisibilityPersistent {
		return Session{}, ErrCredentialsNotRevealable
	}
	return active.session, nil
}

func (m *Manager) Revoke(id string) {
	m.mu.Lock()
	active, ok := m.sessions[id]
	if !ok {
		m.mu.Unlock()
		return
	}
	delete(m.sessions, id)
	if active.session.SessionLifetime == SessionLifetimePersistent && m.persistentStore != nil {
		_ = m.deletePersistentLocked(active.session.RootKey, id)
	}
	m.stopIfIdleLocked()
	m.mu.Unlock()
	if active.mounted != nil {
		_ = active.mounted.Unmount(context.Background())
	}
}

func (m *Manager) RevokeRoot(rootKey string) {
	m.mu.Lock()
	var mounted []*MountedSession
	for id, session := range m.sessions {
		if session.session.RootKey == rootKey {
			if session.mounted != nil {
				mounted = append(mounted, session.mounted)
			}
			delete(m.sessions, id)
		}
	}
	m.stopIfIdleLocked()
	m.mu.Unlock()
	for _, mount := range mounted {
		_ = mount.Unmount(context.Background())
	}
}

func (m *Manager) Count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.sessions)
}

// List returns monitoring and permission state for a root. An empty rootKey
// intentionally means all sessions; callers normally scope this by root.
func (m *Manager) List(rootKey string) []SessionStatus {
	m.mu.Lock()
	defer m.mu.Unlock()
	statuses := make([]SessionStatus, 0, len(m.sessions))
	for _, active := range m.sessions {
		if rootKey != "" && active.session.RootKey != rootKey {
			continue
		}
		statuses = append(statuses, statusFromActive(active))
	}
	sort.Slice(statuses, func(i, j int) bool {
		if statuses[i].DisplayName != statuses[j].DisplayName {
			return statuses[i].DisplayName < statuses[j].DisplayName
		}
		return statuses[i].ID < statuses[j].ID
	})
	return statuses
}

func (m *Manager) Close() error {
	m.mu.Lock()
	var mounted []*MountedSession
	for _, session := range m.sessions {
		if session.mounted != nil {
			mounted = append(mounted, session.mounted)
		}
	}
	m.sessions = make(map[string]activeSession)
	httpErr := m.closeListenerLocked(m.httpState)
	httpsErr := m.closeListenerLocked(m.httpsState)
	m.httpState = nil
	m.httpsState = nil
	m.mu.Unlock()
	for _, mount := range mounted {
		_ = mount.Unmount(context.Background())
	}
	if httpErr != nil {
		return httpErr
	}
	return httpsErr
}

func (m *Manager) Mount(ctx context.Context, id string) (*MountedSession, error) {
	m.mu.Lock()
	active, ok := m.sessions[id]
	if !ok {
		m.mu.Unlock()
		return nil, ErrSessionClosed
	}
	if active.mounted != nil {
		mounted := active.mounted
		m.mu.Unlock()
		return mounted, nil
	}
	m.mu.Unlock()

	mounted, err := MountSession(ctx, active.session)
	if err != nil {
		return nil, err
	}
	m.mu.Lock()
	active, ok = m.sessions[id]
	if !ok {
		m.mu.Unlock()
		_ = mounted.Unmount(context.Background())
		return nil, ErrSessionClosed
	}
	if active.mounted != nil {
		existing := active.mounted
		m.mu.Unlock()
		_ = mounted.Unmount(context.Background())
		return existing, nil
	}
	active.mounted = mounted
	m.sessions[id] = active
	m.mu.Unlock()
	return mounted, nil
}

// Unmount detaches the operating-system mount owned by a session. A failed
// unmount remains visible in List so callers do not report a cleanup success
// while the mount may still be present.
func (m *Manager) Unmount(ctx context.Context, id string) error {
	m.mu.Lock()
	active, ok := m.sessions[id]
	if !ok || active.mounted == nil {
		m.mu.Unlock()
		return nil
	}
	mounted := active.mounted
	m.mu.Unlock()

	if err := mounted.Unmount(ctx); err != nil {
		return err
	}

	m.mu.Lock()
	active, ok = m.sessions[id]
	if ok && active.mounted == mounted {
		active.mounted = nil
		m.sessions[id] = active
	}
	m.mu.Unlock()
	return nil
}

// === Listener lifecycle (scheme-aware) ===

// ensureServerLocked returns the listener state for the requested scheme,
// creating it if necessary. The caller must hold m.mu.
func (m *Manager) ensureServerLocked(tlsEnabled bool, port int) (*listenerState, error) {
	if tlsEnabled {
		return m.ensureSchemeListenerLocked(&m.httpsState, true, port)
	}
	return m.ensureSchemeListenerLocked(&m.httpState, false, port)
}

// ensureSchemeListenerLocked creates or returns the listener for one scheme.
// The caller must hold m.mu.
func (m *Manager) ensureSchemeListenerLocked(statePtr **listenerState, tlsEnabled bool, port int) (*listenerState, error) {
	if *statePtr != nil && (*statePtr).listener != nil {
		if port != 0 && (*statePtr).port != port {
			return nil, ErrPersistentPortConflict
		}
		return *statePtr, nil
	}
	tcpListener, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(port))
	if err != nil {
		return nil, err
	}
	var serveListener net.Listener = tcpListener
	if tlsEnabled {
		tlsConfig, err := EnsureTLSConfig()
		if err != nil {
			tcpListener.Close()
			return nil, fmt.Errorf("webdav tls: %w", err)
		}
		serveListener = tls.NewListener(tcpListener, tlsConfig)
	}
	state := &listenerState{
		listener:  serveListener,
		port:      tcpListener.Addr().(*net.TCPAddr).Port,
		server:    &http.Server{Handler: http.HandlerFunc(m.handle)},
		serveDone: make(chan struct{}),
	}
	*statePtr = state
	done := state.serveDone
	go func() {
		defer close(done)
		_ = state.server.Serve(serveListener)
	}()
	return state, nil
}

func (m *Manager) closeListenerLocked(state *listenerState) error {
	if state == nil || state.server == nil {
		return nil
	}
	err := state.server.Close()
	if state.serveDone != nil {
		<-state.serveDone
	}
	return err
}

func (m *Manager) countSessionsBySchemeLocked() (httpCount, httpsCount int) {
	for _, s := range m.sessions {
		if s.session.TLS {
			httpsCount++
		} else {
			httpCount++
		}
	}
	return
}

func (m *Manager) stopIfIdleLocked() {
	httpCount, httpsCount := m.countSessionsBySchemeLocked()
	if httpCount == 0 && m.httpState != nil {
		_ = m.closeListenerLocked(m.httpState)
		m.httpState = nil
	}
	if httpsCount == 0 && m.httpsState != nil {
		_ = m.closeListenerLocked(m.httpsState)
		m.httpsState = nil
	}
}


// webdavURLScheme returns "https://" when TLS is enabled, "http://" otherwise.
func webdavURLScheme(tlsEnabled bool) string {
	if tlsEnabled {
		return "https://"
	}
	return "http://"
}


func (m *Manager) newValueLocked(size int) (string, error) {
	bytes := make([]byte, size)
	if _, err := io.ReadFull(m.random, bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func (m *Manager) handle(w http.ResponseWriter, r *http.Request) {
	segments := splitURLPath(r.URL.Path)
	if len(segments) < 2 || segments[0] != "webdav" {
		http.NotFound(w, r)
		return
	}
	active, challenge, ok := m.acquireAuthorized(segments[1], r)
	if !ok {
		if challenge == "" {
			challenge = `Bearer realm="safe-disk"`
		}
		w.Header().Set("WWW-Authenticate", challenge)
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}
	defer m.releaseRequest(segments[1])
	if !validURLSegments(segments[2:]) {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}

	switch r.Method {
	case http.MethodOptions:
		// The wrapper rejects LOCK and all content-changing methods, so it must
		// advertise class 1 rather than claiming x/net/webdav's class-2 locks.
		w.Header().Set("DAV", "1")
		allowOpts := methodAllowReadOnly
		if active.session.WritePolicy != WritePolicyReadOnly {
			allowOpts = methodAllowReadWrite
		}
		w.Header().Set("Allow", allowOpts)
		w.Header().Set("MS-Author-Via", "DAV")
		w.WriteHeader(http.StatusOK)
	case http.MethodGet, http.MethodHead, "PROPFIND",
		"PROPPATCH", "COPY", "LOCK", "UNLOCK":
		active.handler.ServeHTTP(w, r)
	case "PUT", http.MethodDelete, "MKCOL", "MOVE":
		if active.session.WritePolicy == WritePolicyReadOnly {
			w.Header().Set("Allow", methodAllowReadOnly)
			http.Error(w, http.StatusText(http.StatusForbidden), http.StatusForbidden)
			return
		}
		active.handler.ServeHTTP(w, r)
	default:
		allowDef := methodAllowReadOnly
		if active.session.WritePolicy != WritePolicyReadOnly {
			allowDef = methodAllowReadWrite
		}
		w.Header().Set("Allow", allowDef)
		http.Error(w, http.StatusText(http.StatusForbidden), http.StatusForbidden)
	}
}

func (m *Manager) acquireAuthorized(id string, request *http.Request) (activeSession, string, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	active, ok := m.sessions[id]
	if !ok {
		return activeSession{}, `Bearer realm="safe-disk"`, false
	}
	challenge, authenticated := m.authenticateLocked(&active, request)
	if !authenticated {
		return activeSession{}, challenge, false
	}
	now := time.Now().UTC()
	active.lastAccessedAt = &now
	active.activeRequests++
	m.sessions[id] = active
	return active, "", true
}

func (m *Manager) releaseRequest(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	active, ok := m.sessions[id]
	if !ok {
		return
	}
	if active.activeRequests > 0 {
		active.activeRequests--
	}
	m.sessions[id] = active
}

func statusFromActive(active activeSession) SessionStatus {
	mountPath := ""
	if active.mounted != nil {
		mountPath = active.mounted.Path()
	}
	return SessionStatus{
		ID:                   active.session.ID,
		DisplayName:          active.session.DisplayName,
		ExposedPath:          active.session.ExposedPath,
		URL:                  active.session.URL,
		ReadOnly:             active.session.ReadOnly,
		AuthMode:             active.session.AuthMode,
		LastAccessedAt:       active.lastAccessedAt,
		ActiveRequests:       active.activeRequests,
		Mounted:              active.mounted != nil,
		MountPath:            mountPath,
		CredentialVisibility: active.session.CredentialVisibility,
		SessionLifetime:      active.session.SessionLifetime,
		Port:                 active.session.Port,
		TLS:                  active.session.TLS,
	}
}

func cleanRelativePath(value string) (string, error) {
	value = strings.Trim(value, "/")
	if value == "" {
		return "", nil
	}
	parts := strings.Split(value, "/")
	for _, part := range parts {
		if part == "" || part == "." || part == ".." || strings.Contains(part, `\`) || strings.ContainsRune(part, 0) {
			return "", ErrInvalidPath
		}
	}
	return strings.Join(parts, "/"), nil
}

func splitURLPath(value string) []string {
	trimmed := strings.Trim(value, "/")
	if trimmed == "" {
		return nil
	}
	return strings.Split(trimmed, "/")
}

func validURLSegments(segments []string) bool {
	for _, segment := range segments {
		if segment == "" || segment == "." || segment == ".." || strings.Contains(segment, `\`) || strings.ContainsRune(segment, 0) {
			return false
		}
	}
	return true
}

func joinSecurePath(base, relative string) string {
	if base == "" {
		return relative
	}
	if relative == "" {
		return base
	}
	return path.Join(base, relative)
}
