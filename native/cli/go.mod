module safe_disk/native/cli

go 1.21

require (
	github.com/spf13/cobra v1.8.0
	safe_disk/native/sec_fs v0.0.0
	safe_disk/native/sec_transfer v0.0.0
)

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
)

replace (
	safe_disk/native/sec_fs => ../sec_fs
	safe_disk/native/sec_transfer => ../sec_transfer
)
