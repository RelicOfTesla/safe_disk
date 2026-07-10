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
		[]string{"aes-ctr", "aes-xts", "chacha20", "rc4"},
		crypto_data.ListFactories(),
	)
	require.ElementsMatch(t,
		[]string{"aes-gcm-name", "none", "rc4"},
		crypto_name.ListNameFactories(),
	)
	require.ElementsMatch(t,
		[]string{"argon2id", "hkdf", "pbkdf2", "scrypt"},
		crypto_hkdf.ListDeriverFactories(),
	)
}
