package hkdf

import (
	"testing"

	"safe_disk/native/config"
	"safe_disk/native/sec_fs/crypto_hkdf"
)

func TestLoadKeySupportsStableAndRenamedConfigNamespaces(t *testing.T) {
	for _, group := range []string{stableConfigGroup, renamedConfigGroup} {
		t.Run(group, func(t *testing.T) {
			cfg := config.NewMemoryConfig()
			grouped := cfg.WithGroup(group)
			grouped.SetStr("salt", "536166654469736b")
			grouped.SetInt("key_length", 32)
			key, err := NewFactory().LoadKey("input-key-material", cfg)
			if err != nil {
				t.Fatalf("load %s namespace: %v", group, err)
			}
			key.Destroy()
		})
	}
}

func TestNewKeyWritesOnlyStableConfigNamespace(t *testing.T) {
	cfg := config.NewMemoryConfig()
	key, err := NewFactory().NewKey(&crypto_hkdf.MakeKeyParams{
		Password:   "input-key-material",
		KeyLength:  32,
		StaticSalt: true,
	}, cfg)
	if err != nil {
		t.Fatalf("create key: %v", err)
	}
	key.Destroy()
	if _, err := cfg.WithGroup(stableConfigGroup).GetStr("salt"); err != nil {
		t.Fatalf("stable namespace missing salt: %v", err)
	}
	if _, err := cfg.WithGroup(renamedConfigGroup).GetStr("salt"); err == nil {
		t.Fatal("renamed namespace unexpectedly written")
	}
}
