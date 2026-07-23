//go:build windows

package sec_webdav

import (
	"context"
	"fmt"
)

func mountSessionPlatform(context.Context, Session) (*MountedSession, error) {
	return nil, fmt.Errorf("%w: Windows WebDAV credential lifecycle is not implemented", ErrMountUnsupported)
}
