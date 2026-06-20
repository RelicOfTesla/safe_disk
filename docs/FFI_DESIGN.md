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

- Root：`sec_root_open`、`sec_root_close`、`sec_create_root_config`
- File：`sec_file_open`、`sec_file_read`、`sec_file_write`、`sec_file_seek`、`sec_file_truncate`、`sec_file_close`
- Root 级文件操作：`sec_file_delete`、`sec_file_exists`、`sec_mkdir_all`、`sec_read_dir`
- Quick 操作：`sec_quick_read_file`、`sec_quick_write_file`
- Transfer V3：`sec_transfer_v3_import_file`、`sec_transfer_v3_import_directory`、`sec_transfer_v3_export_file`、`sec_transfer_v3_export_directory`
- Transfer V3 状态：`sec_transfer_v3_list_unfinished`、`sec_transfer_v3_clean_unfinished`
- Convert V3：`sec_transfer_v3_convert_root`、`sec_transfer_v3_recover_convert`
- 旧 Transfer 兼容导出：`sec_export_directory_async`、`sec_import_directory_async`、`sec_export_file_async`、`sec_import_file_async`
- 旧 Task 兼容导出：`action_task_get_progress`、`action_task_close`，已废弃，返回 V3 废弃说明
- 内存释放：`sec_free_string`

### 当前 Dart 绑定

当前 `bindings.dart` 只绑定了：

- Root
- File
- Root 级目录/文件操作
- Quick 操作
- `sec_free_string`

当前 Dart 已绑定 V3 import/export、unfinished marker、convert recover/convert root。尚未绑定：

- 运行时 progress callback
- 增量加密接口
- `ClearSecureMemory`

## 生命周期设计

### Root 生命周期

1. Flutter 调用 `sec_root_open`。
2. Go 打开 `ISecRoot`。
3. Go 把 root 放入 `RootStore`。
4. Go 返回 `root_id`。
5. Flutter 后续所有文件/目录操作都带 `rootID`。
6. Flutter 调用 `sec_root_close`。
7. Go 关闭 root 并从 `RootStore` 删除。

### File 生命周期

1. Flutter 调用 `sec_file_open(rootID, path, mode)`。
2. Go 通过 root 打开 `ISecFile`。
3. Go 把 file 放入 `FileStore`。
4. Go 返回 `file_id`。
5. Flutter 用 `fileID` 读、写、seek、truncate。
6. Flutter 调用 `sec_file_close`。
7. Go 关闭 file 并从 `FileStore` 删除。

### Transfer V3 生命周期

import/export 不再创建 `ITask`，也不返回 `task_id`。

1. Flutter 调用 V3 transfer 函数。
2. Go 侧在 root 的 `.transfer_v3/active/` 写 operation marker。
3. Go 同步执行 import/export。
4. 成功后清理 marker。
5. 失败或进程中断时 marker 保留。
6. 下次打开 root 后，Flutter/CLI 可查询 marker，并提示用户全量重跑或清理 marker。

旧的 `sec_*_async` 和 `action_task_*` 导出仅作为 ABI 兼容壳保留，不再代表当前设计。

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
- Go 后端并非所有敏感对象 close 时都执行清零。

## 注册与自举

Go 后端依赖 `init()` 注册算法和 transfer 实现。

CLI 和 FFI 当前通过 blank import 完成注册：

- 算法实现
- `sec_transfer/v3`

FFI shared library 也必须完成同样的自举，否则 standalone shared library 可能出现：

- 算法注册表为空，打开 root 失败。
- `sec_transfer.GetDefaultTransferV3()` 仍指向默认 panic 实现。

设计要求：

- `native/ffi_sec_fs` 的构建入口必须注册完整算法集；当前已使用 `crypto_all`。
- `native/ffi_sec_fs` 的构建入口必须 blank import `sec_transfer/v3`。
- 自举依赖应集中放在 FFI 入口文件或专门的 `init.go` 中。

## Transfer 设计

Transfer 是 FFI 当前最重要的未闭环能力。

底层设计以 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md) 为准。V3 中 FFI 层只负责把 import/export 的运行时 progress、unfinished operation 查询、convert phase recovery 暴露给 Flutter，不应重新实现批量复制、恢复或回滚逻辑。

目标能力：

- Flutter 可以导入普通目录到加密 root。
- Flutter 可以导出加密目录到普通文件系统。
- 支持文件和目录。
- 支持运行时 callback 进度回调。
- 支持查询未完成 import/export operation marker。
- 支持查询和恢复未完成 convert phase marker。
- import/export 不提供断点续传；中断后由上层提示全量重跑或清理 marker。

当前状态：

- Go C 导出函数已存在。
- Go 适配层已调用 `sec_transfer.GetDefaultTransferV3()`。
- Dart 绑定已接入 V3 函数。
- Flutter `DirectoryService` 已接通 V3 目录 import/export。
- FFI shared library 已注册 V3；旧 v2 task 模型不再用于 FFI/Dart 主路径。
- Dart FFI 集成测试已覆盖真实 shared library 下的 root create/open、quick read/write、V3 import/export、unfinished marker，以及 `aes-gcm-name` 文件名/目录名加密。
- Go FFI 与 Dart FFI 集成测试已覆盖 CLI 创建 root 后由 FFI/Dart 写读并由 CLI export、FFI/Dart 创建 root 后由 CLI import/export 使用。
- 运行时 progress callback 仍待补齐，当前 V3 Dart 调用表现为同步阻塞。

收口顺序：

1. 补齐运行时 progress callback。
2. 接 UI 层进度展示。
3. 接 UI 层 unfinished operation 提示。
4. 补充 Dart/Flutter 集成测试。

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
| Transfer V3 缺少 Dart 运行时 progress callback | UI 暂时只能同步等待或自建 loading | P1 |
| UI 未处理 unfinished marker | 中断后还不能在界面提示重跑/清理 | P1 |
| `ignoreMatcher` 未解析 | 自定义忽略规则不可用 | P2 |
| 增量加密 FFI 仅有设计文档 | 文档容易误导进度判断 | P2 |
| Dart runtime progress callback 仍未接 UI | UI 暂时只能同步等待或自建 loading | P1 |

## 验收标准

### 基础 FFI

- 能创建 root config。
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
- callback 能收到运行时进度和完成事件。当前未完成。
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
