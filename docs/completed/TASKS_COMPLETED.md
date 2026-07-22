# Safe Disk 已完成任务

> 本文件只接收进度 100% 的任务。每项必须写清验收边界和自动化实际功能测试；范围外能力不得由此推断为完成。
>
> 最后审计：2026-07-23。

## 2026-07 FFI 回归

### UI-59 真实 FFI 图片集成测试本地化壳：100%

验收边界：

- WebP 真实 FFI 集成用例以应用相同的中文 locale、`AppLocalizations.localizationsDelegates` 和 `supportedLocales` 构建 `SecureImageViewer`。
- 测试壳不再因缺少 `AppLocalizations` 在构建期触发空值断言。
- 本任务只修复测试环境的本地化依赖；不代表图片浏览器在三平台的视觉、codec 或读屏验收完成。

实际测试证据：

- 使用重新构建的 `/tmp/safe_disk_ffi_ui58/libffi_sec_fs.so` 执行 `flutter test --no-pub test/native_ffi_integration_test.dart -r compact`，12 项全部通过。
- `dart analyze` 通过。

## 2026-07 属性可访问性

### UI-55 属性对话框的属性值复制与选中：100%

验收边界：

- 属性值使用 `SelectableText`，支持平台原生的鼠标选择和键盘复制。
- 非空且明确安全的值提供带标签的复制按钮；反馈只说明已复制属性值，不回显内容。
- `PropertyValue.copyable: false` 没有复制入口，防止密码、密钥或未来敏感字段写入系统剪贴板。
- 本任务不替代 Windows、macOS 和 Linux 实机选择、快捷键与读屏验收。

实际测试证据：

- `test/property_overlay_test.dart` 覆盖安全值写入系统剪贴板、反馈文案、可选中文本和敏感字段无复制入口。
- `test/file_item_actions_test.dart`、`test/root_directory_properties_test.dart` 覆盖文件/root 属性入口。
- `flutter analyze --no-pub` 通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 236 通过、12 跳过。

## 2026-07 基础安全

### 新 root 安全默认值与随机 salt：100%

验收边界：

- 新 root 默认明确使用 `aes-ctr + none + argon2id`。
- 所有已注册 KDF 创建 root 时使用独立随机 salt。
- 打开 root 严格使用配置中的 factory，不猜测缺失或未知字段。

实际测试证据：

- `native/sec_fs/sec_root_password_test.go`
- `native/sec_fs/crypto_all/init_test.go`
- `test/native_ffi_integration_test.dart` 的 CLI/FFI root 独立 salt 与跨入口测试

### 错误密码拒绝与 password verifier：100%

验收边界：

- 创建 root 时写入版本化 verifier。
- 打开 root 在创建 walker/FFI root handle 前认证密码。
- 错误密码不注册 rootID；缺失或损坏 verifier 失败关闭。

实际测试证据：

- `native/sec_fs/sec_root_password_test.go`
- `native/ffi_sec_fs/ffi_v3_test.go::TestOpenRootFFIRejectsWrongPasswordWithoutRegisteringRoot`
- `test/native_ffi_integration_test.dart` 的“目录 import 后错误密码拒绝、正确密码仍可读”真实动态库测试

### root 路径词法 containment：100%

验收边界：

- sec root、PlainFS、FFI 和 Transfer 拒绝绝对路径、URI/UNC 与逃逸 root 的 `..`。
- 允许仍位于 root 内的规范化相对路径。
- 本任务不包含本地并发符号链接替换防护，该项仍在活跃清单。

实际测试证据：

- `native/sec_fs/sec_root_path_security_test.go`
- `native/ffi_sec_fs/ffi_v3_test.go::TestFFIRootAndTransferRejectPathTraversal`
- `native/sec_fs/sec_transfer/v3/v3_test.go::TestV3CleanUnfinishedRejectsPathTraversalOperationID`

### 私有创建权限基线：100%

验收边界：

- 新建 root/config/密文、marker、lock、work 和 export 使用 `0700/0600` 基线。
- 不递归修改已有 root 权限；Transfer 不伪装保留源 owner/mode/mtime。
- 本任务只验收 Unix 权限，不代表 Windows ACL 完成。

实际测试证据：

- `native/sec_fs/secure_modes_unix_test.go`
- `native/sec_fs/sec_transfer/v3/secure_modes_unix_test.go`

## 2026-07 Transfer/CLI/FFI

### Transfer V3 路径流式消费：100%

验收边界：

- 目录 import/export 使用“计数遍 + 逐项执行遍”，不保存整树文件/目录路径。
- convert verification 使用双向逐项检查，不保存 source/work 双 manifest。
- verification report 每类只保留 16 条稳定排序样本。
- 本任务只消除 Transfer 层整树集合；secure root walker 的待处理目录栈仍无硬上限，继续留在活跃任务。

实际测试证据：

- `native/sec_fs/sec_transfer/v3/v3_test.go` 的隐藏加密名称、计数阶段取消、流式有界报告测试
- Go 四 module 完整测试与 `go vet`
- Transfer/CLI/FFI race 测试
- Go 1.25 Windows 交叉编译
- `test/native_ffi_integration_test.dart` 使用本批重新构建动态库的真实互通测试

### Transfer V3 基础 import/export 闭环：100%

验收边界：

- 文件和目录 import/export 使用 temp/backup 原子替换。
- 支持空目录、Unicode/加密名称、隐藏用户条目、覆盖、取消和 operation marker。
- 失败后可感知并全量重跑/清理，不提供逐文件断点续传。
- 本任务不包含超大目录 walker 硬内存上限和 Windows 掉电保证。

实际测试证据：

- `native/sec_fs/sec_transfer/v3/v3_test.go`
- `native/cli/cmd/functional_test.go`
- `native/ffi_sec_fs/ffi_v3_test.go::TestTransferV3FFIRoundTrip`
- `test/native_ffi_integration_test.dart` 的真实动态库 import/export/progress 测试

### convert work/backup 切换与安全恢复：100%

验收边界：

- encrypt/decrypt convert 均全量复制到同级 work，校验后通过 rename 切换。
- backup 默认保留。
- phase marker 可处理安全 rename 窗口；矛盾状态返回 needs_attention。
- 内容差异持久化有界 verification report，不自动删除 source/work/backup。

实际测试证据：

- `native/sec_fs/sec_transfer/v3/convert_kill_test.go` 的真实子进程 kill checkpoint 测试
- `native/sec_fs/sec_transfer/v3/v3_test.go` 的 encrypt/decrypt、差异报告和 recovery 测试
- `native/cli/cmd/integration_test.go` 的 open-root convert recovery 测试

### CLI create/list/import/export 核心命令：100%

验收边界：

- create 默认仅接受不存在或空目录；非空目录必须显式 in-place。
- list/import/export 使用绝对 root/source/dest 语义。
- 支持安全密码来源、JSON Lines、durability、unfinished ask/rerun/clean/skip。
- 本任务不包含尚未实现的 info/passwd 和发行安装包。

实际测试证据：

- `native/cli/cmd/functional_test.go`
- `native/cli/cmd/integration_test.go`
- `native/ffi_sec_fs/ffi_v3_test.go::TestCLIAndFFICreateOpenCompatibility`
- `test/native_ffi_integration_test.dart` 的 CLI 创建 root 后 Dart 操作、FFI 创建 root 后 CLI 操作

### CLI/FFI/Dart 加密名称互通：100%

验收边界：

- `aes-gcm-name` 下文件名和目录名不以明文 backing name 落盘。
- sec、Transfer、CLI、FFI 和 Dart 能通过 view path 读写同一 root。

实际测试证据：

- `native/sec_fs/sec_dir_walker_name_encryption_external_test.go`
- `native/sec_fs/sec_transfer/v3/v3_test.go::TestV3ImportExportWithEncryptedNames`
- `native/cli/cmd/integration_test.go::TestCLIImportExportWithEncryptedNames`
- `native/ffi_sec_fs/ffi_v3_test.go::TestTransferV3FFIWithEncryptedNames`
- `test/native_ffi_integration_test.dart` 的 encrypted file/directory name 测试

### Transfer V3 未注册安全失败：100%

验收边界：

- 未注册 factory 或 factory 返回 nil 时，公共 API 返回 `ErrTransferV3NotRegistered`，不 panic。

实际测试证据：

- `native/sec_fs/sec_transfer/v3_interface_test.go`

## 2026-07 生命周期

### sec root 可控 key 生命周期：100%

验收边界：

- root close 清理可控 key slice 和 name cryptor。
- 打开失败与 shallow clone 使用独立所有权。
- 不声称能清理 Go cipher/VM 内部不可寻址副本。

实际测试证据：

- `native/sec_fs/sec_root_close_test.go`
- `native/sec_fs/sec_root_clone_lifecycle_test.go`
- `native/sec_fs/crypto_hkdf/key_info_lifecycle_test.go`
- `native/sec_fs/crypto_name/algorithm_impl/*/*close*_test.go`

## 迁移说明

- 历史 TODO 中“整个 UI”“安全记事本”“图片浏览器”“增量加密 FFI 已发布”等条目没有当前自动化实际功能证据，未迁入本文件。
- 某项进入本文件只证明其写明的验收边界，不代表所属大模块整体达到 100%。
