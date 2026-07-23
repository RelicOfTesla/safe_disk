package sec_fs

import "testing"

func TestDefaultIgnoreMatcherHidesWebDavPersistentState(t *testing.T) {
	matcher := newDefaultIgnoreMatcher(ConfigFileName)
	for _, name := range []string{
		".safe_disk.webdav.sessions.json",
		".safe_disk.webdav.sessions.previous.json",
	} {
		if !matcher.ShouldIgnore1(name, false) || !matcher.ShouldIgnore2(name, false) {
			t.Fatalf("persistent state %q was not hidden", name)
		}
	}
	if matcher.ShouldIgnore2(".safe_disk.webdav-visible.txt", false) != false {
		t.Fatal("similar user filename should remain visible")
	}
}
