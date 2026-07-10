module safe_disk/native/sec_fs

go 1.21

require (
	github.com/stretchr/testify v1.11.1
	golang.org/x/crypto v0.22.0
	golang.org/x/sys v0.19.0
	safe_disk/native/config v0.0.0
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace safe_disk/native/config => ../config
