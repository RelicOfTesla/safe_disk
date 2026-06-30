# Safe Disk 代码审计状态

> 以当前可执行代码为准，不以历史 TODO 或路线图为准。

最后审计时间：2026-07-10

## 总结

- Flutter 侧主 UI 已从占位壳恢复，并已重新接入 rootID FFI 基础读写路径；仍不应视为完整可发布 UI。
- Go 侧 `sec_fs` 后端是真实存在的，且实现量较大。
- FFI 层存在，已暴露 Transfer V3 import/export、runtime progress callback、unfinished marker 和 convert 基础接口。
- Flutter service 层目录导入/导出已接 V3，并通过 worker isolate 执行耗时 FFI；主 UI 已接基础 rootID 读写、目录导出进度、真实 runtime cancel 和 unfinished marker 感知，但仍缺目录导入入口。
- 增量加密 FFI 有设计文档，但不在当前活跃导出/绑定面上；Dart `NativeLib` 只保留 unsupported JSON stub，防止设计草稿阻塞编译。
- 当前全量 `dart analyze` 已无 error/warning；仍有若干 info 级 lint。
- FFI 相关目标文件分析可通过，真实 Dart FFI 集成测试可验证 CLI-created root 由 Dart 写读、Dart/FFI-created root 由 CLI import/export 操作，并验证 V3 runtime progress callback、调用 isolate 非阻塞、listener 异常和失败 marker 清理。

## 代码证据

### Flutter

- `lib/main.dart` 启动的是 `HomePage`。
- `lib/pages/home_page.dart` 已从占位页还原为较完整 UI，并将创建、解锁、列表、导入、删除、安全记事本保存和 unfinished marker 清理提示的基础路径接到当前 rootID FFI 模型。
- `lib/services/directory_service.dart` 的目录导出/导入已调用 `NativeLib` 的 Transfer V3 FFI 封装；有无 progress listener 都走后台 worker isolate，且完成计数不再保存在 service 共享字段中。
- `lib/services/file_service.dart` 和 `lib/services/crypto_service.dart` 提供 rootID 底层封装，并额外提供 UI 旧绝对虚拟路径到 root 相对路径的兼容适配。

### FFI

- `native/ffi_sec_fs/exports.go` 导出了根目录、文件、目录、快速操作、Transfer V3 和旧 transfer 兼容壳。
- `lib/native/bindings.dart` 已绑定当前 Dart service 使用的 V3 transfer 符号和兼容 progress callback 符号。
- `lib/native/bindings.dart` 已绑定 `sec_clear_secure_memory`；Dart 字符串清理仅能清理派生 byte copy，不能证明 VM 内部 String 已原地清零。
- `native/ffi_sec_fs/ffi.go` 已解析 `configFileName` 和 `ignoreMatcher` 打开选项；`ignoreMatcher` 支持 before/after 名称与 glob pattern。
- `native/ffi_sec_fs/stores.go` 提供 root、file 的 ID 存储；V3 transfer 不再保存 task 对象。
- `lib/native/native_lib.dart` 在 worker isolate 内执行同步 C ABI 并持有 callback，通过 isolate 消息把进度和结果送回调用方；这不引入持久化 task。
- `native/ffi_sec_fs/runtime_operations.go` 只保存活动 operation 的 `context.CancelFunc`，结束即删除；sec V3 在扫描、复制和原子提交前检查取消。

### Go 后端

- `native/sec_fs` 里存在真实后端实现，包括加密注册表、根目录处理、文件访问和 transfer 代码。
- `native/sec_fs/sec_transfer/v3` 是当前 CLI/FFI/Dart 主路径使用的 transfer 实现。
- `native/sec_fs/sec_transfer/interface.go` 的旧默认 transfer manager 工厂仍然是 `panic("not implemented")`；V3 使用 `GetDefaultTransferV3`。

## 当前不宜再声称已完成的内容

- 安全记事本已完成。
- 图片浏览器已完成。
- 目录导入/导出已通过 Flutter UI 全链路接通。
- 增量加密 FFI 已发布并可从 Flutter 实际使用；当前仅有明确返回 unsupported 的 Dart stub。
- 整个 UI 已完成。

## 使用规则

当某个文档写 `已完成` 时，至少要检查以下三项：

1. `lib/` 或 `native/` 中是否真的有实现
2. 是否存在匹配的公开入口
3. 是否有测试或可运行验证路径

如果三项中有任意一项缺失，就应标记为 `部分完成` 或 `仅设计/规划`。
