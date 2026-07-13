# Safe Disk 已完成重构

> 只记录有当前构建/测试证据的 100% 重构。未完成项见 [../TODO_REFACTOR.md](../TODO_REFACTOR.md)。
>
> 最后审计：2026-07-13。

## Transfer 主线切换到 V3：100%

验收边界：

- 活跃 sec/CLI/FFI/Dart 不再依赖 V1/V2 Transfer task API。
- 旧 task、resume、rollback、逐文件进度持久化只保留在受保护 archive，不参与构建。
- 当前模型只保存 unfinished operation/convert phase marker。

自动化证据：

- Go workspace 四个 module 可共同编译和测试。
- `native/sec_fs/sec_transfer/v3_interface_test.go` 验证注册边界。
- `native/ffi_sec_fs/ffi_v3_test.go` 与 `test/native_ffi_integration_test.dart` 直接调用 V3 ABI。

## Transfer V3 移除整树路径/manifest 常驻：100%

验收边界：

- import/export 不再先构建全部文件和目录 slice。
- convert 不再构建两份 path-to-digest map。
- 精确 `TotalFiles` 通过独立计数遍保留，执行遍逐项复制。
- 本重构不声称 secure root walker 本身已有硬内存上限。

自动化证据：

- V3 真实目录、取消、加密隐藏名称和有界差异报告测试
- Go 完整测试、vet、race、Windows 交叉编译
- 重新构建 C shared library 后的真实 Dart FFI 集成测试

## sec_transfer 移入 sec_fs 边界：100%

验收边界：

- Transfer 接口和 V3 实现位于 `native/sec_fs/sec_transfer`。
- CLI 与 FFI 通过 sec_fs module 使用同一 V3 factory，不保留并行产品实现。

自动化证据：

- `go test ./sec_fs/... ./cli/... ./ffi_sec_fs/...` 覆盖共同依赖。
- CLI/FFI 双向 root 互通测试证明不是两套格式实现。

## 配置显式传递与算法完整注册：100%

验收边界：

- root 创建默认算法明确，打开严格按配置 factory。
- 产品入口使用 `crypto_all` 注册全部当前实现，不依赖 map 随机首项。

自动化证据：

- `native/sec_fs/crypto_all/init_test.go`
- `native/sec_fs/sec_root_password_test.go`
- CLI/FFI 不同算法 root 互通测试

## 相对 view/store 路径类型边界：100%

验收边界：

- sec API 使用 `RelativeViewPath`、`RelativeStorePath`、`FullStorePath` 区分路径语义。
- root 操作统一经过 containment 校验。
- 本项不包含并发符号链接替换防护。

自动化证据：

- `native/sec_fs/sec_fs_test.go`
- `native/sec_fs/sec_root_path_security_test.go`
- `native/sec_fs/sec_root_name_encryption_test.go`

## 删除 TransferResult/ActionTask 产品接口：100%

验收边界：

- 当前 import/export 返回同步 error，并通过 runtime callback 报告临时进度。
- FFI/Dart 不保存 Go task 对象，不提供 resume/rollback ABI。
- 运行时 cancel handle 操作结束即移除。

自动化证据：

- `native/ffi_sec_fs/ffi_v3_test.go` 的 callback/cancel/锁等待取消测试
- `test/native_ffi_integration_test.dart` 的 worker isolate、进度和取消测试
- 全局活跃源码检索不包含旧公开 task ABI

## 说明

- 旧文档曾把“TaskManager 封装化”列为完成；当前产品方向已经删除该模型，因此这里记录的是“删除并切断产品依赖”完成，不是 TaskManager 功能完成。
- walker 流式化、FFI ABI 单一来源、Flutter state 拆分和构建脚本收敛仍未完成，保留在活跃重构清单。
