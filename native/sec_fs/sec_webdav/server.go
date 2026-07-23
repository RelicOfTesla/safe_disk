// Package sec_webdav exposes an explicitly selected secure subtree through a
// revocable, read-only loopback WebDAV session.
package sec_webdav

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"net/url"
	pathpkg "path"
	"strings"
	"sync"
)

var (
	ErrInvalidRootKey = errors.New("webdav root key is empty")
	ErrInvalidPath    = errors.New("webdav path is invalid")
	ErrSessionClosed  = errors.New("webdav session is closed")
)

const (
	methodAllow = "OPTIONS, GET, HEAD, PROPFIND"
	maxDepth    = 1
)

// ResourceProvider is deliberately smaller than sec_fs.ISecRoot. The FFI
// layer adapts an already-open secure root to this interface.
type ResourceProvider interface {
	Stat(path string) (fs.FileInfo, error)
	ReadDir(path string) ([]fs.DirEntry, error)
	Open(path string) (io.ReadCloser, fs.FileInfo, error)
}

type Session struct {
	ID          string `json:"id"`
	RootKey     string `json:"-"`
	Token       string `json:"token"`
	URL         string `json:"url"`
	DisplayName string `json:"display_name"`
	ExposedPath string `json:"exposed_path"`
	ReadOnly    bool   `json:"read_only"`
}

type activeSession struct {
	session  Session
	provider ResourceProvider
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
	token, err := m.newValueLocked(32)
	if err != nil {
		return Session{}, err
	}
	session := Session{
		ID:          id,
		RootKey:     rootKey,
		Token:       token,
		URL:         "http://" + m.listener.Addr().String() + "/webdav/" + id + "/",
		DisplayName: displayName,
		ExposedPath: cleanPath,
		ReadOnly:    true,
	}
	m.sessions[id] = activeSession{session: session, provider: scopedProvider{
		base: cleanPath,
		root: provider,
	}}
	return session, nil
}

func (m *Manager) Revoke(id string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.sessions, id)
	m.stopIfIdleLocked()
}

func (m *Manager) RevokeRoot(rootKey string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, session := range m.sessions {
		if session.session.RootKey == rootKey {
			delete(m.sessions, id)
		}
	}
	m.stopIfIdleLocked()
}

func (m *Manager) Count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.sessions)
}

func (m *Manager) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sessions = make(map[string]activeSession)
	if m.server == nil {
		return nil
	}
	err := m.server.Close()
	m.server = nil
	m.listener = nil
	return err
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
	m.mu.Lock()
	active, ok := m.sessions[segments[1]]
	m.mu.Unlock()
	if !ok || !authorized(r, active.session.Token) {
		w.Header().Set("WWW-Authenticate", `Bearer realm="safe-disk"`)
		http.Error(w, http.StatusText(http.StatusUnauthorized), http.StatusUnauthorized)
		return
	}
	for _, segment := range segments[2:] {
		if segment == "" || segment == "." || segment == ".." || strings.Contains(segment, `\`) || strings.ContainsRune(segment, 0) {
			http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
			return
		}
	}
	relative := strings.Join(segments[2:], "/")
	switch r.Method {
	case http.MethodOptions:
		w.Header().Set("DAV", "1")
		w.Header().Set("Allow", methodAllow)
		w.WriteHeader(http.StatusOK)
	case http.MethodGet, http.MethodHead:
		m.handleRead(w, r, active.provider, relative)
	case "PROPFIND":
		m.handlePropfind(w, r, active.provider, relative, "/webdav/"+segments[1]+"/")
	default:
		w.Header().Set("Allow", methodAllow)
		http.Error(w, http.StatusText(http.StatusForbidden), http.StatusForbidden)
	}
}

func (m *Manager) handleRead(w http.ResponseWriter, r *http.Request, provider ResourceProvider, path string) {
	file, info, err := provider.Open(path)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer file.Close()
	if info.IsDir() {
		http.Error(w, http.StatusText(http.StatusMethodNotAllowed), http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Length", fmt.Sprint(info.Size()))
	if r.Method == http.MethodGet {
		if _, err := io.Copy(w, file); err != nil {
			return
		}
	}
}

func (m *Manager) handlePropfind(w http.ResponseWriter, r *http.Request, provider ResourceProvider, path, baseURL string) {
	depth := r.Header.Get("Depth")
	if depth == "" {
		depth = "1"
	}
	if depth != "0" && depth != "1" {
		http.Error(w, http.StatusText(http.StatusBadRequest), http.StatusBadRequest)
		return
	}
	info, err := provider.Stat(path)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	resources := []davResource{{path: path, info: info}}
	if depth == "1" && info.IsDir() {
		entries, err := provider.ReadDir(path)
		if err != nil {
			http.NotFound(w, r)
			return
		}
		for _, entry := range entries {
			entryInfo, err := entry.Info()
			if err != nil {
				continue
			}
			child := entry.Name()
			if path != "" {
				child = pathpkg.Join(path, child)
			}
			resources = append(resources, davResource{path: child, info: entryInfo})
		}
	}
	response := davMultiStatus{XMLName: xml.Name{Local: "D:multistatus"}, XMLNS: "DAV:"}
	for _, resource := range resources {
		href := baseURL
		if resource.path != "" {
			href += urlPath(resource.path)
		}
		response.Responses = append(response.Responses, davResponse{
			Href: href,
			Propstat: davPropstat{Prop: davProp{
				DisplayName: resource.info.Name(),
				ResourceType: func() *davResourceType {
					if resource.info.IsDir() {
						return &davResourceType{Collection: &struct{}{}}
					}
					return nil
				}(),
				Size:    optionalSize(resource.info),
				ModTime: resource.info.ModTime().UTC().Format(http.TimeFormat),
			}, Status: "HTTP/1.1 200 OK"},
		})
	}
	data, err := xml.Marshal(response)
	if err != nil {
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", `application/xml; charset="utf-8"`)
	w.Header().Set("DAV", "1")
	w.WriteHeader(207)
	_, _ = w.Write(append([]byte(`<?xml version="1.0" encoding="utf-8"?>`), data...))
}

type davResource struct {
	path string
	info fs.FileInfo
}

type davMultiStatus struct {
	XMLName   xml.Name      `xml:"D:multistatus"`
	XMLNS     string        `xml:"xmlns:D,attr"`
	Responses []davResponse `xml:"D:response"`
}

type davResponse struct {
	Href     string      `xml:"D:href"`
	Propstat davPropstat `xml:"D:propstat"`
}

type davPropstat struct {
	Prop   davProp `xml:"D:prop"`
	Status string  `xml:"D:status"`
}

type davProp struct {
	DisplayName  string           `xml:"D:displayname"`
	ResourceType *davResourceType `xml:"D:resourcetype,omitempty"`
	Size         *int64           `xml:"D:getcontentlength,omitempty"`
	ModTime      string           `xml:"D:getlastmodified,omitempty"`
}

type davResourceType struct {
	Collection *struct{} `xml:"D:collection,omitempty"`
}

type scopedProvider struct {
	base string
	root ResourceProvider
}

func (p scopedProvider) path(relative string) string {
	if p.base == "" {
		return relative
	}
	if relative == "" {
		return p.base
	}
	return pathpkg.Join(p.base, relative)
}

func (p scopedProvider) Stat(path string) (fs.FileInfo, error) {
	return p.root.Stat(p.path(path))
}

func (p scopedProvider) ReadDir(path string) ([]fs.DirEntry, error) {
	return p.root.ReadDir(p.path(path))
}

func (p scopedProvider) Open(path string) (io.ReadCloser, fs.FileInfo, error) {
	return p.root.Open(p.path(path))
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

func urlPath(value string) string {
	parts := strings.Split(value, "/")
	for index, part := range parts {
		parts[index] = url.PathEscape(part)
	}
	return strings.Join(parts, "/") + func() string {
		if strings.HasSuffix(value, "/") {
			return "/"
		}
		return ""
	}()
}

func optionalSize(info fs.FileInfo) *int64 {
	size := info.Size()
	return &size
}

func authorized(r *http.Request, token string) bool {
	value := r.Header.Get("Authorization")
	expected := "Bearer " + token
	return len(value) == len(expected) && subtle.ConstantTimeCompare([]byte(value), []byte(expected)) == 1
}
