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
- import/export marker 记录 `entry_kind=file|directory`，供上层按原方向和原路径全量重跑；缺少该字段的旧 marker 不允许猜测类型，只能清理或跳过。

### 4. 并发协调不是 task

同一 root 的 import、export、convert、recover 和 marker clean 必须串行，避免固定 temp/backup 名互删或 convert 切换目录时仍有复制操作。V3 使用应用私有缓存目录中的稳定 OS advisory lock 文件：

- lock key 基于规范化、解析 symlink 后的 root 绝对路径；
- lock 文件位于用户缓存下的 `safe_disk/transfer-locks/`，不写入 root 或其父目录；
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

## 持久化安全等级

`sec_transfer_v3.New` 接受 `WithDurability`，默认等级为 `full`。公共 import/export/convert request 也包含可选 `Durability`：空值继承 manager 默认值，非空值只覆盖本次 operation，不修改进程全局状态。

CLI 的 import/export/create in-place 使用 `--durability=none|data|full` 传入请求，默认 `full`。unfinished marker 不保存 durability；用户选择全量重跑时使用当前命令的 durability，而不是恢复上次策略。

FFI/Dart 当前不暴露降级开关，现有 C ABI 始终使用默认 `full`。不增加 process-wide `set_durability`：这种全局 setter 会让并发 Dart operation 相互覆盖策略。若以后确有 FFI 配置需求，应新增显式 options 参数或新 ABI，而不是共享可变配置。

`ISecRoot.OpenFile` 返回的基础接口 `ISecFile` 直接包含 `Sync()`；durability 数据提交由编译期接口保证，不依赖对 `ISecFilePlus` 或私有 sync 接口的运行时类型断言。

三个等级的实际语义：

- `none`：不主动调用文件或目录 `Sync`，仍保留 temp、backup、rename 和 marker 协议；只保证进程正常运行时的逻辑顺序，不承诺掉电持久化。
- `data`：在 rename 前同步 import 的加密临时文件、export 的普通临时文件和 marker 临时文件；不主动同步目录 metadata。
- `full`：包含 `data`，并在 marker 提交/删除、目录创建、文件 rename/delete、convert 目录 rename 和恢复清理后同步相关目录及父目录。

marker 使用“写临时 JSON -> 同步临时文件 -> rename -> 同步 active/base/root 目录”的顺序。import/export 覆盖目标时，每次 `dest -> backup`、`temp -> dest` 和 backup 删除都是独立提交点；正式数据提交期间的 sync 失败会返回错误并保留 operation marker，后续仍按完整操作重跑，而不是尝试恢复百分比。

成功路径最后删除 marker 后还会同步 active 目录。若这一次目录 sync 失败，函数返回错误，但 unlink 已经发生，当前进程中 marker 已不可见，掉电后的 marker 状态不确定；数据提交本身已经完成，不应据此回滚正式目标。

平台边界：Linux/Unix 使用打开目录后 `Sync` 的方式提交目录项。Windows 目前只保证文件数据 `Sync`，目录 metadata flush 仍为 best effort；因此 Windows 下名为 `full` 的策略尚未达到与 Linux/Unix 等价的掉电保证。

## 大目录执行模型

Transfer 的“流式”必须按层次描述，不能只因为单文件使用 `io.Copy` 就宣称目录操作内存有界。

当前代码实现结论：

- 单文件内容通过固定缓冲区复制和 hash，不把完整文件读入内存；
- 目录 import/export 使用“计数遍 + 执行遍”，不再保存全部文件路径和目录路径；
- convert verification 使用双向逐项校验，不再保存 source/work 两份 path-to-digest manifest；
- `filepath.WalkDir` 不保存整树，但会受递归深度和单目录条目数影响；
- secure root walker 每次只读取 100 个 backing entries，但会保存尚未遍历的子目录。目录宽度很大时，该待处理栈仍可能随目录数增长，因此仅改 Transfer 消费方式还不能宣称端到端存在固定硬上限。

当前执行模型：

1. **计数遍**：只统计文件数，不保存路径，用于保持现有 `TotalFiles` 精确语义。取消或扫描错误发生在该阶段时，不创建目标内容，保留 operation marker 供下次全量重跑。
2. **执行遍**：再次遍历；遇到目录立即创建，遇到文件立即原子 import/export。内存中只保留当前路径、当前文件 copy buffer、walker 工作集和进度计数，不保存整树文件列表。
3. **校验遍**：convert 不再构建两份 manifest。先从 expected 方向逐项检查 actual 是否存在、类型是否一致、文件摘要是否一致；再从 actual 方向逐项统计 unexpected entry。报告只保存总数和每类最多 16 条稳定样本。

两遍扫描是有意的兼容取舍：它保留 CLI/FFI/Dart 已使用的精确 `TotalFiles`，代价是目录元数据读取两次。Transfer 不提供源快照；若源在计数遍与执行遍之间变化，最终 `DoneFiles` 可以与最初 `TotalFiles` 不同，普通 import/export 按实际第二遍结果执行，convert 还会在 rename 前通过全树校验阻止不一致 work 切换。进度仍不持久化，失败后仍是全量重跑。

初始实现保持单 worker 顺序复制。并发 worker、I/O 限速和字节级进度必须建立在明确的资源预算与回调兼容语义上，不与本轮路径内存优化捆绑。只有 secure root walker 的待处理目录也改为受控工作集，并完成超宽/超深目录测试后，文档才可声明端到端目录遍历具有硬内存上限。

## Import

### 单文件

1. 写 marker。
2. 打开普通源文件。
3. 在 root 内写 `<dest>.tmp.safe_disk`。
4. copy 完成，按 durability 策略 sync，再 close。
5. 若目标存在，先 rename 为 `<dest>.raw.safe_disk`。
6. temp rename 为正式目标。
7. 删除 backup。
8. 删除 marker。

copy 或 close 失败时删除 temp。正式 rename 失败时尝试从 backup 恢复原目标。

### 目录

1. 拒绝源目录本身是加密 root。
2. 第一遍流式扫描并统计文件总数，不保存路径。
3. 拒绝符号链接。
4. 跳过 `.transfer_v3`、`_cryption.json`、work/backup 名称和嵌套加密 root。
5. 第二遍遇到目录立即创建，保留空目录。
6. 遇到文件立即复用单文件原子导入，不保存整树列表。
7. 成功后删除 marker。

`aes-gcm-name` 下文件名和目录名都通过 root view path 转换，不直接拼 store path。
用户点文件和点目录（例如 `.env`）参与 import/export；root walker 显式包含隐藏项后，再按保留名称过滤 `.transfer_v3` 及其子树、配置和 work/backup 条目，不能用“隐藏”替代内部对象边界。

## Export

### 单文件

1. 写 marker。
2. 通过 root view path 打开加密文件。
3. 写普通目标 `<dest>.tmp.safe_disk`。
4. copy，按 durability 策略 sync、close，并在需要时保存原目标 backup。
5. temp rename 为正式目标。
6. 删除 backup 和 marker。

### 目录

1. 第一遍使用 root walker 按 view path 统计文件总数，不保存路径。
2. 第二遍遇到目录立即创建，保留空目录。
3. 拒绝符号链接。
4. 遇到文件立即复用单文件原子导出，不保存整树列表。
5. 成功后删除 marker。

## 覆盖语义

请求包含 `Overwrite`：

- `false`：目标存在时返回错误
- `true`：文件通过 temp + backup + rename 替换；目录采用合并语义，替换同名文件但保留目标独有内容

Flutter 文件和目录 import 在顶层目标已存在时先交互确认，提供取消、保留两者和显式替换；默认传入 `Overwrite=false`。目录 import 即使源目录为空，也会在顶层目标存在且未授权覆盖时拒绝，不依赖遍历过程中偶然遇到文件冲突。FFI import ABI 显式携带 overwrite 位，不再硬编码覆盖。CLI/FFI 的其他调用方同样必须明确决定策略。V3 不实现隐式 skip 列表或逐文件冲突 task。

import marker 保存本次 `overwrite` 决策和 `destination_initially_existed`。用户选择全量重跑时沿用原决策；若目标在首次运行前不存在，重跑可以合并覆盖该 operation 自己留下的部分目录/文件。缺少后一个字段的旧 marker 不允许据此升级为覆盖，仍按显式 `overwrite` 处理。

## 元数据与创建权限

当前 V3 是内容与目录拓扑 Transfer，不保留源对象的 owner、permission mode 或 mtime：

- owner/group 归执行进程，避免依赖特权 `chown` 和跨主机 UID/GID 映射；
- import 不把源 mode/mtime 写到密文 backing file，避免只读/`000` 权限使 vault 无法重开，也避免额外泄漏源时间；
- export 不伪造无法从当前加密格式可信恢复的原始 metadata；
- 文件 mtime 是本次写入时间，不能作为源文件时间证据。

新创建对象使用安全基线：密文文件、配置、operation marker、lock 和导出明文文件为 `0600`，密文目录、marker 目录、convert work 和新建导出目录为 `0700`。操作系统 `umask` 可以进一步收紧。`MkdirAll` 不修改已经存在的目录；本轮也不递归 chmod 旧 root，以免无提示接管用户已有权限。

import/export 的原子替换通过新建 temp 后 rename，因此被替换的正式文件会采用新 temp 的安全 mode。若未来要支持可选 metadata restore，必须先定义经过认证加密、版本化且不与用户路径冲突的 metadata 格式；不得直接借用密文 backing file 的 mode/mtime 作为原始明文 metadata side channel。

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

内容不一致时不能只返回第一条字符串错误。V3 生成结构化 `verification` 报告并写回 convert marker：

- expected/actual 目录数和文件数；
- missing/unexpected 目录总数与稳定排序样本；
- missing/unexpected 文件总数与稳定排序样本；
- digest mismatch 总数与稳定排序样本；
- 每类最多保存前 16 条路径，超出时设置 `truncated=true`，避免 marker 无上限增长。

报告写入后 marker 使用 `phase=needs_attention`、`status=failed`。source、work 和 marker 全部保留，不进入 rename，也不由 recovery 自动删除。扫描失败、权限错误或 context cancel 不伪造成内容差异报告，仍保留原 phase 和底层错误供重跑诊断。

### Recovery

`RecoverConvert` 同时检查 marker phase 与 root/work/backup 实际存在状态：

- `creating_work/copying_to_work/verifying_work` 且原 root 仍存在、backup 不存在：删除由 root 与 op id 派生的 work，清理 marker，返回 rerun
- `renaming_root_to_backup` 且 root/work 存在、backup 不存在：先完成 `root -> backup`，再完成 `work -> root`
- root 不存在、work/backup 存在：完成 `work -> root`
- root/backup 存在、work 不存在：切换已经完成，清理 marker 并返回 completed
- 状态矛盾或无法唯一判断：返回 needs_attention，不猜测、不删除目录
- `needs_attention` 且带 verification 报告：返回差异计数与样本位置，保留 source/work/backup，要求用户检查后重新完整 convert

恢复前必须验证 marker：op id 只能包含字母、数字、`-`、`_`，`root` 必须等于当前恢复目标，`work/backup` 必须严格由 `root + op id` 派生。存在多个不同 convert op id 时直接返回 `needs_attention`。marker 内容不可信，禁止据其任意删除或 rename 路径。

人工处理顺序：先确认 marker 中 root/work/backup 都是预期路径，再读取 verification 计数和样本；不得手工把未验证 work rename 为 root。若原 root 完整且 backup 不存在，可保留或复制 work 供排查，随后清理该次 convert 状态并从原 root 全量重跑。若 root 已缺失或 backup 已出现，不自动删除任何目录，先离线备份三者。

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
- `none/data/full` 的文件与目录 sync 策略矩阵
- 加密临时文件 sync 失败时不提交目标并保留 marker
- 导出临时文件 sync 失败时保留原目标、清理 temp 并保留 marker
- rename 后目录 sync 失败时保留 marker，要求后续完整重跑
- 请求级 durability override 不污染 manager 默认值，CLI `full/none/data` create/import/export 互通及非法值无副作用拒绝
- convert 多类别差异计数、稳定排序、每类 16 条截断、marker JSON 持久化与 recovery 不删除 work

## 尚未完成

- 经过认证加密的可选 metadata restore 格式（当前明确只做安全归一化，不保留 owner/mode/mtime）
- FFI 对 durability 等级的显式 per-operation options ABI（当前有意固定默认 `full`）
- Windows 目录 metadata flush 的等价实现与掉电故障验证
- Windows rename/占用句柄专项故障注入
- Windows `LockFileEx` 运行时竞争与进程退出释放测试（当前仅有实现和 API 签名核对）
- secure root walker 待处理目录的硬上限，以及超宽/超深目录资源测试
- 并发 worker、I/O 限速与字节级进度

## 明确不做

- 不恢复 v1/v2 task 模型
- 不保存逐文件进度
- 不支持断点续传
- 不让 FFI/Dart 持有 Go task 对象
- 不自动删除 convert backup
- 不在状态不确定时自动猜测 rename 或删除目录

历史实现仍可在受保护的 `native/sec_fs/sec_transfer/_archived/` 与本轮只读备份中审计，但不参与 Go 构建和产品接口。
