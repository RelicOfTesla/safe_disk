package main

import (
	"safe_disk/native/cli/cmd"

	_ "safe_disk/native/sec_fs/crypto_all"
	_ "safe_disk/native/sec_fs/sec_transfer/v3"
)

func main() {
	cmd.Execute()
}
