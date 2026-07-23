# CLI 设计文档

> 本文档定义 Safe Disk CLI 的目标形态、命令语义、底层 `sec_fs/sec_transfer` 配合要求和测试规划。当前实现进度以实际代码为准；`sec_transfer` 原理与规划见 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md)。

最后更新：2026-07-23

## 设计目标

CLI 是加密目录的运维入口，不只是 Flutter 的辅助工具。

CLI 需要负责：

- 创建加密目录。
- 打开已有加密目录。
- 导入明文文件/目录到加密目录。
- 导出加密文件/目录到明文路径。
- 支持原地加密已有目录。
- 展示 import/export/convert 的运行时进度。
- 打开 root 时自动发现未完成 operation。
- import/export 未完成时提示重新全量执行或清理状态。
- convert 未完成时按 phase 恢复、重跑或进入人工处理。
- 支持安全密码输入。
- 使用完整算法注册，确保 CLI 能打开所有当前后端支持的配置。
- 为第三方工具启动受限、临时的 WebDAV 只读会话，并可选请求 Go 完成系统挂载。

## 当前实现状态

截至 2026-06-30，CLI 已接入 Transfer V3 的基础 import/export/create --in-place，但仍未达到完整目标态。

已确认：

- `native/cli/cmd/root.go` 已注册 `version`、`list`、`import`、`export`、`create`；`webdav` 尚未注册。
- `native/cli/main.go` 已 blank import `crypto_all` 和 `sec_transfer/v3`。
- `import/export/list/create` 已支持 `--password`、`--password-env`、`--password-stdin` 和交互式隐藏输入。
- `import/export` 已通过 `sec_transfer.GetDefaultTransferV3()` 执行同步 V3 操作，并在失败/中断时保留 operation marker。
- `import/export --json` 已输出 JSON Lines 运行时事件：`operation_started`、`progress`、`operation_completed`、`operation_failed`。
- `list/import/export` 已通过统一 open root helper 接入 unfinished marker 检查；`skip/ask/clean/rerun` 可用，其中 `rerun` 只自动处理 import/export。
- 统一 open root helper 已在打开 root 前检查 convert phase marker；可判断的 rename 窗口会自动继续，无法判断时拒绝打开并要求人工处理。
- `create` 已注册，`info/passwd` 未注册为 CLI 命令。
- `create` 对非空目录默认要求显式 `--in-place`；交互式终端可确认后进入原地加密，非交互和 `--json` 模式仍直接拒绝。
- `export --dest -` 的单文件 stdout 路径存在；目录导出到 stdout 会明确报错。
- Go 原生层已有只读 loopback WebDAV 会话及 FFI open/close ABI；CLI 尚未调用该会话管理器，也尚未提供系统挂载命令。

明确不再作为主线：

- CLI 不再围绕 `sec_transfer/v2` 的 `TaskStatus`、`LoadTasks`、`ResumeAllTasks`、`Pause/Resume/Rollback` 设计。
- import/export 不做持久化进度和断点续传。
- 未完成 import/export 只保留 operation marker，用于下次打开 root 时提示全量重跑或清理。
- import/export/create in-place 支持 `--durability=none|data|full`，默认 `full`；该值只影响本次 operation，不写入 marker。
- CLI 新建 root、convert work 和导出对象采用 `0700/0600` 安全权限；不保留源 owner/mode/mtime，也不递归修改已存在目录权限。
- convert 使用 phase marker 和目录切换恢复，不复用 v2 task 模型。

后续实现应继续以 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md) 中的 operation marker 和 convert phase marker 为准。

## 基本原则

### 路径原则

CLI 参数使用绝对路径。

- `import --source`：外部明文绝对路径。
- `import --dest`：加密目录视图中的绝对路径。
- `export --source`：加密目录视图中的绝对路径。
- `export --dest`：外部明文绝对路径。
- `list --path`：加密目录视图中的绝对路径。
- `create --path`：待创建的加密 root 绝对路径。
- `webdav serve --path`：加密视图中要暴露的文件或目录绝对路径。

命令内部可以继续用 `FindRootConfig(absPath)` 向上查找 `_cryption.json`，从用户角度不暴露 `--root + --relative-path` 这种拆分模型。

### Root 打开原则

所有需要访问加密目录的命令都必须走统一的 root 打开流程：

1. 校验路径是绝对路径，或先规范化为绝对路径。
2. 通过 `FindRootConfig` 找到 root 和 root 内相对路径。
3. 读取密码。
4. 调用 `OpenRootQuick`。
5. 查询 root 上的未完成 operation marker。
6. 对未完成 import/export 提示重新全量执行、清理 marker 或跳过。
7. 对未完成 convert 按 phase 提示恢复、重跑或人工处理。
8. 返回 root、相对路径、transfer manager。

不要在每个命令中复制这套流程。

`webdav serve` 成功打开 root 后，还必须把 root 生命周期绑定到 Go WebDAV 会话。它是前台常驻
命令，不能在打印地址后立即退出；进程退出前必须关闭会话并请求卸载。

### 密码原则

优先级从高到低：

1. `--password`：直接命令行传入，不推荐，但保留用于测试和脚本兼容。
2. `--password-env NAME`：从指定环境变量读取。
3. `--password-stdin`：从 stdin 读取一行。
4. 无密码参数且是交互式终端时，隐藏输入。

非交互环境下，如果没有任何密码来源，必须直接报错，不允许卡住等待输入。

### Operation 原则

CLI 命令对用户表现为同步命令。底层可以使用 goroutine 实现运行时进度，但 import/export 不做进度持久化和断点续传。

CLI 必须负责：

- 展示进度。
- 监听完成/失败。
- 响应 Ctrl-C。
- import/export 中断时说明 operation marker 已保留，可下次全量重跑或清理。
- convert 中断时说明存在 convert phase marker，下次 open root 会提示恢复。

## 命令设计

### version

```bash
safe-disk version
```

输出版本信息。

### create

创建加密 root。

```bash
safe-disk create --path /abs/root
safe-disk create --path /abs/root --password-stdin
safe-disk create --path /abs/root --password-env SAFE_DISK_PASSWORD
```

默认要求：

- `/abs/root` 不存在：创建目录并初始化 root。
- `/abs/root` 存在且为空目录：直接初始化 root。
- `/abs/root` 存在且非空：默认拒绝。
- `/abs/root` 已存在 `_cryption.json`：默认拒绝。

支持原地加密已有目录：

```bash
safe-disk create --path /abs/root --in-place
```

交互式终端中，如果 `/abs/root` 存在且非空、但用户没有传 `--in-place`，可以提示是否原地加密：

```text
目录非空。是否将现有文件原地加密？[y/N]
```

非交互模式必须拒绝，不能默认原地加密。

`--json` 模式按非交互规则处理：如果目录非空且没有 `--in-place`，直接返回错误，不输出交互提示，避免污染 JSON Lines。

语义：

- 不带 `--in-place`：只创建 `_cryption.json`，不转换已有文件。
- 带 `--in-place`：创建 root 后，把 root 中已有明文文件原地转换为加密文件。
- 如果 root 已经存在 `_cryption.json`，默认报错。
- `--in-place` 必须有明确输入：命令行参数或交互确认。
- 可后续增加 `--force`，但第一版不建议实现。

底层要求：

- 使用 `CreateRootConfigQuick` 创建配置。
- 使用 `OpenRootQuick` 打开新 root。
- `--in-place` 使用 Transfer V3 `ConvertRoot`。
- `ConvertOptions.Password` 必须来自同一次密码输入，不能二次提示。

### list

```bash
safe-disk list --path /abs/encrypted/root/or/file
```

语义：

- `--path` 必须能通过向上查找找到 `_cryption.json`。
- 如果 path 是文件，输出单个文件信息。
- 如果 path 是目录，列出目录内容。
- 打开 root 时先处理未完成 operation marker。

### import

```bash
safe-disk import --source /abs/plain/file --dest /abs/encrypted/file
safe-disk import --source /abs/plain/dir --dest /abs/encrypted/dir
```

语义：

- `--source` 是明文路径。
- `--dest` 是加密视图路径。
- `--dest` 必须属于已有加密 root。
- `import` 不负责创建 root。
- 如果需要新 root，先运行 `create`。

选项：

- `--skip-recursive`：目录导入时只处理顶层。
- `--no-progress`：不显示进度。
- `--json`：输出机器可读进度。
- `--unfinished`：打开 root 时对未完成 operation 的处理策略。

### export

```bash
safe-disk export --source /abs/encrypted/file --dest /abs/plain/file
safe-disk export --source /abs/encrypted/dir --dest /abs/plain/dir
safe-disk export --source /abs/encrypted/file --dest -
```

语义：

- `--source` 是加密视图路径。
- `--dest` 是明文路径。
- `--dest -` 表示单文件输出到 stdout。
- 目录导出到 stdout 第一版不支持，必须明确报错。

选项同 `import`。

### info

第一版可暂不实现，但目标语义如下：

```bash
safe-disk info --path /abs/encrypted/root/or/file
```

输出：

- root 路径。
- root 内相对路径。
- 配置算法。
- 是否存在 pending task。
- 文件/目录基本信息。

### webdav serve

> 规划中，当前 CLI 尚未实现。完整安全模型见 [THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md](design/THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md)。

```bash
safe-disk webdav serve --path /abs/encrypted/root/or/item
safe-disk webdav serve --path /abs/encrypted/root/or/item --mount
safe-disk webdav serve --path /abs/encrypted/root/or/item --json
```

语义：

- 使用统一密码与 root open helper；文件仅暴露该文件，目录仅暴露该目录树。
- 直接复用 Go `sec_webdav` 会话管理器；CLI 不经过 FFI，不自行实现 HTTP 服务或平台挂载。
- 固定创建只读 loopback 会话。首期不支持 `--edit`，不写明文临时目录。
- 默认前台持续运行，`Ctrl-C`、正常退出和启动失败清理路径均关闭会话并请求 Go 卸载。
- `--mount` 仅请求 Go 平台适配层挂载。平台不支持、挂载失败或卸载失败必须输出稳定错误码或状态，不能退化为普通目录。
- 人类模式只向终端显示一次地址和访问凭据；不得写入日志或 stderr。`--json` 向 stdout 输出 JSON Lines 生命周期事件，地址/token 只出现在启动事件中。
- 首期不提供跨进程 `list/close/mount/unmount`，也不能操作 GUI 进程创建的会话。现有会话是进程内资源；需要跨进程控制时必须先实现经本地认证的常驻 Go daemon/IPC。

建议的 JSON Lines 事件：

```json
{"event":"webdav_started","url":"http://127.0.0.1:...","token":"...","read_only":true,"mounted":false}
{"event":"webdav_mount_changed","mounted":true,"mount_path":"..."}
{"event":"webdav_stopped","reason":"signal","unmount_error":null}
```

`token` 是访问能力，不属于普通诊断信息；实现不得在错误、进度或日志事件中重复输出，也不得在测试快照和失败转储中保留真实 token。

## 未完成 Operation 处理设计

恢复不作为单独命令。未完成 operation 的发现和处理是打开 root 的一部分。

### 策略参数

```bash
--unfinished=ask
--unfinished=rerun
--unfinished=clean
--unfinished=skip
```

默认策略：

- 交互式终端：`ask`
- 非交互式终端：`skip`

### ask 行为

当发现未完成 import/export marker 时，显示：

- operation ID
- operation 类型：import/export
- source
- target
- 创建时间
- 上次更新时间

然后询问：

```text
发现未完成导入/导出操作，选择操作：[r]erun / [c]lean marker / [s]kip
```

当发现未完成 convert marker 时，显示：

- operation ID
- convert 类型：encrypt/decrypt
- phase
- root
- work
- backup
- root/work/backup 当前存在状态

然后询问：

```text
发现未完成转换操作，选择操作：[r]ecover / [a]bort and rerun / [s]kip
```

### rerun 行为

- import/export：按 marker 中的 source/target 重新全量执行。
- convert：只在当前 phase 明确可丢弃 work 时允许 abort 后重跑。
- 执行前必须说明会覆盖或重新生成目标路径，遵循覆盖策略。

### clean 行为

- 仅用于 import/export marker。
- 清理 marker 和可安全识别的临时文件。
- 不删除用户目标文件。

### recover 行为

- 仅用于 convert marker。
- 按 phase 和 root/work/backup 实际状态继续目录切换或完成状态收敛。
- 无法判断时标记 `needs_attention` 并输出具体路径。
- verification 失败时同时输出 missing/unexpected/digest mismatch 总数、是否截断和样本路径；不得只显示“校验失败”。

### skip 行为

- 打印摘要。
- 不恢复、不清理。
- 对 `create --in-place` 这类会修改 root 的操作，发现未完成 convert 时必须拒绝继续，除非用户显式 recover 或 abort。

## 进度显示设计

### 人类可读模式

默认输出：

```text
Importing: /abs/plain/a.txt (12/80 files) 15.0%
```

完成输出：

```text
Import successful
Files imported: 80
```

### JSON 模式

`--json` 输出 JSON Lines：

```json
{"event":"operation_started","op_id":"...","type":"import"}
{"event":"progress","op_id":"...","completed":12,"total":80,"current_file":"/abs/plain/a.txt"}
{"event":"operation_completed","op_id":"...","completed":80,"total":80}
```

错误：

```json
{"event":"operation_failed","op_id":"...","error":"..."}
```

当前实现状态：

- `import --json` 和 `export --json` 已接入 V3 runtime callback。
- `create --in-place --json` 已接入 convert runtime callback。
- 普通 `create --path` 不涉及 transfer 进度，当前仍输出人类可读创建结果。
- JSON 模式已有统一错误出口：参数缺失、密码错误、open-root 失败和 transfer 运行时失败均输出单行 `operation_failed` JSON，不混入 Cobra `Error:` 或 usage。
- transfer callback 已报告失败时，命令返回的 error 会带“已报告”标记，root 出口不重复输出第二条失败事件。
- 非 JSON 模式保持人类可读 `Error: ...` 到 stderr，同样不自动打印整段 usage。

## 底层 sec 设计要求

### sec_fs

`sec_fs` 需要提供稳定 root 操作：

- `CreateRootConfigQuick(path, password, options...)`
- `OpenRootQuick(path, password, options...)`
- `FindRootConfig(absPath, options...)`

要求：

- path 处理必须保持绝对路径语义。
- 错误必须可区分：未找到 config、密码错误、路径不存在、权限不足。
- root close 时应尽量清理敏感数据。

### sec_transfer

`sec_transfer` 是 CLI import/export/create --in-place 的底层执行器。

必须稳定支持：

- `ImportFile`
- `ImportDirectory`
- `ExportFile`
- `ExportDirectory`
- `ConvertRoot`
- `ListUnfinishedOperations`
- `CleanUnfinishedImportExport`
- `RecoverConvert`

CLI 需要额外能力：

- import/export 开始前写 operation marker，完成后清理。
- root open 时能列出未完成 import/export 和 convert marker。
- import/export 运行时 progress callback 必须保证最终 complete 或 error，避免 CLI 永久等待。
- import/export 不要求断点续传；未完成后由 CLI 提示全量重跑。
- convert 必须记录 phase marker，并能按 phase recover。
- convert 的 work/backup 目录必须创建在 root 同级目录。
- convert 成功后默认保留 backup，后续显式清理。

建议 V3 接口草案：

```go
type Transfer interface {
    ImportFile(ctx context.Context, req ImportFileRequest, cb ProgressCallback) error
    ImportDirectory(ctx context.Context, req ImportDirectoryRequest, cb ProgressCallback) error
    ExportFile(ctx context.Context, req ExportFileRequest, cb ProgressCallback) error
    ExportDirectory(ctx context.Context, req ExportDirectoryRequest, cb ProgressCallback) error

    ConvertRoot(ctx context.Context, req ConvertRequest, cb ProgressCallback) error
    RecoverConvert(ctx context.Context, rootPath string) (RecoverResult, error)

    ListUnfinishedOperations(ctx context.Context, rootPath string) ([]OperationMarker, error)
    CleanUnfinishedImportExport(ctx context.Context, opID string) error
}
```

marker 草案：

```go
type OperationMarker struct {
    Version int
    OpID string
    Type string // import/export/convert_encrypt/convert_decrypt
    Status string
    Phase string
    Src string
    Dst string
    Root string
    Work string
    Backup string
    CreatedAt time.Time
    UpdatedAt time.Time
}
```

## 算法注册

CLI 目标应使用完整算法注册：

```go
import _ "safe_disk/native/sec_fs/crypto_all"
import _ "safe_disk/native/sec_fs/sec_transfer/v3"
```

不要在 CLI 中手工挑选部分算法实现。否则配置文件使用其他算法时，CLI 可能无法打开 root。

当前 `native/cli/main.go` 已使用 `crypto_all` 聚合注册和 `sec_transfer/v3` 注册。回归测试应继续覆盖不同 key/data/name 算法创建 root 后 CLI 能打开。

已覆盖：

- CLI import/export 可打开 `aes-gcm-name` root，并保持磁盘 store path 不泄漏明文文件名/目录名。

## 测试规划

测试目标是覆盖真实实践路径，不只覆盖函数调用。

### 1. 参数与交互测试

- 缺 `--password`、`--password-env`、`--password-stdin` 时的行为。
- `--password-env` 环境变量不存在。
- `--password-stdin` 能读取密码并成功打开 root。
- 非交互模式无密码时直接失败。
- 相对路径输入会被拒绝或规范化为绝对路径。
- `export --dest -` 仅允许单文件。
- 目录 export 到 stdout 明确失败。

### 2. create 测试

- 空目录 create 成功。
- 不存在目录 create 成功并创建目录。
- 非空目录 create 默认失败。
- 非空目录 create 在交互确认后进入原地加密流程。
- 非交互模式下非空目录 create 不允许隐式原地加密。
- 已有 `_cryption.json` 时 create 失败。
- create 后 list root 成功。
- create 后 import/export 单文件成功。
- `create --in-place` 能把已有明文文件转换为加密文件。
- `create --in-place` 后用系统直接读文件不应得到明文。
- `create --in-place` 后 export 能恢复原始内容。

### 3. import/export 测试

- 单文本文件 round trip。
- 二进制文件 round trip。
- 大文件 round trip。
- 多层目录 round trip。
- 空目录导入。
- 文件名包含空格、中文、特殊字符。
- 覆盖已有目标文件。
- 目标父目录不存在。
- `--skip-recursive` 只处理顶层。

### 4. operation 进度测试

- import/export 时人类可读进度有输出。
- `--json` 输出 JSON Lines。
- callback 最终发出 completed。
- 失败时进度能带出 error。
- Ctrl-C 中断后进程退出码和提示正确。
- import/export 中断后保留 operation marker。

### 5. unfinished/recover 测试

- 人工构造或中断一个 import operation。
- 再次 list/open root 时能发现未完成 import/export marker。
- `--unfinished=rerun` 能全量重跑并完成。
- `--unfinished=rerun` 严格使用 marker 的 `entry_kind=file|directory`，不通过文件系统现状猜测；缺少字段的旧 marker 在清理前失败关闭。
- `--unfinished=clean` 能清理 marker 和安全临时文件。
- `--unfinished=skip` 不恢复、不清理。
- 非交互模式默认不阻塞。
- 人工构造 convert marker 的各个 phase。
- copy/verify phase 可删除 work 后重跑。
- rename 中间态可继续目录切换或进入 `needs_attention`。
- encrypt/decrypt 已通过真实子进程 kill 覆盖 copy、verify 和两次 rename 窗口；Windows 运行时故障注入仍单独保留。
- marker 的 root/work/backup 路径必须校验；路径注入或多个 convert operation 必须进入 `needs_attention`。
- convert 成功后 backup 默认保留。

### 6. 安全测试

- 默认交互密码输入不回显。
- `--password` 的文档明确标注不推荐。
- 日志、进度、JSON 输出不包含密码。
- import/list 不写明文临时文件。
- export 明确写出明文到用户指定位置。

### 7. 兼容测试

- CLI 创建的 root 可被 FFI/Flutter 打开。
- FFI/Flutter 创建的 root 可被 CLI 打开。
- 使用不同算法配置的 root 可被 CLI 打开。
- 嵌套 root 的路径查找符合最近 root 优先原则。

### 8. WebDAV CLI 测试

- 真实 CLI 子进程以文件和目录路径启动 `webdav serve`，能读取限定范围。
- 无 token、错误 token、越界 URL 和全部写方法必须失败；合法 `OPTIONS/GET/HEAD/PROPFIND` 行为与 Go 协议测试一致。
- `Ctrl-C`、启动错误和异常退出均撤销地址；旧 token 不能在下一次启动中复用。
- `--json` 仅向 stdout 输出可解析事件；stderr、错误和日志不包含 token 或密码。
- `--mount` 在每个支持平台验证挂载、卸载和失败状态；未实现平台适配时明确报不支持。
- Flutter/GUI 创建的 root 能由 CLI 暴露；CLI 创建的 root 也能由 GUI 对同一范围创建会话。

## 实施顺序

1. 定义 `sec_transfer` V3 operation marker 和 convert phase marker。
2. 改 CLI 入口为完整算法注册。
3. 提取统一密码读取 helper。
4. 提取统一 root open helper，并接入 unfinished operation 检查。
5. 增加 `create` 命令。
6. 实现 import/export marker、运行时进度和 JSON 输出。
7. 实现 `create --in-place`，基于 convert work/backup 目录切换。
8. 增加前台 `webdav serve`，复用 Go 会话管理器和 root 生命周期。
9. 补齐实践测试矩阵。

## 不做的事

- 不新增单独 `recover` 命令。
- 不把 CLI 路径模型改成 `--root + --path`。
- 不在 CLI 中保存密码。
- 不先扩展增量加密 FFI。
- 不让 CLI 绕过 `sec_fs/sec_transfer` 直接操作内部加密文件。
- 不为 import/export 做断点续传。
- 不围绕 v2 `ResumeAllTasks` 设计 CLI。
- 不把短生命周期的 CLI 命令伪装成可跨进程管理的 WebDAV 会话控制器。
- 不让 CLI 直接调用 FFI、另起 WebDAV server、拼接系统挂载命令或用明文临时目录替代挂载。
