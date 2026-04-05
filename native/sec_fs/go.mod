module safe_disk/native/sec_fs

go 1.21

require (
	golang.org/x/crypto v0.22.0
	safe_disk/native/config v0.0.0
)

replace safe_disk/native/config => ../config
