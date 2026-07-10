# Transfer V3 设计

> 本文只描述当前代码中的 Transfer V3。v1/v2 task、进度持久化、resume、rollback 接口已经从活跃源码和 FFI/Dart 接口删除，不提供兼容。

## 模块定位

Transfer 负责普通文件系统与 `sec_fs.ISecRoot` 之间的数据搬运，以及整棵 root 的加密/解密切换：

- import：普通文件或目录写入加密 root
- export：加密 root 中的文件或目录写入普通文件系统
- convert encrypt：普通目录转换为加密 root
- convert decrypt：加密 root 转换为普通目录
- unfinished 感知：只判断 import/export 是否未完成
- convert recovery：根据目录与 phase marker 恢复最终切换

当前实现：

- 公共类型：`native/sec_fs/sec_transfer/v3_interface.go`
- 实现：`native/sec_fs/sec_transfer/v3/`
- CLI：`native/cli/cmd/`
- FFI：`native/ffi_sec_fs/`
- Dart：`lib/native/`、`lib/services/directory_service.dart`

## 核心原则

### 1. 不做持久化 task

import/export 不创建 task ID，不保存逐文件进度，不支持断点续传：

1. 操作开始时写 operation marker。
2. 每次执行都重新全量扫描、全量复制。
3. 运行中通过 callback 报告临时进度。
4. 成功后删除 marker。
5. 失败、取消或进程退出时保留 marker。
6. 下次打开 root 时只提示“存在未完成操作”，由用户选择清理或重新全量执行。

这避免了文件列表、逐文件状态、回滚日志和版本迁移组成的臃肿 task 系统。

### 2. 运行时进度不持久化

`V3ProgressCallback` 只在当前进程有效：

```go
type ProgressEvent struct {
    OpID        string
    Type        OperationType
    TotalFiles  int64
    DoneFiles   int64
    CurrentPath string
    Error       error
    Complete    bool
}
```

进度用于 CLI 展示、JSON Lines、FFI callback 和 Flutter 进度框。进程退出后不恢复百分比。

### 3. 取消只存在于内存

FFI 为活动 operation 保存一次性 `context.CancelFunc`：

- handle 仅在操作运行期间存在
- 操作完成后立即删除
- 不写 task 文件
- 扫描、逐文件循环、文件 copy reader 和提交前检查 `context`
- 取消发生在提交前时删除临时文件，不覆盖原目标
- 取消或失败后保留 unfinished marker

### 4. 并发协调不是 task

同一 root 的 import、export、convert、recover 和 marker clean 必须串行，避免固定 temp/backup 名互删或 convert 切换目录时仍有复制操作。V3 使用 root 同级目录中的稳定 OS advisory lock 文件：

- lock key 基于规范化、解析 symlink 后的 root 绝对路径；
- Unix 使用 `flock`，Windows 使用 `LockFileEx`；
- 不删除 lock 文件，避免 unlock 后 unlink 导致不同进程锁住两个 inode；
- 文件不保存 operation、进度、密码或恢复状态，不属于持久化 task；
- 文件描述符关闭或进程退出时 OS 自动释放锁；
- 等待锁时检查 `context`，FFI runtime cancel 可以终止等待；
- 获得锁后才写 operation marker，因此未开始的等待者取消时不制造 unfinished marker。

锁粒度当前是整个 root，而不是单文件。它牺牲同 root 并行吞吐，换取 import/export/convert 与 recovery 的确定性；不同 root 仍可并行。

### 5. convert 使用目录切换

convert 不在原目录逐文件改写，而是：

1. 创建同级 work 目录。
2. 通过 import/export 全量复制到 work。
3. 验证 work 可打开及文件摘要。
4. `root -> backup`。
5. `work -> root`。
6. 保留 backup，不自动删除。

双倍存储空间是明确接受的取舍。两次 rename 不是单个原子操作，因此 convert 单独使用 phase marker。

## 公共接口

```go
type V3Transfer interface {
    ImportFile(ctx context.Context, req ImportFileRequest, cb V3ProgressCallback) error
    ImportDirectory(ctx context.Context, req ImportDirectoryRequest, cb V3ProgressCallback) error
    ExportFile(ctx context.Context, req ExportFileRequest, cb V3ProgressCallback) error
    ExportDirectory(ctx context.Context, req ExportDirectoryRequest, cb V3ProgressCallback) error

    ConvertRoot(ctx context.Context, req ConvertRequest, cb V3ProgressCallback) error
    RecoverConvert(ctx context.Context, rootPath string) (RecoverResult, error)

    ListUnfinishedOperations(ctx context.Context, rootPath string) ([]OperationMarker, error)
    CleanUnfinishedImportExport(ctx context.Context, rootPath string, opID string) error
}
```

旧 `ISecTransfer`、`ITask`、`ITransferProgress`、`LoadTasks`、`ResumeAllTasks`、`PauseTask`、`AsyncRollback` 已删除。

## 实现注册

`sec_transfer` 公共包不直接 import `sec_transfer/v3`，避免包循环。CLI 与 FFI main 通过 blank import 触发：

```go
_ "safe_disk/native/sec_fs/sec_transfer/v3"
```

V3 实现通过 `RegisterTransferV3Factory` 注册。若调用方遗漏注册：

- `GetDefaultTransferV3()` 不 panic
- 返回 unavailable manager
- 所有操作返回 `ErrTransferV3NotRegistered`

这让库嵌入错误能够被调用方处理，而不是在公共 API 边界崩溃进程。

## Operation Marker

marker 位于 root 内部：

```text
<root>/.transfer_v3/active/<op_id>.json
```

核心字段：

```json
{
  "version": 3,
  "op_id": "import-...",
  "type": "import",
  "status": "running",
  "src": "/absolute/plain/path",
  "dst": "relative/view/path",
  "root": "/absolute/root/path",
  "created_at": "...",
  "updated_at": "..."
}
```

marker 只证明操作未正常完成，不证明：

- 已完成百分比
- 哪些文件已复制
- 临时文件一定存在
- 能从中断位置继续

重新执行时仍是一次完整 import/export。

## Import

### 单文件

1. 写 marker。
2. 打开普通源文件。
3. 在 root 内写 `<dest>.tmp.safe_disk`。
4. copy 完成并 close。
5. 若目标存在，先 rename 为 `<dest>.raw.safe_disk`。
6. temp rename 为正式目标。
7. 删除 backup。
8. 删除 marker。

copy 或 close 失败时删除 temp。正式 rename 失败时尝试从 backup 恢复原目标。

### 目录

1. 拒绝源目录本身是加密 root。
2. 全量扫描普通目录。
3. 拒绝符号链接。
4. 跳过 `.transfer_v3`、`_cryption.json`、work/backup 名称和嵌套加密 root。
5. 先创建目标目录与空目录。
6. 逐文件复用单文件原子导入。
7. 成功后删除 marker。

`aes-gcm-name` 下文件名和目录名都通过 root view path 转换，不直接拼 store path。

## Export

### 单文件

1. 写 marker。
2. 通过 root view path 打开加密文件。
3. 写普通目标 `<dest>.tmp.safe_disk`。
4. copy、close，并在需要时保存原目标 backup。
5. temp rename 为正式目标。
6. 删除 backup 和 marker。

### 目录

1. 使用 root walker 按 view path 扫描。
2. 保留空目录。
3. 拒绝符号链接。
4. 逐文件复用单文件原子导出。
5. 成功后删除 marker。

## 覆盖语义

请求包含 `Overwrite`：

- `false`：目标存在时返回错误
- `true`：通过 temp + backup + rename 替换

Flutter 目录导入在目标目录已存在时先交互确认；CLI/FFI 的调用方必须显式决定策略。V3 不实现隐式 skip 列表或逐文件冲突 task。

## Convert

### Phase

```text
creating_work
copying_to_work
verifying_work
renaming_root_to_backup
renaming_work_to_root
completed
needs_attention
```

convert marker 记录：

- root
- work
- backup
- convert kind
- 当前 phase
- 时间戳

### Encrypt

1. 普通 root 作为源。
2. work 创建新的加密 root 配置。
3. 普通 root 全量 import 到 work。
4. 使用同一密码重新打开 work，按 view-relative path 比较源与 work 的目录集合、文件集合和逐文件 SHA-256。
5. 关闭所有句柄。
6. root rename 为 backup。
7. work rename 为 root。
8. 标记 completed，保留 backup。

### Decrypt

1. 使用密码打开加密 root。
2. 全量 export 到普通 work。
3. 在关闭加密源 root 前，按 view-relative path 比较源与普通 work 的目录集合、文件集合和逐文件 SHA-256。
4. 关闭所有句柄。
5. root rename 为 backup。
6. work rename 为 root。
7. 标记 completed，保留 backup。

### Verification

`verifying_work` 不是“配置可打开”的代名词。rename 前必须同时满足：

- 空目录和非空目录集合完全一致；
- 文件 view-relative path 集合完全一致；
- 每个文件解密视图内容的 SHA-256 一致；
- 扫描和 hash 期间持续检查 `context`；
- 缺失、额外或摘要不一致时保留 source、work 和 convert marker，不进入第一次 rename。

验证沿用 import 对普通源的过滤语义：跳过 `.transfer_v3`、配置文件、convert work/backup 名称和嵌套加密 root。该机制不是文件系统快照；同权限外部进程在验证完成后、rename 前继续修改源仍属于尚未解决的并发篡改场景。

### Recovery

`RecoverConvert` 同时检查 marker phase 与 root/work/backup 实际存在状态：

- `creating_work/copying_to_work/verifying_work` 且原 root 仍存在、backup 不存在：删除由 root 与 op id 派生的 work，清理 marker，返回 rerun
- `renaming_root_to_backup` 且 root/work 存在、backup 不存在：先完成 `root -> backup`，再完成 `work -> root`
- root 不存在、work/backup 存在：完成 `work -> root`
- root/backup 存在、work 不存在：切换已经完成，清理 marker 并返回 completed
- 状态矛盾或无法唯一判断：返回 needs_attention，不猜测、不删除目录

恢复前必须验证 marker：op id 只能包含字母、数字、`-`、`_`，`root` 必须等于当前恢复目标，`work/backup` 必须严格由 `root + op id` 派生。存在多个不同 convert op id 时直接返回 `needs_attention`。marker 内容不可信，禁止据其任意删除或 rename 路径。

## CLI 映射

- `create --in-place` 使用 convert encrypt
- `import/export` 使用 V3 同步方法与运行时 callback
- `--json` 输出 started/progress/completed JSON Lines
- 打开 root 时处理 unfinished marker
- `--unfinished=ask|rerun|clean|skip`
- 不提供独立 resume/recover task 命令

convert recovery 属于打开 root 前的 phase 检查，不是旧 task resume。

## FFI 与 Dart 映射

活跃 C ABI 只保留：

- `sec_transfer_v3_import_file`
- `sec_transfer_v3_import_directory`
- `sec_transfer_v3_export_file`
- `sec_transfer_v3_export_directory`
- 对应的 `_with_callback` operation 版本
- `sec_transfer_v3_cancel`
- `sec_transfer_v3_list_unfinished`
- `sec_transfer_v3_clean_unfinished`
- `sec_transfer_v3_convert_root`
- `sec_transfer_v3_recover_convert`

已删除：

- `sec_*_async` 兼容别名
- `sec_*_async_with_callback` 兼容别名
- `action_task_get_progress`
- `action_task_close`

Dart 使用 worker isolate 执行同步 C ABI，通过消息转发进度，避免阻塞 UI isolate。该 isolate 不是持久化 task。

## 测试证据

当前测试覆盖：

- 单文件与目录 import/export
- `aes-gcm-name` 文件名和目录名往返
- 空目录保留
- 符号链接拒绝
- 源 root 拒绝与嵌套 root 跳过
- overwrite 原目标保护
- context 取消、temp 清理和 marker 保留
- marker query/clean
- convert encrypt/decrypt 与 backup 保留
- convert 双向目录/文件集合与逐文件 SHA-256，源在 copy 后变化时禁止 rename
- convert rename 窗口 recovery
- Linux/Unix 下 encrypt/decrypt 在 copying、verifying、第一次 rename 前后、第二次 rename 后、completed marker 写入后共 12 个真实子进程 kill/recover 场景
- convert marker 路径注入、多个 operation 冲突与早期 work 安全清理
- CLI 普通输出与 JSON progress
- FFI callback 与 runtime cancel
- 同进程和真实子进程 root lock 竞争、context 取消等待、symlink alias 锁键一致性
- FFI operation 等锁时取消且不落 marker、不提交目标
- Dart worker isolate 非阻塞、listener 异常、取消
- CLI 创建 root 后 Dart 操作、Dart/FFI 创建 root 后 CLI 操作
- V3 未注册或 factory 返回 nil 时返回 `ErrTransferV3NotRegistered`，不 panic

## 尚未完成

- 权限、owner、mtime 的跨平台保留策略
- 可配置 fsync 安全等级
- Windows rename/占用句柄专项故障注入
- Windows `LockFileEx` 运行时竞争与进程退出释放测试（当前仅有实现和 API 签名核对）
- 更完整的 convert 校验报告与人工处理指引
- UI 对 unfinished import/export 的“一键全量重跑”入口
- 超大目录扫描的内存上限、并发 worker、限速与字节级进度

## 明确不做

- 不恢复 v1/v2 task 模型
- 不保存逐文件进度
- 不支持断点续传
- 不让 FFI/Dart 持有 Go task 对象
- 不自动删除 convert backup
- 不在状态不确定时自动猜测 rename 或删除目录

历史实现仍可在受保护的 `native/sec_fs/sec_transfer/_archived/` 与本轮只读备份中审计，但不参与 Go 构建和产品接口。
