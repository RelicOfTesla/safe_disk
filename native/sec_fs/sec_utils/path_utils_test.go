// Package sec_utils provides utilities for secure file system operations.
// This file contains tests for path utility functions.
package sec_utils

import (
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestPathParsing_Clean tests that paths are correctly cleaned.
func TestPathParsing_Clean(t *testing.T) {
	tests := []struct {
		name string
		path string
		want string
	}{
		// Basic cleaning
		{"Empty path", "", ""},
		{"Single component", "a", "a"},
		{"Simple path", "a/b/c", "a/b/c"},

		// Current directory (.)
		{"Single dot", ".", ""},
		{"Dot in path", "a/./b", "a/b"},
		{"Multiple dots", "a/././b", "a/b"},
		{"Dot at start", "./a/b", "a/b"},
		{"Dot at end", "a/b/.", "a/b"},

		// Parent directory (..)
		{"Double dot", "..", ".."},
		{"Double dot in path", "a/../b", "b"},
		{"Multiple double dots", "a/b/../../c", "c"},
		{"Double dot at start", "../a/b", "../a/b"},
		{"Double dot exceed", "a/b/../../../c", "../c"},

		// Consecutive separators
		{"Double slash", "a//b", "a/b"},
		{"Triple slash", "a///b", "a/b"},
		{"Multiple separators", "a////b", "a/b"},

		// Absolute paths
		{"Unix absolute", "/a/b/c", "/a/b/c"},
		{"Unix absolute with dot", "/a/./b", "/a/b"},
		{"Unix absolute with double dot", "/a/b/../c", "/a/c"},
		{"Unix root", "/", "/"},

		// Windows paths
		{"Windows drive", `C:\a\b`, `C:\a\b`},
		{"Windows with dot", `C:\a\.\b`, `C:\a\b`},
		{"Windows with double dot", `C:\a\b\..\c`, `C:\a\c`},

		// URI paths
		{"file:// URI", "file:///a/b/c", "file:///a/b/c"},
		{"file:// with dot", "file:///a/./b", "file:///a/b"},
		{"file:// with double dot", "file:///a/b/../c", "file:///a/c"},
		{"files:// URI", "files:///a/b/c", "files:///a/b/c"},
		{"custom:// URI", "custom://host/path", "custom:///host/path"},

		// UNC paths
		{"UNC path", `\\server\share\path`, `\\server\share\path`},
		{"UNC with dot", `\\server\share\.\path`, `\\server\share\path`},
		{"UNC with double dot", `\\server\share\a\..\path`, `\\server\share\path`},

		// Mixed . and ..
		{"Mixed dots", "a/./b/../c/./d", "a/c/d"},
		{"Complex path", "a/b/c/../../d/./e", "a/d/e"},

		// Edge cases
		{"Only separators", "///", "/"},
		{"Trailing separator", "a/b/", "a/b"},
		{"Leading separator", "/a/b", "/a/b"},

		// ========== Extended test cases from original TestPathParsing_Prefix ==========

		// Additional URI schemes
		{"files:// URI extended", "files:///documents/report.pdf", "files:///documents/report.pdf"},
		{"custom:/// URI extended", "custom:///path/to/file", "custom:///path/to/file"},

		// Additional UNC paths
		{"UNC path with IP", `\\192.168.1.2\share\file.txt`, `\\192.168.1.2\share\file.txt`},
		{"UNC path with hostname", `\\server\share\file.txt`, `\\server\share\file.txt`},

		// Additional Windows drives
		{"Windows drive D", `d:\data\file.txt`, `d:\data\file.txt`},
		{"Windows drive lowercase", `e:\test\file.txt`, `e:\test\file.txt`},

		// ========== Extended test cases from original TestPathParsing_Separator ==========

		// Unix paths with various separators
		{"Unix path with subdirs", "/a/b/c/file.txt", "/a/b/c/file.txt"},
		{"Relative Unix path", "a/b/c/file.txt", "a/b/c/file.txt"},

		// Windows paths with backslash
		{"Windows path with subdirs", `C:\Documents\file.txt`, `C:\Documents\file.txt`},
		{"Relative Windows path", `a\b\c\file.txt`, `a\b\c\file.txt`},

		// ========== Extended test cases from original TestPathParsing_SplitJoin ==========

		// Various path lengths
		{"Short path", "a/b", "a/b"},
		{"Medium path", "a/b/c/d/e", "a/b/c/d/e"},
		{"Long path", "a/b/c/d/e/f/g/h", "a/b/c/d/e/f/g/h"},
		{"Windows medium path", `C:\a\b\c\d\e`, `C:\a\b\c\d\e`},

		// ========== Pure special characters (., \, /) combinations ==========

		// Single character
		{"Single dot", ".", ""},
		{"Single backslash", `\`, ""}, // Treated as relative path separator
		{"Single slash", "/", "/"},

		// Double characters
		{"Double dot", "..", ".."},
		{"Double backslash", `\\`, `\\`}, // UNC path prefix
		{"Double slash", "//", "/"},
		{"Dot slash", "./", ""},
		{"Dot backslash", `.\`, ""},
		{"Slash dot", "/.", "/"},
		{"Backslash dot", `\.`, ""}, // Treated as relative path separator

		// Triple characters
		{"Dot dot slash", "../", ".."},
		{"Dot dot backslash", "..\\", ".."},
		{"Slash dot dot", "/..", "/.."},
		{"Backslash dot dot", `\..`, ".."}, // Treated as relative path
		{"Dot dot dot", "...", "..."},
		{"Slash slash slash", "///", "/"},
		{"Backslash backslash backslash", `\\\`, `\\\`}, // UNC path prefix

		// Mixed combinations
		{"Dot slash dot", "./.", ""},
		{"Dot backslash dot", ".\\.", ""},
		{"Slash dot slash", "/./", "/"},
		{"Backslash dot backslash", `\.\`, ""}, // Treated as relative path separator
		{"Dot dot slash dot", "../.", ".."},
		{"Dot dot backslash dot", `..\.`, ".."},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := PathClean(tt.path)
			if got != tt.want {
				t.Errorf("PathClean(%q) = %q, want %q", tt.path, got, tt.want)
			}
		})
	}
}

// TestSchemeBehavior tests scheme behavior configuration.
func TestSchemeBehavior(t *testing.T) {
	// Save and restore default behavior
	originalDefault := DefaultSchemeBehavior
	defer func() {
		DefaultSchemeBehavior = originalDefault
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
	}()

	t.Run("StandardScheme_HTTP_FollowRFC3986", func(t *testing.T) {
		// Standard schemes (http, https) must follow RFC 3986
		// http://host/path -> host + path
		info, err := ParsePathInfoWithOptions("http://example.com/path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "http://", info.Scheme())
		assert.Equal(t, "example.com", info.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info.Parts())
		assert.Equal(t, PathTypeCustomUri, info.Type())

		// http:///path -> empty host + absolute path (RFC 3986)
		info2, err := ParsePathInfoWithOptions("http:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "http://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
		assert.Equal(t, PathTypeCustomUri, info2.Type())
	})

	t.Run("StandardScheme_HTTPS_FollowRFC3986", func(t *testing.T) {
		// https://host/path -> host + path
		info, err := ParsePathInfoWithOptions("https://example.com/path")
		require.NoError(t, err)
		assert.Equal(t, "https://", info.Scheme())
		assert.Equal(t, "example.com", info.Host())
		assert.Equal(t, []string{"path"}, info.Parts())

		// https:///path -> empty host + absolute path
		info2, err := ParsePathInfoWithOptions("https:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "https://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("CustomScheme_DefaultBehavior", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		// Default behavior: MustFollowRFC3986Authority = false
		DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

		// custom://host/path -> with default behavior (MustFollowRFC3986Authority=false),
		// host should NOT be extracted; all content after scheme:// is treated as path
		info, err := ParsePathInfoWithOptions("mycustom://host/path")
		require.NoError(t, err)
		assert.Equal(t, "mycustom://", info.Scheme())
		assert.Equal(t, "", info.Host(), "Host should be empty when MustFollowRFC3986Authority=false")
		assert.Equal(t, []string{"host", "path"}, info.Parts(), "All content after scheme:// should be path")

		// custom:///path -> empty host (same as RFC 3986 for 3+ slashes)
		info2, err := ParsePathInfoWithOptions("mycustom:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "mycustom://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("CustomScheme_Registered_FollowRFC3986", func(t *testing.T) {
		// Register a custom scheme to follow RFC 3986
		RegisterScheme("myrfc", SchemeBehavior{MustFollowRFC3986Authority: true})

		// myrfc://host/path -> host + path
		info, err := ParsePathInfoWithOptions("myrfc://server/path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "myrfc://", info.Scheme())
		assert.Equal(t, "server", info.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info.Parts())

		// myrfc:///path -> empty host + absolute path
		info2, err := ParsePathInfoWithOptions("myrfc:///path/to/file")
		require.NoError(t, err)
		assert.Equal(t, "myrfc://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("OverrideSchemeBehavior_ForceRFC3986", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()

		// Set default behavior to NOT follow RFC 3986
		DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

		// Use WithSchemeBehaviorOverride to force RFC 3986 behavior
		opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: true})

		// custom://host/path with override -> should follow RFC 3986
		info, err := ParsePathInfoWithOptions("customscheme://host/path", opt)
		require.NoError(t, err)
		assert.Equal(t, "customscheme://", info.Scheme())
		assert.Equal(t, "host", info.Host())
		assert.Equal(t, []string{"path"}, info.Parts())

		// custom:///path with override -> empty host + absolute path
		info2, err := ParsePathInfoWithOptions("customscheme:///path/to/file", opt)
		require.NoError(t, err)
		assert.Equal(t, "customscheme://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("OverrideSchemeBehavior_DisableRFC3986", func(t *testing.T) {
		// Use WithSchemeBehaviorOverride to disable RFC 3986 behavior for standard scheme
		opt := WithSchemeBehaviorOverride(SchemeBehavior{MustFollowRFC3986Authority: false})

		// http://host/path with override (MustFollowRFC3986Authority=false) ->
		// host should NOT be extracted; all content after scheme:// is treated as path
		info, err := ParsePathInfoWithOptions("http://example.com/path", opt)
		require.NoError(t, err)
		assert.Equal(t, "http://", info.Scheme())
		assert.Equal(t, "", info.Host(), "Host should be empty when MustFollowRFC3986Authority=false")
		assert.Equal(t, []string{"example.com", "path"}, info.Parts(), "All content after scheme:// should be path")

		// http:///path with override -> empty host (3+ slashes always mean empty host)
		info2, err := ParsePathInfoWithOptions("http:///path/to/file", opt)
		require.NoError(t, err)
		assert.Equal(t, "http://", info2.Scheme())
		assert.Equal(t, "", info2.Host())
		assert.Equal(t, []string{"path", "to", "file"}, info2.Parts())
	})

	t.Run("BackwardCompatibility_ParsePathInfoEasy", func(t *testing.T) {
		// Reset registry
		schemeRegistry.Lock()
		schemeRegistry.behaviors = make(map[string]SchemeBehavior)
		schemeRegistry.Unlock()
		DefaultSchemeBehavior = SchemeBehavior{MustFollowRFC3986Authority: false}

		// ParsePathInfoEasy should behave with the fixed behavior
		info, err := ParsePathInfoEasy("custom://host/path")
		require.NoError(t, err)
		assert.Equal(t, "custom://", info.Scheme())
		assert.Equal(t, "", info.Host(), "Host should be empty when MustFollowRFC3986Authority=false")
		assert.Equal(t, []string{"host", "path"}, info.Parts(), "All content after scheme:// should be path")

		// Standard scheme should still follow RFC 3986
		info2, err := ParsePathInfoEasy("http://example.com/path")
		require.NoError(t, err)
		assert.Equal(t, "http://", info2.Scheme())
		assert.Equal(t, "example.com", info2.Host())
		assert.Equal(t, []string{"path"}, info2.Parts())
	})
}

// TestPathParsing_ParsePathInfo tests that paths are correctly parsed into PathInfo.
func TestPathParsing_ParsePathInfo(t *testing.T) {
	const _fileEmptyScheme = ""
	const _fileEmptyLocalhost = ""
	tests := []struct {
		name       string
		path       string
		wantScheme string
		wantHost   string
		wantEncode string
		wantSep    rune
		wantParts  []string
		wantType   PathType
		wantErr    bool
	}{
		// Empty path
		{"Empty path", "", "", "", "", filepath.Separator, nil, PathTypeUnknown, false},

		// Unix paths
		{"Unix absolute", "/a/b/c", _fileEmptyScheme, _fileEmptyLocalhost, "/a/b/c", '/', []string{"a", "b", "c"}, PathTypeLocalAbsolute, false},
		{"Unix relative", "a/b/c", _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c", '/', []string{"a", "b", "c"}, PathTypeLocalRelative, false},
		{"Unix root", "/", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},

		// Windows paths
		{"Windows drive", `C:\a\b`, _fileEmptyScheme, "C:", `C:\a\b`, '\\', []string{"a", "b"}, PathTypeLocalAbsolute, false},
		{"Windows UNC local file", `\\?\C:\a\b`, _fileEmptyScheme, "C:", `C:\a\b`, '\\', []string{"a", "b"}, PathTypeLocalAbsolute, false},

		// windows not support drive relative path like "d:a\b". but linux support it.
		{"Windows error path", `d:\a:\b`, "", "", ``, '\\', []string{}, PathTypeUnknown, true},
		{"Windows drive relative", `d:a\b`, "", "", ``, '\\', []string{}, PathTypeUnknown, true},
		{"linux", `/home/d:a/b`, _fileEmptyScheme, _fileEmptyLocalhost, `/home/d:a/b`, '/', []string{"home", "d:a", "b"}, PathTypeLocalAbsolute, false},
		{"linux", `home/d:a/b`, _fileEmptyScheme, _fileEmptyLocalhost, `home/d:a/b`, '/', []string{"home", "d:a", "b"}, PathTypeLocalRelative, false},

		// Mixed separators (以第一个\u002f或\u005c为准，URI/UNC协议的除外)
		{"Mixed separators", `a/b\c/d`, _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c/d", '/', []string{"a", "b", "c", "d"}, PathTypeLocalRelative, false},
		{"Mixed separators", `a\b/c/d`, _fileEmptyScheme, _fileEmptyLocalhost, `a\b\c\d`, '\\', []string{"a", "b", "c", "d"}, PathTypeLocalRelative, false},

		// Windows drive variations
		{"Windows drive D", `d:\data\files\config.json`, _fileEmptyScheme, "d:", `d:\data\files\config.json`, '\\', []string{"data", "files", "config.json"}, PathTypeLocalAbsolute, false},
		{"Windows drive lowercase", `e:\test\file.txt`, _fileEmptyScheme, "e:", `e:\test\file.txt`, '\\', []string{"test", "file.txt"}, PathTypeLocalAbsolute, false},

		// Relative paths
		{"Relative nested", "a/b/c/d/file.txt", _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, PathTypeLocalRelative, false},

		// Paths with . and .. (cleaned)
		{"Path with .", `d:\data\.\config.json`, _fileEmptyScheme, "d:", `d:\data\config.json`, '\\', []string{"data", "config.json"}, PathTypeLocalAbsolute, false},
		{"Path with ..", `d:\data\..\config.json`, _fileEmptyScheme, "d:", `d:\config.json`, '\\', []string{"config.json"}, PathTypeLocalAbsolute, false},
		{"Path with multiple ..", `d:\a\b\..\..\c\file.txt`, _fileEmptyScheme, "d:", `d:\c\file.txt`, '\\', []string{"c", "file.txt"}, PathTypeLocalAbsolute, false},
		{"Relative path with .", "documents/./report.pdf", _fileEmptyScheme, _fileEmptyLocalhost, "documents/report.pdf", '/', []string{"documents", "report.pdf"}, PathTypeLocalRelative, false},
		{"Relative path with ..", "documents/../config.json", _fileEmptyScheme, _fileEmptyLocalhost, "config.json", '/', []string{"config.json"}, PathTypeLocalRelative, false},

		// Complex paths (cleaned)
		{"Complex path 1", `d:\data\.\files\..\config.json`, _fileEmptyScheme, "d:", `d:\data\config.json`, '\\', []string{"data", "config.json"}, PathTypeLocalAbsolute, false},
		{"Complex path 3", "/a/b/../c/./d/file.txt", _fileEmptyScheme, _fileEmptyLocalhost, "/a/c/d/file.txt", '/', []string{"a", "c", "d", "file.txt"}, PathTypeLocalAbsolute, false},

		// Unix path with colons (not URI)
		{"Unix path with colon", "/xx/xxx:xx/xxx:/xxxx", _fileEmptyScheme, _fileEmptyLocalhost, "/xx/xxx:xx/xxx:/xxxx", '/', []string{"xx", "xxx:xx", "xxx:", "xxxx"}, PathTypeLocalAbsolute, false},
		{"Unix path with multiple colons", "/a/b:c/d:e/f:g", _fileEmptyScheme, _fileEmptyLocalhost, "/a/b:c/d:e/f:g", '/', []string{"a", "b:c", "d:e", "f:g"}, PathTypeLocalAbsolute, false},
		{"Unix path with colon at end", "/path/to/file:attribute", _fileEmptyScheme, _fileEmptyLocalhost, "/path/to/file:attribute", '/', []string{"path", "to", "file:attribute"}, PathTypeLocalAbsolute, false},

		// Various path lengths
		{"Short path", "a/b", _fileEmptyScheme, _fileEmptyLocalhost, "a/b", '/', []string{"a", "b"}, PathTypeLocalRelative, false},
		{"Medium path", "a/b/c/d/e", _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c/d/e", '/', []string{"a", "b", "c", "d", "e"}, PathTypeLocalRelative, false},
		{"Long path", "a/b/c/d/e/f/g/h", _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c/d/e/f/g/h", '/', []string{"a", "b", "c", "d", "e", "f", "g", "h"}, PathTypeLocalRelative, false},

		{"Windows medium path", `C:\a\b\c\d\e`, _fileEmptyScheme, "C:", `C:\a\b\c\d\e`, '\\', []string{"a", "b", "c", "d", "e"}, PathTypeLocalAbsolute, false},
		// Additional Windows drives
		{"Windows drive D extended", `d:\data\file.txt`, _fileEmptyScheme, "d:", `d:\data\file.txt`, '\\', []string{"data", "file.txt"}, PathTypeLocalAbsolute, false},

		// Unix paths with various separators
		{"Unix path with subdirs", "/a/b/c/file.txt", _fileEmptyScheme, _fileEmptyLocalhost, "/a/b/c/file.txt", '/', []string{"a", "b", "c", "file.txt"}, PathTypeLocalAbsolute, false},
		{"Relative Unix path extended", "a/b/c/file.txt", _fileEmptyScheme, _fileEmptyLocalhost, "a/b/c/file.txt", '/', []string{"a", "b", "c", "file.txt"}, PathTypeLocalRelative, false},
		//
		{"Relative Windows path extended", `a\b\c\file.txt`, _fileEmptyScheme, _fileEmptyLocalhost, `a\b\c\file.txt`, '\\', []string{"a", "b", "c", "file.txt"}, PathTypeLocalRelative, false},

		// Windows paths with backslash
		{"Windows path with subdirs", `C:\Documents\file.txt`, _fileEmptyScheme, "C:", `C:\Documents\file.txt`, '\\', []string{"Documents", "file.txt"}, PathTypeLocalAbsolute, false},
		// ====================

		// URI paths
		// TODO: RFC 8089 format: file:
		// file://[可选主机]/<路径>

		// URI files:
		{"", `file:///d:\data\file.txt`, "file://", "d:", "file:///d:/data/file.txt", '/', []string{"data", "file.txt"}, PathTypeFileUriLocal, false},
		{"", `file:///d:\aaa\bbb/ccc`, "file://", "d:", "file:///d:/aaa/bbb/ccc", '/', []string{"aaa", "bbb", "ccc"}, PathTypeFileUriLocal, false},
		{"files:/// URI", "files:///a/b/c", "files://", _fileEmptyLocalhost, "files:///a/b/c", '/', []string{"a", "b", "c"}, PathTypeFileUriLocal, false},
		{"files:/// nested", "files:///a/b/c/d/file.txt", "files://", _fileEmptyLocalhost, "files:///a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, PathTypeFileUriLocal, false},
		{"files:/// + backslash separator", `files:\\\d:\a\b\c`, "files://", "d:", "files:///d:/a/b/c", '/', []string{"a", "b", "c"}, PathTypeFileUriLocal, false},
		{"", `files:///d:\data\file.txt`, "files://", "d:", "files:///d:/data/file.txt", '/', []string{"data", "file.txt"}, PathTypeFileUriLocal, false},
		{"files:/// URI extended", "files:///documents/report.pdf", "files://", _fileEmptyLocalhost, "files:///documents/report.pdf", '/', []string{"documents", "report.pdf"}, PathTypeFileUriLocal, false},
		{"files:/// + complex path", `files:///d:\aaa\bbb/ccc\.\\../.\xxx`, "files://", "d:", "files:///d:/aaa/bbb/xxx", '/', []string{"aaa", "bbb", "xxx"}, PathTypeFileUriLocal, false},
		//
		{"file:// with host", "file://server/share/file.txt", "file://", "server", "file://server/share/file.txt", '/', []string{"share", "file.txt"}, PathTypeFileUriRemote, false},
		{"file:// URI", "file://a/b/c", "file://", "a", "file://a/b/c", '/', []string{"b", "c"}, PathTypeFileUriRemote, false},
		{"file:// + mixed slashes", `file://aaa\bbb/\/\/\/\/\/\/\ccc`, "file://", "aaa", "file://aaa/bbb/ccc", '/', []string{"bbb", "ccc"}, PathTypeFileUriRemote, false},

		// RFC 8089: file:/path is equivalent to file:///path (minimal representation)
		{"file:/ minimal (RFC 8089)", "file:/path/to/file", "file://", "", "file:///path/to/file", '/', []string{"path", "to", "file"}, PathTypeFileUriLocal, false},

		// RFC 8089: file://localhost/path is local file
		{"file://localhost (RFC 8089)", "file://localhost/path/to/file", "file://", "localhost", "file://localhost/path/to/file", '/', []string{"path", "to", "file"}, PathTypeFileUriLocal, false},

		// RFC 8089: file://127.0.0.1/path is local file (loopback)
		{"file://127.0.0.1 (RFC 8089)", "file://127.0.0.1/path/to/file", "file://", "127.0.0.1", "file://127.0.0.1/path/to/file", '/', []string{"path", "to", "file"}, PathTypeFileUriLocal, false},

		// RFC 8089: file://[::1]/path is local file (IPv6 loopback)
		{"file://[::1] (RFC 8089)", "file://[::1]/path/to/file", "file://", "[::1]", "file://[::1]/path/to/file", '/', []string{"path", "to", "file"}, PathTypeFileUriLocal, false},

		{"file+unc", "files:////aaa/bbb/ccc", "files://", "aaa", "files:////aaa/bbb/ccc", '/', []string{"bbb", "ccc"}, PathTypeFileUriUnc, false},
		//
		{"files:/// with backslash", `files:///documents\report.pdf`, "files://", _fileEmptyLocalhost, `files:///documents/report.pdf`, '/', []string{"documents", "report.pdf"}, PathTypeFileUriLocal, false},

		// URI: file://x:/ 非标准的兼容语法.windows下自动补/
		{"win fix file://x:/ => file:///x:/", `file://d:\data\file.txt`, "file://", "d:", "file:///d:/data/file.txt", '/', []string{"data", "file.txt"}, PathTypeFileUriLocal, false},
		{"", "file://d:/xxx/xxx/xxx", "file://", "d:", "file:///d:/xxx/xxx/xxx", '/', []string{"xxx", "xxx", "xxx"}, PathTypeFileUriLocal, false},
		{"", `file://d:\xxx\xxx/xxx`, "file://", "d:", "file:///d:/xxx/xxx/xxx", '/', []string{"xxx", "xxx", "xxx"}, PathTypeFileUriLocal, false},
		{"file:// multiple slashes", `file://////////d:\xxx\xxx/xxx`, "file://", "d:", "file:///d:/xxx/xxx/xxx", '/', []string{"xxx", "xxx", "xxx"}, PathTypeFileUriLocal, false},
		{"", `files://d:\data\file.txt`, "files://", "d:", "files:///d:/data/file.txt", '/', []string{"data", "file.txt"}, PathTypeFileUriLocal, false},
		// {"file:/// multiple slashes", "file://////d:/xxx/xxx", "files://", "d:/xxx/xxx", '/', []string{"d:", "xxx", "xxx"}, PathTypeFileUriLocal, false},

		// custom URI - unregistered schemes with MustFollowRFC3986Authority=false (default)
		// When MustFollowRFC3986Authority=false, scheme://a/b/c should NOT extract host
		{"custom:// URI", "http://host/path", "http://", "host", "http://host/path", '/', []string{"path"}, PathTypeCustomUri, false},
		{"custom:// URI", "custom://host/path", "custom://", "", "custom:///host/path", '/', []string{"host", "path"}, PathTypeCustomUri, false},
		{"custom:// with backslash", `custom://host\path\file.txt`, "custom://", "", "custom:///host/path/file.txt", '/', []string{"host", "path", "file.txt"}, PathTypeCustomUri, false},
		{"myscheme:// URI", "myscheme://server/share/data.json", "myscheme://", "", "myscheme:///server/share/data.json", '/', []string{"server", "share", "data.json"}, PathTypeCustomUri, false},
		{"abc123:// URI", "abc123://host/path", "abc123://", "", "abc123:///host/path", '/', []string{"host", "path"}, PathTypeCustomUri, false},
		///
		{"custom:/// URI", "custom:///path/to/file.txt", "custom://", _fileEmptyLocalhost, "custom:///path/to/file.txt", '/', []string{"path", "to", "file.txt"}, PathTypeCustomUri, false},
		{"custom:/// with backslash", `custom:///path\to\file.txt`, "custom://", _fileEmptyLocalhost, `custom:///path/to/file.txt`, '/', []string{"path", "to", "file.txt"}, PathTypeCustomUri, false},
		{"custom:/// with backslash", `custom:///path\to/file.txt`, "custom://", _fileEmptyLocalhost, `custom:///path/to/file.txt`, '/', []string{"path", "to", "file.txt"}, PathTypeCustomUri, false},
		{"test-scheme:/// URI", "test-scheme:///a/b/c/file.dat", "test-scheme://", _fileEmptyLocalhost, "test-scheme:///a/b/c/file.dat", '/', []string{"a", "b", "c", "file.dat"}, PathTypeCustomUri, false},
		{"x.y-z:/// URI", "x.y-z:///data/file.txt", "x.y-z://", _fileEmptyLocalhost, "x.y-z:///data/file.txt", '/', []string{"data", "file.txt"}, PathTypeCustomUri, false},
		{"custom:/// URI extended", "custom:///path/to/file", "custom://", _fileEmptyLocalhost, "custom:///path/to/file", '/', []string{"path", "to", "file"}, PathTypeCustomUri, false},

		// ===========

		// UNC paths
		{"UNC path", `\\server\share\path`, `\\`, "server", `\\server\share\path`, '\\', []string{"share", "path"}, PathTypeUncWindows, false},
		{"UNC path with IP", `\\192.168.1.2\share\documents\report.pdf`, `\\`, `192.168.1.2`, `\\192.168.1.2\share\documents\report.pdf`, '\\', []string{"share", "documents", "report.pdf"}, PathTypeUncWindows, false},
		{"UNC path with hostname", `\\server\share\folder\file.txt`, `\\`, `server`, `\\server\share\folder\file.txt`, '\\', []string{"share", "folder", "file.txt"}, PathTypeUncWindows, false},
		{"UNC path with IP extended", `\\192.168.1.2\share\file.txt`, `\\`, `192.168.1.2`, `\\192.168.1.2\share\file.txt`, '\\', []string{"share", "file.txt"}, PathTypeUncWindows, false},
		{"UNC path with hostname extended", `\\server\share\file.txt`, `\\`, `server`, `\\server\share\file.txt`, '\\', []string{"share", "file.txt"}, PathTypeUncWindows, false},
		{"UNC ", `\\?\\server\share\path`, `\\`, "server", `\\server\share\path`, '\\', []string{"share", "path"}, PathTypeUncWindows, false},

		// ========== Pure special characters (., \, /) combinations ==========

		// Single character
		{"Single dot", ".", _fileEmptyScheme, _fileEmptyLocalhost, "", DefaultSystemSeparator, []string{}, PathTypeLocalRelative, false},
		{"Single backslash", `\`, _fileEmptyScheme, _fileEmptyLocalhost, "", '\\', []string{}, PathTypeLocalRelative, false},
		{"Single slash", "/", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},

		// Double characters
		{"Double dot", "..", _fileEmptyScheme, _fileEmptyLocalhost, "..", DefaultSystemSeparator, []string{".."}, PathTypeLocalRelative, false},
		{"Double backslash", `\\`, `\\`, _fileEmptyLocalhost, `\\`, '\\', nil, PathTypeUncWindows, false},
		{"Double slash", "//", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},
		{"Dot slash", "./", _fileEmptyScheme, _fileEmptyLocalhost, "", '/', []string{}, PathTypeLocalRelative, false},
		{"Dot backslash", `.\`, _fileEmptyScheme, _fileEmptyLocalhost, "", '\\', []string{}, PathTypeLocalRelative, false},
		{"Slash dot", "/.", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},
		{"Backslash dot", `\.`, _fileEmptyScheme, _fileEmptyLocalhost, "", '\\', []string{}, PathTypeLocalRelative, false},

		// Triple characters
		{"Dot dot slash", "../", _fileEmptyScheme, _fileEmptyLocalhost, "..", '/', []string{".."}, PathTypeLocalRelative, false},
		{"Dot dot backslash", `..\`, _fileEmptyScheme, _fileEmptyLocalhost, "..", '\\', []string{".."}, PathTypeLocalRelative, false},
		{"Slash dot dot", "/..", _fileEmptyScheme, _fileEmptyLocalhost, "/..", '/', []string{".."}, PathTypeLocalAbsolute, false},
		{"Backslash dot dot", `\..`, _fileEmptyScheme, _fileEmptyLocalhost, "..", '\\', []string{".."}, PathTypeLocalRelative, false},
		{"Dot dot dot", "...", _fileEmptyScheme, _fileEmptyLocalhost, "...", DefaultSystemSeparator, []string{"..."}, PathTypeLocalRelative, false},
		{"Slash slash slash", "///", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},
		{"Backslash backslash backslash", `\\\`, `\\`, _fileEmptyLocalhost, `\\\`, '\\', []string{""}, PathTypeUncWindows, false},

		// Mixed combinations
		{"Dot slash dot", "./.", _fileEmptyScheme, _fileEmptyLocalhost, "", '/', []string{}, PathTypeLocalRelative, false},
		{"Dot backslash dot", `.\.`, _fileEmptyScheme, _fileEmptyLocalhost, "", '\\', []string{}, PathTypeLocalRelative, false},
		{"Slash dot slash", "/./", _fileEmptyScheme, _fileEmptyLocalhost, "/", '/', []string{""}, PathTypeLocalAbsolute, false},
		{"Backslash dot backslash", `\.\`, _fileEmptyScheme, _fileEmptyLocalhost, "", '\\', []string{}, PathTypeLocalRelative, false},
		{"Dot dot slash dot", "../.", _fileEmptyScheme, _fileEmptyLocalhost, "..", '/', []string{".."}, PathTypeLocalRelative, false},
		{"Dot dot backslash dot", `..\.`, _fileEmptyScheme, _fileEmptyLocalhost, "..", '\\', []string{".."}, PathTypeLocalRelative, false},
		{"Dot dot backslash dot", `..\.`, _fileEmptyScheme, _fileEmptyLocalhost, "..", '\\', []string{".."}, PathTypeLocalRelative, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info, err := ParsePathInfo(tt.path)
			if tt.wantErr {
				assert.Error(t, err)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, tt.wantScheme, info.Scheme())
			assert.Equal(t, tt.wantHost, info.Host())
			
			// For UNC Windows paths, adjust expected separator based on platform
			// Only for pure UNC prefix "\\" (without server/share)
			expectedSep := tt.wantSep
			if tt.wantType == PathTypeUncWindows && tt.wantSep == '\\' && len(tt.path) == 2 {
				// On Linux, UNC Windows prefix "\\" uses '/' as separator
				// On Windows, it uses '\\' as separator
				expectedSep = filepath.Separator
			}
			assert.Equal(t, expectedSep, info.Separator())
			
			assert.EqualValues(t, tt.wantParts, info.Parts())
			assert.Equal(t, tt.wantType, info.Type())
			assert.Equal(t, tt.wantEncode, info.Encode())
		})
	}
}

// TestPathInfo_Methods tests PathInfo methods: Join, Encode, ReplaceParts.
func TestPathInfo_Methods(t *testing.T) {
	t.Run("Join", func(t *testing.T) {
		info := ParsePathInfoMust("/a/b")
		newInfo := info.Join("c", "d")

		assert.Equal(t, "/a/b/c/d", newInfo.Encode())
		// Original info should not be modified
		assert.Equal(t, "/a/b", info.Encode())
	})

	t.Run("Encode", func(t *testing.T) {
		info := ParsePathInfoMust("file:///a/b/c")
		encoded := info.Encode()

		assert.Equal(t, "file:///a/b/c", encoded)
	})

	t.Run("ReplaceParts", func(t *testing.T) {
		info := ParsePathInfoMust("/a/b/c")
		newInfo := info.ReplaceParts([]string{"x", "y", "z"})

		assert.Equal(t, "/x/y/z", newInfo.Encode())
		// Original info should not be modified
		assert.Equal(t, "/a/b/c", info.Encode())
	})

	// ========== Pure special characters (., \, /) combinations ==========

	t.Run("SpecialChars: single dot", func(t *testing.T) {
		info := ParsePathInfoMust(".")
		assert.Equal(t, "", info.Encode())
		assert.Equal(t, []string{}, info.Parts())
	})

	t.Run("SpecialChars: single slash", func(t *testing.T) {
		info := ParsePathInfoMust("/")
		assert.Equal(t, "/", info.Encode())
		assert.Equal(t, []string{""}, info.Parts())
	})

	t.Run("SpecialChars: single backslash", func(t *testing.T) {
		info := ParsePathInfoMust(`\`)
		assert.Equal(t, "", info.Encode())
		assert.Equal(t, []string{}, info.Parts())
	})

	t.Run("SpecialChars: double dot", func(t *testing.T) {
		info := ParsePathInfoMust("..")
		assert.Equal(t, "..", info.Encode())
		assert.Equal(t, []string{".."}, info.Parts())
	})

	t.Run("SpecialChars: double slash", func(t *testing.T) {
		info := ParsePathInfoMust("//")
		assert.Equal(t, "/", info.Encode())
	})

	t.Run("SpecialChars: double backslash (UNC)", func(t *testing.T) {
		info := ParsePathInfoMust(`\\`)
		assert.Equal(t, `\\`, info.Encode())
		assert.Equal(t, `\\`, info.Scheme())
	})
}

// TestPathInfo_ContainsPath tests the ContainsPath method.
// ContainsPath returns true if otherPath is a sub-path OR the same path.
func TestPathInfo_ContainsPath(t *testing.T) {
	tests := []struct {
		name      string
		basePath  string
		otherPath string
		want      bool
	}{
		// ==================== Same paths (contained) ====================
		{"Same path", `/a/b`, `/a/b`, true},
		{"Same path (relative)", `a/b`, `a/b`, true},
		{"Path with . (cleaned, same path)", `/a/b`, `/a/./b`, true},

		// ==================== Sub-paths (contained) ====================
		{"Sub-path (1 level)", `/a/b`, `/a/b/c`, true},
		{"Sub-path (2 levels)", `/a/b`, `/a/b/c/d`, true},
		{"Sub-path (deep)", `/a/b`, `/a/b/c/d/e/f`, true},
		{"Relative sub-path", `a/b`, `a/b/c`, true},

		// ==================== Not contained ====================
		{"Parent path", `/a/b`, `/a`, false},
		{"Sibling path", `/a/b`, `/a/c`, false},
		{"Completely different path", `/a/b`, `/x/y`, false},

		// ==================== Different prefix ====================
		{"Different prefix (URI)", `file:///a/b`, `files:///a/b/c`, false},
		{"Different prefix (drive)", `C:\a\b`, `D:\a\b\c`, false},

		// ==================== Empty paths ====================
		{"Empty base path", ``, `/a/b/c`, false},
		{"Empty other path", `/a/b`, ``, false},

		// ==================== Windows paths ====================
		{"Windows same path", `C:\a\b`, `C:\a\b`, true},
		{"Windows sub-path", `C:\a\b`, `C:\a\b\c`, true},

		// ==================== URI paths ====================
		{"URI same path", `file:///a/b`, `file:///a/b`, true},
		{"URI sub-path", `file:///a/b`, `file:///a/b/c`, true},

		// ==================== Path with . and .. (cleaned before comparison) ====================
		{"Path with .", `/a/b`, `/a/./b/c`, true},
		{"Path with ..", `/a/b`, `/a/b/../b/c`, true},

		// ==================== Root path ====================
		{"Root contains path", `/`, `/a`, true},
		{"Root contains deep path", `/`, `/a/b/c/d`, true},
		{"Root contains root", `/`, `/`, true},

		// ========== Pure special characters (., \, /) combinations ==========

		// Same paths
		{"Same path: .", `.`, `.`, true},
		{"Same path: ..", `..`, `..`, true},
		{"Same path: /", `/`, `/`, true},
		{"Same path: \\\\", `\\`, `\\`, true},

		// Different paths
		{"Different: . vs ..", `.`, `..`, false},        // . and .. are different paths
		{"Different: / vs .", `/`, `.`, false},          // Absolute vs relative
		{"Different: / vs backslash", `/`, `\\`, false}, // Unix root vs UNC prefix

		// Sub-path relationships
		{"Sub-path: / contains /a", `/`, `/a`, true},
		{"Sub-path: / contains /..", `/`, `/..`, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			baseInfo := ParsePathInfoMust(tt.basePath)

			// Test with string input
			got := baseInfo.ContainsPath(tt.otherPath)
			if got != tt.want {
				t.Errorf("ContainsPath(%q) = %v, want %v", tt.otherPath, got, tt.want)
			}

			// Test with *PathInfo input
			otherInfo := ParsePathInfoMust(tt.otherPath)
			got = baseInfo.ContainsPathInfo(otherInfo)
			if got != tt.want {
				t.Errorf("ContainsPath(*PathInfo) = %v, want %v", got, tt.want)
			}
		})
	}
}
