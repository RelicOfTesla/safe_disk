package crypto_hkdf

import (
	"bytes"
	"testing"
)

func TestNewKeyInfoCopyOwnsAndDestroysIndependentBytes(t *testing.T) {
	source := []byte("independent-key-material")
	wantSource := append([]byte(nil), source...)
	keyInfo := NewKeyInfoCopy(source)
	owned := keyInfo.GetKey()
	if len(owned) == 0 || &owned[0] == &source[0] {
		t.Fatal("key info did not copy source bytes")
	}

	keyInfo.Destroy()
	for index, value := range owned {
		if value != 0 {
			t.Fatalf("owned key byte %d was not cleared", index)
		}
	}
	if keyInfo.GetKey() != nil {
		t.Fatal("destroyed key info retained its key reference")
	}
	if !bytes.Equal(source, wantSource) {
		t.Fatal("destroying key copy modified source bytes")
	}
	keyInfo.Destroy()
}
