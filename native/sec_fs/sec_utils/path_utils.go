// Package sec_utils provides utilities for secure file system operations.
// This file contains utility functions for path processing.
package sec_utils

import (
	"path/filepath"
	"strings"
)

// ==================== Path Info ====================

// PathInfo is an interface for parsed path information.
// It provides lazy computation and caching for performance.
//
// Usage analysis shows:
//   - Path (34 uses) and Parts (18 uses) are most frequently accessed
//   - Original (1 use) and IsAbs (1 use) are rarely used
//
// This design uses an interface to hide implementation details and allow
// for different implementations in the future.
type PathInfo interface {
	// RawPath returns the raw input path (before cleaning).
	RawPath() string
	// Original returns the cleaned path string.
	Original() string
	// Prefix returns the path prefix (URI, UNC, drive letter, etc.).
	Prefix() string
	// Path returns the actual path part (without prefix).
	Path() string
	// Separator returns the path separator ('/' or '\\').
	Separator() rune
	// Parts returns the path components (split by separator, cleaned).
	Parts() []string
	// IsAbs returns whether this is an absolute path.
	IsAbs() bool
	// Encode returns the full path string.
	Encode() string
	// Join adds new path components and returns a new PathInfo.
	Join(parts ...string) PathInfo
	// ContainsPath checks if the given path is contained within this path.
	ContainsPath(otherPath interface{}) bool
	// ReplaceParts creates a new PathInfo with replaced path parts.
	ReplaceParts(newParts []string) PathInfo
}

// pathInfoImpl is the concrete implementation of PathInfo.
// Fields are lazily computed and cached for performance.
type pathInfoImpl struct {
	// Initialized fields (always available)
	prefix    string   // Path prefix (URI, UNC, Windows drive letter, etc.)
	separator rune     // Path separator ('/' or '\\')
	parts     []string // Path components (split by separator, cleaned)
	
	// Lazily computed fields (nil until first access)
	original  *string // Cleaned path string (cached)
	path      *string // Actual path part without prefix (cached)
}

// RawPath returns the raw input path (before cleaning).
// Since rawPath field is removed for memory optimization, this returns Original().
func (info *pathInfoImpl) RawPath() string {
	return info.Original()
}

// Original returns the cleaned path string.
// This is computed lazily and cached.
func (info *pathInfoImpl) Original() string {
	if info == nil {
		return ""
	}
	if info.original == nil {
		cleaned := buildPath(info.prefix, info.parts, info.separator)
		info.original = &cleaned
	}
	return *info.original
}

// Prefix returns the path prefix (URI, UNC, drive letter, etc.).
func (info *pathInfoImpl) Prefix() string {
	if info == nil {
		return ""
	}
	return info.prefix
}

// Path returns the actual path part (without prefix).
// This is computed lazily and cached.
func (info *pathInfoImpl) Path() string {
	if info == nil {
		return ""
	}
	if info.path == nil {
		actualPath := buildPath("", info.parts, info.separator)
		info.path = &actualPath
	}
	return *info.path
}

// Separator returns the path separator ('/' or '\\').
func (info *pathInfoImpl) Separator() rune {
	if info == nil {
		return filepath.Separator
	}
	return info.separator
}

// Parts returns the path components (split by separator, cleaned).
func (info *pathInfoImpl) Parts() []string {
	if info == nil {
		return nil
	}
	return info.parts
}

// IsAbs returns whether this is an absolute path.
func (info *pathInfoImpl) IsAbs() bool {
	if info == nil {
		return false
	}
	return len(info.parts) > 0 && info.parts[0] == ""
}

// Encode returns the full path string.
// This is equivalent to Original().
func (info *pathInfoImpl) Encode() string {
	return info.Original()
}

// ParsePathInfo parses a path and returns all information in one call.
// This function is optimized to parse the path in a single pass, combining:
//   - Prefix detection (URI, UNC, drive letter)
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
			separator: filepath.Separator,
		}, nil
	}

	// Single-pass parsing: extract prefix, detect separator, split and clean path
	prefix, separator, parts, _ := parsePathOnce(path)

	// Only initialize essential fields; others are lazily computed
	return &pathInfoImpl{
		prefix:    prefix,
		separator: separator,
		parts:     parts,
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
// It extracts prefix, detects separator, splits and cleans the path in one traversal.
// Optimized to avoid unnecessary string allocations.
func parsePathOnce(path string) (prefix string, separator rune, parts []string, isAbs bool) {
	// Default separator
	separator = filepath.Separator

	// Step 1: Extract prefix (URI, UNC, drive letter)
	var prefixEnd int
	prefix, prefixEnd = extractPrefixWithIndex(path)

	// Step 2: Handle empty path after prefix
	if prefixEnd >= len(path) {
		return prefix, separator, parts, isAbs
	}

	// Step 3: Check if prefix is URI (URI always uses '/' as separator)
	isURI := strings.HasPrefix(prefix, "file://") || strings.HasPrefix(prefix, "files://") || 
			(strings.Contains(prefix, "://") && !strings.HasPrefix(prefix, "\\\\"))
	if isURI {
		separator = '/'
	}

	// Step 4: Skip leading separators after prefix (for URI with multiple slashes)
	if isURI {
		for prefixEnd < len(path) && (path[prefixEnd] == '/' || path[prefixEnd] == '\\') {
			prefixEnd++
		}
	}

	// Step 5: Manual split and clean in one pass
	// Pre-allocate parts with estimated capacity
	parts = make([]string, 0, 16)
	
	start := prefixEnd
	firstPart := true
	
	for i := prefixEnd; i <= len(path); i++ {
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
			} else if start == prefixEnd && i == prefixEnd && !isURI {
				// Empty first part means absolute path (only for non-URI paths)
				isAbs = true
				parts = append(parts, "")
			}
			start = i + 1
		}
	}

	// Handle trailing separator (root path case)
	if len(parts) == 1 && parts[0] == "" && len(path) > prefixEnd {
		// Root path: add empty second part
		parts = append(parts, "")
	}

	return prefix, separator, parts, isAbs
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

	newParts := make([]string, 0, len(info.Parts())+len(parts))
	newParts = append(newParts, info.Parts()...)
	newParts = append(newParts, parts...)

	newPath := buildPath("", newParts, info.Separator())
	return ParsePathInfoMust(info.Prefix() + newPath)
}

// ContainsPath checks if the given path is contained within the current path.
// This includes both sub-paths and the same path.
//
// A path is contained if:
//   - It has the same prefix (URI, UNC, drive letter, etc.)
//   - It has the same path components (same path)
//   - Or it has more path components starting with the current path's components (sub-path)
//
// Special cases:
//   - Root path "/" contains all absolute paths with the same prefix
//   - Empty base path never contains any path
//   - Empty other path is never contained
//
// Parameters:
//   - otherPath: The path to check (can be string or *PathInfo)
//
// Returns:
//   - bool: true if otherPath is a sub-path or the same as the current path
func (info *pathInfoImpl) ContainsPath(otherPath interface{}) bool {
	var otherInfo PathInfo

	switch v := otherPath.(type) {
	case string:
		var err error
		otherInfo, err = ParsePathInfo(v)
		if err != nil {
			return false
		}
	case PathInfo:
		otherInfo = v
	default:
		return false
	}

	// Empty paths are never valid
	if len(info.Parts()) == 0 || len(otherInfo.Parts()) == 0 {
		return false
	}

	// Prefix must match
	if info.Prefix() != otherInfo.Prefix() {
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
	return &pathInfoImpl{
		prefix:    info.Prefix(),
		separator: info.Separator(),
		parts:     newParts,
	}
}

// ==================== PathClean (optimized) ====================

// PathClean cleans a path by removing redundant elements.
// This is now a wrapper around ParsePathInfo for consistency and performance.
func PathClean(path string) string {
	if path == "" {
		return ""
	}
	return ParsePathInfoMust(path).Original()
}
