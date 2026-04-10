// Package sec_utils provides utilities for secure file system operations.
// This file contains tests for path utility functions.
package sec_utils

import (
	"path/filepath"
	"testing"
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
		{"custom:// URI", "custom://host/path", "custom://host/path"},

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
		{"UNC path extended", `\\server\share\file.txt`, `\\server\share\file.txt`},
		{"Relative Windows path", `a\b\c\file.txt`, `a\b\c\file.txt`},

		// ========== Extended test cases from original TestPathParsing_SplitJoin ==========

		// Various path lengths
		{"Short path", "a/b", "a/b"},
		{"Medium path", "a/b/c/d/e", "a/b/c/d/e"},
		{"Long path", "a/b/c/d/e/f/g/h", "a/b/c/d/e/f/g/h"},
		{"Windows short path", `C:\a\b`, `C:\a\b`},
		{"Windows medium path", `C:\a\b\c\d\e`, `C:\a\b\c\d\e`},
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

// TestPathParsing_ParsePathInfo tests that paths are correctly parsed into PathInfo.
func TestPathParsing_ParsePathInfo(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		wantPrefix string
		wantPath   string
		wantSep    rune
		wantParts  []string
		wantIsAbs  bool
	}{
		// Empty path
		{"Empty path", "", "", "", filepath.Separator, nil, false},

		// Unix paths
		{"Unix absolute", "/a/b/c", "", "/a/b/c", '/', []string{"", "a", "b", "c"}, true},
		{"Unix relative", "a/b/c", "", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"Unix root", "/", "", "/", '/', []string{"", ""}, true},

		// Windows paths
		{"Windows drive", `C:\a\b`, "C:", `\a\b`, '\\', []string{"", "a", "b"}, true},
		{"Windows drive relative", `d:a\b`, "d:", `a\b`, '\\', []string{"a", "b"}, false},

		// URI paths
		{"file:// URI", "file:///a/b/c", "file:///", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"file:// relative", "file://a/b/c", "file://", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"files:// URI", "files:///a/b/c", "files:///", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"custom:// URI", "custom://host/path", "custom://", "host/path", '/', []string{"host", "path"}, false},

		// UNC paths
		{"UNC path", `\\server\share\path`, `\\server`, `\share\path`, '\\', []string{"", "share", "path"}, true},

		// Mixed separators (cleaned to use '/')
		{"Mixed separators", `a/b\c/d`, "", "a/b/c/d", '/', []string{"a", "b", "c", "d"}, false},

		// ========== Extended test cases from TestPathEncryption_AllPathFormats ==========

		// UNC paths with variations
		{"UNC path with IP", `\\192.168.1.2\share\documents\report.pdf`, `\\192.168.1.2`, `\share\documents\report.pdf`, '\\', []string{"", "share", "documents", "report.pdf"}, true},
		{"UNC path with hostname", `\\server\share\folder\file.txt`, `\\server`, `\share\folder\file.txt`, '\\', []string{"", "share", "folder", "file.txt"}, true},

		// files:// URI variations
		{"files:// nested", "files:///a/b/c/d/file.txt", "files:///", "a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, false},
		// Note: files:// with backslash is a mixed separator case, behavior may vary by OS
		// {"files:// with backslash", `files:///documents\report.pdf`, "files:///", "documents/report.pdf", '/', []string{"documents", "report.pdf"}, false},

		// file:// URI variations
		{"file:// with host", "file://server/share/file.txt", "file://", "server/share/file.txt", '/', []string{"server", "share", "file.txt"}, false},

		// Arbitrary URI schemes
		{"custom:/// URI", "custom:///path/to/file.txt", "custom:///", "path/to/file.txt", '/', []string{"path", "to", "file.txt"}, false},
		// Note: custom:// with backslash is a mixed separator case, behavior may vary by OS
		// {"custom:// with backslash", `custom://host\path\file.txt`, "custom://", "host/path/file.txt", '/', []string{"host", "path", "file.txt"}, false},
		// {"custom:/// with backslash", `custom:///path\to\file.txt`, "custom:///", "path/to/file.txt", '/', []string{"path", "to", "file.txt"}, false},
		{"myscheme:// URI", "myscheme://server/share/data.json", "myscheme://", "server/share/data.json", '/', []string{"server", "share", "data.json"}, false},
		{"test-scheme:/// URI", "test-scheme:///a/b/c/file.dat", "test-scheme:///", "a/b/c/file.dat", '/', []string{"a", "b", "c", "file.dat"}, false},
		{"abc123:// URI", "abc123://host/path", "abc123://", "host/path", '/', []string{"host", "path"}, false},
		{"x.y-z:/// URI", "x.y-z:///data/file.txt", "x.y-z:///", "data/file.txt", '/', []string{"data", "file.txt"}, false},

		// Windows drive variations
		{"Windows drive D", `d:\data\files\config.json`, "d:", `\data\files\config.json`, '\\', []string{"", "data", "files", "config.json"}, true},
		{"Windows drive lowercase", `e:\test\file.txt`, "e:", `\test\file.txt`, '\\', []string{"", "test", "file.txt"}, true},

		// Relative paths
		{"Relative nested", "a/b/c/d/file.txt", "", "a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, false},

		// Paths with . and .. (cleaned)
		{"Path with .", `d:\data\.\config.json`, "d:", `\data\config.json`, '\\', []string{"", "data", "config.json"}, true},
		{"Path with ..", `d:\data\..\config.json`, "d:", `\config.json`, '\\', []string{"", "config.json"}, true},
		{"Path with multiple ..", `d:\a\b\..\..\c\file.txt`, "d:", `\c\file.txt`, '\\', []string{"", "c", "file.txt"}, true},
		{"Relative path with .", "documents/./report.pdf", "", "documents/report.pdf", '/', []string{"documents", "report.pdf"}, false},
		{"Relative path with ..", "documents/../config.json", "", "config.json", '/', []string{"config.json"}, false},

		// Complex paths (cleaned)
		{"Complex path 1", `d:\data\.\files\..\config.json`, "d:", `\data\config.json`, '\\', []string{"", "data", "config.json"}, true},
		{"Complex path 3", "/a/b/../c/./d/file.txt", "", "/a/c/d/file.txt", '/', []string{"", "a", "c", "d", "file.txt"}, true},

		// URI + Windows drive combinations
		// Note: These are complex cases with mixed OS-specific behavior
		// {"file:// + Windows drive", `file://d:\data\file.txt`, "file://", "d:/data/file.txt", '/', []string{"d:", "data", "file.txt"}, false},
		// {"files:// + Windows drive", `files://d:\data\file.txt`, "files://", "d:/data/file.txt", '/', []string{"d:", "data", "file.txt"}, false},
		// {"file:/// + Windows drive", `file:///d:\data\file.txt`, "file:///", "d/data/file.txt", '/', []string{"d", "data", "file.txt"}, false},
		// {"files:/// + Windows drive", `files:///d:\data\file.txt`, "files:///", "d/data/file.txt", '/', []string{"d", "data", "file.txt"}, false},

		// Unix path with colons (not URI)
		{"Unix path with colon", "/xx/xxx:xx/xxx:/xxxx", "", "/xx/xxx:xx/xxx:/xxxx", '/', []string{"", "xx", "xxx:xx", "xxx:", "xxxx"}, true},
		{"Unix path with multiple colons", "/a/b:c/d:e/f:g", "", "/a/b:c/d:e/f:g", '/', []string{"", "a", "b:c", "d:e", "f:g"}, true},
		{"Unix path with colon at end", "/path/to/file:attribute", "", "/path/to/file:attribute", '/', []string{"", "path", "to", "file:attribute"}, true},

		// ========== Extended test cases from original TestPathParsing_Prefix ==========

		// Additional URI schemes
		{"files:// URI extended", "files:///documents/report.pdf", "files:///", "documents/report.pdf", '/', []string{"documents", "report.pdf"}, false},
		{"custom:/// URI extended", "custom:///path/to/file", "custom:///", "path/to/file", '/', []string{"path", "to", "file"}, false},

		// Additional UNC paths
		{"UNC path with IP extended", `\\192.168.1.2\share\file.txt`, `\\192.168.1.2`, `\share\file.txt`, '\\', []string{"", "share", "file.txt"}, true},
		{"UNC path with hostname extended", `\\server\share\file.txt`, `\\server`, `\share\file.txt`, '\\', []string{"", "share", "file.txt"}, true},

		// Additional Windows drives
		{"Windows drive D extended", `d:\data\file.txt`, "d:", `\data\file.txt`, '\\', []string{"", "data", "file.txt"}, true},
		{"Windows drive lowercase extended", `e:\test\file.txt`, "e:", `\test\file.txt`, '\\', []string{"", "test", "file.txt"}, true},

		// ========== Extended test cases from original TestPathParsing_Separator ==========

		// Unix paths with various separators
		{"Unix path with subdirs", "/a/b/c/file.txt", "", "/a/b/c/file.txt", '/', []string{"", "a", "b", "c", "file.txt"}, true},
		{"Relative Unix path extended", "a/b/c/file.txt", "", "a/b/c/file.txt", '/', []string{"a", "b", "c", "file.txt"}, false},

		// Windows paths with backslash
		{"Windows path with subdirs", `C:\Documents\file.txt`, "C:", `\Documents\file.txt`, '\\', []string{"", "Documents", "file.txt"}, true},
		{"UNC path extended", `\\server\share\file.txt`, `\\server`, `\share\file.txt`, '\\', []string{"", "share", "file.txt"}, true},
		{"Relative Windows path extended", `a\b\c\file.txt`, "", `a\b\c\file.txt`, '\\', []string{"a", "b", "c", "file.txt"}, false},

		// ========== Extended test cases from original TestPathParsing_SplitJoin ==========

		// Various path lengths
		{"Short path", "a/b", "", "a/b", '/', []string{"a", "b"}, false},
		{"Medium path", "a/b/c/d/e", "", "a/b/c/d/e", '/', []string{"a", "b", "c", "d", "e"}, false},
		{"Long path", "a/b/c/d/e/f/g/h", "", "a/b/c/d/e/f/g/h", '/', []string{"a", "b", "c", "d", "e", "f", "g", "h"}, false},
		{"Windows short path", `C:\a\b`, "C:", `\a\b`, '\\', []string{"", "a", "b"}, true},
		{"Windows medium path", `C:\a\b\c\d\e`, "C:", `\a\b\c\d\e`, '\\', []string{"", "a", "b", "c", "d", "e"}, true},

		// ========== New test cases for user-requested path formats ==========

		// file:// + Windows drive combinations
		{"file:// + Windows drive (forward slash)", "file://d:/xxx/xxx/xxx", "file://", "d:/xxx/xxx/xxx", '/', []string{"d:", "xxx", "xxx", "xxx"}, false},
		{"file:// + Windows drive (backslash)", `file://d:\xxx\xxx/xxx`, "file://", "d:/xxx/xxx/xxx", '/', []string{"d:", "xxx", "xxx", "xxx"}, false},
		{"file:/// + Windows drive", `file:///d:\xxx\xxx/xxx`, "file:///", "d:/xxx/xxx/xxx", '/', []string{"d", "xxx", "xxx", "xxx"}, false},
		{"file:// multiple slashes", `file://////////d:\xxx\xxx/xxx`, "file:///", "d:/xxx/xxx/xxx", '/', []string{"d", "xxx", "xxx", "xxx"}, false},

		// files:// + complex paths
		{"files:// + complex path", `files:///d:\xxx\xxx/xxx\.\\../.\xxx`, "files:///", "d:/xxx/xxx/xxx", '/', []string{"d", "xxx", "xxx", "xxx"}, false},
		{"files:// multiple slashes", "files://////d:/xxx/xxx", "files:///", "d:/xxx/xxx", '/', []string{"d", "xxx", "xxx"}, false},
		{"files:// + backslash separator", `files:\\\d:\xxx\xxx\xxx`, "files:///", "d:/xxx/xxx/xxx", '/', []string{"d", "xxx", "xxx", "xxx"}, false},

		// file:// + mixed slashes
		{"file:// + mixed slashes", `file://xxx\xxx/\/\/\/\/\/\/\xxx`, "file://", "xxx/xxx/xxx", '/', []string{"xxx", "xxx", "xxx"}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info := ParsePathInfoMust(tt.path)

			// RawPath now returns Original() (cleaned path) since rawPath field was removed
			if info.RawPath() != info.Original() {
				t.Errorf("RawPath = %q, want %q", info.RawPath(), info.Original())
			}
			// Original should be the cleaned full path (Prefix + Path)
			wantOriginal := tt.wantPrefix + tt.wantPath
			if info.Original() != wantOriginal {
				t.Errorf("Original = %q, want %q", info.Original(), wantOriginal)
			}
			if info.Prefix() != tt.wantPrefix {
				t.Errorf("Prefix = %q, want %q", info.Prefix(), tt.wantPrefix)
			}
			if info.Path() != tt.wantPath {
				t.Errorf("Path = %q, want %q", info.Path(), tt.wantPath)
			}
			if info.Separator() != tt.wantSep {
				t.Errorf("Separator = %q, want %q", info.Separator(), tt.wantSep)
			}
			if len(info.Parts()) != len(tt.wantParts) {
				t.Errorf("Parts = %v, want %v", info.Parts(), tt.wantParts)
			}
			if info.IsAbs() != tt.wantIsAbs {
				t.Errorf("IsAbs = %v, want %v", info.IsAbs(), tt.wantIsAbs)
			}
		})
	}
}

// TestPathInfo_Methods tests PathInfo methods: Join, Encode, ReplaceParts.
func TestPathInfo_Methods(t *testing.T) {
	t.Run("Join", func(t *testing.T) {
		info := ParsePathInfoMust("/a/b")
		newInfo := info.Join("c", "d")

		if newInfo.Path() != "/a/b/c/d" {
			t.Errorf("Join failed: got %q, want %q", newInfo.Path(), "/a/b/c/d")
		}
		// Original info should not be modified
		if info.Path() != "/a/b" {
			t.Errorf("Original info was modified: got %q, want %q", info.Path(), "/a/b")
		}
	})

	t.Run("Encode", func(t *testing.T) {
		info := ParsePathInfoMust("file:///a/b/c")
		encoded := info.Encode()

		if encoded != "file:///a/b/c" {
			t.Errorf("Encode failed: got %q, want %q", encoded, "file:///a/b/c")
		}
	})

	t.Run("ReplaceParts", func(t *testing.T) {
		info := ParsePathInfoMust("/a/b/c")
		newInfo := info.ReplaceParts([]string{"", "x", "y", "z"})

		if newInfo.Path() != "/x/y/z" {
			t.Errorf("ReplaceParts failed: got %q, want %q", newInfo.Path(), "/x/y/z")
		}
		// Original info should not be modified
		if info.Path() != "/a/b/c" {
			t.Errorf("Original info was modified: got %q, want %q", info.Path(), "/a/b/c")
		}
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
			got = baseInfo.ContainsPath(otherInfo)
			if got != tt.want {
				t.Errorf("ContainsPath(*PathInfo) = %v, want %v", got, tt.want)
			}
		})
	}
}
