// Package sec_webdav exposes an explicitly selected secure subtree through a
// revocable, read-only loopback WebDAV session.
package sec_webdav

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"io"
	"io/fs"
	"net"
	"net/http"
	"path"
	"sort"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/webdav"
)

var (
	ErrInvalidRootKey = errors.New("webdav root key is empty")
	ErrInvalidPath    = errors.New("webdav path is invalid")
	ErrSessionClosed  = errors.New("webdav session is closed")
)

const methodAllow = "OPTIONS, GET, HEAD, PROPFIND"

// ResourceProvider is deliberately smaller than sec_fs.ISecRoot. The FFI
// layer adapts an already-open secure root to this interface.
type ResourceProvider interface {
	Stat(path string) (fs.FileInfo, error)
	ReadDir(path string) ([]fs.DirEntry, error)
	Open(path string) (io.ReadCloser, fs.FileInfo, error)
}

type Session struct {
	ID          string   `json:"id"`
	RootKey     string   `json:"-"`
	Token       string   `json:"token,omitempty"`
	AuthMode    AuthMode `json:"auth_mode"`
	Username    string   `json:"username,omitempty"`
	Password    string   `json:"password,omitempty"`
	Realm       string   `json:"realm,omitempty"`
	URL         string   `json:"url"`
	DisplayName string   `json:"display_name"`
	ExposedPath string   `json:"exposed_path"`
	ReadOnly    bool     `json:"read_only"`
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
	ID             string     `json:"id"`
	DisplayName    string     `json:"display_name"`
	ExposedPath    string     `json:"exposed_path"`
	URL            string     `json:"url"`
	ReadOnly       bool       `json:"read_only"`
	AuthMode       AuthMode   `json:"auth_mode"`
	LastAccessedAt *time.Time `json:"last_accessed_at"`
	ActiveRequests int        `json:"active_requests"`
	Mounted        bool       `json:"mounted"`
	MountPath      string     `json:"mount_path,omitempty"`
}

type Manager struct {
	mu       sync.Mutex
	random   io.Reader
	server   *http.Server
	listener net.Listener
	sessions map[string]activeSession
}

func NewManager() *Manager {
	return &Manager{
		random:   rand.Reader,
		sessions: make(map[string]activeSession),
	}
}

func (m *Manager) Open(rootKey, displayName, exposedPath string, provider ResourceProvider) (Session, error) {
	return m.OpenWithOptions(rootKey, displayName, exposedPath, provider, OpenOptions{AuthMode: AuthModeBearer})
}

func (m *Manager) OpenWithOptions(rootKey, displayName, exposedPath string, provider ResourceProvider, options OpenOptions) (Session, error) {
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
	if err := m.ensureServerLocked(); err != nil {
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
		ID:          id,
		RootKey:     rootKey,
		Token:       auth.token,
		AuthMode:    auth.mode,
		Username:    auth.username,
		Password:    auth.password,
		Realm:       auth.realm,
		URL:         "http://" + m.listener.Addr().String() + "/webdav/" + id + "/",
		DisplayName: displayName,
		ExposedPath: cleanPath,
		ReadOnly:    true,
	}
	secureFS := newSecureFileSystem(provider, cleanPath)
	active := activeSession{
		session:  session,
		auth:     auth,
		provider: provider,
		handler: &webdav.Handler{
			Prefix:     "/webdav/" + id,
			FileSystem: secureFS,
			LockSystem: webdav.NewMemLS(),
		},
	}
	m.sessions[id] = active
	return session, nil
}

func (m *Manager) Revoke(id string) {
	m.mu.Lock()
	active, ok := m.sessions[id]
	if !ok {
		m.mu.Unlock()
		return
	}
	delete(m.sessions, id)
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
	var err error
	if m.server == nil {
		m.mu.Unlock()
		for _, mount := range mounted {
			if unmountErr := mount.Unmount(context.Background()); err == nil {
				err = unmountErr
			}
		}
		return err
	}
	err = m.server.Close()
	m.server = nil
	m.listener = nil
	m.mu.Unlock()
	for _, mount := range mounted {
		if unmountErr := mount.Unmount(context.Background()); err == nil {
			err = unmountErr
		}
	}
	return err
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

func (m *Manager) ensureServerLocked() error {
	if m.server != nil {
		return nil
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return err
	}
	server := &http.Server{Handler: http.HandlerFunc(m.handle)}
	m.listener = listener
	m.server = server
	go func() {
		_ = server.Serve(listener)
	}()
	return nil
}

func (m *Manager) stopIfIdleLocked() {
	if len(m.sessions) != 0 || m.server == nil {
		return
	}
	_ = m.server.Close()
	m.server = nil
	m.listener = nil
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
		w.Header().Set("DAV", "1")
		w.Header().Set("Allow", methodAllow)
		w.Header().Set("MS-Author-Via", "DAV")
		w.WriteHeader(http.StatusOK)
	case http.MethodGet, http.MethodHead, "PROPFIND":
		active.handler.ServeHTTP(w, r)
	default:
		w.Header().Set("Allow", methodAllow)
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
		ID:             active.session.ID,
		DisplayName:    active.session.DisplayName,
		ExposedPath:    active.session.ExposedPath,
		URL:            active.session.URL,
		ReadOnly:       active.session.ReadOnly,
		AuthMode:       active.session.AuthMode,
		LastAccessedAt: active.lastAccessedAt,
		ActiveRequests: active.activeRequests,
		Mounted:        active.mounted != nil,
		MountPath:      mountPath,
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
