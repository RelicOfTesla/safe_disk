# Safe Disk 代码审计状态

> 以当前可执行代码为准，不以历史 TODO 或路线图为准。

最后审计时间：2026-06-20

## 总结

- Flutter 侧主 UI 仍是占位壳，不应视为已完成。
- Go 侧 `sec_fs` 后端是真实存在的，且实现量较大。
- FFI 层存在，但对外暴露的能力比文档描述更窄。
- Flutter 侧目录导入/导出仍是未完成状态。
- 增量加密 FFI 有设计文档，但不在当前活跃导出/绑定面上。

## 代码证据

### Flutter

- `lib/main.dart` 启动的是 `HomePage`。
- `lib/pages/home_page.dart` 仍是占位页，渲染的是 `UI under reconstruction`。
- `lib/services/directory_service.dart` 的目录导出/导入会直接抛出 `UnimplementedError`。
- `lib/services/file_service.dart` 和 `lib/services/crypto_service.dart` 只提供底层封装，不是完整的浏览器/编辑器界面。

### FFI

- `native/ffi_sec_fs/exports.go` 导出了根目录、文件、目录、快速操作和转移回调。
- `lib/native/bindings.dart` 只绑定了当前已导出的符号。
- `native/ffi_sec_fs/ffi.go` 在选项解析上仍有 TODO，包括 `ignoreMatcher`。
- `native/ffi_sec_fs/stores.go` 提供了 root、file、task 的 ID 存储。

### Go 后端

- `native/sec_fs` 里存在真实后端实现，包括加密注册表、根目录处理、文件访问和 transfer 代码。
- `native/sec_fs/sec_transfer/v2` 是真实实现区域，但仍需要单独核实工厂接线和各公开操作的实际可用性。
- `native/sec_fs/sec_transfer/interface.go` 里默认 transfer manager 工厂仍然是 `panic("not implemented")`。

## 当前不宜再声称已完成的内容

- 安全记事本已完成。
- 图片浏览器已完成。
- 目录导入/导出已通过 Flutter 全链路接通。
- 增量加密 FFI 已发布并可从 Flutter 调用。
- 整个 UI 已完成。

## 使用规则

当某个文档写 `已完成` 时，至少要检查以下三项：

1. `lib/` 或 `native/` 中是否真的有实现
2. 是否存在匹配的公开入口
3. 是否有测试或可运行验证路径

如果三项中有任意一项缺失，就应标记为 `部分完成` 或 `仅设计/规划`。
