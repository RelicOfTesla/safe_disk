.PHONY: build test clean

build-go:
	cd native && go build -buildmode=c-shared -o ../build/libsafe_disk.so ./exports.go

build-cli:
	cd native && go build -o ../build/safe-disk ./cli/main.go

build-flutter:
	flutter build linux

test-go:
	cd native && go test ./...

test-flutter:
	flutter test

clean:
	rm -rf build/
	rm -f native/*.so native/*.h
