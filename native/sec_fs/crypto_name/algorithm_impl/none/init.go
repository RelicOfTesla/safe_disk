// Package none registers the no-op name encryption factory.
package none

import (
	"safe_disk/native/sec_fs/crypto_name"
)

func init() {
	factory := NewFactory()
	crypto_name.RegisterNameFactory(factory)
}
