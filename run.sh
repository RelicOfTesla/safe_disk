#!/bin/bash
# Safe Disk - Build and Run Script
# Compiles Go library, Flutter app, and runs the application

set -e  # Exit on error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE_DIR="$PROJECT_ROOT/native"
BUILD_DIR="$PROJECT_ROOT/build/linux/x64/debug/bundle"
LIB_NAME="libsafedisk_native.so"

# Add Flutter to PATH if not already there
if ! command -v flutter &> /dev/null; then
    if [ -d "$HOME/flutter/bin" ]; then
        export PATH="$PATH:$HOME/flutter/bin"
    else
        echo "❌ Error: Flutter not found in PATH or ~/flutter/bin"
        echo "Please install Flutter or add it to PATH"
        exit 1
    fi
fi

echo "=== Safe Disk Build Script ==="
echo ""

# Step 1: Build Go shared library
echo "📦 Step 1/4: Building Go shared library..."
cd "$NATIVE_DIR"
go build -buildmode=c-shared -o "$LIB_NAME" main.go
echo "✓ Go library built: $NATIVE_DIR/$LIB_NAME"
echo ""

# Step 2: Build Flutter app
echo "📱 Step 2/4: Building Flutter app..."
cd "$PROJECT_ROOT"
flutter build linux --debug
echo "✓ Flutter app built"
echo ""

# Step 3: Copy shared library
echo "📋 Step 3/4: Copying shared library..."
mkdir -p "$BUILD_DIR/lib"
cp "$NATIVE_DIR/$LIB_NAME" "$BUILD_DIR/lib/"
echo "✓ Library copied to $BUILD_DIR/lib/"
echo ""

# Step 4: Run application
echo "🚀 Step 4/4: Running Safe Disk..."
echo ""

# Set library path and run
export LD_LIBRARY_PATH="$BUILD_DIR/lib:$LD_LIBRARY_PATH"
cd "$BUILD_DIR"
./safe_disk
