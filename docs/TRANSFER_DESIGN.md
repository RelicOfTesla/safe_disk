# sec_transfer 设计文档

> 本文档概括 `native/sec_fs/sec_transfer` 的设计意图、核心原理、当前实现状态和后续规划。当前完成度仍以代码审计为准，不能把历史报告或测试名直接视为完整实现证明。

最后更新：2026-06-20

## 模块定位

`sec_transfer` 是 `sec_fs` 之上的批量数据迁移层。

它不负责定义加密算法，也不直接管理 UI。它的职责是安全地执行 import/export/convert 这三类文件迁移操作。

V3 方向不再延续 v1/v2 的通用 task/progress 持久化模型。新设计只保留“未完成操作可感知”和“破坏性转换可恢复”，避免把普通 import/export 做成臃肿任务系统。

当前包路径：

- 公共接口：`native/sec_fs/sec_transfer/interface.go`
- V3 公共接口：`native/sec_fs/sec_transfer/v3_interface.go`
- 当前实现：`native/sec_fs/sec_transfer/v3`
- 旧实现：`native/sec_fs/sec_transfer/v2`
- 历史实现：`native/sec_fs/sec_transfer/_archived`

## 设计目标

`sec_transfer` 目标上要支撑三类操作：

- Import：外部明文路径 -> 加密 root。
- Export：加密 root -> 外部明文路径。
- Convert：root 内原地转换，用于已有明文目录初始化加密，或把加密 root 解密回普通目录。

V3 目标需要满足：

- import/export 提供运行时进度回调，但不做进度持久化。
- import/export 开始时写入 operation marker，成功后清理；后续 open root 只需要知道“存在未完成 import/export”。
- import/export 未完成后的恢复策略是重新全量执行或清理中间态，不做断点续传。
- convert/in-place 才需要可恢复状态，因为它会改变 root 本身。
- convert 尽量复用 import/export 到 work 目录，最后通过目录 rename 切换。
- 文件级原子替换，避免半写文件覆盖正常数据。
- 设计必须优先简单、可解释、可验证，不追求复杂 pause/resume/rollback。

## V3 重新设计方向

### 当前落地状态

截至 2026-06-20，V3 已有第一版基础设施：

- `native/sec_fs/sec_transfer/v3_interface.go` 定义了 V3 公共接口。
- `native/sec_fs/sec_transfer/v3` 实现了 import/export 全量执行、operation marker、convert work/backup 切换骨架和基础 recover 判断。
- import/export 失败会保留 marker，成功会清理 marker。
- 已有 Go 测试覆盖 import/export round trip、失败 marker 保留与清理、rename 窗口 recover。
- CLI `create --in-place` 已接入 V3 convert。
- CLI `import/export` 已迁移到 V3 同步 import/export API，保留原命令参数。
- FFI 已暴露 V3 import/export、unfinished query/clean、convert/recover 基础函数。

仍未完成：

- CLI/FFI 入口已可使用 `crypto_all`；deriver 实现会同时注册旧 deriver registry 与 factory registry。
- V3 默认 root 创建暂用 `nameFactory=none`，尚未解决随机文件名加密下目录稳定映射问题。
- convert recover 已能跨 root/backup/work 发现 phase marker，并对可判断的 rename 窗口继续切换；仍需后续增加更细的校验报告。
- convert 成功后会保留同级 `.safe_disk.backup.<op_id>` 目录；测试已覆盖 backup 保留和 marker 清理。

### 总体取舍

V3 不兼容 v1/v2，不迁移旧 task 格式，只吸收以下有价值能力：

- import/export 的批量复制能力。
- 运行时进度 callback。
- 单文件原子写入。
- root open 时发现未完成操作。
- convert 失败后的状态恢复。

V3 明确不做：

- import/export 进度持久化。
- import/export 断点续传。
- 通用 task engine。
- pause/resume channel 生命周期。
- 依赖内存状态的通用 rollback。
- 单独 recover 命令作为核心入口。

### import/export：operation marker，不做 task

import/export 是普通复制操作。失败或中断后，用户可以重新全量 import/export。

开始操作前写 marker：

```text
<root>/.transfer_v3/active/<op_id>.json
```

marker 示例：

```json
{
  "version": 3,
  "op_id": "20260620-001",
  "type": "import",
  "status": "running",
  "src": "/abs/plain/src",
  "dst": "/abs/encrypted/dst",
  "created_at": "2026-06-20T00:00:00Z",
  "updated_at": "2026-06-20T00:00:00Z"
}
```

语义：

- 写 marker 成功后才开始复制。
- 复制成功后删除 marker。
- 进程中断时 marker 留下。
- 下次 open root 时只提示存在未完成 import/export。
- 用户选择重新执行时，全量重跑。
- 用户选择忽略时，可保留 marker 或显式清理 marker。

import/export 仍必须保证：

- 单文件写入原子替换。
- 临时文件和 backup 文件可被清理。
- 全量重跑的最终结果可预期。
- 覆盖/跳过/报错策略明确。

### convert：work/backup 目录切换，不做逐文件续跑

convert 是破坏性操作，应单独建模。推荐不要在原目录中逐文件原地替换，而是旁路构建目标目录，最后用 rename 切换。

加密普通目录：

```text
/data/root                         # 原普通目录
/data/root.safe_disk.work.<op_id>   # 新加密 root
/data/root.safe_disk.backup.<op_id> # 原目录 backup
```

流程：

1. 创建 work 目录。
2. 在 work 目录创建 `_cryption.json`。
3. 打开 work root。
4. 全量 import `/data/root` 到 work root。
5. 校验 work root 可打开，文件数量/大小摘要符合预期。
6. rename `/data/root` -> `/data/root.safe_disk.backup.<op_id>`。
7. rename `/data/root.safe_disk.work.<op_id>` -> `/data/root`。
8. 成功后保留 backup，后续由显式清理流程处理。

解密加密目录：

```text
/data/root                         # 原加密 root
/data/root.safe_disk.work.<op_id>   # 新普通目录
/data/root.safe_disk.backup.<op_id> # 原加密 root backup
```

流程：

1. 打开 encrypted root。
2. 创建 plain work 目录。
3. 全量 export root 内容到 work。
4. 校验 work。
5. close root，确保没有打开的 root/file handle。
6. rename `/data/root` -> backup。
7. rename work -> `/data/root`。
8. 成功后保留 backup，后续由显式清理流程处理。

这套模型中，convert 失败后也不做逐文件续跑。恢复策略按 phase 处理：

- copy 阶段失败：删除 work，重新全量执行。
- verify 阶段失败：删除 work，重新全量执行或报告错误。
- rename 阶段失败：根据 root/work/backup 是否存在继续切换或进入人工处理。
- completed 阶段：清理 marker，保留 backup。

### convert marker

convert marker 记录 phase，而不是逐文件进度：

```json
{
  "version": 3,
  "op_id": "20260620-002",
  "type": "convert_encrypt",
  "phase": "copying_to_work",
  "root": "/data/root",
  "work": "/data/root.safe_disk.work.20260620-002",
  "backup": "/data/root.safe_disk.backup.20260620-002",
  "created_at": "2026-06-20T00:00:00Z"
}
```

建议 phase：

```text
creating_work
copying_to_work
verifying_work
renaming_root_to_backup
renaming_work_to_root
completed
needs_attention
```

恢复判断：

- `creating_work/copying_to_work/verifying_work`：如果 root 仍存在，删除 work 后可重新全量执行。
- `renaming_root_to_backup`：如果 root 不存在、backup 存在、work 存在，继续 rename work -> root。
- `renaming_work_to_root`：如果 root 已存在且 work 不存在，检查 root 是否为目标目录，成功则标记 completed；如果 root 不存在且 work 存在，继续 rename work -> root。
- 无法判断时标记 `needs_attention`，输出 root/work/backup 的实际存在状态。

### 主要风险

- rename 原子性只在同一 filesystem/mount 内成立，work/backup 必须在 root 同级目录下创建。
- Windows 目录 rename 对打开句柄敏感，切换前必须 close root 和文件句柄。
- 最终切换是两次 rename，不是单个原子操作；必须依赖 phase marker 恢复。
- backup 第一版不应自动删除，避免成功后发现校验遗漏却无回退数据。
- import 时必须排除 `.transfer_v3`、work/backup 目录、已有 `_cryption.json` 和嵌套 root。
- 权限、mtime、空目录、符号链接策略必须显式定义；第一版可先拒绝符号链接。

## 分层关系

```text
Flutter / CLI
    |
FFI 适配层 / CLI 命令
    |
sec_transfer.ISecTransfer
    |
sec_transfer.V3Transfer
    |
sec_transfer/v3.Manager
    |
sec_fs.ISecRoot
    |
crypto_data / crypto_name / crypto_hkdf
```

约束：

- `sec_transfer` 只通过 `sec_fs.ISecRoot` 访问加密 root。
- import/export 的外部明文路径使用 `sec_fs.FullStorePath`。
- root 内路径使用 `sec_fs.RelativeViewPath`。
- 不应绕过 `sec_fs` 直接拼内部加密文件路径，除非是原子 rename 这类需要 store path 的底层操作。

## 公共接口现状

旧 `ISecTransfer` 暴露：

- `ImportFileAsync`
- `ImportDirectoryAsync`
- `ExportFileAsync`
- `ExportDirectoryAsync`
- `ConvertRootAsync`
- `LoadTasks`
- `ResumeAllTasks`
- `RegisterTaskCallback`

旧 `ITask` 暴露：

- `GetTaskID`
- `GetSrcPath`
- `GetTargetPath`
- `GetTotalProgress`
- `PauseTask`
- `ResumeTask`
- `AsyncRollback`

旧 `ITransferProgress` 暴露：

- `GetTotal`
- `GetCompleted`
- `GetCurrentFile`
- `GetError`
- `IsComplete`

接口缺口：

- `ITask` 不暴露 task 类型和状态。
- `ITask` 不暴露当前文件、错误摘要、创建时间、更新时间。
- `ProgressCallback` 不带 task ID，多任务恢复时调用方需要自己捕获 task ID。
- `ResumeAllTasks` 只返回恢复数量，不返回被恢复任务列表、等待句柄或最终结果。
- `LoadTasks` 返回 `[]ITask`，但调用方只能看到 ID/source/target/progress，无法完整展示恢复提示。

这些缺口会直接影响 CLI 的恢复提示和 FFI 的任务状态查询。

## v2 核心模型

`v2` 使用单一 `TransferManager`：

```text
TransferManager
    tasks: map[taskID]*Task
```

每个 `Task` 包含：

- task identity：`taskID`
- task type：export/import/convert
- source 和 target 路径
- source/dest root
- progress：total、completed、currentFile
- status：pending/running/paused/completed/failed/rolling_back/cancelled
- callback
- pause/resume/stop channel
- rollbackFiles
- fileInfos

任务创建后会：

1. 创建 `Task`。
2. 放入 manager 的 `tasks` map。
3. 写入 task manifest。
4. 启动 goroutine 执行。
5. 执行中不断更新 progress/callback。
6. 结束时写 status，并发出最终 callback。

## 操作语义

### Import

Import 从外部普通文件系统读取明文，再写入 `ISecRoot`。

```text
plain src path -> destRoot.OpenFile(relative view path) -> encrypted storage
```

目录 import 会先扫描外部目录，得到文件列表和总数，再逐个导入。

单文件 import 使用 `importFileAtomic`。

### Export

Export 从 `ISecRoot` 读取文件，再写出到外部普通文件系统。

```text
srcRoot.OpenFile(relative view path) -> plain dest path
```

目录 export 会先通过 `srcRoot.WalkDir` 收集文件，再逐个导出。

单文件 export 使用 `exportFileAtomic`。

### ConvertRoot

Convert 是 root 内转换：

- `ConvertActionEncrypt`：把 root 目录中已有明文文件转成加密存储。
- `ConvertActionDecrypt`：把加密 root 导出成普通目录，并删除 `_cryption.json`。

当前 encrypt 实现策略：

1. 在 root 下创建 `.safe_disk.backup`。
2. 把非系统文件移动到 backup。
3. 从 backup import 回原 root。
4. 删除 backup。

当前 decrypt 实现策略：

1. 遍历 root 内加密视图文件。
2. export 到 root 对应明文路径。
3. 删除 `_cryption.json`。
4. close root。

注意：Convert 是高风险操作，CLI/FFI 层必须在执行前检查未完成 task，并要求显式确认恢复或回滚策略。

## 原子文件写入

`atomic_file.go` 的目标是避免目标文件被半写覆盖。

核心模式：

```text
1. 写入 target.tmp.safe_disk
2. 如 target 已存在，rename target -> target.raw.safe_disk
3. rename target.tmp.safe_disk -> target
4. 记录进度
5. 删除 target.raw.safe_disk
```

如果中断：

- `.tmp.safe_disk` 表示未完成临时文件，可清理。
- `.raw.safe_disk` 表示原文件备份，可恢复。

当前已有内部恢复函数：

- `recoverAtomicOperations(root sec_fs.ISecRoot)`
- `recoverAtomicOperationsPlain(rootPath string)`

规划要求：

- root open 时应触发 atomic recovery 或至少暴露给上层调用。
- 对 import/export/convert 的不同存储侧分别处理 encrypted root 和 plain path。
- 恢复过程应输出可审计日志，避免静默删除用户数据。

## v2 任务持久化现状

以下内容描述当前 v2 实现，不代表 V3 目标设计。

v2 任务持久化目录：

```text
<root>/.transfer/<task_id>/
    manifest.json
    progress.log
```

`manifest.json` 写一次，保存冷数据：

- task id
- task type
- source path
- destination path
- source root
- destination root
- single file 标记
- convert action
- created_at

`progress.log` append-only，保存热数据：

- 文件完成记录
- 状态变更记录

v2 设计意图：

- manifest 冷数据只写一次，避免频繁重写大 JSON。
- progress 使用 append-only，单次文件完成后 O(1) 追加。
- 恢复时从 manifest 和 progress 重建 task 状态。

v2 当前限制：

- progress append 后默认没有 `fsync`，性能优先，断电场景可能丢最后几条 progress。
- `Total` 恢复时不从 progress 精确恢复，注释中说明需要重新扫描源。
- 当前 `ProgressEntry` 只记录 file/status，不记录错误详情、字节进度、文件大小。
- 已完成文件是否跳过依赖执行逻辑，恢复幂等性还需要实践测试确认。
- V3 不继续采用这种逐文件 progress 持久化模型。

## v2 恢复机制现状

以下内容描述当前 v2 恢复目标，不代表 V3 目标设计。

v2 恢复流程目标：

```text
Open root
    |
manager.LoadTasks([root])
    |
显示 task 摘要
    |
为 task 注册 callback
    |
按策略 ResumeAllTasks / AsyncRollback / Skip
```

v2 当前实现：

- `LoadTasks` 从每个 root 的 `.transfer` 目录加载 task。
- 已完成 task 会尝试清理持久化目录。
- running 状态的历史 task 会被重置为 pending。
- 恢复出的 task channel 被设为 nil。
- `ResumeAllTasks` 只恢复 pending/paused 且 channel 为 nil 的 task。
- `RegisterTaskCallback` 可以为已加载 task 重新注册 callback。

v2 当前问题：

- 上层无法只靠公共接口拿到 task 类型和状态。
- `ResumeAllTasks` 不返回 task 最终完成/失败结果。
- 对 failed task 的恢复策略需要明确：是 resume、rollback，还是只允许用户选择。
- 多 root、多 task 的 callback 输出需要 task ID 关联。
- V3 不再设计通用 `ResumeAllTasks`，import/export 只提示未完成并允许全量重跑，convert 只按 phase 恢复。

## v2 回滚机制现状

当前 `AsyncRollback` 语义是异步清理任务产生的文件。

限制：

- `rollbackFiles` 主要是运行期内存状态；从持久化恢复后能否完整回滚，需要按 import/export/convert 分别测试。
- 对 ConvertRoot 这种移动目录/删除配置的操作，回滚复杂度更高，不能简单等同于删除目标文件。
- rollback 的最终状态和错误没有通过公共 snapshot 暴露给 CLI/FFI。

如果继续维护 v2，才需要满足：

- rollback 必须基于持久化 manifest/progress 重建可回滚动作。
- 对 import/export/convert 分别定义回滚边界。
- 对无法自动回滚的状态，应报告“需要人工处理”的具体文件，而不是静默跳过。

V3 不设计通用 rollback。V3 的策略是：

- import/export：失败后清理 marker 和临时文件，用户按需全量重跑。
- convert：按 phase 恢复到明确状态；无法判断时进入 `needs_attention`。
- committed 后的 backup 不自动删除，不把 rollback 伪装成万能撤销。

## 与 CLI 的关系

CLI 不应直接实现批量复制逻辑。

CLI 应做：

- 解析绝对路径。
- 通过 `FindRootConfig` 找 root。
- 读取密码并打开 root。
- 检查 `.transfer_v3/active` 和 convert marker，发现未完成 import/export/convert。
- import/export 未完成时提示用户重新全量执行、清理 marker 或跳过。
- convert 未完成时按 phase 提示 recover、重新全量执行、或进入人工处理。
- 调用 import/export/convert API。
- 展示进度或 JSON Lines。

V3 中 CLI/FFI/Dart 不依赖 `ITask` 对象。当前主路径使用 `V3Transfer`：同步 import/export、operation marker 查询/清理、convert 和 convert recover。

## 与 FFI 的关系

FFI 层应把 `sec_transfer` 包装为 C ABI 可调用能力：

- export/import file
- export/import directory
- 运行时 progress callback
- unfinished operation query
- convert recover/cleanup

V3 中 FFI 不应暴露复杂 task 对象。Flutter 只需要查询是否存在未完成 operation，并对 convert 展示 phase 与恢复建议。

## 测试现状

`native/sec_fs/sec_transfer/v3` 当前已有测试覆盖：

- import/export round trip
- import/export 失败 marker 保留
- marker clean
- convert rename 窗口 recover

`native/sec_fs/sec_transfer/v2` 旧实现已有测试覆盖：

- basic import/export
- single file import/export
- ConvertRoot encrypt/decrypt
- pause/resume
- rollback
- progress callback
- atomic import/export
- atomic recovery
- task persistence
- LoadTasks
- empty directory
- ignore patterns
- encrypted data and filenames
- multi-level directories
- RegisterTaskCallback
- ResumeAllTasks

这些测试说明 v2 已有较多基础能力，但还不能替代以下实践验收：

- 真实进程被 kill 后恢复。
- 恢复后跳过已完成文件，不重复覆盖。
- 断电后 `.tmp/.raw` 恢复。
- failed task 的 resume/rollback 行为。
- ConvertRoot 中断后的恢复/回滚。
- FFI callback 与 Dart isolate 生命周期。
- CLI Ctrl-C 后再次 open root 的恢复提示。

## 后续规划

P0：

- 定义 V3 operation marker 格式：import/export active marker、convert phase marker。
- 实现 unfinished operation query，供 CLI/FFI 在 open root 时调用。
- 实现 import/export 全量执行 API：运行时 progress callback，无持久化进度。
- import/export 开始写 marker，成功后清理 marker，失败保留 marker。
- 实现 convert work/backup 目录切换模型。
- convert phase 更新必须在关键 rename 前后落盘。
- work/backup 必须创建在 root 同级目录，禁止跨 filesystem rename。

P1：

- 实现 convert recover：按 phase 和 root/work/backup 实际状态继续、清理或报告 `needs_attention`。
- 实现 transfer temp cleanup：清理孤儿 `.tmp.safe_disk`，在安全条件下恢复 `.raw.safe_disk`。
- 定义覆盖策略：overwrite/skip/error，默认建议 error 或交互确认。
- 定义排除规则：`.transfer_v3`、work/backup、`_cryption.json`、嵌套 root。
- 补齐 crash 测试：copy 阶段 kill、verify 阶段 kill、两次 rename 中间 kill。

P2：

- progress 增加字节级统计，但仍只做运行时回调。
- 定义权限、mtime、空目录、符号链接策略。
- 可配置 fsync 策略：性能优先或安全优先。
- 支持并发 worker 数配置和限速。

## 不做的事

- 不在 `sec_transfer` 中直接处理用户密码输入。
- 不在 `sec_transfer` 中实现 CLI 交互。
- 不绕过 `sec_fs` 直接实现独立加密格式。
- 不把单独 `recover` 命令作为核心模型；恢复应由打开 root 后发现 task 触发。
- 不为 import/export 设计断点续传。
- 不保留 v1/v2 通用 task/progress 持久化模型。
