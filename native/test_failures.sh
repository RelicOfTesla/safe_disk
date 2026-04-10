#!/bin/bash
cd /home/john/Desktop/dev/safe_disk/native

echo "=== 测试 custom:/// ==="
go test ./sec_fs/sec_utils -run "TestPathParsing_ParsePathInfo/custom:///_URI" -v 2>&1 | grep -A 5 "custom:///_URI"

echo ""
echo "=== 测试 file:// with host ==="
go test ./sec_fs/sec_utils -run "TestPathParsing_ParsePathInfo/file://_with_host" -v 2>&1 | grep -A 5 "file://_with_host"

echo ""
echo "=== 测试 file+unc ==="
go test ./sec_fs/sec_utils -run "TestPathParsing_ParsePathInfo/file+unc" -v 2>&1 | grep -A 5 "file+unc"

echo ""
echo "=== 测试 files:/// + backslash separator ==="
go test ./sec_fs/sec_utils -run "TestPathParsing_ParsePathInfo/files:///_+_backslash_separator" -v 2>&1 | grep -A 5 "files:///_+_backslash_separator"
