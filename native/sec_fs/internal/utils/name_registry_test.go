package utils

import "testing"

type registryTestFactory struct {
	name string
}

func (f *registryTestFactory) GetName() string { return f.name }

func TestNameRegistryFoldLookupAndRejectsAmbiguousRegistration(t *testing.T) {
	registry := NewNameRegistry[*registryTestFactory]()
	factory := &registryTestFactory{name: "AES-CTR"}
	if err := registry.Register(factory); err != nil {
		t.Fatalf("register canonical factory: %v", err)
	}
	if got := registry.GetOrNilFold("aes-ctr"); got != factory {
		t.Fatalf("case-insensitive lookup returned %p, want %p", got, factory)
	}
	if err := registry.Register(&registryTestFactory{name: "aes-ctr"}); err == nil {
		t.Fatal("case-only duplicate registration unexpectedly succeeded")
	}
}
