package crypto_all_test

import (
	"testing"

	"github.com/stretchr/testify/require"

	_ "safe_disk/native/sec_fs/crypto_all"
	"safe_disk/native/sec_fs/crypto_data"
	"safe_disk/native/sec_fs/crypto_hkdf"
	"safe_disk/native/sec_fs/crypto_name"
)

func TestRegistersEveryImplementedAlgorithm(t *testing.T) {
	require.ElementsMatch(t,
		[]string{"AES-CTR", "AES-XTS", "ChaCha20", "RC4"},
		crypto_data.ListFactories(),
	)
	require.ElementsMatch(t,
		[]string{"AES-256-GCM", "None", "RC4"},
		crypto_name.ListNameFactories(),
	)
	require.ElementsMatch(t,
		[]string{"Argon2id", "HKDF-SHA-256", "PBKDF2", "scrypt"},
		crypto_hkdf.ListDeriverFactories(),
	)
}
