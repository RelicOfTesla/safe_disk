# Safe Disk 代码审计状态

> 以当前可执行代码为准，不以历史 TODO 或路线图为准。

最后审计时间：2026-06-20

## 总结

- Flutter 侧主 UI 仍是占位壳，不应视为已完成。
- Go 侧 `sec_fs` 后端是真实存在的，且实现量较大。
- FFI 层存在，已暴露 Transfer V3 import/export、unfinished marker 和 convert 基础接口。
- Flutter service 层目录导入/导出已接 V3；主 UI 仍未完整接通这些能力。
- 增量加密 FFI 有设计文档，但不在当前活跃导出/绑定面上。
- 当前全量 `dart analyze` 失败，主要来自还原后的 UI/旧 service API 调用和增量加密设计代码仍引用未实现 FFI；不能据此声称 Flutter UI 已恢复可发布状态。
- FFI 相关目标文件分析可通过，真实 Dart FFI 集成测试可验证 CLI-created root 由 Dart 写读、Dart/FFI-created root 由 CLI import/export 操作。

## 代码证据

### Flutter

- `lib/main.dart` 启动的是 `HomePage`。
- `lib/pages/home_page.dart` 已从占位页还原为较完整 UI，但当前仍调用多处旧 service API，导致全量 `dart analyze` 不通过。
- `lib/services/directory_service.dart` 的目录导出/导入已调用 `NativeLib` 的 Transfer V3 FFI 封装。
- `lib/services/file_service.dart` 和 `lib/services/crypto_service.dart` 只提供底层封装，不是完整的浏览器/编辑器界面。

### FFI

- `native/ffi_sec_fs/exports.go` 导出了根目录、文件、目录、快速操作、Transfer V3 和旧 transfer 兼容壳。
- `lib/native/bindings.dart` 已绑定当前 Dart service 使用的 V3 transfer 符号。
- `lib/native/bindings.dart` 已绑定 `sec_clear_secure_memory`；Dart 字符串清理仅能清理派生 byte copy，不能证明 VM 内部 String 已原地清零。
- `native/ffi_sec_fs/ffi.go` 在选项解析上仍有 TODO，包括 `ignoreMatcher`。
- `native/ffi_sec_fs/stores.go` 提供 root、file 的 ID 存储；V3 transfer 不再保存 task 对象。

### Go 后端

- `native/sec_fs` 里存在真实后端实现，包括加密注册表、根目录处理、文件访问和 transfer 代码。
- `native/sec_fs/sec_transfer/v3` 是当前 CLI/FFI/Dart 主路径使用的 transfer 实现。
- `native/sec_fs/sec_transfer/interface.go` 的旧默认 transfer manager 工厂仍然是 `panic("not implemented")`；V3 使用 `GetDefaultTransferV3`。

## 当前不宜再声称已完成的内容

- 安全记事本已完成。
- 图片浏览器已完成。
- 目录导入/导出已通过 Flutter UI 全链路接通。
- 增量加密 FFI 已发布并可从 Flutter 调用。
- 整个 UI 已完成。

## 使用规则

当某个文档写 `已完成` 时，至少要检查以下三项：

1. `lib/` 或 `native/` 中是否真的有实现
2. 是否存在匹配的公开入口
3. 是否有测试或可运行验证路径

如果三项中有任意一项缺失，就应标记为 `部分完成` 或 `仅设计/规划`。
