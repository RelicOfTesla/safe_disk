// Package sec_utils provides utilities for secure file system operations.
// This file contains utility functions for path processing.
package sec_utils

import (
	"errors"
	"path/filepath"
	"strings"
)

// ==================== Path Info ====================

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
	// IsAbs returns whether this is an absolute path.
	IsAbs() bool
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

var DefaultSystemSeparator = filepath.Separator

// pathInfoImpl is the concrete implementation of PathInfo.
// Fields are lazily computed and cached for performance.
type pathInfoImpl struct {
	// Initialized fields (always available)
	scheme    string   // Path scheme (URI scheme, UNC prefix, etc.)
	host      string   // Host part (for URI/UNC; drive letter for Windows)
	separator rune     // Path separator ('/' or '\\')
	parts     []string // Path components (split by separator, cleaned, without drive letter)
	pathType  PathType // Path type classification

	// Lazily computed fields (nil until first access)
	path   *string // Actual path part without scheme (cached)
	encode *string // Full encoded path (cached)
}

// Path returns the actual path part (without scheme).
// This is computed lazily and cached.
func (info *pathInfoImpl) Path() string {
	if info == nil {
		return ""
	}
	if info.path == nil {
		// For Windows drive paths, include the host (drive letter)
		var prefix string
		if info.host != "" && info.scheme == "" && info.pathType == PathTypeLocalAbsolute {
			// Windows drive path like C:\a\b
			prefix = info.host
		}
		actualPath := buildPath(prefix, info.parts, info.separator)
		info.path = &actualPath
	}
	return *info.path
}

// isAbsolutePath returns true if the path is an absolute path.
func (info *pathInfoImpl) isAbsolutePath() bool {
	if info == nil {
		return false
	}
	switch info.pathType {
	case PathTypeLocalAbsolute, PathTypeFileUriLocal, PathTypeFileUriRemote, PathTypeFileUriUnc, PathTypeUncWindows:
		return true
	default:
		return false
	}
}

// Scheme returns the path scheme (URI scheme, UNC prefix, etc.).
func (info *pathInfoImpl) Scheme() string {
	if info == nil {
		return ""
	}
	return info.scheme
}

// Host returns the host part (for URI/UNC; drive letter for Windows).
func (info *pathInfoImpl) Host() string {
	if info == nil {
		return ""
	}
	return info.host
}

// Separator returns the path separator ('/' or '\\').
func (info *pathInfoImpl) Separator() rune {
	if info == nil {
		return DefaultSystemSeparator
	}
	return info.separator
}

// Parts returns the path components (split by separator, cleaned, without drive letter).
func (info *pathInfoImpl) Parts() []string {
	if info == nil {
		return nil
	}
	// For absolute paths, skip the leading empty string (used internally for buildPath)
	// But keep the empty string for root path (parts = [""])
	if len(info.parts) > 1 && len(info.parts[0]) == 0 {
		return info.parts[1:]
	}
	return info.parts
}

func (info *pathInfoImpl) Type() PathType {
	if info == nil {
		return PathTypeUnknown
	}
	return info.pathType
}

// IsAbs returns whether this is an absolute path.
func (info *pathInfoImpl) IsAbs() bool {
	if info == nil {
		return false
	}
	return len(info.parts) > 0 && (info.pathType != PathTypeLocalRelative && info.pathType != PathTypeUnknown)
}

// Encode returns the full path string.
// This is computed lazily and cached.
func (info *pathInfoImpl) Encode() string {
	if info == nil {
		return ""
	}
	if info.encode == nil {
		encoded := info.buildEncodedPath()
		info.encode = &encoded
	}
	return *info.encode
}

// buildEncodedPath builds the full encoded path string.
func (info *pathInfoImpl) buildEncodedPath() string {
	var result strings.Builder

	// Add scheme if present
	if info.scheme != "" {
		result.WriteString(info.scheme)
	}

	// Add host if present
	if info.host != "" {
		// For Windows drive letters, no separator needed after scheme
		if info.scheme != "" && info.pathType != PathTypeLocalAbsolute {
			// For remote URI schemes (file://host/path, custom://host/path), add host
			if info.pathType == PathTypeFileUriRemote || info.pathType == PathTypeCustomUri {
				result.WriteString(info.host)
				// Add separator if parts doesn't start with empty string (not absolute)
				if len(info.parts) == 0 || info.parts[0] != "" {
					result.WriteString("/")
				}
			}
			// For UNC paths (\\server\share\path), add host
			if info.pathType == PathTypeUncWindows {
				result.WriteString(info.host)
			}
			// For UNC format URIs (files:////server/share/path), add // + host
			if info.pathType == PathTypeFileUriUnc {
				result.WriteString("//")
				result.WriteString(info.host)
			}
			// For local file URIs with Windows drive (file:///d:\path), add /host
			// For local file URIs with localhost (file://localhost/path), just add host
			if info.pathType == PathTypeFileUriLocal {
				// Check if host is a Windows drive letter (e.g., "d:")
				if len(info.host) == 2 && info.host[1] == ':' {
					result.WriteString("/")
					result.WriteString(info.host)
				} else {
					// For localhost, 127.0.0.1, [::1], etc., just add host
					result.WriteString(info.host)
				}
			}
			// For local URI schemes (file:///path), host is empty, path already starts with /
		} else if info.scheme == "" {
			// For UNC paths or Windows drives without scheme
			result.WriteString(info.host)
		}
	}

	// Add path parts
	path := buildPath("", info.parts, info.separator)
	result.WriteString(path)

	return result.String()
}

// WithoutScheme returns the path without the scheme.
func (info *pathInfoImpl) WithoutScheme() string {
	if info == nil {
		return ""
	}
	return info.Path()
}

// Dir returns the parent directory.
func (info *pathInfoImpl) Dir() PathInfo {
	if info == nil || len(info.parts) == 0 {
		return info
	}

	// Remove the last part
	newParts := make([]string, len(info.parts)-1)
	copy(newParts, info.parts)

	return &pathInfoImpl{
		scheme:    info.scheme,
		host:      info.host,
		separator: info.separator,
		parts:     newParts,
		pathType:  info.pathType,
	}
}

// ParsePathInfo parses a path and returns all information in one call.
// This function is optimized to parse the path in a single pass, combining:
//   - Scheme detection (URI, UNC, drive letter)
//   - Host detection (for URI/UNC; drive letter for Windows)
//   - Separator detection
//   - Path splitting and cleaning (handling . and ..)
//
// The path is cleaned before parsing (removing redundant . and .., consecutive separators, etc.)
//
// Parameters:
//   - path: The path to parse
//
// Returns:
//   - PathInfo: Parsed path information (nil if path is empty)
//   - error: Always returns nil for now, reserved for future error handling
func ParsePathInfo(path string) (PathInfo, error) {
	if path == "" {
		return &pathInfoImpl{
			separator: DefaultSystemSeparator,
		}, nil
	}

	// Single-pass parsing: extract scheme, host, detect separator, split and clean path
	scheme, host, separator, parts, pathType := parsePathOnce(path)

	// Validate: check for invalid drive letter in the middle of path
	// Example: d:\a:\b is invalid because a: appears in the middle
	for _, part := range parts {
		if len(part) == 2 && part[1] == ':' {
			if (part[0] >= 'A' && part[0] <= 'Z') || (part[0] >= 'a' && part[0] <= 'z') {
				return nil, errors.New("invalid path: drive letter cannot appear in the middle of path")
			}
		}
	}

	// Validate: Windows drive-relative path (d:a\b) is not supported
	// Drive-relative path has a drive letter but no separator after it
	if host != "" && len(host) == 2 && host[1] == ':' {
		if (host[0] >= 'A' && host[0] <= 'Z') || (host[0] >= 'a' && host[0] <= 'z') {
			if pathType == PathTypeLocalRelative && len(parts) > 0 {
				return nil, errors.New("invalid path: Windows drive-relative path (d:a\\b) is not supported")
			}
		}
	}

	// Only initialize essential fields; others are lazily computed
	return &pathInfoImpl{
		scheme:    scheme,
		host:      host,
		separator: separator,
		parts:     parts,
		pathType:  pathType,
	}, nil
}

// ParsePathInfoMust is like ParsePathInfo but panics if an error occurs.
// This is useful for cases where the path is guaranteed to be valid,
// such as hardcoded paths or paths that have been validated elsewhere.
func ParsePathInfoMust(path string) PathInfo {
	info, err := ParsePathInfo(path)
	if err != nil {
		panic(err)
	}
	return info
}

// parsePathOnce performs single-pass path parsing.
// It extracts scheme, host, detects separator, splits and cleans the path in one traversal.
// Optimized to avoid unnecessary string allocations.
func parsePathOnce(path string) (scheme string, host string, separator rune, parts []string, pathType PathType) {
	// Default separator
	separator = DefaultSystemSeparator

	// Step 1: Extract scheme and host (URI, UNC, drive letter)
	var pathEnd int
	scheme, host, pathEnd, pathType = extractSchemeAndHost(path)

	// Step 2: Handle empty path after scheme
	if pathEnd >= len(path) {
		return scheme, host, separator, parts, pathType
	}

	// Step 3: Check if scheme is URI (URI always uses '/' as separator)
	isURI := strings.HasPrefix(scheme, "file://") || strings.HasPrefix(scheme, "files://") ||
		(strings.Contains(scheme, "://") && !strings.HasPrefix(scheme, "\\\\"))
	if isURI {
		separator = '/'
	}

	// Step 4: Skip leading separators after scheme (for URI with multiple slashes)
	if isURI {
		for pathEnd < len(path) && (path[pathEnd] == '/' || path[pathEnd] == '\\') {
			pathEnd++
		}
	}

	// Step 5: Manual split and clean in one pass
	// Pre-allocate parts with estimated capacity
	parts = make([]string, 0, 16)

	start := pathEnd
	firstPart := true

	for i := pathEnd; i <= len(path); i++ {
		if i == len(path) || path[i] == '/' || path[i] == '\\' {
			// Detect separator from first separator encountered (only for non-URI paths)
			if firstPart && i < len(path) && !isURI {
				separator = rune(path[i])
				firstPart = false
			}

			// Extract part
			if i > start {
				part := path[start:i]
				switch part {
				case ".":
					// Skip current directory
				case "..":
					// Parent directory - pop if possible
					if len(parts) > 0 {
						lastIdx := len(parts) - 1
						if parts[lastIdx] != "" && parts[lastIdx] != ".." {
							parts = parts[:lastIdx]
						} else {
							parts = append(parts, part)
						}
					} else {
						parts = append(parts, part)
					}
				default:
					parts = append(parts, part)
				}
			}
			start = i + 1
		}
	}

	// Handle root path (e.g., "/")
	// Only add empty string for absolute paths (not for "." which is relative)
	if len(parts) == 0 && len(path) > pathEnd && pathType != PathTypeLocalRelative && pathType != PathTypeUnknown {
		// Root path: add empty string
		parts = append(parts, "")
	}

	// Mark absolute paths with leading empty string for buildPath
	switch pathType {
	case PathTypeLocalAbsolute, PathTypeFileUriLocal, PathTypeFileUriRemote, PathTypeFileUriUnc, PathTypeUncWindows, PathTypeCustomUri:
		if len(parts) > 0 && parts[0] != "" {
			parts = append([]string{""}, parts...)
		}
	}

	return scheme, host, separator, parts, pathType
}

// extractSchemeAndHost extracts the scheme and host from the path.
// Returns: scheme, host, pathEndIndex, pathType
func extractSchemeAndHost(path string) (scheme string, host string, pathEnd int, pathType PathType) {
	if len(path) == 0 {
		return "", "", 0, PathTypeUnknown
	}

	// 1. Check for URI scheme (scheme://, scheme:/, scheme:///)
	if schemeEnd := findURISchemeEnd(path); schemeEnd > 0 {
		if len(path) > schemeEnd && path[schemeEnd] == ':' {
			// Check for :// or :\\\
			if len(path) > schemeEnd+2 {
				// Check for ://
				if path[schemeEnd+1] == '/' && path[schemeEnd+2] == '/' {
					// Count consecutive slashes after ://
					slashCount := 2
					for i := schemeEnd + 3; i < len(path) && (path[i] == '/' || path[i] == '\\'); i++ {
						slashCount++
					}
					// Scheme is always the part before ://
					scheme = path[:schemeEnd+3]
					pathEnd = schemeEnd + slashCount

					// Determine path type based on scheme and slashes
					if slashCount >= 3 {
						// file:/// or files:/// is local file URI
						if strings.HasPrefix(scheme, "file://") || strings.HasPrefix(scheme, "files://") {
							pathType = PathTypeFileUriLocal
						} else {
							pathType = PathTypeCustomUri
						}
					} else {
						// file:// or files:// with 2 slashes could be remote or have host
						if strings.HasPrefix(scheme, "file://") || strings.HasPrefix(scheme, "files://") {
							pathType = PathTypeFileUriRemote
						} else {
							pathType = PathTypeCustomUri
						}
					}

					// Extract host if present (for file://host/path format, slashCount == 2)
					// For local file URIs (file:///path, slashCount >= 3), there is no host
					if slashCount == 2 {
						// Skip leading slashes after scheme
						hostStart := pathEnd
						for hostStart < len(path) && (path[hostStart] == '/' || path[hostStart] == '\\') {
							hostStart++
						}
						if hostStart < len(path) {
							// Find end of host (next separator)
							hostEnd := hostStart
							for hostEnd < len(path) && path[hostEnd] != '/' && path[hostEnd] != '\\' {
								hostEnd++
							}
							if hostEnd > hostStart {
								host = path[hostStart:hostEnd]
								pathEnd = hostEnd

								// Check if host is a Windows drive letter
								if len(host) == 2 && host[1] == ':' {
									// Windows drive as host, treat as local file URI
									pathType = PathTypeFileUriLocal
								}
								// RFC 8089: localhost, 127.0.0.1, [::1] are local hosts
								if isLocalhost(host) {
									pathType = PathTypeFileUriLocal
								}
							}
						}
					}


				// For local file URIs with Windows drive (file:///d:\path)
				// Or UNC format (files:////server/share/path)
				if slashCount >= 3 {
					hostStart := pathEnd
					for hostStart < len(path) && (path[hostStart] == '/' || path[hostStart] == '\\') {
						hostStart++
					}
					
					// Check for UNC format (files:////server/share/path, slashCount == 4)
					if slashCount == 4 && (strings.HasPrefix(scheme, "file://") || strings.HasPrefix(scheme, "files://")) {
						// Find end of host (next separator)
						hostEnd := hostStart
						for hostEnd < len(path) && path[hostEnd] != '/' && path[hostEnd] != '\\' {
							hostEnd++
						}
						if hostEnd > hostStart {
							host = path[hostStart:hostEnd]
							pathEnd = hostEnd
							pathType = PathTypeFileUriUnc
						}
					} else {
						// Check if path starts with Windows drive letter (X:)
						if hostStart+1 < len(path) && path[hostStart+1] == ':' {
							if (path[hostStart] >= 'A' && path[hostStart] <= 'Z') || (path[hostStart] >= 'a' && path[hostStart] <= 'z') {
								host = path[hostStart : hostStart+2]
								pathEnd = hostStart + 2
							}
						}
					}
				}
					return scheme, host, pathEnd, pathType
				}
				// Check for :\\\
				if path[schemeEnd+1] == '\\' && path[schemeEnd+2] == '\\' {
					// Count consecutive backslashes
					slashCount := 2
					for i := schemeEnd + 3; i < len(path) && (path[i] == '\\' || path[i] == '/'); i++ {
						slashCount++
					}
					// Scheme is always "scheme://" format
					scheme = strings.ReplaceAll(path[:schemeEnd+3], "\\", "/")
					pathEnd = schemeEnd + slashCount

					// Same logic for path type and host extraction
					if slashCount >= 3 {
						if strings.HasPrefix(scheme, "file://") || strings.HasPrefix(scheme, "files://") {
							pathType = PathTypeFileUriLocal
						} else {
							pathType = PathTypeCustomUri
						}
					} else {
						pathType = PathTypeFileUriRemote
					}

					// Extract host if present
					hostStart := pathEnd
					for hostStart < len(path) && (path[hostStart] == '/' || path[hostStart] == '\\') {
						hostStart++
					}
					if hostStart < len(path) {
						hostEnd := hostStart
						for hostEnd < len(path) && path[hostEnd] != '/' && path[hostEnd] != '\\' {
							hostEnd++
						}
						if hostEnd > hostStart {
							host = path[hostStart:hostEnd]
							pathEnd = hostEnd
							if len(host) == 2 && host[1] == ':' {
								pathType = PathTypeFileUriLocal
							}
							// RFC 8089: localhost, 127.0.0.1, [::1] are local hosts
							if isLocalhost(host) {
								pathType = PathTypeFileUriLocal
							}
						}
					}

					return scheme, host, pathEnd, pathType
				}
			}
			// Check for :/
			if len(path) > schemeEnd+1 && path[schemeEnd+1] == '/' {
				schemePrefix := path[:schemeEnd]
				// RFC 8089: file:/path is equivalent to file:///path (minimal representation)
				// Normalize file:/ and files:/ to file:/// and files:///
				if schemePrefix == "file" || schemePrefix == "files" {
					scheme = schemePrefix + "://"
					pathEnd = schemeEnd + 2
					pathType = PathTypeFileUriLocal
					return scheme, host, pathEnd, pathType
				}
				scheme = path[:schemeEnd+2]
				pathEnd = schemeEnd + 2
				pathType = PathTypeCustomUri
				return scheme, host, pathEnd, pathType
			}
			// scheme: without slashes
			scheme = path[:schemeEnd+1]
			pathEnd = schemeEnd + 1
			pathType = PathTypeCustomUri
			return scheme, host, pathEnd, pathType
		}
	}

	// 2. Check for UNC path (\\server\share\path)
	if len(path) >= 2 && path[0] == '\\' && path[1] == '\\' {
		// Check for \\?\ prefix (Windows extended-length path)
		if len(path) >= 4 && path[2] == '?' && path[3] == '\\' {
			// Check for \\?\C: (Windows drive)
			if len(path) >= 6 && path[5] == ':' {
				if (path[4] >= 'A' && path[4] <= 'Z') || (path[4] >= 'a' && path[4] <= 'z') {
					host = path[4:6]  // Preserve original case
					pathEnd = 6
					if len(path) > 6 && (path[6] == '\\' || path[6] == '/') {
						pathType = PathTypeLocalAbsolute
					} else {
						pathType = PathTypeLocalRelative
					}
					return "", host, pathEnd, pathType
				}
			}
			// \\?\\server\share\path -> treat as UNC path (skip \\?\)
			// Find server name after \\?\\
			if len(path) >= 6 && path[4] == '\\' {
				serverEnd := 5
				for serverEnd < len(path) && path[serverEnd] != '\\' {
					serverEnd++
				}
				if serverEnd > 5 {
					host = path[5:serverEnd]
				}
				pathEnd = serverEnd
				pathType = PathTypeUncWindows
				return "\\\\", host, pathEnd, pathType
			}
		}

		scheme = "\\\\"

		// Find server name
		serverEnd := 2
		for serverEnd < len(path) && path[serverEnd] != '\\' {
			serverEnd++
		}
		if serverEnd > 2 {
			host = path[2:serverEnd]
		}
		pathEnd = serverEnd
		pathType = PathTypeUncWindows

		return scheme, host, pathEnd, pathType
	}

	// 3. Check for Windows drive letter (C:\path or C:path)
	if len(path) >= 2 && path[1] == ':' {
		if (path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z') {
			host = path[0:2]  // Preserve original case
			pathEnd = 2

			// Check if it's absolute (has separator after drive letter)
			if len(path) > 2 && (path[2] == '\\' || path[2] == '/') {
				pathType = PathTypeLocalAbsolute
				// Don't skip the leading separator; let main loop handle it
				pathEnd = 2
			} else {
				pathType = PathTypeLocalRelative
			}

			return scheme, host, pathEnd, pathType
		}
	}

	// 4. Check for absolute Unix path
	if len(path) > 0 && path[0] == '/' {
		// Don't skip the leading slash; let main loop handle it
		pathEnd = 0
		pathType = PathTypeLocalAbsolute
		return scheme, host, pathEnd, pathType
	}

	// 5. Relative path
	pathType = PathTypeLocalRelative
	return scheme, host, pathEnd, pathType
}

// extractPrefixWithIndex extracts the path prefix and returns the end index.
// This avoids creating a new string for the remaining path.
func extractPrefixWithIndex(path string) (prefix string, endIndex int) {
	if len(path) == 0 {
		return "", 0
	}

	// 1. Check for URI scheme (scheme://, scheme:/, scheme:///)
	if schemeEnd := findURISchemeEnd(path); schemeEnd > 0 {
		if len(path) > schemeEnd && path[schemeEnd] == ':' {
			// Check for :// or :\\\ (URI with backslashes)
			if len(path) > schemeEnd+2 {
				// Check for ://
				if path[schemeEnd+1] == '/' && path[schemeEnd+2] == '/' {
					// Count consecutive slashes after ://
					slashCount := 2
					for i := schemeEnd + 3; i < len(path) && (path[i] == '/' || path[i] == '\\'); i++ {
						slashCount++
					}
					// Normalize: use :// for 2 slashes, :/// for 3 or more
					if slashCount >= 3 {
						return path[:schemeEnd+4], schemeEnd + slashCount
					}
					return path[:schemeEnd+3], schemeEnd + slashCount
				}
				// Check for :\\\ (backslash variant)
				if path[schemeEnd+1] == '\\' && path[schemeEnd+2] == '\\' {
					// Count consecutive backslashes
					slashCount := 2
					for i := schemeEnd + 3; i < len(path) && (path[i] == '\\' || path[i] == '/'); i++ {
						slashCount++
					}
					// Normalize: use :// for 2 slashes, :/// for 3 or more
					// Replace backslashes with forward slashes
					if slashCount >= 3 {
						return strings.ReplaceAll(path[:schemeEnd+4], "\\", "/"), schemeEnd + slashCount
					}
					return strings.ReplaceAll(path[:schemeEnd+3], "\\", "/"), schemeEnd + slashCount
				}
			}
			// Check for :/
			if len(path) > schemeEnd+1 && path[schemeEnd+1] == '/' {
				return path[:schemeEnd+2], schemeEnd + 2
			}
			// scheme:
			return path[:schemeEnd+1], schemeEnd + 1
		}
	}

	// 2. Check for UNC path (\\server\share\path)
	if len(path) >= 2 && path[0] == '\\' && path[1] == '\\' {
		slashIndex := strings.Index(path[2:], "\\")
		if slashIndex == -1 {
			return path, len(path)
		}
		serverEnd := 2 + slashIndex
		return path[:serverEnd], serverEnd
	}

	// 3. Check for Windows drive letter (C:\, d:\)
	if len(path) >= 2 && path[1] == ':' {
		c := path[0]
		if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') {
			return path[:2], 2
		}
	}

	// 4. No special prefix
	return "", 0
}

// findURISchemeEnd finds the end of a URI scheme in a string.
// Returns the index of the ':' character, or -1 if no scheme is found.
// For Windows drive paths (C:\path), returns -1 to avoid misidentification.
func findURISchemeEnd(path string) int {
	if len(path) == 0 {
		return -1
	}

	// First character must be ALPHA
	c := path[0]
	if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
		return -1
	}

	// Find the end of the scheme
	for i := 1; i < len(path); i++ {
		c := path[i]
		if c == ':' {
			// Check for Windows drive pattern: single letter followed by :
			// This includes both absolute paths (d:\a\b) and relative paths (d:a\b)
			if i == 1 {
				return -1 // Windows drive path, not a URI scheme
			}
			return i
		}
		// Check if character is valid for scheme
		if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
			(c >= '0' && c <= '9') || c == '+' || c == '-' || c == '.') {
			return -1
		}
	}

	return -1
}

// buildPath constructs a path string from prefix, parts, and separator.
func buildPath(prefix string, parts []string, separator rune) string {
	if len(parts) == 0 {
		return prefix
	}

	// Calculate total length for pre-allocation
	totalLen := len(prefix)
	for _, part := range parts {
		totalLen += len(part) + 1 // +1 for separator
	}

	var builder strings.Builder
	builder.Grow(totalLen)

	if prefix != "" {
		builder.WriteString(prefix)
	}

	// Add leading separator if first part is empty (absolute path)
	if len(parts) > 0 && parts[0] == "" {
		builder.WriteRune(separator)
	}

	// Add non-empty parts
	first := true
	for _, part := range parts {
		if part == "" {
			continue
		}
		if !first {
			builder.WriteRune(separator)
		}
		builder.WriteString(part)
		first = false
	}

	return builder.String()
}

// ==================== PathInfo Methods ====================

// Join adds new path components to the current PathInfo and returns a new PathInfo.
func (info *pathInfoImpl) Join(parts ...string) PathInfo {
	if len(parts) == 0 {
		return info
	}

	// Use internal parts (with leading empty string for absolute paths)
	partsToUse := info.parts
	if partsToUse == nil {
		partsToUse = []string{}
	}

	newParts := make([]string, 0, len(partsToUse)+len(parts))
	newParts = append(newParts, partsToUse...)
	newParts = append(newParts, parts...)

	return &pathInfoImpl{
		scheme:    info.scheme,
		host:      info.host,
		separator: info.separator,
		parts:     newParts,
		pathType:  info.pathType,
	}
}

// ContainsPath checks if the given path is contained within the current path.
// This includes both sub-paths and the same path.
//
// A path is contained if:
//   - It has the same scheme and host
//   - It has the same path components (same path)
//   - Or it has more path components starting with the current path's components (sub-path)
//
// Special cases:
//   - Root path "/" contains all absolute paths with the same scheme and host
//   - Empty base path never contains any path
//   - Empty other path is never contained
func (info *pathInfoImpl) ContainsPath(otherPath string) bool {
	otherInfo, err := ParsePathInfo(otherPath)
	if err != nil {
		return false
	}

	return info.ContainsPathInfo(otherInfo)
}

// ContainsPathInfo checks if the given PathInfo is contained within the current path.
func (info *pathInfoImpl) ContainsPathInfo(otherInfo PathInfo) bool {
	if otherInfo == nil {
		return false
	}

	// Empty paths are never valid
	if len(info.Parts()) == 0 || len(otherInfo.Parts()) == 0 {
		return false
	}

	// Scheme and host must match
	if info.Scheme() != otherInfo.Scheme() || info.Host() != otherInfo.Host() {
		return false
	}

	// Check if current path is root
	isRoot := len(info.Parts()) == 1 && info.Parts()[0] == "" ||
		(len(info.Parts()) == 2 && info.Parts()[0] == "" && info.Parts()[1] == "")
	if isRoot {
		// Check if otherPath is also root (same path)
		otherIsRoot := len(otherInfo.Parts()) == 1 && otherInfo.Parts()[0] == "" ||
			(len(otherInfo.Parts()) == 2 && otherInfo.Parts()[0] == "" && otherInfo.Parts()[1] == "")
		if otherIsRoot {
			return true // Root contains itself
		}
		// Check if otherPath has non-empty parts (sub-path)
		for _, part := range otherInfo.Parts() {
			if part != "" {
				return true
			}
		}
		return false
	}

	// Check if same path (same number of parts, all match)
	if len(info.Parts()) == len(otherInfo.Parts()) {
		for i := 0; i < len(info.Parts()); i++ {
			if info.Parts()[i] != otherInfo.Parts()[i] {
				return false
			}
		}
		return true
	}

	// Check if sub-path (other has more parts, current parts match)
	if len(otherInfo.Parts()) > len(info.Parts()) {
		for i := 0; i < len(info.Parts()); i++ {
			if info.Parts()[i] != otherInfo.Parts()[i] {
				return false
			}
		}
		return true
	}

	// Other path has fewer parts, cannot be contained
	return false
}

// ReplaceParts creates a new PathInfo with replaced path parts.
func (info *pathInfoImpl) ReplaceParts(newParts []string) PathInfo {
	// For absolute paths, ensure leading empty string is present
	if info.isAbsolutePath() && (len(newParts) == 0 || newParts[0] != "") {
		newParts = append([]string{""}, newParts...)
	}

	return &pathInfoImpl{
		scheme:    info.scheme,
		host:      info.host,
		separator: info.separator,
		parts:     newParts,
		pathType:  info.pathType,
	}
}

// ==================== PathClean (optimized) ====================

// PathClean cleans a path by removing redundant elements.
// This is now a wrapper around ParsePathInfo for consistency and performance.
func PathClean(path string) string {
	if path == "" {
		return ""
	}
	return ParsePathInfoMust(path).Encode()
}

// ==================== Localhost Detection ====================

// isLocalhost checks if a host string represents the local machine.
// Returns true for:
//   - "localhost" (case-insensitive)
//   - IPv4 loopback addresses (127.0.0.0/8)
//   - IPv6 loopback address [::1]
func isLocalhost(host string) bool {
	if host == "" {
		return false
	}
	
	// Check for localhost (case-insensitive)
	if strings.EqualFold(host, "localhost") {
		return true
	}
	
	// Check for IPv4 loopback (127.0.0.0/8)
	if strings.HasPrefix(host, "127.") {
		return true
	}
	
	// Check for IPv6 loopback [::1]
	if host == "[::1]" {
		return true
	}
	
	return false
}
