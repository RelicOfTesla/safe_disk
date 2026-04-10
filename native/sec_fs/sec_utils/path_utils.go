// Package sec_utils provides utilities for secure file system operations.
// This file contains utility functions for path processing.
package sec_utils

import (
	"path/filepath"
	"strings"
)

// ==================== Path Info ====================

// PathInfo contains parsed information about a path.
type PathInfo struct {
	RawPath   string    // Raw input path (before cleaning)
	Original  string    // Cleaned path string
	Prefix    string    // Path prefix (URI, UNC, Windows drive letter, etc.)
	Path      string    // Actual path part (without prefix)
	Separator rune      // Path separator ('/' or '\\')
	Parts     []string  // Path components (split by separator)
	IsAbs     bool      // Whether this is an absolute path
}

// ParsePathInfo parses a path and returns all information in one call.
// This is more efficient than calling ParsePathPrefix, DetectPathSeparator, and SplitPath separately.
// The path is cleaned before parsing (removing redundant . and .., consecutive separators, etc.)
//
// Parameters:
//   - path: The path to parse
//
// Returns:
//   - *PathInfo: Parsed path information (nil if path is empty)
func ParsePathInfo(path string) *PathInfo {
	if path == "" {
		return &PathInfo{
			Separator: filepath.Separator,
		}
	}

	// Clean the path first
	cleanedPath := PathClean(path)

	// Parse prefix
	prefix, actualPath := ParsePathPrefix(cleanedPath)

	// Detect separator
	separator := DetectPathSeparator(cleanedPath)

	// Split path into components
	parts := SplitPath(actualPath)

	// Determine if absolute path
	isAbs := len(parts) > 0 && parts[0] == ""

	return &PathInfo{
		RawPath:   path,
		Original:  cleanedPath,
		Prefix:    prefix,
		Path:      actualPath,
		Separator: separator,
		Parts:     parts,
		IsAbs:     isAbs,
	}
}

// Join adds new path components to the current PathInfo and returns a new PathInfo.
// The new components are joined using the current separator.
// This method does not modify the original PathInfo.
//
// Parameters:
//   - parts: Path components to add
//
// Returns:
//   - *PathInfo: New PathInfo with the added components
func (info *PathInfo) Join(parts ...string) *PathInfo {
	if len(parts) == 0 {
		return info
	}

	// Join the new parts
	newParts := make([]string, 0, len(info.Parts)+len(parts))
	newParts = append(newParts, info.Parts...)
	newParts = append(newParts, parts...)

	// Build the new path
	newPath := JoinPathWithSeparator(newParts, info.Separator)

	// Parse the new path
	return ParsePathInfo(info.Prefix + newPath)
}

// Encode returns the full path string from the PathInfo.
// It reconstructs the path by combining Prefix and Path using the Separator.
//
// Returns:
//   - string: The encoded full path
func (info *PathInfo) Encode() string {
	if info.Prefix == "" && info.Path == "" {
		return ""
	}
	return info.Prefix + info.Path
}

// ReplaceParts creates a new PathInfo with replaced path parts.
// This is useful for encryption/decryption operations where each part
// needs to be transformed individually.
func (info *PathInfo) ReplaceParts(newParts []string) *PathInfo {
	newPath := JoinPathWithSeparator(newParts, info.Separator)
	return &PathInfo{
		RawPath:   info.RawPath,
		Original:  info.Prefix + newPath,
		Prefix:    info.Prefix,
		Path:      newPath,
		Separator: info.Separator,
		Parts:     newParts,
		IsAbs:     info.IsAbs,
	}
}

// ==================== Path Parsing Utilities ====================

// ParsePathPrefix extracts path prefix from various path formats.
// Returns the prefix and the remaining path.
// Supported formats:
//   - URI: "scheme://path" or "scheme:///path" -> ("scheme://", "path")
//   - UNC: "\\server\share\path" -> ("\\server\", "share\path")
//   - Windows drive: "C:\path", "d:\path" -> ("C:", "\path")
//   - Unix absolute: "/path" -> ("", "/path")
func ParsePathPrefix(path string) (prefix string, remainingPath string) {
	if path == "" {
		return "", ""
	}

	// 1. Check for URI schemes (any scheme:// or scheme:/ or scheme:///)
	// URI scheme format: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
	// See RFC 3986 for URI syntax
	if schemeEnd := FindURISchemeEnd(path); schemeEnd > 0 {
		// Found a URI scheme
		// Check for :// or :/
		if len(path) > schemeEnd+1 && path[schemeEnd] == ':' {
			// Check for ://
			if len(path) > schemeEnd+2 && path[schemeEnd+1] == '/' && path[schemeEnd+2] == '/' {
				// Found scheme://
				// Check if there's a third / (scheme:///)
				if len(path) > schemeEnd+3 && path[schemeEnd+3] == '/' {
					// scheme:/// - return scheme:/// as prefix
					return path[:schemeEnd+4], path[schemeEnd+4:]
				}
				// scheme:// - return scheme:// as prefix
				return path[:schemeEnd+3], path[schemeEnd+3:]
			}
			// Check for :/
			if len(path) > schemeEnd+1 && path[schemeEnd+1] == '/' {
				// scheme:/ - return scheme:/ as prefix
				return path[:schemeEnd+2], path[schemeEnd+2:]
			}
			// Just scheme: - return scheme: as prefix
			return path[:schemeEnd+1], path[schemeEnd+1:]
		}
	}

	// 2. Check for UNC path (\\server\share\path)
	if len(path) >= 2 && path[0] == '\\' && path[1] == '\\' {
		// Find the server name (second backslash or end)
		slashIndex := strings.Index(path[2:], "\\")
		if slashIndex == -1 {
			// Only server name, no share
			return path, ""
		}
		// Return \\server\ as prefix
		serverEnd := 2 + slashIndex
		return path[:serverEnd], path[serverEnd:]
	}

	// 3. Check for Windows drive letter (C:\, d:\, etc.)
	if len(path) >= 2 && path[1] == ':' {
		c := path[0]
		if (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') {
			// Found drive letter, return "C:" or "d:" as prefix
			return path[:2], path[2:]
		}
	}

	// 4. No special prefix
	return "", path
}

// FindURISchemeEnd finds the end of a URI scheme in a string.
// Returns the index of the ':' character, or -1 if no scheme is found.
// URI scheme format: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
func FindURISchemeEnd(path string) int {
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

// DetectPathSeparator detects the primary path separator used in a path.
// Returns '\' for Windows-style paths, '/' for Unix-style paths.
// If the path contains both, it returns the first one found in the path portion.
// If the path contains no separators, it returns the OS default.
//
// Note: For URI paths, this function ignores the URI scheme portion and only
// detects separators in the actual path part.
func DetectPathSeparator(path string) rune {
	// Extract the actual path portion (without URI prefix, UNC prefix, or drive letter)
	_, actualPath := ParsePathPrefix(path)
	
	// Detect separator in the actual path portion
	for _, c := range actualPath {
		if c == '\\' {
			return '\\'
		}
		if c == '/' {
			return '/'
		}
	}
	
	// If no separator in actual path, check the prefix portion
	// (e.g., for URI like "file:///" the separator is in the prefix)
	for _, c := range path {
		if c == '\\' {
			return '\\'
		}
		if c == '/' {
			return '/'
		}
	}
	
	// No separator found, use OS default
	return filepath.Separator
}

// SplitPath splits a path into components, handling both Unix (/) and Windows (\) separators.
// It preserves the separator information for later reconstruction.
func SplitPath(path string) []string {
	if path == "" {
		return nil
	}

	// Replace all backslashes with forward slashes for consistent splitting
	normalized := strings.ReplaceAll(path, "\\", "/")
	return strings.Split(normalized, "/")
}

// JoinPathWithSeparator joins path components using the specified separator.
// This allows preserving the original path separator style.
func JoinPathWithSeparator(parts []string, separator rune) string {
	if len(parts) == 0 {
		return ""
	}

	// Build the path
	result := ""
	
	// Add leading separator if first part is empty (absolute path)
	if len(parts) > 0 && parts[0] == "" {
		result = string(separator)
	}
	
	// Join non-empty parts
	for i, part := range parts {
		if part == "" {
			// Skip empty parts (already handled leading separator above)
			continue
		}
		
		if i > 0 && result != "" && !strings.HasSuffix(result, string(separator)) {
			result += string(separator)
		}
		result += part
	}
	
	return result
}

// joinPath joins path components using the OS default separator.
// Deprecated: Use JoinPathWithSeparator for cross-platform compatibility.
func joinPath(parts []string) string {
	return JoinPathWithSeparator(parts, filepath.Separator)
}

// PathClean cleans a path by removing redundant elements.
// It handles:
//   - Mixed path separators (/ and \)
//   - Consecutive separators
//   - Current directory (.)
//   - Parent directory (..)
//   - Path prefixes (URI, UNC, Windows drive letters)
//
// This function is similar to path.Clean() or filepath.Clean(), but supports:
//   - Any URI scheme (scheme://, scheme:///)
//   - UNC paths (\\server\share\path)
//   - Windows drive letters (C:\, d:\)
//   - Mixed separators
//
// Parameters:
//   - path: The path to clean
//
// Returns:
//   - The cleaned path
func PathClean(path string) string {
	if path == "" {
		return ""
	}

	// Detect the path separator used in the input
	separator := DetectPathSeparator(path)

	// Extract path prefix (URI, UNC, drive letter) if present
	pathPrefix, actualPath := ParsePathPrefix(path)

	// Split path into components (handles both / and \)
	parts := SplitPath(actualPath)

	// Clean the path components
	cleanedParts := make([]string, 0, len(parts))
	for _, part := range parts {
		switch part {
		case "":
			// Empty part (from consecutive separators or leading separator)
			// Skip for consecutive separators, but keep for leading separator
			if len(cleanedParts) == 0 {
				// Keep leading empty part (indicates absolute path)
				cleanedParts = append(cleanedParts, part)
			}
		case ".":
			// Current directory - skip
			continue
		case "..":
			// Parent directory
			if len(cleanedParts) > 0 {
				lastIdx := len(cleanedParts) - 1
				// Don't remove leading empty part (absolute path indicator)
				// Don't remove previous .. either
				if cleanedParts[lastIdx] != "" && cleanedParts[lastIdx] != ".." {
					cleanedParts = cleanedParts[:lastIdx]
				} else {
					// Can't go up, keep the ..
					cleanedParts = append(cleanedParts, part)
				}
			} else {
				// No previous component, keep the ..
				cleanedParts = append(cleanedParts, part)
			}
		default:
			// Normal path component
			cleanedParts = append(cleanedParts, part)
		}
	}

	// Join the cleaned parts
	result := JoinPathWithSeparator(cleanedParts, separator)

	// Restore path prefix if present
	if pathPrefix != "" {
		result = pathPrefix + result
	}

	return result
}
