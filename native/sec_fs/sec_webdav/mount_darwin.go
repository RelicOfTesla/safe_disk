//go:build darwin

package sec_webdav

import (
	"context"
	"fmt"
)

func mountSessionPlatform(context.Context, Session) (*MountedSession, error) {
	return nil, fmt.Errorf("%w: macOS WebDAV credential lifecycle is not implemented", ErrMountUnsupported)
}
