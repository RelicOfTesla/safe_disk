// Package sec_utils provides utilities for secure file system operations.
// This file contains comprehensive tests for scheme behavior configuration.
package sec_utils

import (
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ==================== 1. Standard Scheme Tests ====================

// TestStandardSchemes_All tests all standard RFC 3986 schemes.
func TestStandardSchemes_All(t *testing.T) {
	// Save and restore default behavior
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	tests := []struct {
		name        string
		scheme      string
		path2Slash  string // scheme://host/path
		path3Slash  string // scheme:///path
		expectHost  string // expected host for 2-slash format
		expectEmpty bool   // expected empty host for 3-slash format
	}{
		{"HTTP", "http", "http://example.com/path", "http:///path/to/file", "example.com", true},
		{"HTTPS", "https", "https://example.com/path", "https:///path/to/file", "example.com", true},
		{"FTP", "ftp", "ftp://ftp.example.com/pub/file", "ftp:///path/to/file", "ftp.example.com", true},
		{"SFTP", "sftp", "sftp://ssh.example.com/home/user/file", "sftp:///path/to/file", "ssh.example.com", true},
		{"SSH", "ssh", "ssh://ssh.example.com/home/user", "ssh:///path", "ssh.example.com", true},
		{"WS", "ws", "ws://websocket.example.com/socket", "ws:///socket", "websocket.example.com", true},
		{"WSS", "wss", "wss://secure.example.com/socket", "wss:///socket", "secure.example.com", true},
		{"GIT", "git", "git://git.example.com/repo.git", "git:///repo.git", "git.example.com", true},
		{"SVN", "svn", "svn://svn.example.com/repo", "svn:///repo", "svn.example.com", true},
		{"SVN+SSH", "svn+ssh", "svn+ssh://svn.example.com/repo", "svn+ssh:///repo", "svn.example.com", true},
		{"DAV", "dav", "dav://webdav.example.com/files", "dav:///files", "webdav.example.com", true},
		{"DAVS", "davs", "davs://webdav.example.com/files", "davs:///files", "webdav.example.com", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test scheme://host/path format (2 slashes)
			info, err := ParsePathInfoWithOptions(tt.path2Slash)
			require.NoError(t, err, "Failed to parse %s", tt.path2Slash)
			assert.Equal(t, tt.scheme+"://", info.Scheme(), "Scheme mismatch for %s", tt.path2Slash)
			assert.Equal(t, tt.expectHost, info.Host(), "Host mismatch for %s", tt.path2Slash)
			assert.Equal(t, PathTypeCustomUri, info.Type(), "PathType mismatch for %s", tt.path2Slash)

			// Test scheme:///path format (3 slashes, empty host)
			info2, err := ParsePathInfoWithOptions(tt.path3Slash)
			require.NoError(t, err, "Failed to parse %s", tt.path3Slash)
			assert.Equal(t, tt.scheme+"://", info2.Scheme(), "Scheme mismatch for %s", tt.path3Slash)
			if tt.expectEmpty {
				assert.Empty(t, info2.Host(), "Host should be empty for %s", tt.path3Slash)
			}
			assert.Equal(t, PathTypeCustomUri, info2.Type(), "PathType mismatch for %s", tt.path3Slash)
		})
	}
}

// TestStandardSchemes_WithPort tests standard schemes with port numbers.
func TestStandardSchemes_WithPort(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
	}{
		{"HTTP with port", "http://example.com:8080/path/to/file", "http://", "example.com:8080", []string{"path", "to", "file"}},
		{"HTTPS with port", "https://example.com:8443/api/resource", "https://", "example.com:8443", []string{"api", "resource"}},
		{"FTP with port", "ftp://ftp.example.com:2121/pub/file.txt", "ftp://", "ftp.example.com:2121", []string{"pub", "file.txt"}},
		{"SSH with port", "ssh://ssh.example.com:2222/home/user/file", "ssh://", "ssh.example.com:2222", []string{"home", "user", "file"}},
		{"WS with port", "ws://websocket.example.com:9001/socket", "ws://", "websocket.example.com:9001", []string{"socket"}},
		{"GIT with port", "git://git.example.com:9418/repo.git", "git://", "git.example.com:9418", []string{"repo.git"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
			assert.Equal(t, PathTypeCustomUri, info.Type())
		})
	}
}

// TestStandardSchemes_SingleSlash tests scheme:/path format.
func TestStandardSchemes_SingleSlash(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
		wantType   PathType
	}{
		// RFC 8089: file:/path is equivalent to file:///path
		{"file:/ minimal", "file:/path/to/file", "file://", "", []string{"path", "to", "file"}, PathTypeFileUriLocal},
		{"files:/ minimal", "files:/path/to/file", "files://", "", []string{"path", "to", "file"}, PathTypeFileUriLocal},
		// For other schemes, treat as scheme:/path (not standard RFC 3986)
		{"http:/ single slash", "http:/path/to/file", "http:", "", []string{"path", "to", "file"}, PathTypeCustomUri},
		{"custom:/ single slash", "custom:/path/to/file", "custom:", "", []string{"path", "to", "file"}, PathTypeCustomUri},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
			assert.Equal(t, tt.wantType, info.Type())
		})
	}
}

// TestStandardSchemes_NoSlash tests scheme:path format (no slashes).
func TestStandardSchemes_NoSlash(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
		wantType   PathType
	}{
		// RFC 8089: file: should be normalized to file:///
		{"file: no slash", "file:", "file://", "", []string(nil), PathTypeFileUriLocal},
		{"files: no slash", "files:", "files://", "", []string(nil), PathTypeFileUriLocal},
		// For other schemes, it's scheme:path
		{"http: no slash", "http:path", "http:", "", []string{"path"}, PathTypeCustomUri},
		{"custom: no slash", "custom:path/to/file", "custom:", "", []string{"path", "to", "file"}, PathTypeCustomUri},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
			assert.Equal(t, tt.wantType, info.Type())
		})
	}
}

// ==================== 2. Custom Scheme Tests ====================

// TestCustomScheme_Unregistered tests unregistered custom schemes.
func TestCustomScheme_Unregistered(t *testing.T) {
	// Save and restore default behavior
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Set default behavior to NOT follow RFC 3986
	DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
	}{
		// When MustFollowRFC3986Authority=false, scheme://a/b/c should NOT extract host
		// All content after scheme:// is treated as path
		{"unregistered://host/path", "myapp://server/path/to/file", "myapp://", "", []string{"server", "path", "to", "file"}},
		{"unregistered:///path", "myapp:///path/to/file", "myapp://", "", []string{"path", "to", "file"}},
		{"another://host/path", "another://example.com/resource", "another://", "", []string{"example.com", "resource"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// TestCustomScheme_Registered tests registered custom schemes.
func TestCustomScheme_Registered(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	t.Run("FollowRFC3986", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		// Register custom scheme to follow RFC 3986
		RegisterScheme("myrfc", SchemeBehavior{MustFollowRFC3986Authority: true})

		// scheme://host/path should have host
		info, err := ParsePathInfoWithOptions("myrfc://server/path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "myrfc://", info.Scheme())
		assert.Equal(t, "server", info.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info.Parts())

		// scheme:///path should have empty host
		info2, err := ParsePathInfoWithOptions("myrfc:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "myrfc://", info2.Scheme())
		assert.Empty(t, info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("NotFollowRFC3986", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		// Register custom scheme to NOT follow RFC 3986
		RegisterScheme("mynonrfc", SchemeBehavior{MustFollowRFC3986Authority: false})

		// When MustFollowRFC3986Authority=false, scheme://a/b/c should NOT extract host
		// All content after scheme:// is treated as path
		info, err := ParsePathInfoWithOptions("mynonrfc://server/path")
		require.NoError(t, err)
		assert.Equal(t, "mynonrfc://", info.Scheme())
		assert.Empty(t, info.Host(), "Host should be empty when MustFollowRFC3986Authority=false")
		assert.Equal(t, []string{"server", "path"}, info.Parts(), "All content after scheme:// should be path")

		// scheme:///path should also have empty host
		info2, err := ParsePathInfoWithOptions("mynonrfc:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "mynonrfc://", info2.Scheme())
		assert.Empty(t, info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})
}

// TestCustomScheme_DynamicModification tests dynamic modification of scheme registry.
func TestCustomScheme_DynamicModification(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Reset registry
	schemeRegistry.Lock()
	schemeRegistry.behaviors = make(map[string]SchemeBehavior)
	schemeRegistry.Unlock()

	// Initially, unregistered scheme uses default behavior
	behavior := GetSchemeBehavior("dynamic")
	assert.False(t, behavior.MustFollowRFC3986Authority, "Unregistered scheme should use default behavior")

	// Register with RFC 3986 behavior
	RegisterScheme("dynamic", SchemeBehavior{MustFollowRFC3986Authority: true})
	behavior = GetSchemeBehavior("dynamic")
	assert.True(t, behavior.MustFollowRFC3986Authority, "Registered scheme should follow RFC 3986")

	// Modify registration
	RegisterScheme("dynamic", SchemeBehavior{MustFollowRFC3986Authority: false})
	behavior = GetSchemeBehavior("dynamic")
	assert.False(t, behavior.MustFollowRFC3986Authority, "Modified scheme should not follow RFC 3986")
}

// ==================== 3. Override Behavior Tests ====================

// TestOverrideBehavior_ForceRFC3986 tests WithSchemeBehaviorOverride forcing RFC 3986.
func TestOverrideBehavior_ForceRFC3986(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Set default behavior to NOT follow RFC 3986
	DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

	// Use override to force RFC 3986 behavior
	opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: true})

	tests := []struct {
		name       string
		path       string
		wantHost   string
		wantEmpty  bool
		wantParts  []string
	}{
		{"custom://host/path with override", "customscheme://host/path", "host", false, []string{"path"}},
		{"custom:///path with override", "customscheme:///path/to/file", "", true, []string{"path", "to", "file"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path, opt)
			require.NoError(t, err)
			if tt.wantEmpty {
				assert.Empty(t, info.Host())
			} else {
				assert.Equal(t, tt.wantHost, info.Host())
			}
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// TestOverrideBehavior_DisableRFC3986 tests WithSchemeBehaviorOverride disabling RFC 3986.
func TestOverrideBehavior_DisableRFC3986(t *testing.T) {
	// Use override to disable RFC 3986 behavior for standard scheme
	opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: false})

	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
	}{
		// When MustFollowRFC3986Authority=false (via override), host should NOT be extracted
		// All content after scheme:// is treated as path
		{"http://host/path with disable override", "http://example.com/path", "http://", "", []string{"example.com", "path"}},
		// 3 slashes still mean empty host
		{"http:///path with disable override", "http:///path/to/file", "http://", "", []string{"path", "to", "file"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path, opt)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// TestOverrideBehavior_StandardScheme tests override affecting standard schemes.
func TestOverrideBehavior_StandardScheme(t *testing.T) {
	opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: true})

	// Standard schemes with override should still work correctly
	info, err := ParsePathInfoWithOptions("http://example.com/path", opt)
	require.NoError(t, err)
	assert.Equal(t, "http://", info.Scheme())
	assert.Equal(t, "example.com", info.Host())
	assert.Equal(t, []string{"path"}, info.Parts())
}

// TestOverrideBehavior_CustomScheme tests override affecting custom schemes.
func TestOverrideBehavior_CustomScheme(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Set default behavior to NOT follow RFC 3986
	DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

	opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: true})

	// Custom scheme with override should follow RFC 3986
	info, err := ParsePathInfoWithOptions("myapp://server/resource", opt)
	require.NoError(t, err)
	assert.Equal(t, "myapp://", info.Scheme())
	assert.Equal(t, "server", info.Host())
	assert.Equal(t, []string{"resource"}, info.Parts())
}

// ==================== 4. Default Behavior Tests ====================

// TestDefaultBehavior_InitialValue tests initial default behavior value.
func TestDefaultBehavior_InitialValue(t *testing.T) {
	// The initial default should not force RFC 3986
	assert.False(t, DefaultSchemeBehavior.MustFollowRFC3986Authority, 
		"Initial default behavior should not force RFC 3986")
}

// TestDefaultBehavior_Modification tests SetDefaultSchemeBehavior.
func TestDefaultBehavior_Modification(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Modify default behavior
	SetDefaultSchemeBehavior(SchemeBehavior{MustFollowRFC3986Authority: true})
	assert.True(t, DefaultSchemeBehavior.MustFollowRFC3986Authority, 
		"DefaultSchemeBehavior should be modified")

	// Verify GetSchemeBehavior returns new default for unregistered scheme
	behavior := GetSchemeBehavior("unregistered-scheme")
	assert.True(t, behavior.MustFollowRFC3986Authority, 
		"GetSchemeBehavior should return modified default for unregistered scheme")
}

// TestDefaultBehavior_ParsingResult tests parsing results after modifying default behavior.
func TestDefaultBehavior_ParsingResult(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Reset registry
	schemeRegistry.Lock()
	schemeRegistry.behaviors = make(map[string]SchemeBehavior)
	schemeRegistry.Unlock()

	// Set default to follow RFC 3986
	SetDefaultSchemeBehavior(SchemeBehavior{MustFollowRFC3986Authority: true})

	// Unregistered custom scheme should now follow RFC 3986
	info, err := ParsePathInfoWithOptions("customapp://server/path")
	require.NoError(t, err)
	assert.Equal(t, "customapp://", info.Scheme())
	assert.Equal(t, "server", info.Host())
	assert.Equal(t, []string{"path"}, info.Parts())

	// 3 slashes should result in empty host
	info2, err := ParsePathInfoWithOptions("customapp:///path/to/file")
	require.NoError(t, err)
	assert.Empty(t, info2.Host())
	assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
}

// ==================== 5. Edge Case Tests ====================

// TestEdgeCases_EmptyPath tests empty path handling.
func TestEdgeCases_EmptyPath(t *testing.T) {
	info, err := ParsePathInfoWithOptions("")
	require.NoError(t, err)
	assert.Empty(t, info.Scheme())
	assert.Empty(t, info.Host())
	assert.Equal(t, PathTypeUnknown, info.Type())
}

// TestEdgeCases_RootPath tests root path handling.
func TestEdgeCases_RootPath(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
		wantType   PathType
	}{
		{"Unix root", "/", "", "", []string{""}, PathTypeLocalAbsolute},
		{"file:// root", "file:///", "file://", "", []string{""}, PathTypeFileUriLocal},
		{"files:// root", "files:///", "files://", "", []string{""}, PathTypeFileUriLocal},
		{"http:// root", "http://example.com/", "http://", "example.com", []string{""}, PathTypeCustomUri},
		{"custom:// root", "custom:///", "custom://", "", []string{""}, PathTypeCustomUri},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
			assert.Equal(t, tt.wantType, info.Type())
		})
	}
}

// TestEdgeCases_SpecialCharacters tests paths with special characters.
func TestEdgeCases_SpecialCharacters(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantParts  []string
		wantErr    bool
	}{
		{"path with spaces", "/path/to/file name.txt", []string{"path", "to", "file name.txt"}, false},
		{"path with unicode", "/路径/到/文件.txt", []string{"路径", "到", "文件.txt"}, false},
		{"path with encoded chars", "/path%20to/file%2Fname", []string{"path%20to", "file%2Fname"}, false},
		{"path with brackets", "/path/to/file[1].txt", []string{"path", "to", "file[1].txt"}, false},
		{"path with parentheses", "/path/to/file(1).txt", []string{"path", "to", "file(1).txt"}, false},
		{"path with ampersand", "/path/to/file&name.txt", []string{"path", "to", "file&name.txt"}, false},
		{"path with equals", "/path/to/file=name.txt", []string{"path", "to", "file=name.txt"}, false},
		{"path with question mark", "/path/to/file?query", []string{"path", "to", "file?query"}, false},
		{"path with hash", "/path/to/file#fragment", []string{"path", "to", "file#fragment"}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.wantParts, info.Parts())
			}
		})
	}
}

// TestEdgeCases_LongPath tests very long paths.
func TestEdgeCases_LongPath(t *testing.T) {
	// Generate a long path
	longPart := "a"
	for i := 0; i < 100; i++ {
		longPart += "bcdefghij"
	}
	longPath := "/" + longPart

	info, err := ParsePathInfoWithOptions(longPath)
	require.NoError(t, err)
	assert.Equal(t, []string{longPart}, info.Parts())
	assert.Equal(t, PathTypeLocalAbsolute, info.Type())
}

// TestEdgeCases_CaseInsensitiveScheme tests case sensitivity of schemes.
func TestEdgeCases_CaseInsensitiveScheme(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
	}{
		{"HTTP uppercase", "HTTP://example.com/path", "HTTP://", "example.com"},
		{"Http mixed case", "Http://example.com/path", "Http://", "example.com"},
		{"FILE uppercase", "FILE:///path/to/file", "FILE://", ""},
		{"File mixed case", "File:///path/to/file", "File://", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoWithOptions(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
		})
	}

	// Test that GetSchemeBehavior is case-insensitive
	behavior1 := GetSchemeBehavior("HTTP")
	behavior2 := GetSchemeBehavior("http")
	assert.Equal(t, behavior1, behavior2, "GetSchemeBehavior should be case-insensitive")
}

// ==================== 6. Concurrency Safety Tests ====================

// TestConcurrency_RegisterScheme tests concurrent scheme registration.
func TestConcurrency_RegisterScheme(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	// Reset registry
	schemeRegistry.Lock()
	schemeRegistry.behaviors = make(map[string]SchemeBehavior)
	schemeRegistry.Unlock()

	var wg sync.WaitGroup
	numGoroutines := 100

	// Concurrent registration of different schemes
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			scheme := "scheme" + string(rune('a'+idx%26))
			RegisterScheme(scheme, SchemeBehavior{MustFollowRFC3986Authority: idx%2 == 0})
		}(i)
	}

	wg.Wait()

	// Verify no panic occurred and registry is valid
	behavior := GetSchemeBehavior("test")
	_ = behavior
}

// TestConcurrency_GetSchemeBehavior tests concurrent behavior lookup.
func TestConcurrency_GetSchemeBehavior(t *testing.T) {
	// Register some schemes first
	RegisterScheme("conctest1", SchemeBehavior{MustFollowRFC3986Authority: true})
	RegisterScheme("conctest2", SchemeBehavior{MustFollowRFC3986Authority: false})

	var wg sync.WaitGroup
	numGoroutines := 100

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			behavior := GetSchemeBehavior("conctest1")
			assert.True(t, behavior.MustFollowRFC3986Authority)
			behavior = GetSchemeBehavior("conctest2")
			assert.False(t, behavior.MustFollowRFC3986Authority)
			behavior = GetSchemeBehavior("http")
			assert.True(t, behavior.MustFollowRFC3986Authority)
		}(i)
	}

	wg.Wait()
}

// TestConcurrency_ParsePathInfo tests concurrent path parsing.
func TestConcurrency_ParsePathInfo(t *testing.T) {
	var wg sync.WaitGroup
	numGoroutines := 100
	paths := []string{
		"http://example.com/path/to/file",
		"file:///home/user/document.txt",
		"custom://server/resource",
		"/unix/path/to/file",
		"C:\\Windows\\System32\\file.dll",
	}

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			path := paths[idx%len(paths)]
			info, err := ParsePathInfoWithOptions(path)
			require.NoError(t, err)
			assert.NotEmpty(t, info.Encode())
		}(i)
	}

	wg.Wait()
}

// ==================== 7. Backward Compatibility Tests ====================

// TestBackwardCompatibility_ParsePathInfoEasy tests ParsePathInfoEasy behavior.
func TestBackwardCompatibility_ParsePathInfoEasy(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	schemeRegistry.Lock()
	schemeRegistry.behaviors = make(map[string]SchemeBehavior)
	schemeRegistry.Unlock()
	DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
	}{
		{"Unix path", "/a/b/c", "", "", []string{"a", "b", "c"}},
		{"Windows path", `C:\a\b`, "", "C:", []string{"a", "b"}},
		{"file:// URI", "file:///a/b/c", "file://", "", []string{"a", "b", "c"}},
		{"custom:// URI", "custom://host/path", "custom://", "", []string{"host", "path"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfoEasy(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// TestBackwardCompatibility_ParsePathInfo tests ParsePathInfo behavior.
func TestBackwardCompatibility_ParsePathInfo(t *testing.T) {
	// ParsePathInfo is an alias for ParsePathInfoEasy
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantParts  []string
	}{
		{"Unix path", "/a/b/c", "", "", []string{"a", "b", "c"}},
		{"file:// URI", "file:///a/b/c", "file://", "", []string{"a", "b", "c"}},
		{"http:// URI", "http://example.com/path", "http://", "example.com", []string{"path"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// TestBackwardCompatibility_ExistingFormats tests existing path format parsing.
func TestBackwardCompatibility_ExistingFormats(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantEncode string
	}{
		{"Unix absolute", "/a/b/c", "/a/b/c"},
		{"Unix relative", "a/b/c", "a/b/c"},
		{"file:// local", "file:///a/b/c", "file:///a/b/c"},
		{"file:// remote", "file://server/share/file", "file://server/share/file"},
		{"UNC path", `\\server\share\path`, `\\server\share\path`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantEncode, info.Encode())
		})
	}
}

// ==================== 8. Path Encoding/Decoding Tests ====================

// TestPathEncoding_Encode tests that Encode() returns correct path.
func TestPathEncoding_Encode(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantEncode string
	}{
		{"Simple path", "/a/b/c", "/a/b/c"},
		{"Path with dots", "/a/./b/../c", "/a/c"},
		{"URI path", "file:///a/b/c", "file:///a/b/c"},
		{"URI with host", "http://example.com/a/b/c", "http://example.com/a/b/c"},
		{"UNC path", `\\server\share\path`, `\\server\share\path`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantEncode, info.Encode())
		})
	}
}

// TestPathEncoding_RoundTrip tests that Encode() can be re-parsed.
func TestPathEncoding_RoundTrip(t *testing.T) {
	paths := []string{
		"/a/b/c",
		"file:///a/b/c",
		"http://example.com/path",
		"custom://server/resource",
		`\\server\share\path`,
	}

	for _, path := range paths {
		t.Run("RoundTrip: "+path, func(t *testing.T) {
			info1, err := ParsePathInfo(path)
			require.NoError(t, err)

			encoded := info1.Encode()
			info2, err := ParsePathInfo(encoded)
			require.NoError(t, err)

			assert.Equal(t, info1.Scheme(), info2.Scheme())
			assert.Equal(t, info1.Host(), info2.Host())
			assert.Equal(t, info1.Parts(), info2.Parts())
			assert.Equal(t, info1.Encode(), info2.Encode())
		})
	}
}

// TestPathEncoding_ReplaceParts tests ReplaceParts and Encode.
func TestPathEncoding_ReplaceParts(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		newParts   []string
		wantEncode string
	}{
		{"Replace Unix path", "/a/b/c", []string{"x", "y", "z"}, "/x/y/z"},
		{"Replace URI path", "file:///a/b/c", []string{"d", "e"}, "file:///d/e"},
		{"Replace UNC path", `\\server\share\path`, []string{"new", "path"}, `\\server\new\path`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			require.NoError(t, err)

			newInfo := info.ReplaceParts(tt.newParts)
			assert.Equal(t, tt.wantEncode, newInfo.Encode())
			// Original should not be modified
			originalInfo, _ := ParsePathInfo(tt.path)
			assert.Equal(t, originalInfo.Encode(), info.Encode())
		})
	}
}

// TestPathEncoding_PartsCorrect tests that Parts() returns correct values.
func TestPathEncoding_PartsCorrect(t *testing.T) {
	tests := []struct {
		name      string
		path      string
		wantParts []string
	}{
		{"Simple path", "/a/b/c", []string{"a", "b", "c"}},
		{"Root path", "/", []string{""}},
		{"Relative path", "a/b/c", []string{"a", "b", "c"}},
		{"URI path", "file:///a/b/c", []string{"a", "b", "c"}},
		{"URI with host", "http://example.com/a/b/c", []string{"a", "b", "c"}},
		{"Empty path", "", []string(nil)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			require.NoError(t, err)
			assert.Equal(t, tt.wantParts, info.Parts())
		})
	}
}

// ==================== 9. Error Handling Tests ====================

// TestErrorHandling_InvalidPathFormat tests invalid path formats.
func TestErrorHandling_InvalidPathFormat(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		wantErr bool
	}{
		{"Empty string (valid)", "", false}, // Empty is valid
		{"Drive letter in middle", `d:\a:\b`, true},
		{"Drive relative path", `d:a\b`, true}, // Windows drive-relative not supported
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := ParsePathInfo(tt.path)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// TestErrorHandling_InvalidSchemeFormat tests invalid scheme formats.
func TestErrorHandling_InvalidSchemeFormat(t *testing.T) {
	// Note: The current implementation is permissive with scheme formats
	// It accepts most scheme-like patterns
	
	tests := []struct {
		name        string
		path        string
		wantScheme  string
		wantErr     bool
	}{
		{"Scheme with digits", "scheme123://host/path", "scheme123://", false},
		{"Scheme with plus", "scheme+plus://host/path", "scheme+plus://", false},
		{"Scheme with minus", "scheme-minus://host/path", "scheme-minus://", false},
		{"Scheme with dot", "scheme.dot://host/path", "scheme.dot://", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				require.NoError(t, err)
				assert.Equal(t, tt.wantScheme, info.Scheme())
			}
		})
	}
}

// ==================== 10. Integration Tests ====================

// TestIntegration_ComplexScenarios tests complex real-world scenarios.
func TestIntegration_ComplexScenarios(t *testing.T) {
	// Save and restore
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	t.Run("GitRepositoryPath", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		// Git scheme should follow RFC 3986
		info, err := ParsePathInfoWithOptions("git://github.com/user/repo.git")
		require.NoError(t, err)
		assert.Equal(t, "git://", info.Scheme())
		assert.Equal(t, "github.com", info.Host())
		assert.Equal(t, []string{"user", "repo.git"}, info.Parts())
	})

	t.Run("WebDAVPath", func(t *testing.T) {
		info, err := ParsePathInfoWithOptions("davs://webdav.example.com:8443/files/document.pdf")
		require.NoError(t, err)
		assert.Equal(t, "davs://", info.Scheme())
		assert.Equal(t, "webdav.example.com:8443", info.Host())
		assert.Equal(t, []string{"files", "document.pdf"}, info.Parts())
	})

	t.Run("WebSocketPath", func(t *testing.T) {
		info, err := ParsePathInfoWithOptions("wss://websocket.example.com:9001/chat")
		require.NoError(t, err)
		assert.Equal(t, "wss://", info.Scheme())
		assert.Equal(t, "websocket.example.com:9001", info.Host())
		assert.Equal(t, []string{"chat"}, info.Parts())
	})

	t.Run("CustomAppScheme", func(t *testing.T) {
		// Reset and register custom scheme
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		RegisterScheme("myapp", SchemeBehavior{MustFollowRFC3986Authority: true})

		info, err := ParsePathInfoWithOptions("myapp://server:8080/api/v1/resource")
		require.NoError(t, err)
		assert.Equal(t, "myapp://", info.Scheme())
		assert.Equal(t, "server:8080", info.Host())
		assert.Equal(t, []string{"api", "v1", "resource"}, info.Parts())
	})
}

// TestIntegration_JoinAndReplace tests Join and ReplaceParts together.
func TestIntegration_JoinAndReplace(t *testing.T) {
	info, err := ParsePathInfo("file:///home/user/documents")
	require.NoError(t, err)

	// Join adds components
	joined := info.Join("project", "file.txt")
	assert.Equal(t, "file:///home/user/documents/project/file.txt", joined.Encode())

	// ReplaceParts replaces all components
	replaced := info.ReplaceParts([]string{"new", "path"})
	assert.Equal(t, "file:///new/path", replaced.Encode())

	// Join after replace
	final := replaced.Join("extra")
	assert.Equal(t, "file:///new/path/extra", final.Encode())
}

// TestIntegration_ContainsPath tests ContainsPath with various scenarios.
func TestIntegration_ContainsPath(t *testing.T) {
	tests := []struct {
		name      string
		basePath  string
		otherPath string
		want      bool
	}{
		{"URI containment", "file:///home/user", "file:///home/user/documents", true},
		{"URI not contained", "file:///home/user", "file:///var/log", false},
		{"HTTP containment", "http://example.com/api", "http://example.com/api/v1/users", true},
		{"Different hosts", "http://example.com/api", "http://other.com/api", false},
		{"UNC containment", `\\server\share`, `\\server\share\folder`, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			baseInfo, err := ParsePathInfo(tt.basePath)
			require.NoError(t, err)
			assert.Equal(t, tt.want, baseInfo.ContainsPath(tt.otherPath))
		})
	}
}
