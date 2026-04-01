#!/bin/bash
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Safe Disk - Build & Run Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NATIVE_DIR="$PROJECT_ROOT/native"
FLUTTER_DIR="$PROJECT_ROOT"

echo -e "${CYAN}Project root: $PROJECT_ROOT${NC}"
echo -e "${CYAN}Native dir: $NATIVE_DIR${NC}"
echo ""

# Step 1: 编译 Go 原生库
echo -e "${GREEN}[1/5] Building Go native library...${NC}"
cd "$NATIVE_DIR"

# 编译为共享库（使用 Flutter 期望的名称）
echo -e "  ${YELLOW}Running: go build -buildmode=c-shared -o libsafedisk_native.so${NC}"
go build -buildmode=c-shared -o libsafedisk_native.so

if [ ! -f "libsafedisk_native.so" ]; then
    echo -e "${RED}✗ Failed to build libsafedisk_native.so${NC}"
    exit 1
fi

LIB_SIZE=$(du -h libsafedisk_native.so | cut -f1)
echo -e "${GREEN}✓ Built libsafedisk_native.so (${LIB_SIZE})${NC}"

# 也生成头文件（用于调试）
if [ -f "libsafedisk_native.h" ]; then
    echo -e "${GREEN}✓ Generated header: libsafedisk_native.h${NC}"
fi

echo ""

# Step 2: 复制库文件到多个位置
echo -e "${GREEN}[2/5] Copying library to Flutter directories...${NC}"

# 目标目录列表
TARGET_DIRS=(
    "$FLUTTER_DIR/linux"
    "$FLUTTER_DIR/build/linux/x64/debug/bundle"
    "$FLUTTER_DIR/build/linux/x64/release/bundle"
)

for TARGET_DIR in "${TARGET_DIRS[@]}"; do
    if [ -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
        cp -f "$NATIVE_DIR/libsafedisk_native.so" "$TARGET_DIR/"
        echo -e "${GREEN}✓ Copied to: $TARGET_DIR/${NC}"
    fi
done

# 确保项目根目录的 linux/ 目录存在
mkdir -p "$FLUTTER_DIR/linux"
cp -f "$NATIVE_DIR/libsafedisk_native.so" "$FLUTTER_DIR/linux/"
echo -e "${GREEN}✓ Ensured: $FLUTTER_DIR/linux/libsafedisk_native.so${NC}"

# 复制头文件（如果需要）
if [ -f "$NATIVE_DIR/libsafedisk_native.h" ]; then
    cp -f "$NATIVE_DIR/libsafedisk_native.h" "$FLUTTER_DIR/linux/"
    echo -e "${GREEN}✓ Copied header to: $FLUTTER_DIR/linux/${NC}"
fi

echo ""

# Step 3: Flutter 清理和获取依赖
echo -e "${GREEN}[3/5] Flutter clean and get dependencies...${NC}"
cd "$FLUTTER_DIR"

# flutter clean
echo -e "  ${YELLOW}Running: flutter clean${NC}"
flutter clean > /dev/null 2>&1 || true

# flutter pub get
echo -e "  ${YELLOW}Running: flutter pub get${NC}"
flutter pub get > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Flutter dependencies ready${NC}"
echo ""

# Step 4: 设置库文件路径
echo -e "${GREEN}[4/5] Setting library path...${NC}"
export LD_LIBRARY_PATH="$FLUTTER_DIR/linux:$FLUTTER_DIR/build/linux/x64/debug/bundle:$FLUTTER_DIR/build/linux/x64/release/bundle:$LD_LIBRARY_PATH"
echo -e "${GREEN}✓ LD_LIBRARY_PATH set${NC}"
echo -e "${CYAN}  LD_LIBRARY_PATH=$LD_LIBRARY_PATH${NC}"
echo ""

# Step 5: 运行 Flutter 应用
echo -e "${GREEN}[5/5] Running Flutter app...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd "$FLUTTER_DIR"

# 如果有参数，使用参数；否则使用默认的 linux 设备
if [ "$#" -gt 0 ]; then
    flutter run "$@"
else
    flutter run -d linux
fi
