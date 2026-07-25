# Safe Disk CLI - 命令行工具

> CLI 使用说明。命令进度按 [TODO.md](TODO.md) 的统一口径审计；100% 的核心命令验收边界见 [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md)。
> 命令语义、异步任务恢复和测试规划见 [CLI_DESIGN.md](CLI_DESIGN.md)。

## 概述

独立的 Go 命令行工具，用于管理加密目录。当前已注册命令：`version`、`create`、`list`、`info`、`import`、`export`、`webdav`。

## 安装

```bash
cd native
go build -o safe-disk ./cli/main.go
```

## 通用选项

所有需要认证的命令支持以下密码输入方式（优先级从高到低）：

- `-p, --password` — 直接传入密码（不安全，会被 shell 历史记录）
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从标准输入读取密码
- 不传任何密码参数且在交互式终端运行时，CLI 会使用隐藏输入提示

支持 `--json` 的命令以 JSON Lines 格式输出进度和结果。

---

## 命令

### version

```bash
safe-disk version
```

输出版本信息。

### create

创建加密目录。默认要求目录不存在或为空；非空目录需 `--in-place`。

```bash
# 创建新加密目录
safe-disk create --path /path/to/new/dir

# 原地加密已有非空目录
safe-disk create --path /path/to/existing/dir --in-place
```

选项：

- `--path` — 目录路径（必填）
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--in-place` — 原地加密已有非空目录的内容
- `--json` — JSON Lines 进度输出（仅 --in-place 时有效）
- `--durability` — 持久化级别：`full`（默认）、`fast`、`none`

### list

列出加密目录内容。

```bash
safe-disk list -d /path/to/encrypted/dir
safe-disk list -d /path/to/encrypted/dir/subdir
```

选项：

- `-d, --path` — 加密目录路径（默认：根目录）
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--unfinished` — 未完成操作处理策略：`skip`（默认）、`ask`、`clean`、`rerun`

### info

显示加密根目录的元数据（加密算法、KDF、名称加密模式等）。

```bash
safe-disk info --root /path/to/encrypted/dir
```

选项：

- `--root` — root 目录路径（必填）
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--json` — JSON 格式输出

### export

导出解密文件或目录。

```bash
# 导出文件到指定路径
safe-disk export -s /encrypted/file.txt -d /output/file.txt

# 导出目录
safe-disk export -s /encrypted/dir -d /output/dir

# 导出到 stdout
safe-disk export -s /encrypted/file.txt

# 仅导出顶层
safe-disk export -s /encrypted/dir -d /output/dir -n
```

选项：

- `-s, --source` — 源路径（加密路径，必填）
- `-d, --dest` — 目标路径（明文路径，为空时输出到 stdout）
- `-n, --skip-recursive` — 不递归处理子目录
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--json` — JSON Lines 进度输出
- `--durability` — 持久化级别：`full`（默认）、`fast`、`none`

导出到 stdout 仅适用于单文件；目录导出必须使用绝对目标目录。

### import

导入明文文件或目录到加密目录。

```bash
# 导入文件
safe-disk import -s /plaintext/file.txt -d /encrypted/file.txt

# 导入目录
safe-disk import -s /plaintext/dir -d /encrypted/dir

# 仅导入顶层
safe-disk import -s /plaintext/dir -d /encrypted/dir -n
```

选项：

- `-s, --source` — 源路径（明文路径，必填）
- `-d, --dest` — 目标路径（加密路径，必填）
- `-n, --skip-recursive` — 不递归处理子目录
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--json` — JSON Lines 进度输出
- `--durability` — 持久化级别：`full`（默认）、`fast`、`none`

创建 root 使用独立 `create` 命令；`import` 只向已经存在且可认证的 root 导入。

### webdav

启动 WebDAV 服务共享加密目录。

```bash
# 启动只读 WebDAV 服务
safe-disk webdav serve --path /path/to/encrypted/dir --port 8080
```

选项：

- `--path` — root 目录路径（必填，须为绝对路径）
- `--port` — 监听端口（默认 8080）
- `--auth` — 认证方式：`digest`（默认）、`basic`
- `--credential-visibility` — 凭据可见性：`once`（默认）、`persistent`
- `--session-lifetime` — 会话生命周期
- `-p, --password` — 密码
- `--password-env` — 从环境变量读取密码
- `--password-stdin` — 从 stdin 读取密码
- `--json` — JSON Lines 输出
- `--mount` — 尝试系统挂载

---

## 使用示例

### 批量加密

```bash
for f in *.pdf; do
  safe-disk import -s "$f" -d "/encrypted/docs/$f"
done
```

### 脚本集成

```bash
#!/bin/bash
PASS="${SAFE_DISK_PASSWORD:?请设置 SAFE_DISK_PASSWORD 环境变量}"
safe-disk import --password-env SAFE_DISK_PASSWORD -s /data -d /backup/data
```

### 查看加密文件内容（不解密到磁盘）

```bash
safe-disk export --password-env SAFE_DISK_PASSWORD -s /encrypted/secret.txt | less
```

## 安全建议

1. 不要在命令行直接输入密码（`-p` 会被 shell 历史记录）
2. 优先使用 `--password-env` 或 `--password-stdin`
3. 加密目录权限应为 700：`chmod 700 /path/to/encrypted/dir`

## 与 Flutter 应用共享

- CLI 和 Flutter 应用使用相同的加密库和 `_cryption.json` 格式
- 加密目录完全兼容，可互相操作

## 实现状态

| 命令 | 状态 |
|------|------|
| `version` | 已注册 |
| `create` | 已注册，支持 --in-place 原地加密 |
| `list` | 已注册，支持 --unfinished 策略 |
| `info` | 已注册 |
| `import` | 已注册 |
| `export` | 已注册 |
| `webdav serve` | 已注册 |

未实现：`passwd`（改密）命令目前仅在 Flutter UI 中可用。
