#!/bin/bash
# Safe Disk CLI Build Wrapper
# 核心逻辑在 build_cli.go 中，此 wrapper 直接 go run 调用。

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
go run build_cli.go "$@"
