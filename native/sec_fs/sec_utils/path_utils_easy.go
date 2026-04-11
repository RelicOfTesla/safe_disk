// Package sec_utils provides utilities for secure file system operations.
// This file contains the "easy" implementation of path utilities.
// The implementation is straightforward and easy to understand.
package sec_utils

import (
	"errors"
	"strings"
	"sync"
)

// ==================== Scheme Behavior Configuration ====================

// SchemeBehavior defines how a URI scheme should be parsed.
// This controls whether the scheme follows RFC 3986 authority semantics.
type SchemeBehavior struct {
	// MustFollowRFC3986Authority indicates whether the scheme must follow
	// RFC 3986 authority semantics (scheme://host/path).
	// When true, scheme:///path means empty host + absolute path.
	// When false, the interpretation is scheme-specific.
	MustFollowRFC3986Authority bool
}

// DefaultSchemeBehavior is the default behavior for unknown schemes.
var DefaultSchemeBehavior = SchemeBehavior{
	MustFollowRFC3986Authority: false, // Default: do not force RFC 3986 authority
}

// Standard schemes that follow RFC 3986 authority semantics
var standardRFC3986Schemes = map[string]struct{}{
	"http":    {},
	"https":   {},
	"file":    {},
	"files":   {},
	"ftp":     {},
	"sftp":    {},
	"ssh":     {},
	"ws":      {},
	"wss":     {},
	"git":     {},
	"svn":     {},
	"svn+ssh": {},
	"dav":     {},
	"davs":    {},
}

// schemeRegistry holds registered scheme behaviors.
// Schemes are stored in lowercase for case-insensitive lookup.
var schemeRegistry = struct {
	sync.RWMutex
	behaviors map[string]SchemeBehavior
}{
	behaviors: make(map[string]SchemeBehavior),
}

// RegisterScheme registers a scheme with its behavior.
// The scheme name is case-insensitive (stored as lowercase).
func RegisterScheme(scheme string, behavior SchemeBehavior) {
	schemeRegistry.Lock()
	defer schemeRegistry.Unlock()
	schemeRegistry.behaviors[strings.ToLower(scheme)] = behavior
}

// GetSchemeBehavior returns the behavior for a scheme.
// If the scheme is not registered, it checks standard RFC 3986 schemes first,
// then returns DefaultSchemeBehavior.
func GetSchemeBehavior(scheme string) SchemeBehavior {
	schemeLower := strings.ToLower(scheme)

	// Check if registered
	schemeRegistry.RLock()
	if behavior, ok := schemeRegistry.behaviors[schemeLower]; ok {
		schemeRegistry.RUnlock()
		return behavior
	}
	schemeRegistry.RUnlock()

	// Check standard RFC 3986 schemes
	if _, ok := standardRFC3986Schemes[schemeLower]; ok {
		return SchemeBehavior{MustFollowRFC3986Authority: true}
	}

	// Return default behavior
	return DefaultSchemeBehavior
}

// SetDefaultSchemeBehavior sets the default behavior for unknown schemes.
func SetDefaultSchemeBehavior(behavior SchemeBehavior) {
	DefaultSchemeBehavior = behavior
}

// ==================== Parse Options ====================

// ParseOptions holds options for path parsing.
type ParseOptions struct {
	// OverrideSchemeBehavior forces a specific behavior for all schemes,
	// ignoring registered behaviors. Use nil to use default behavior.
	OverrideSchemeBehavior *SchemeBehavior
}

// DefaultParseOptions is the default parse options.
var DefaultParseOptions = ParseOptions{}

// ParseOption is a functional option for configuring ParseOptions.
type ParseOption func(*ParseOptions)

// WithSchemeBehaviorOverride sets a behavior override for all schemes.
func WithSchemeBehaviorOverride(behavior SchemeBehavior) ParseOption {
	return func(opts *ParseOptions) {
		opts.OverrideSchemeBehavior = &behavior
	}
}

// applyParseOptions applies functional options to ParseOptions.
func applyParseOptions(options ...ParseOption) ParseOptions {
	opts := DefaultParseOptions
	for _, option := range options {
		option(&opts)
	}
	return opts
}

// ==================== Helper Functions ====================

// isWindowsDriveString checks if a string is a Windows drive letter (e.g., "C:").
func isWindowsDriveString(s string) bool {
	return len(s) == 2 && s[1] == ':' && isEnglishLetter(s[0])
}

// isFileURIScheme checks if the scheme is a file:// or files:// scheme.
func isFileURIScheme(scheme string) bool {
	return scheme == "file://" || scheme == "files://"
}

// isURIScheme checks if the scheme is a URI scheme (ends with ://).
func isURIScheme(scheme string) bool {
	return len(scheme) > 3 && strings.HasSuffix(scheme, "://") && scheme != `\\`
}

// ==================== Path Info Implementation ====================

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

// IsRelative returns whether this is a relative path.
func (info *pathInfoImpl) IsRelative() bool {
	if info == nil {
		return false
	}
	return info.pathType == PathTypeLocalRelative
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
				if isWindowsDriveString(info.host) {
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

	// For file:// and files:// schemes, if there's no path, add a root separator
	// This ensures file: and file:// are normalized to file:///
	// According to RFC 8089, file: is equivalent to file:///
	if (info.scheme == "file://" || info.scheme == "files://") && len(info.parts) == 0 {
		result.WriteString("/")
	}

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
	otherInfo, err := ParsePathInfoEasy(otherPath)
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

	// Special case: empty paths (current directory ".") should contain themselves
	// When both paths have empty parts, they are both the current directory
	if len(info.Parts()) == 0 && len(otherInfo.Parts()) == 0 {
		// Both are current directory - they should be equal
		return info.Encode() == otherInfo.Encode()
	}

	// Empty paths are never valid (after the above check)
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
	// Check if original parts has leading empty string (absolute path indicator)
	if len(info.parts) > 0 && info.parts[0] == "" && (len(newParts) == 0 || newParts[0] != "") {
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

// ==================== ParsePathInfoEasy ====================

// ParsePathInfoWithOptions parses a path with custom options and returns all information in one call.
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
//   - options: Functional options for customizing parsing behavior
//
// Returns:
//   - PathInfo: Parsed path information (nil if path is empty)
//   - error: Returns error for invalid paths
func ParsePathInfoWithOptions(path string, options ...ParseOption) (PathInfo, error) {
	opts := applyParseOptions(options...)

	if path == "" {
		return &pathInfoImpl{
			separator: DefaultSystemSeparator,
		}, nil
	}

	// Single-pass parsing: extract scheme, host, detect separator, split and clean path
	scheme, host, separator, parts, pathType := parsePathOnce(path, opts)

	// Validate: check for invalid drive letter in the middle of path
	// Example: d:\a:\b is invalid because a: appears in the middle
	for _, part := range parts {
		if isWindowsDriveString(part) {
			return nil, errors.New("invalid path: drive letter cannot appear in the middle of path")
		}
	}

	// Validate: Windows drive-relative path (d:a\b) is not supported
	// Drive-relative path has a drive letter but no separator after it
	if isWindowsDriveString(host) && pathType == PathTypeLocalRelative && len(parts) > 0 {
		return nil, errors.New("invalid path: Windows drive-relative path (d:a\\b) is not supported")
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

// ParsePathInfoEasy parses a path and returns all information in one call.
// This is a convenience wrapper around ParsePathInfoWithOptions with default options.
//
// Parameters:
//   - path: The path to parse
//
// Returns:
//   - PathInfo: Parsed path information (nil if path is empty)
//   - error: Returns error for invalid paths
func ParsePathInfoEasy(path string) (PathInfo, error) {
	return ParsePathInfoWithOptions(path)
}

// ParsePathInfoEasyMust is like ParsePathInfoEasy but panics if an error occurs.
// This is useful for cases where the path is guaranteed to be valid,
// such as hardcoded paths or paths that have been validated elsewhere.
func ParsePathInfoEasyMust(path string) PathInfo {
	info, err := ParsePathInfoEasy(path)
	if err != nil {
		panic(err)
	}
	return info
}

// parsePathOnce performs single-pass path parsing.
// It extracts scheme, host, detects separator, splits and cleans the path in one traversal.
// Optimized to avoid unnecessary string allocations.
func parsePathOnce(path string, opts ParseOptions) (scheme string, host string, separator rune, parts []string, pathType PathType) {
	// Default separator
	separator = DefaultSystemSeparator

	// Step 1: Extract scheme and host (URI, UNC, drive letter)
	var pathEnd int
	scheme, host, pathEnd, pathType = extractSchemeAndHost(path, opts)

	// Step 2: Handle empty path after scheme
	if pathEnd >= len(path) {
		return scheme, host, separator, parts, pathType
	}

	// Step 3: Check if scheme is URI (URI always uses '/' as separator)
	// Cache the scheme checks to avoid repeated HasPrefix calls
	isFileScheme := isFileURIScheme(scheme)
	isURI := isFileScheme || isURIScheme(scheme)
	if isURI {
		separator = '/'
	}

	// Step 4: Skip leading separators after scheme (for URI with multiple slashes)
	// Save original pathEnd for root path detection
	originalPathEnd := pathEnd
	if isURI {
		for pathEnd < len(path) && (path[pathEnd] == '/' || path[pathEnd] == '\\') {
			pathEnd++
		}
	}

	// Step 5: Manual split and clean in one pass
	// Pre-allocate parts with estimated capacity based on path length
	estimatedParts := (len(path)-pathEnd)/8 + 4
	if estimatedParts > 32 {
		estimatedParts = 32
	}
	parts = make([]string, 0, estimatedParts)

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
	// Use originalPathEnd to check if there was content after scheme/host
	if len(parts) == 0 && len(path) > originalPathEnd && pathType != PathTypeLocalRelative && pathType != PathTypeUnknown {
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

// getEffectiveSchemeBehavior returns the effective scheme behavior considering overrides.
// If opts.OverrideSchemeBehavior is set, it returns that override.
// Otherwise, it returns the behavior from GetSchemeBehavior.
func getEffectiveSchemeBehavior(scheme string, opts ParseOptions) SchemeBehavior {
	if opts.OverrideSchemeBehavior != nil {
		return *opts.OverrideSchemeBehavior
	}
	return GetSchemeBehavior(scheme)
}

// ==================== URI Scheme Extraction ====================

// extractURIScheme extracts URI scheme from path.
// Handles: scheme://host/path, scheme:///path, scheme:/path, scheme:
func extractURIScheme(path string, opts ParseOptions) (scheme string, host string, pathEnd int, pathType PathType) {
	schemeEnd := findURISchemeEnd(path)
	if schemeEnd <= 0 || len(path) <= schemeEnd || path[schemeEnd] != ':' {
		return "", "", 0, PathTypeUnknown
	}

	// Check for :// or :\\
	if len(path) > schemeEnd+2 {
		// Try :// pattern
		if path[schemeEnd+1] == '/' && path[schemeEnd+2] == '/' {
			return extractURISchemeWithSlashes(path, schemeEnd, '/', opts)
		}
		// Try :\\ pattern (backslash variant)
		if path[schemeEnd+1] == '\\' && path[schemeEnd+2] == '\\' {
			return extractURISchemeWithSlashes(path, schemeEnd, '\\', opts)
		}
	}

	// Check for :/ (single slash)
	if len(path) > schemeEnd+1 && path[schemeEnd+1] == '/' {
		return extractURISchemeWithSingleSlash(path, schemeEnd, opts)
	}

	// scheme: without slashes
	return extractURISchemeWithoutSlashes(path, schemeEnd, opts)
}

// extractURISchemeWithSlashes handles scheme:// or scheme:\\ patterns.
func extractURISchemeWithSlashes(path string, schemeEnd int, sep byte, opts ParseOptions) (scheme string, host string, pathEnd int, pathType PathType) {
	// Count consecutive slashes after :// or :\\
	slashCount := 2
	for i := schemeEnd + 3; i < len(path) && (path[i] == '/' || path[i] == '\\'); i++ {
		slashCount++
	}

	// Normalize scheme to always use forward slashes
	scheme = path[:schemeEnd+3]
	if sep == '\\' {
		scheme = strings.ReplaceAll(scheme, `\`, "/")
	}
	pathEnd = schemeEnd + slashCount

	// Determine if this is a file scheme
	isFileScheme := scheme == "file://" || scheme == "files://"

	// Get scheme behavior
	schemePrefix := strings.TrimSuffix(scheme, "://")
	behavior := getEffectiveSchemeBehavior(schemePrefix, opts)

	// Determine path type based on slash count and scheme behavior
	if slashCount >= 3 {
		// file:/// or files:/// is local file URI
		if isFileScheme {
			pathType = PathTypeFileUriLocal
		} else if behavior.MustFollowRFC3986Authority {
			// For RFC 3986 schemes with 3+ slashes, it's a local path (empty host)
			pathType = PathTypeCustomUri
		} else {
			pathType = PathTypeCustomUri
		}
		// Check for UNC format (files:////server/share/path) or Windows drive
		if host, pathEnd, pathType = extractHostForMultiSlashURI(path, pathEnd, slashCount, isFileScheme, behavior); host != "" {
			return scheme, host, pathEnd, pathType
		}
	} else {
		// slashCount == 2: file://host/path or custom://host/path
		if isFileScheme {
			pathType = PathTypeFileUriRemote
		} else {
			pathType = PathTypeCustomUri
		}
		// Extract host for 2-slash URI
		if host, pathEnd, pathType = extractHostForTwoSlashURI(path, pathEnd, isFileScheme, behavior); host != "" {
			return scheme, host, pathEnd, pathType
		}
	}

	return scheme, host, pathEnd, pathType
}

// extractHostForTwoSlashURI extracts host from URI with 2 slashes (scheme://host/path).
func extractHostForTwoSlashURI(path string, pathEnd int, isFileScheme bool, behavior SchemeBehavior) (host string, newPathEnd int, pathType PathType) {
	// If not following RFC 3986 authority semantics, do not extract host
	// All content after scheme:// is treated as path
	if !behavior.MustFollowRFC3986Authority {
		// Skip leading slashes after scheme
		pathStart := pathEnd
		for pathStart < len(path) && (path[pathStart] == '/' || path[pathStart] == '\\') {
			pathStart++
		}
		return "", pathStart, PathTypeCustomUri
	}

	// Skip leading slashes after scheme
	hostStart := pathEnd
	for hostStart < len(path) && (path[hostStart] == '/' || path[hostStart] == '\\') {
		hostStart++
	}

	if hostStart >= len(path) {
		// No host, treat file:// as local
		if isFileScheme {
			return "", pathEnd, PathTypeFileUriLocal
		}
		return "", pathEnd, PathTypeCustomUri
	}

	// Find end of host
	hostEnd := hostStart
	for hostEnd < len(path) && path[hostEnd] != '/' && path[hostEnd] != '\\' {
		hostEnd++
	}

	if hostEnd <= hostStart {
		return "", pathEnd, PathTypeCustomUri
	}

	host = path[hostStart:hostEnd]
	newPathEnd = hostEnd

	// Determine path type based on host
	if isFileScheme {
		// Windows drive as host -> local file URI
		if isWindowsDriveString(host) {
			return host, newPathEnd, PathTypeFileUriLocal
		}
		// localhost/127.0.0.1/[::1] -> local file URI
		if isLocalhost(host) {
			return host, newPathEnd, PathTypeFileUriLocal
		}
		return host, newPathEnd, PathTypeFileUriRemote
	}

	return host, newPathEnd, PathTypeCustomUri
}

// extractHostForMultiSlashURI extracts host from URI with 3+ slashes.
func extractHostForMultiSlashURI(path string, pathEnd int, slashCount int, isFileScheme bool, behavior SchemeBehavior) (host string, newPathEnd int, pathType PathType) {
	// Skip leading slashes
	hostStart := pathEnd
	for hostStart < len(path) && (path[hostStart] == '/' || path[hostStart] == '\\') {
		hostStart++
	}

	// Check for UNC format (files:////server/share/path, slashCount == 4)
	if slashCount == 4 && isFileScheme {
		hostEnd := hostStart
		for hostEnd < len(path) && path[hostEnd] != '/' && path[hostEnd] != '\\' {
			hostEnd++
		}
		if hostEnd > hostStart {
			return path[hostStart:hostEnd], hostEnd, PathTypeFileUriUnc
		}
	}

	// Check for Windows drive letter (X:)
	if hostStart+1 < len(path) && path[hostStart+1] == ':' {
		if isEnglishLetter(path[hostStart]) {
			return path[hostStart : hostStart+2], hostStart + 2, PathTypeFileUriLocal
		}
	}

	// No host extracted, return appropriate path type based on scheme
	if isFileScheme {
		return "", pathEnd, PathTypeFileUriLocal
	}
	return "", pathEnd, PathTypeCustomUri
}

// extractURISchemeWithSingleSlash handles scheme:/path pattern.
func extractURISchemeWithSingleSlash(path string, schemeEnd int, opts ParseOptions) (scheme string, host string, pathEnd int, pathType PathType) {
	schemePrefix := path[:schemeEnd]

	// RFC 8089: file:/path is equivalent to file:///path
	if schemePrefix == "file" || schemePrefix == "files" {
		return schemePrefix + "://", "", schemeEnd + 2, PathTypeFileUriLocal
	}

	// For other schemes, treat the slash as part of the path
	return path[:schemeEnd+1], "", schemeEnd + 1, PathTypeCustomUri
}

// extractURISchemeWithoutSlashes handles scheme: pattern.
func extractURISchemeWithoutSlashes(path string, schemeEnd int, opts ParseOptions) (scheme string, host string, pathEnd int, pathType PathType) {
	schemePrefix := path[:schemeEnd]

	// RFC 8089: file: and files: should be normalized to file:/// and files:///
	if schemePrefix == "file" || schemePrefix == "files" {
		return schemePrefix + "://", "", len(path), PathTypeFileUriLocal
	}

	return path[:schemeEnd+1], "", schemeEnd + 1, PathTypeCustomUri
}

// ==================== UNC Path Extraction ====================

// extractUNCPath extracts UNC path from path.
// Handles: \\server\share\path, \\?\C:\path, \\?\\server\share
func extractUNCPath(path string) (scheme string, host string, pathEnd int, pathType PathType) {
	if len(path) < 2 || path[0] != '\\' || path[1] != '\\' {
		return "", "", 0, PathTypeUnknown
	}

	// Check for \?\ prefix (Windows extended-length path)
	if len(path) >= 4 && path[2] == '?' && path[3] == '\\' {
		return extractExtendedLengthPath(path)
	}

	// Standard UNC path: \\server\share\path
	return extractStandardUNCPath(path)
}

// extractExtendedLengthPath handles Windows extended-length path (\\?\C:\path or \\?\\server\share).
func extractExtendedLengthPath(path string) (scheme string, host string, pathEnd int, pathType PathType) {
	// Check for \\?\C: (Windows drive)
	if len(path) >= 6 && path[5] == ':' {
		if isEnglishLetter(path[4]) {
			host = path[4:6]
			pathEnd = 6
			if len(path) > 6 && (path[6] == '\\' || path[6] == '/') {
				pathType = PathTypeLocalAbsolute
			} else {
				pathType = PathTypeLocalRelative
			}
			return "", host, pathEnd, pathType
		}
	}

	// \\?\\server\share\path -> treat as UNC path
	if len(path) >= 6 && path[4] == '\\' {
		serverEnd := 5
		for serverEnd < len(path) && path[serverEnd] != '\\' {
			serverEnd++
		}
		if serverEnd > 5 {
			return `\\`, path[5:serverEnd], serverEnd, PathTypeUncWindows
		}
	}

	return "", "", 0, PathTypeUnknown
}

// extractStandardUNCPath handles standard UNC path (\\server\share\path).
func extractStandardUNCPath(path string) (scheme string, host string, pathEnd int, pathType PathType) {
	// Find server name
	serverEnd := 2
	for serverEnd < len(path) && path[serverEnd] != '\\' {
		serverEnd++
	}

	if serverEnd > 2 {
		host = path[2:serverEnd]
	}

	return `\\`, host, serverEnd, PathTypeUncWindows
}

// ==================== Windows Drive Extraction ====================

// extractWindowsDrive extracts Windows drive from path.
// Handles: C:\path, C:path, d:\path
func extractWindowsDrive(path string) (scheme string, host string, pathEnd int, pathType PathType) {
	if len(path) < 2 || path[1] != ':' {
		return "", "", 0, PathTypeUnknown
	}

	if !isEnglishLetter(path[0]) {
		return "", "", 0, PathTypeUnknown
	}

	host = path[0:2] // Preserve original case
	pathEnd = 2

	// Check if absolute (has separator after drive letter)
	if len(path) > 2 && (path[2] == '\\' || path[2] == '/') {
		pathType = PathTypeLocalAbsolute
	} else {
		pathType = PathTypeLocalRelative
	}

	return "", host, pathEnd, pathType
}

// extractSchemeAndHost extracts the scheme and host from the path.
// Returns: scheme, host, pathEndIndex, pathType
//
// Supported path formats:
//   - Unix absolute path: /a/b/c
//   - Windows drive: C:\a\b or C:a\b
//   - UNC path: \\server\share\path
//   - Windows extended-length path: \\?\C:\path or \\?\\server\share
//   - URI: scheme://host/path, scheme:///path, scheme:/path, scheme:
//
// The function handles the following URI slash patterns:
//   - scheme://host/path (2 slashes, remote host)
//   - scheme:///path (3+ slashes, local path)
//   - scheme:/path (1 slash after colon)
//   - scheme: (no slashes)
//
// For file:// and files:// schemes, RFC 8089 normalization is applied:
//   - file: -> file:///
//   - file:/path -> file:///path
//   - file://localhost/path -> file:///path (localhost is recognized)
func extractSchemeAndHost(path string, opts ParseOptions) (scheme string, host string, pathEnd int, pathType PathType) {
	if len(path) == 0 {
		return "", "", 0, PathTypeUnknown
	}

	// Try each path type in order of specificity

	// 1. URI scheme (scheme://, scheme:/, scheme:///)
	if scheme, host, pathEnd, pathType := extractURIScheme(path, opts); pathType != PathTypeUnknown {
		return scheme, host, pathEnd, pathType
	}

	// 2. UNC path (\\server\share\path)
	if scheme, host, pathEnd, pathType := extractUNCPath(path); pathType != PathTypeUnknown {
		return scheme, host, pathEnd, pathType
	}

	// 3. Windows drive (C:\path or C:path)
	if scheme, host, pathEnd, pathType := extractWindowsDrive(path); pathType != PathTypeUnknown {
		return scheme, host, pathEnd, pathType
	}

	// 4. Unix absolute path
	if len(path) > 0 && path[0] == '/' {
		return "", "", 0, PathTypeLocalAbsolute
	}

	// 5. Relative path
	return "", "", 0, PathTypeLocalRelative
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
						return strings.ReplaceAll(path[:schemeEnd+4], `\`, "/"), schemeEnd + slashCount
					}
					return strings.ReplaceAll(path[:schemeEnd+3], `\`, "/"), schemeEnd + slashCount
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
		slashIndex := strings.Index(path[2:], `\`)
		if slashIndex == -1 {
			return path, len(path)
		}
		serverEnd := 2 + slashIndex
		return path[:serverEnd], serverEnd
	}

	// 3. Check for Windows drive letter (C:\, d:\)
	if len(path) >= 2 && path[1] == ':' {
		if isEnglishLetter(path[0]) {
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
	if !isEnglishLetter(path[0]) {
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
		if !isPathSchemeChar(c) {
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

// ==================== PathCleanEasy ====================

// PathCleanEasy cleans a path by removing redundant elements.
// This is now a wrapper around ParsePathInfoEasy for consistency and performance.
func PathCleanEasy(path string) string {
	if path == "" {
		return ""
	}
	return ParsePathInfoEasyMust(path).Encode()
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

// Ensure pathInfoImpl implements PathInfo interface
var _ PathInfo = (*pathInfoImpl)(nil)
