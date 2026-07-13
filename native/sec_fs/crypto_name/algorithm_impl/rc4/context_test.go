package rc4

import (
	"bytes"
	"testing"
)

type testKeyInfo struct{ key []byte }

func (k *testKeyInfo) GetKey() []byte { return k.key }
func (k *testKeyInfo) Destroy() {
	clear(k.key)
	k.key = nil
}

func TestContextCloseClearsKeyBytes(t *testing.T) {
	keyBytes := []byte("rc4-sensitive-key")
	context, err := NewContext(&testKeyInfo{key: keyBytes}, nil)
	if err != nil {
		t.Fatal(err)
	}
	ownedKey := context.key
	if err := context.Close(); err != nil {
		t.Fatal(err)
	}
	for index, value := range ownedKey {
		if value != 0 {
			t.Fatalf("owned key byte %d was not cleared", index)
		}
	}
	if !bytes.Equal(keyBytes, []byte("rc4-sensitive-key")) {
		t.Fatal("closing name context modified keyInfo-owned bytes")
	}
	if context.key != nil || context.cipher != nil {
		t.Fatal("context retained sensitive references after close")
	}
}
