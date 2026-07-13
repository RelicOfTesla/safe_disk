package sec_fs

import (
	"errors"
	"testing"
)

type closeTestKeyInfo struct {
	key       []byte
	destroyed bool
}

func (k *closeTestKeyInfo) GetKey() []byte { return k.key }
func (k *closeTestKeyInfo) Destroy() {
	clear(k.key)
	k.key = nil
	k.destroyed = true
}

type closeTestNameCryptor struct {
	keyWasLive bool
	closed     bool
	err        error
	key        []byte
}

func (c *closeTestNameCryptor) EncryptName(name string) (string, error) { return name, nil }
func (c *closeTestNameCryptor) DecryptName(name string) (string, error) { return name, nil }
func (c *closeTestNameCryptor) Close() error {
	c.closed = true
	for _, value := range c.key {
		if value != 0 {
			c.keyWasLive = true
			break
		}
	}
	return c.err
}

func TestSecRootCloseClearsKeyAndReleasesCryptor(t *testing.T) {
	keyBytes := []byte("root-close-sensitive-key-material")
	keyInfo := &closeTestKeyInfo{key: keyBytes}
	nameCryptor := &closeTestNameCryptor{key: keyBytes}
	root := &secRootImpl{keyInfo: keyInfo, nameCryptor: nameCryptor}

	if err := root.Close(); err != nil {
		t.Fatal(err)
	}
	if !nameCryptor.closed || !nameCryptor.keyWasLive {
		t.Fatal("name cryptor was not closed before the root key was destroyed")
	}
	if !keyInfo.destroyed || root.keyInfo != nil || root.nameCryptor != nil {
		t.Fatal("root did not destroy and release sensitive dependencies")
	}
	for index, value := range keyBytes {
		if value != 0 {
			t.Fatalf("key byte %d was not cleared", index)
		}
	}
	if err := root.Close(); err != nil {
		t.Fatalf("second close must be idempotent: %v", err)
	}
}

func TestSecRootCloseClearsKeyWhenNameCryptorCloseFails(t *testing.T) {
	wantErr := errors.New("name close failed")
	keyBytes := []byte("root-close-error-key-material")
	keyInfo := &closeTestKeyInfo{key: keyBytes}
	root := &secRootImpl{
		keyInfo:     keyInfo,
		nameCryptor: &closeTestNameCryptor{key: keyBytes, err: wantErr},
	}

	if err := root.Close(); !errors.Is(err, wantErr) {
		t.Fatalf("close error=%v want=%v", err, wantErr)
	}
	if !keyInfo.destroyed || root.keyInfo != nil || root.nameCryptor != nil {
		t.Fatal("close error prevented sensitive dependency cleanup")
	}
	for index, value := range keyBytes {
		if value != 0 {
			t.Fatalf("key byte %d was not cleared after close error", index)
		}
	}
}
