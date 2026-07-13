.PHONY: build test clean run build-go build-flutter build-cli test-go test-flutter

# 使用 Go 构建脚本
BUILD_TOOL := go run scripts/build.go

run:
	$(BUILD_TOOL) run

build-go:
	$(BUILD_TOOL) build-go

build-flutter:
	$(BUILD_TOOL) build-flutter

build-cli:
	$(BUILD_TOOL) build-cli

test-go:
	$(BUILD_TOOL) test-go

test-flutter:
	$(BUILD_TOOL) test-flutter

clean:
	$(BUILD_TOOL) clean
