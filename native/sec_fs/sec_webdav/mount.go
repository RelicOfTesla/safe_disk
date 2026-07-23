package sec_webdav

import (
	"context"
	"errors"
	"sync"
)

var (
	ErrMountUnsupported = errors.New("webdav system mount is unsupported")
	ErrMountFailed      = errors.New("webdav system mount failed")
)

// MountedSession owns a Go-created operating-system mount. Its credentials
// and cleanup lifecycle remain native; callers only receive the mount path.
type MountedSession struct {
	path    string
	unmount func(context.Context) error
	once    sync.Once
	err     error
}

func MountSession(ctx context.Context, session Session) (*MountedSession, error) {
	return mountSessionPlatform(ctx, session)
}

func (m *MountedSession) Path() string {
	if m == nil {
		return ""
	}
	return m.path
}

func (m *MountedSession) Unmount(ctx context.Context) error {
	if m == nil {
		return nil
	}
	m.once.Do(func() {
		m.err = m.unmount(ctx)
	})
	return m.err
}
