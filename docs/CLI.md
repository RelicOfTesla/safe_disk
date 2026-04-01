# Safe Disk CLI - 命令行工具

## 概述

独立的 Go 命令行工具，用于加密/解密目录，支持批量操作和脚本集成。

## 安装

```bash
# 编译
go build -o safedisk-cli ./cmd/cli

# 或使用预编译版本
# Windows: safedisk-cli.exe
# Linux: safedisk-cli
```

## 命令

### 创建加密目录

```bash
# 可变密码模式（默认，支持修改密码）
safedisk-cli create /path/to/dir

# 不可变密码模式（需显式指定，更安全但不支持修改密码）
safedisk-cli create /path/to/dir --immutable-password
```

交互式输入：
- 密码
- 迭代次数（默认 10000）
- 密码模式：默认可变，可选不可变

### 加密已有目录

```bash
# 加密整个目录
safedisk-cli encrypt /path/to/plain/dir --output /path/to/encrypted/dir

# 加密单个文件
safedisk-cli encrypt /path/to/file.txt --output /path/to/encrypted/file.enc
```

### 解密目录

```bash
# 解密整个目录
safedisk-cli decrypt /path/to/encrypted/dir --output /path/to/decrypted/dir

# 解密单个文件
safedisk-cli decrypt /path/to/file.enc --output /path/to/file.txt
```

### 查看信息

```bash
safedisk-cli info /path/to/encrypted/dir

# 输出
Directory: /path/to/encrypted/dir
Created: 2026-04-01 23:00:00
Algorithm: AES-256-GCM
Files: 42
Size: 1.2 MB
```

### 修改密码

```bash
# 仅可变密码模式支持
safedisk-cli passwd /path/to/encrypted/dir

# 不可变密码模式会提示错误：
# Error: Password modification not supported in immutable mode
# To change password, re-encrypt all files with new password
```

交互式输入：
- 旧密码
- 新密码

## 选项

```bash
--password, -p           密码（不推荐，可能被历史记录）
--output, -o             输出路径
--iter, -i               迭代次数（默认 10000）
--immutable-password     创建不可变密码模式目录（不支持修改密码，安全性更高）
--mutable-password       创建可变密码模式目录（默认，支持修改密码）
--verbose, -v            详细输出
--quiet, -q              静默模式
--help, -h               帮助信息
--version                版本信息
```

**默认行为**：
- `safedisk-cli create /dir` → 可变密码模式（支持修改密码）
- `safedisk-cli create /dir --immutable-password` → 不可变密码模式

## 使用示例

### 批量加密

```bash
# 加密所有 PDF 文件
find . -name "*.pdf" -exec safedisk-cli encrypt {} --output {}.enc \;

# 解密所有 .enc 文件
find . -name "*.enc" -exec safedisk-cli decrypt {} \;
```

### 脚本集成

```bash
#!/bin/bash
# backup.sh - 加密备份脚本

BACKUP_DIR="/backup/$(date +%Y%m%d)"
PASSWORD="your-password-here"  # 从环境变量读取更安全

# 创建加密备份
safedisk-cli create "$BACKUP_DIR" --password "$PASSWORD"
safedisk-cli encrypt /data --output "$BACKUP_DIR/data" --password "$PASSWORD"

echo "Backup created: $BACKUP_DIR"
```

### 自动化任务

```bash
# 定时加密备份（cron）
0 2 * * * /usr/local/bin/safedisk-cli encrypt /data --output /backup/daily
```

## 安全建议

1. **不要在命令行直接输入密码**
   ```bash
   # 不安全（密码会被历史记录）
   safedisk-cli encrypt /dir --password "secret"
   
   # 安全（交互式输入）
   safedisk-cli encrypt /dir
   ```

2. **使用环境变量**
   ```bash
   export SAFE_DISK_PASSWORD="your-password"
   safedisk-cli encrypt /dir
   ```

3. **检查文件权限**
   ```bash
   # 加密目录权限应该是 700
   chmod 700 /path/to/encrypted/dir
   ```

## 与 Flutter 应用共享

- CLI 工具和 Flutter 应用使用相同的加密库
- 加密目录格式完全兼容
- 可以用 CLI 创建，Flutter 应用打开
- 可以用 Flutter 应用创建，CLI 解密

## 实现状态

- [ ] 基础框架
- [ ] create 命令
- [ ] encrypt 命令
- [ ] decrypt 命令
- [ ] info 命令
- [ ] passwd 命令
- [ ] 批量操作
- [ ] 彩色输出
- [ ] 错误处理
