//go:build !linux && !darwin && !windows

package sec_webdav

import (
	"context"
	"fmt"
)

func mountSessionPlatform(context.Context, Session) (*MountedSession, error) {
	return nil, fmt.Errorf("%w: operating system is not supported", ErrMountUnsupported)
}
