// Package sec_utils provides utilities for secure file system operations.
// This file contains interface definitions and type declarations for path utilities.
package sec_utils

import (
	"path/filepath"
)

// ==================== Path Info Interface ====================

// PathInfo is an interface for parsed path information.
// It provides lazy computation and caching for performance.
//
// Usage analysis shows:
//   - Path (34 uses) and Parts (18 uses) are most frequently accessed
//
// This design uses an interface to hide implementation details and allow
// for different implementations in the future.
type PathInfo interface {
	// Scheme returns the path prefix (URI, UNC, etc.).
	Scheme() string
	// Host returns the host part of the path (for URI/UNC paths; drive letter for Windows).
	Host() string
	// Separator returns the path separator ('/' or '\\').
	Separator() rune
	// Parts returns the path components (split by separator, cleaned, without drive letter for Windows).
	Parts() []string
	// IsRelative returns whether this is a relative path.
	IsRelative() bool
	// Encode returns the full path string.
	Encode() string
	// WithoutScheme returns the path without the scheme.
	WithoutScheme() string
	// Join adds new path components and returns a new PathInfo.
	Join(parts ...string) PathInfo
	//
	Dir() PathInfo
	// ContainsPath checks if the given path is contained within this path.
	ContainsPath(otherPath string) bool
	// TODO:
	ContainsPathInfo(otherPath PathInfo) bool
	// ReplaceParts creates a new PathInfo with replaced path parts.
	ReplaceParts(newParts []string) PathInfo

	Type() PathType
}

// ==================== Path Type ====================

type PathType int

const (
	PathTypeUnknown PathType = iota
	PathTypeLocalRelative
	PathTypeLocalAbsolute
	PathTypeFileUriLocal
	PathTypeFileUriRemote
	PathTypeFileUriUnc
	PathTypeCustomUri
	PathTypeUncWindows
)

// ==================== Constants ====================

var DefaultSystemSeparator = filepath.Separator

// ==================== Aliases (指向默认实现) ====================

// ParsePathInfo parses a path and returns all information in one call.
// This is an alias for ParsePathInfoEasy (the default implementation).
var ParsePathInfo = ParsePathInfoEasy

// ParsePathInfoMust is like ParsePathInfo but panics if an error occurs.
var ParsePathInfoMust = func(path string) PathInfo {
	info, err := ParsePathInfo(path)
	if err != nil {
		panic(err)
	}
	return info
}

// PathClean cleans a path by removing redundant elements.
// This is an alias for PathCleanEasy (the default implementation).
var PathClean = PathCleanEasy
