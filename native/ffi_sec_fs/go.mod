module safe_disk/native/ffi_sec_fs

go 1.21

require (
	safe_disk/native/ffi_comm v0.0.0
	safe_disk/native/sec_fs v0.0.0
)

replace safe_disk/native/ffi_comm => ../ffi_comm
replace safe_disk/native/sec_fs => ../sec_fs
