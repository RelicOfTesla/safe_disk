# FFI 设计文档

> 本文档描述 Flutter 与 Go 后端之间的 FFI 边界设计。当前实现进度以实际代码为准；批量导入/导出、未完成状态 marker 和 convert 恢复原理见 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md)。

最后更新：2026-06-20

## 目标

FFI 层的职责是把 Go 后端能力稳定、安全地暴露给 Flutter，而不是把 Go 内部 API 原样透传给 Dart。

核心目标：

- Flutter 不直接持有 Go 对象或指针。
- Go 侧持有 `ISecRoot`、`ISecFile` 等真实对象。
- Flutter 侧只持有 `rootID`、`fileID`；transfer V3 不再向 Dart 暴露 task 对象。
- 跨 FFI 只传 C 基础类型和 JSON 字符串。
- 二进制数据通过 JSON 中的 base64 字段传输。
- Go 侧分配返回字符串，Flutter 侧负责调用释放函数。

## 分层

### 1. C 导出层

位置：`native/ffi_sec_fs/exports.go`

职责：

- 提供 `//export` 函数，供 `dart:ffi` 查找。
- 做 C 字符串与 Go 字符串的转换。
- 调用 Go 适配层函数。
- 返回 `C.CString(result)`。

这一层不应包含复杂业务逻辑。

### 2. Go 适配层

位置：`native/ffi_sec_fs/ffi.go`

职责：

- 调用 `sec_fs` 和 `sec_transfer`。
- 统一 JSON 响应格式。
- 管理 `rootID`、`fileID`。
- 处理 FFI 入参解析，例如 `OpenOptions` 和 `CreateRootOptions`。

### 3. Go 对象存储层

位置：`native/ffi_sec_fs/stores.go`、`native/ffi_sec_fs/idstore.go`

职责：

- `RootStore` 保存 `RootEntry`。
- `FileStore` 保存 `ISecFile`。
- Flutter 侧只能通过 ID 访问这些对象。

### 4. Dart 绑定层

位置：`lib/native/bindings.dart`

职责：

- 用 `lookupFunction` 绑定 C 导出函数。
- 类型必须与 `exports.go` 完全一致。
- 不做业务封装。

### 5. Dart 封装层

位置：`lib/native/native_lib.dart`

职责：

- 把 C 字符串结果转换成 Dart 对象。
- 调用 `sec_free_string` 释放 Go 返回的 C 字符串。
- 检查 JSON 中的 `success` 字段。
- 给上层 service 暴露更易用的 Dart API。

### 6. Flutter service 层

位置：`lib/services/`

职责：

- `CryptoService` 封装 root/file 级操作。
- `DirectoryService` 封装目录导入/导出。
- `FileService` 提供文件类型判断和文件读写 helper。
- 不直接调用 `DynamicLibrary`。

## 当前接口面

### 已有 Go 导出

当前 `exports.go` 已包含：

- Root：`sec_root_open`、`sec_root_close`、`sec_create_root_config`、`sec_root_change_password`
- File：`sec_file_open`、`sec_file_read`、`sec_file_write`、`sec_file_seek`、`sec_file_truncate`、`sec_file_close`
- Root 级文件操作：`sec_file_delete`、`sec_file_exists`、`sec_rename`、`sec_copy_entry`、`sec_mkdir_all`、`sec_read_dir`
- Quick 操作：`sec_quick_read_file`、`sec_quick_write_file`
- Transfer V3：`sec_transfer_v3_import_file`、`sec_transfer_v3_import_directory`、`sec_transfer_v3_export_file`、`sec_transfer_v3_export_directory`
- Transfer V3 状态：`sec_transfer_v3_list_unfinished`、`sec_transfer_v3_clean_unfinished`
- Convert V3：`sec_transfer_v3_convert_root`、`sec_transfer_v3_recover_convert`
- 内存释放：`sec_free_string`

### 当前 Dart 绑定

当前 `bindings.dart` 已绑定：

- Root
- File
- Root 级目录/文件操作
- Quick 操作
- `sec_free_string`
- Transfer V3 import/export、unfinished marker、convert/recover
- Transfer V3 runtime operation callback 与 cancel handle

`sec_copy_entry(srcRootID, srcPath, dstRootID, dstPath, overwrite)` 复制逻辑条目。文件内容通过源 root 解密并由目标 root 重新加密，支持不同密码和算法配置的两个已打开 root；目录递归复制，覆盖时合并目录并原子替换同名文件。该操作不创建持久化 task，Dart 在 worker isolate 中执行。

Transfer V3 的 import 同步 ABI 和 callback ABI 均显式携带 `overwrite` 整数位。Dart 默认传 `0`；只有 UI 完成冲突询问并选择替换后才传 `1`。

当前 Dart 已绑定 V3 import/export、unfinished marker、convert recover/convert root。尚未绑定：

- 增量加密 C ABI。`NativeLib` 仅保留返回 `success:false` 的 unsupported JSON stub，避免设计草稿代码导致 Dart 编译失败。

## 生命周期设计

### Root 生命周期

1. Flutter 调用 `sec_root_open`。
2. Go 加载 KDF 参数并派生候选 key。
3. sec 层验证 password verifier；错误密码、缺失 verifier 或损坏配置均在此失败。
4. 认证成功后 Go 才创建 `ISecRoot` 并放入 `RootStore`。
5. Go 返回 `root_id`。
6. Flutter 后续所有文件/目录操作都带 `rootID`。
7. Flutter 调用 `sec_root_close`。
8. Go 关闭 root 并从 `RootStore` 删除。

FFI 不自行实现密码算法，也不能通过“列目录是否为空”判断密码。错误密码不得分配 `root_id` 或改变 `RootStore`；密码认证格式见 [ENCRYPTION.md](ENCRYPTION.md)。

`sec_root_open` 的 `optionsJSON` 当前支持：

```json
{
  "configFileName": "_cryption.json",
  "ignoreMatcher": {
    "before": ["raw-store-name"],
    "beforePatterns": ["*.tmp"],
    "after": ["view-name"],
    "afterPatterns": [".*", "*.tmp"]
  }
}
```

`before`/`beforePatterns` 在文件名解密前匹配 store name，`after`/`afterPatterns` 在文件名解密后匹配 view name。即使传入自定义 matcher，FFI 仍会保留 config 文件忽略逻辑。

`sec_create_root_config` 的 `optionsJSON` 额外支持 `passwordChangeable`。为 `true` 时，sec 创建随机内容密钥，并以密码派生的包装密钥写入版本化密钥包装记录；Flutter 创建界面默认传 `true`。`sec_root_change_password(rootPath, oldPassword, newPassword)` 只接受这种新格式，成功后调用方必须关闭旧 `root_id` 会话并用新密码重新打开。旧格式返回明确的不支持错误，不能通过 FFI 伪造改密。

### File 生命周期

1. Flutter 调用 `sec_file_open(rootID, path, mode)`。
2. Go 通过 root 打开 `ISecFile`。
3. Go 把 file 放入 `FileStore`。
4. Go 返回 `file_id`。
5. Flutter 用 `fileID` 读、写、seek、truncate。
6. Flutter 调用 `sec_file_close`。
7. Go 关闭 file 并从 `FileStore` 删除。

### Transfer V3 生命周期

Transfer V3 的 C ABI 当前固定使用 `full` durability。Go 公共 request 和 CLI 虽支持 per-operation `none/data/full`，FFI 不提供 process-wide setter，避免多个 Dart isolate 或并发 operation 相互覆盖全局落盘策略。若后续需要开放，应新增每次调用显式携带 options 的 ABI，并保留现有函数的 `full` 默认语义。

import/export 不再创建 `ITask`，也不返回 `task_id`。

convert 内容校验失败时，unfinished marker 的 JSON 包含结构化 `verification`：目录/文件期望与实际数量、missing/unexpected/digest mismatch 总数、每类最多 16 条排序样本和 `truncated`。FFI 不根据这些路径自动执行删除或 rename，只负责原样返回给 Dart 展示和人工处理。

1. Flutter 调用 V3 transfer 函数，Go 注册一次性 runtime cancel handle。
2. Go 等待该 root 的跨进程 OS lock；等待期间可通过 `sec_transfer_v3_cancel` 取消。
3. 获得锁后在 root 的 `.transfer_v3/active/` 写 operation marker。
4. Go 同步执行 import/export。
5. 成功后清理 marker 并释放锁。
6. 失败或进程中断时 marker 保留，OS 在进程退出时自动释放锁。
7. 下次打开 root 后，Flutter/CLI 可查询 marker，并提示用户全量重跑或清理 marker。

锁文件只作为 OS advisory lock 的稳定 inode，不保存 task 状态。等待者在获得锁前取消时不会创建 marker；Go FFI 测试覆盖这一行为。

旧的 `sec_*_async`、`sec_*_async_with_callback` 和 `action_task_*` 已删除，不保留 v1/v2 ABI 兼容。

## 响应格式

所有 FFI 函数返回 JSON 字符串。

成功：

```json
{
  "success": true,
  "data": {}
}
```

失败：

```json
{
  "success": false,
  "error": "message"
}
```

约束：

- Go 侧不应 panic 到 FFI 边界外。
- Dart 侧统一检查 `success`。
- 二进制字段统一用 base64 字符串。

## 内存约定

- Go 返回给 Dart 的字符串使用 `C.CString` 分配。
- Dart 必须调用 `sec_free_string` 释放。
- Dart 传给 Go 的字符串由 Dart 侧分配和释放。
- 敏感数据清零不能只依赖 GC。

当前缺口：

- `ClearSecureMemory` 已通过 `sec_clear_secure_memory` 和 Dart `NativeLib.clearSecureBytes/clearSecureMemory` 暴露；字符串清理属于 best-effort，只能清理 UTF-8 byte copy，不能保证 Dart `String` 对象原地清零。
- Go sec root close 已关闭 name cryptor 并销毁 KDF keyInfo，失败打开与 shallow clone 也有独立生命周期测试；但标准库 cipher 内部展开状态和 Dart `String` 仍不能声称可完全清零。

## 注册与自举

Go 后端依赖 `init()` 注册算法和 transfer 实现。

CLI 和 FFI 当前通过 blank import 完成注册：

- 算法实现
- `sec_transfer/v3`

FFI shared library 也必须完成同样的自举，否则 standalone shared library 可能出现：

- 算法注册表为空，打开 root 失败。
- `sec_transfer.GetDefaultTransferV3()` 在未注册实现时返回 unavailable manager，操作返回 `ErrTransferV3NotRegistered`，不会 panic。

设计要求：

- `native/ffi_sec_fs` 的构建入口必须注册完整算法集；当前已使用 `crypto_all`。
- `native/ffi_sec_fs` 的构建入口必须 blank import `sec_transfer/v3`。
- 自举依赖应集中放在 FFI 入口文件或专门的 `init.go` 中。
- Windows C ABI 产物规范名为 `ffi_sec_fs.dll`；构建脚本、CMake bundle 与 Dart loader 必须一致。Dart 只从 `safe_disk.exe` 同目录绝对加载，禁止回退到 `PATH`，避免误用旧 ABI 动态库。

## Transfer 设计

Transfer 是 FFI 当前最重要的未闭环能力。

底层设计以 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md) 为准。V3 中 FFI 层只负责把 import/export 的运行时 progress、unfinished operation 查询、convert phase recovery 暴露给 Flutter，不应重新实现批量复制、恢复或回滚逻辑。

目标能力：

- Flutter 可以导入普通目录到加密 root。
- Flutter 可以导出加密目录到普通文件系统。
- unfinished marker 通过 `entry_kind` 明确区分文件与目录，UI 不从路径或存在性猜测重跑类型。
- 支持文件和目录。
- 支持运行时 callback 进度回调。
- 支持查询未完成 import/export operation marker。
- 支持查询和恢复未完成 convert phase marker。
- import/export 不提供断点续传；中断后由上层提示全量重跑或清理 marker。

当前状态：

- Go C 导出函数已存在。
- Go 适配层已调用 `sec_transfer.GetDefaultTransferV3()`。
- Dart 绑定已接入 V3 函数和运行时 progress callback；耗时 C 调用在 worker isolate 中执行，主 isolate 只接收进度和最终结果。
- Flutter `DirectoryService` 已接通 V3 目录 import/export；有无 progress listener 都不会在调用 isolate 上同步执行传输。
- Flutter `HomePage` 验证 root 后会查询 unfinished import/export marker，并提示用户清理或跳过。
- FFI shared library 已注册 V3；`sec_transfer/v2` 活跃源码和旧 task 公共接口已删除。
- Dart FFI 集成测试已覆盖真实 shared library 下的 root create/open、quick read/write、文件/目录原子重命名、跨密码加密 root 复制、copy/import 目标冲突保护、V3 import/export、runtime progress callback、调用 isolate 非阻塞、listener 异常、native 失败 marker 清理，以及 `aes-gcm-name` 文件名/目录名加密。
- Go FFI 边界测试覆盖 quick write 与 V3 import 的 `../` 路径逃逸拒绝，并断言 root 外不产生文件。
- Go FFI 与 Dart FFI 集成测试已覆盖 CLI 创建 root 后由 FFI/Dart 写读并由 CLI export、FFI/Dart 创建 root 后由 CLI import/export 使用。
- 运行时 progress callback 通过 `sec_transfer_v3_*_with_callback` C ABI 传递 V3 `ProgressEvent`；Dart worker isolate 在同步 C 调用期间持有 `NativeCallable`，通过 `SendPort` 把事件转发给调用 isolate。
- Dart progress listener 抛错时不会提前销毁 native callback；worker 会先等 native 调用结束，再把 listener 错误交还调用方。
- FFI 提供一次性 runtime operation handle；`sec_transfer_v3_cancel` 只触发进程内 `context.CancelFunc`，操作结束立即移除，不保存 task 或进度。
- Flutter 目录导出 UI 已接真实取消；handle 尚未 active 时拒绝关闭进度框，取消成功后保留 unfinished marker 供下次打开时清理或全量重跑。
- Flutter 已提供独立文件/目录导入入口：顶层同名冲突可取消、保留两者或显式替换；目录替换采用合并并替换同名文件语义，同时支持进度和真实取消。
- Flutter 打开 root 时可选择 unfinished operation 全量重跑；Dart service 先校验 `type/entry_kind/src/dst`，再清理旧 marker 并调用对应文件/目录 import/export，页面显示运行时进度并支持取消。
- `HomePage` 已支持 service 与文件/目录选择器注入，整页 widget 测试覆盖未认证 root 不提前列目录、错误密码后重试、文件 import 默认拒绝覆盖、文件显式替换、目录合并确认和 transfer 失败后关闭进度框。
- 文件导入使用选择器返回的本地绝对路径进入 Transfer V3，不再在 Dart 主 isolate 中一次性读取完整文件字节。
- 空目录 FFI 响应固定为 JSON `[]`，Dart 绑定同时兼容历史 `null`；真实 FFI 测试覆盖加密目录名下的空目录往返。

## 增量加密接口

`docs/design/FFI_INCREMENTAL_ENCRYPTION.md` 当前应视为设计文档，不是当前活跃实现证明。

当前情况：

- `exports.go` 没有 `Incremental*` 或 `Stream*` 导出。
- `bindings.dart` 没有增量加密绑定。
- `crypto_data` 中存在 `CryptModeIncremental` 枚举，但当前生产算法主要报告普通模式。

处理原则：

- 在 Transfer 和基础文件浏览未闭环前，不把增量加密作为 FFI 主线。
- 增量加密文档保留为设计输入。
- 后续如要实现，应单独立项，并补充格式兼容、随机访问、安全校验和测试计划。

## 当前问题清单

| 问题 | 影响 | 建议优先级 |
|------|------|------------|
| 增量加密 FFI 仅有设计文档 | 文档容易误导进度判断 | P2 |

## 验收标准

### 基础 FFI

- 能创建 root config。
- 空 root 和已有 import 内容的 root 都会拒绝错误密码。
- 错误密码失败时不向 `RootStore` 注册对象。
- 能打开 root。
- 能写入文件。
- 能读取文件。
- 能列目录。
- 能关闭 root。

### Transfer FFI

- 能导入单文件。
- 能导出单文件。
- 能导入目录。
- 能导出目录。
- callback 能收到运行时进度和完成事件。
- Dart `DirectoryService` 调用有无 progress listener 都不会阻塞调用 isolate。
- Dart listener 抛错不会使 native callback 在传输结束前失效。
- runtime cancel 能停止扫描或文件复制，清理临时文件、不提交部分目标，并保留 unfinished marker。
- runtime cancel 能终止 root lock 等待；未获得锁的 operation 不写 marker、不提交目标。
- import/export 中断后能查询 unfinished operation marker。
- convert 中断后能查询 phase marker 和恢复建议。
- import/export 不要求断点续传，不暴露 v2 task resume/rollback。

### Flutter service

- `DirectoryService.exportDirectory` 不再抛 `UnimplementedError`。
- `DirectoryService.importDirectory` 不再抛 `UnimplementedError`。
- `CryptoService` 与 `DirectoryService` 不直接触碰 C 指针。
- Dart FFI 集成测试能通过 `SAFE_DISK_FFI_LIBRARY=/path/to/libffi_sec_fs.so flutter test test/native_ffi_integration_test.dart` 运行。

### 文档

- 所有 FFI 完成度描述必须区分：
  - 已实现
  - 已导出但未绑定
  - 已设计但未实现
  - 已绑定但未接 UI

## 不做的事

- 不在 FFI 层保存密码明文。
- 不让 Dart 持有 Go 指针。
- 不把内部 Go 接口直接暴露成大量 FFI 函数。
- 不在基础 transfer 闭环前扩展增量加密 FFI。
