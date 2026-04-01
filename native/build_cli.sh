#!/bin/bash

# Safe Disk CLI Build Script
# This script compiles the safedisk-cli tool for different platforms

set -e

# Version
VERSION="1.0.0"

# Output directory
OUTPUT_DIR="./bin"
mkdir -p "$OUTPUT_DIR"

echo "Building Safe Disk CLI v${VERSION}..."

# Build for Linux (amd64)
echo "Building for Linux (amd64)..."
GOOS=linux GOARCH=amd64 go build -ldflags="-s -w -X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli-linux-amd64" ./cli/

# Build for Linux (arm64)
echo "Building for Linux (arm64)..."
GOOS=linux GOARCH=arm64 go build -ldflags="-s -w -X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli-linux-arm64" ./cli/

# Build for Windows (amd64)
echo "Building for Windows (amd64)..."
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w -X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli-windows-amd64.exe" ./cli/

# Build for macOS (amd64)
echo "Building for macOS (amd64)..."
GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w -X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli-darwin-amd64" ./cli/

# Build for macOS (arm64)
echo "Building for macOS (arm64)..."
GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w -X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli-darwin-arm64" ./cli/

# Build for current platform (development)
echo "Building for current platform (development)..."
go build -ldflags="-X main.Version=${VERSION}" -o "${OUTPUT_DIR}/safedisk-cli" ./cli/

echo ""
echo "Build complete! Binaries are in ${OUTPUT_DIR}/"
echo ""
ls -lh "${OUTPUT_DIR}/"
