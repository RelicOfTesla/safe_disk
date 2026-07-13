package aes_gcm_name

import "testing"

type closeTestKeyInfo struct{ key []byte }

func (k *closeTestKeyInfo) GetKey() []byte { return k.key }
func (k *closeTestKeyInfo) Destroy() {
	clear(k.key)
	k.key = nil
}

func TestContextCloseClearsOwnedKey(t *testing.T) {
	context, err := NewContext(&closeTestKeyInfo{
		key: []byte("0123456789abcdef0123456789abcdef"),
	}, nil)
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
	if context.key != nil || context.gcm != nil {
		t.Fatal("context retained sensitive references after close")
	}
}
