# Safe Disk CLI - 命令行工具

> 这是 CLI 使用说明，不是实现完成证明。当前可用能力以代码审计状态为准。

## 概述

独立的 Go 命令行工具，用于加密/解密目录，支持批量操作和脚本集成。
当前已确认的命令主要是 `version`、`list`、`export`、`import`；`create`、`info`、`passwd` 仍需按代码逐项核实，不能直接视为已完成。

目标命令语义、`create`、原地加密、安全密码输入、异步任务恢复和测试规划见 [CLI_DESIGN.md](CLI_DESIGN.md)。本文只描述当前使用方式。

## 安装

```bash
# 编译
cd native
go build -o safe-disk ./cli/main.go

# 使用预编译版本（如果有）
# Windows: safe-disk.exe
# Linux: safe-disk
```

## 命令

### version

```bash
safe-disk version
```

输出版本信息。

### list

列出加密目录内容。

```bash
# 列出根目录
safe-disk list -p <password> -d /path/to/encrypted/dir

# 列出子目录
safe-disk list -p <password> -d /path/to/encrypted/dir/subdir
```

**选项**：
- `-p, --password` — 密码（必填）
- `-d, --path` — 加密目录路径（默认：当前目录）

**输出示例**：
```
Contents of /path/to/encrypted/dir:
=====================================
[DIR ] documents (0 bytes)
[FILE] readme.txt (1245 bytes)
[FILE] image.png (45231 bytes)
=====================================
Total: 3 items
```

### export

导出解密文件或目录。

```bash
# 导出文件到指定路径
safe-disk export -p <password> -s /encrypted/file.txt -d /output/file.txt

# 导出目录
safe-disk export -p <password> -s /encrypted/dir -d /output/dir

# 导出文件到 stdout
safe-disk export -p <password> -s /encrypted/file.txt -
safe-disk export -p <password> -s /encrypted/file.txt

# 仅导出顶层，不递归子目录
safe-disk export -p <password> -s /encrypted/dir -d /output/dir -n
```

**选项**：
- `-p, --password` — 密码（必填）
- `-s, --source` — 源路径（加密路径，必填）
- `-d, --dest` — 目标路径（明文路径，为空或 `-` 时输出到 stdout）
- `-n, --skip-recursive` — 不递归处理子目录

**说明**：
- 源路径可以是加密目录内的文件或目录
- 工具会自动向上查找 `_cryption.json` 确定加密根目录
- 导出目录时显示进度条

### import

导入明文文件或目录到加密目录。

```bash
# 导入文件
safe-disk import -p <password> -s /plaintext/file.txt -d /encrypted/file.txt

# 导入目录
safe-disk import -p <password> -s /plaintext/dir -d /encrypted/dir

# 仅导入顶层，不递归子目录
safe-disk import -p <password> -s /plaintext/dir -d /encrypted/dir -n
```

**选项**：
- `-p, --password` — 密码（必填）
- `-s, --source` — 源路径（明文路径，必填）
- `-d, --dest` — 目标路径（加密路径，必填）
- `-n, --skip-recursive` — 不递归处理子目录

## 使用示例

### 批量加密

```bash
# 加密所有 PDF 文件到同一加密目录
for f in *.pdf; do
  safe-disk import -p "$PASS" -s "$f" -d /encrypted/docs/"$f"
done
```

### 脚本集成

```bash
#!/bin/bash
# backup.sh - 加密备份脚本

BACKUP_DIR="/backup/$(date +%Y%m%d)"
PASS="${SAFE_DISK_PASSWORD:?请设置 SAFE_DISK_PASSWORD 环境变量}"

# 导入数据到加密目录
safe-disk import -p "$PASS" -s /data -d "$BACKUP_DIR/data"

echo "Backup imported to: $BACKUP_DIR"
```

### 查看加密文件内容（不解密到磁盘）

```bash
# 直接输出到 stdout（不保存到磁盘）
safe-disk export -p "$PASS" -s /encrypted/secret.txt | less
```

## 安全建议

1. **不要在命令行直接输入密码**
   ```bash
   # 不安全（密码会被历史记录）
   safe-disk list -p "secret" -d /encrypted
   
   # 当前版本没有安全密码输入参数；脚本中只能先降低暴露面
   PASS="secret" safe-disk list -p "$PASS" -d /encrypted
   ```

2. **目标安全输入方式**
   当前版本还没有 `--password-env`、`--password-stdin` 和隐藏交互输入。目标设计见 [CLI_DESIGN.md](CLI_DESIGN.md)，后续应优先实现。

3. **使用环境变量时仍需注意**
   ```bash
   export SAFE_DISK_PASSWORD="your-password"
   safe-disk list -p "$SAFE_DISK_PASSWORD" -d /encrypted
   ```
   这只是当前版本的折中方式，不等同于安全密码输入，因为 shell 环境和进程启动参数仍可能暴露。

4. **检查文件权限**
   ```bash
   # 加密目录权限应该是 700
   chmod 700 /path/to/encrypted/dir
   ```

## 与 Flutter 应用共享

- CLI 工具和 Flutter 应用使用相同的加密库
- 加密目录格式完全兼容
- 可以用 CLI 导出，Flutter 应用浏览
- 可以用 Flutter 应用创建，CLI 导出

## 实现状态

- [x] `version` — 版本信息
- [x] `list` — 列出加密目录内容
- [x] `export` — 导出解密
- [x] `import` — 导入加密
- [ ] `create` — 创建加密目录（未实现）
- [ ] `info` — 查看加密目录信息（未实现）
- [ ] `passwd` — 修改密码（未实现）

## 代码审计提示

- `export` 的单文件 stdout 输出在代码里存在，但目录 stdout 导出是否满足文档说法，需要按实现逐项确认。
- `import.go` 里仍有创建目录的 TODO 分支，不能把“能导入”自动等同于“能自动创建根目录”。
