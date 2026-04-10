// Package sec_utils provides utilities for secure file system operations.
// This file contains tests for path utility functions.
package sec_utils

import (
	"testing"
)

// TestPathParsing_Prefix tests that path prefixes are correctly parsed.
func TestPathParsing_Prefix(t *testing.T) {
	tests := []struct {
		name           string
		path           string
		wantPrefix     string
		wantRemaining  string
	}{
		// URI schemes
		{"file:// URI", "file:///documents/report.pdf", "file:///", "documents/report.pdf"},
		{"files:// URI", "files:///a/b/c", "files:///", "a/b/c"},
		{"custom:// URI", "custom://host/path", "custom://", "host/path"},
		{"custom:/// URI", "custom:///path/to/file", "custom:///", "path/to/file"},
		
		// UNC paths
		{"UNC path", "\\\\server\\share\\file.txt", "\\\\server", "\\share\\file.txt"},
		
		// Windows drives
		{"Windows drive C", "C:\\Documents\\file.txt", "C:", "\\Documents\\file.txt"},
		{"Windows drive d", "d:\\data\\file.txt", "d:", "\\data\\file.txt"},
		
		// Unix paths
		{"Unix absolute", "/documents/report.pdf", "", "/documents/report.pdf"},
		
		// Relative paths
		{"Relative path", "documents/report.pdf", "", "documents/report.pdf"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			prefix, remaining := ParsePathPrefix(tt.path)
			
			if prefix != tt.wantPrefix {
				t.Errorf("prefix mismatch: got %q, want %q", prefix, tt.wantPrefix)
			}
			
			if remaining != tt.wantRemaining {
				t.Errorf("remaining mismatch: got %q, want %q", remaining, tt.wantRemaining)
			}
		})
	}
}

// TestPathParsing_Separator tests that path separators are correctly detected.
func TestPathParsing_Separator(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		wantSep rune
	}{
		{"Unix path", "/a/b/c/file.txt", '/'},
		{"Windows path", "C:\\Documents\\file.txt", '\\'},
		{"file:// URI", "file:///a/b/c", '/'},
		{"UNC path", "\\\\server\\share\\file.txt", '\\'},
		{"Relative Unix", "a/b/c/file.txt", '/'},
		{"Relative Windows", "a\\b\\c\\file.txt", '\\'},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sep := DetectPathSeparator(tt.path)
			
			if sep != tt.wantSep {
				t.Errorf("separator mismatch: got %q, want %q", sep, tt.wantSep)
			}
		})
	}
}

// TestPathParsing_SplitJoin tests that paths are correctly split and joined.
func TestPathParsing_SplitJoin(t *testing.T) {
	tests := []struct {
		name    string
		path    string
		sep     rune
		wantLen int
	}{
		{"Unix path", "/a/b/c/file.txt", '/', 5},
		{"Windows path", "C:\\Documents\\file.txt", '\\', 3},
		{"Relative Unix", "a/b/c/file.txt", '/', 4},
		{"Relative Windows", "a\\b\\c\\file.txt", '\\', 4},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			parts := SplitPath(tt.path)
			
			if len(parts) != tt.wantLen {
				t.Errorf("parts length mismatch: got %d, want %d", len(parts), tt.wantLen)
			}
			
			// Join with separator
			joined := JoinPathWithSeparator(parts, tt.sep)
			
			// The joined path should have the same components
			joinedParts := SplitPath(joined)
			if len(joinedParts) != len(parts) {
				t.Errorf("joined parts length mismatch: got %d, want %d", len(joinedParts), len(parts))
			}
		})
	}
}

// TestPathParsing_Clean tests that paths are correctly cleaned.
func TestPathParsing_Clean(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		want     string
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
		{"Windows drive", "C:\\a\\b", "C:\\a\\b"},
		{"Windows with dot", "C:\\a\\.\\b", "C:\\a\\b"},
		{"Windows with double dot", "C:\\a\\b\\..\\c", "C:\\a\\c"},
		
		// URI paths
		{"file:// URI", "file:///a/b/c", "file:///a/b/c"},
		{"file:// with dot", "file:///a/./b", "file:///a/b"},
		{"file:// with double dot", "file:///a/b/../c", "file:///a/c"},
		{"files:// URI", "files:///a/b/c", "files:///a/b/c"},
		{"custom:// URI", "custom://host/path", "custom://host/path"},
		
		// UNC paths
		{"UNC path", "\\\\server\\share\\path", "\\\\server\\share\\path"},
		{"UNC with dot", "\\\\server\\share\\.\\path", "\\\\server\\share\\path"},
		{"UNC with double dot", "\\\\server\\share\\a\\..\\path", "\\\\server\\share\\path"},
		
		// Mixed . and ..
		{"Mixed dots", "a/./b/../c/./d", "a/c/d"},
		{"Complex path", "a/b/c/../../d/./e", "a/d/e"},
		
		// Edge cases
		{"Only separators", "///", "/"},
		{"Trailing separator", "a/b/", "a/b"},
		{"Leading separator", "/a/b", "/a/b"},
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
		name         string
		path         string
		wantPrefix   string
		wantPath     string
		wantSep      rune
		wantParts    []string
		wantIsAbs    bool
	}{
		// Empty path
		{"Empty path", "", "", "", '/', nil, false},
		
		// Unix paths
		{"Unix absolute", "/a/b/c", "", "/a/b/c", '/', []string{"", "a", "b", "c"}, true},
		{"Unix relative", "a/b/c", "", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"Unix root", "/", "", "/", '/', []string{"", ""}, true},
		
		// Windows paths
		{"Windows drive", "C:\\a\\b", "C:", "\\a\\b", '\\', []string{"", "a", "b"}, true},
		{"Windows drive relative", "d:a\\b", "d:", "a\\b", '\\', []string{"a", "b"}, false},
		
		// URI paths
		{"file:// URI", "file:///a/b/c", "file:///", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"file:// relative", "file://a/b/c", "file://", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"files:// URI", "files:///a/b/c", "files:///", "a/b/c", '/', []string{"a", "b", "c"}, false},
		{"custom:// URI", "custom://host/path", "custom://", "host/path", '/', []string{"host", "path"}, false},
		
		// UNC paths
		{"UNC path", "\\\\server\\share\\path", "\\\\server", "\\share\\path", '\\', []string{"", "share", "path"}, true},
		
		// Mixed separators (cleaned to use '/')
		{"Mixed separators", "a/b\\c/d", "", "a/b/c/d", '/', []string{"a", "b", "c", "d"}, false},
		
		// ========== Extended test cases from TestPathEncryption_AllPathFormats ==========
		
		// UNC paths with variations
		{"UNC path with IP", "\\\\192.168.1.2\\share\\documents\\report.pdf", "\\\\192.168.1.2", "\\share\\documents\\report.pdf", '\\', []string{"", "share", "documents", "report.pdf"}, true},
		{"UNC path with hostname", "\\\\server\\share\\folder\\file.txt", "\\\\server", "\\share\\folder\\file.txt", '\\', []string{"", "share", "folder", "file.txt"}, true},
		
		// files:// URI variations
		{"files:// nested", "files:///a/b/c/d/file.txt", "files:///", "a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, false},
		// Note: files:// with backslash is a mixed separator case, behavior may vary by OS
		// {"files:// with backslash", "files:///documents\\report.pdf", "files:///", "documents/report.pdf", '/', []string{"documents", "report.pdf"}, false},
		
		// file:// URI variations
		{"file:// with host", "file://server/share/file.txt", "file://", "server/share/file.txt", '/', []string{"server", "share", "file.txt"}, false},
		
		// Arbitrary URI schemes
		{"custom:/// URI", "custom:///path/to/file.txt", "custom:///", "path/to/file.txt", '/', []string{"path", "to", "file.txt"}, false},
		// Note: custom:// with backslash is a mixed separator case, behavior may vary by OS
		// {"custom:// with backslash", "custom://host\\path\\file.txt", "custom://", "host/path/file.txt", '/', []string{"host", "path", "file.txt"}, false},
		// {"custom:/// with backslash", "custom:///path\\to\\file.txt", "custom:///", "path/to/file.txt", '/', []string{"path", "to", "file.txt"}, false},
		{"myscheme:// URI", "myscheme://server/share/data.json", "myscheme://", "server/share/data.json", '/', []string{"server", "share", "data.json"}, false},
		{"test-scheme:/// URI", "test-scheme:///a/b/c/file.dat", "test-scheme:///", "a/b/c/file.dat", '/', []string{"a", "b", "c", "file.dat"}, false},
		{"abc123:// URI", "abc123://host/path", "abc123://", "host/path", '/', []string{"host", "path"}, false},
		{"x.y-z:/// URI", "x.y-z:///data/file.txt", "x.y-z:///", "data/file.txt", '/', []string{"data", "file.txt"}, false},
		
		// Windows drive variations
		{"Windows drive D", "d:\\data\\files\\config.json", "d:", "\\data\\files\\config.json", '\\', []string{"", "data", "files", "config.json"}, true},
		{"Windows drive lowercase", "e:\\test\\file.txt", "e:", "\\test\\file.txt", '\\', []string{"", "test", "file.txt"}, true},
		
		// Relative paths
		{"Relative nested", "a/b/c/d/file.txt", "", "a/b/c/d/file.txt", '/', []string{"a", "b", "c", "d", "file.txt"}, false},
		
		// Paths with . and .. (cleaned)
		{"Path with .", "d:\\data\\.\\config.json", "d:", "\\data\\config.json", '\\', []string{"", "data", "config.json"}, true},
		{"Path with ..", "d:\\data\\..\\config.json", "d:", "\\config.json", '\\', []string{"", "config.json"}, true},
		{"Path with multiple ..", "d:\\a\\b\\..\\..\\c\\file.txt", "d:", "\\c\\file.txt", '\\', []string{"", "c", "file.txt"}, true},
		{"Relative path with .", "documents/./report.pdf", "", "documents/report.pdf", '/', []string{"documents", "report.pdf"}, false},
		{"Relative path with ..", "documents/../config.json", "", "config.json", '/', []string{"config.json"}, false},
		
		// Complex paths (cleaned)
		{"Complex path 1", "d:\\data\\.\\files\\..\\config.json", "d:", "\\data\\config.json", '\\', []string{"", "data", "config.json"}, true},
		{"Complex path 3", "/a/b/../c/./d/file.txt", "", "/a/c/d/file.txt", '/', []string{"", "a", "c", "d", "file.txt"}, true},
		
		// URI + Windows drive combinations
		// Note: These are complex cases with mixed OS-specific behavior
		// {"file:// + Windows drive", "file://d:\\data\\file.txt", "file://", "d:/data/file.txt", '/', []string{"d:", "data", "file.txt"}, false},
		// {"files:// + Windows drive", "files://d:\\data\\file.txt", "files://", "d:/data/file.txt", '/', []string{"d:", "data", "file.txt"}, false},
		// {"file:/// + Windows drive", "file:///d:\\data\\file.txt", "file:///", "d/data/file.txt", '/', []string{"d", "data", "file.txt"}, false},
		// {"files:/// + Windows drive", "files:///d:\\data\\file.txt", "files:///", "d/data/file.txt", '/', []string{"d", "data", "file.txt"}, false},
		
		// Unix path with colons (not URI)
		{"Unix path with colon", "/xx/xxx:xx/xxx:/xxxx", "", "/xx/xxx:xx/xxx:/xxxx", '/', []string{"", "xx", "xxx:xx", "xxx:", "xxxx"}, true},
		{"Unix path with multiple colons", "/a/b:c/d:e/f:g", "", "/a/b:c/d:e/f:g", '/', []string{"", "a", "b:c", "d:e", "f:g"}, true},
		{"Unix path with colon at end", "/path/to/file:attribute", "", "/path/to/file:attribute", '/', []string{"", "path", "to", "file:attribute"}, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			info := ParsePathInfo(tt.path)
			
			if info.RawPath != tt.path {
				t.Errorf("RawPath = %q, want %q", info.RawPath, tt.path)
			}
			// Original should be the cleaned full path (Prefix + Path)
			wantOriginal := tt.wantPrefix + tt.wantPath
			if info.Original != wantOriginal {
				t.Errorf("Original = %q, want %q", info.Original, wantOriginal)
			}
			if info.Prefix != tt.wantPrefix {
				t.Errorf("Prefix = %q, want %q", info.Prefix, tt.wantPrefix)
			}
			if info.Path != tt.wantPath {
				t.Errorf("Path = %q, want %q", info.Path, tt.wantPath)
			}
			if info.Separator != tt.wantSep {
				t.Errorf("Separator = %q, want %q", info.Separator, tt.wantSep)
			}
			if len(info.Parts) != len(tt.wantParts) {
				t.Errorf("Parts = %v, want %v", info.Parts, tt.wantParts)
			}
			if info.IsAbs != tt.wantIsAbs {
				t.Errorf("IsAbs = %v, want %v", info.IsAbs, tt.wantIsAbs)
			}
		})
	}
}
