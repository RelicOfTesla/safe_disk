# Safe Disk 代码审计状态

> 以当前可执行代码为准，不以历史 TODO 或路线图为准。

最后审计时间：2026-07-23

## 总结

- Flutter 侧主 UI 已从占位壳恢复，并已重新接入 rootID FFI 基础读写路径；仍不应视为完整可发布 UI。
- Go 侧 `sec_fs` 后端是真实存在的，且实现量较大。
- sec root 已在构造 root 前执行 KDF 无关的 password verifier 认证；错误密码不再表现为可打开的空目录。旧的无 verifier 配置失败关闭，需要重建并重新导入。
- Go 默认 root helper 固定为 `aes-ctr + none + argon2id`；Flutter 主界面新建 root 显式使用 `aes-ctr + aes-gcm-name`。所有 KDF 创建均使用每 root 随机 salt；打开时严格按配置 factory，不再依赖 registry map 的随机首项或缺字段猜测。
- FFI 层存在，已暴露 Transfer V3 import/export、runtime progress callback、unfinished marker 和 convert 基础接口。
- Flutter service 层目录导入/导出已接 V3，并通过 worker isolate 执行耗时 FFI；主 UI 已接基础 rootID 读写、目录导入/导出进度、真实 runtime cancel 和 unfinished marker 感知。
- 增量加密 FFI 有历史设计文档，但不在当前活跃导出/绑定面上；无 Dart 包装或 `NativeLib` 占位桩，不能从 Flutter 调用。
- 当前全量 `dart analyze` 为 0 issue。
- FFI 相关目标文件分析可通过，真实 Dart FFI 集成测试可验证 CLI-created root 由 Dart 写读、Dart/FFI-created root 由 CLI import/export 操作，并验证 V3 runtime progress callback、调用 isolate 非阻塞、listener 异常和失败 marker 清理。

## 代码证据

### Flutter

- `lib/main.dart` 启动的是 `HomePage`。
- `lib/pages/home_page.dart` 已从占位页还原为较完整 UI，并将创建、解锁、列表、文件/目录导入、目录导出、删除、安全记事本保存和 unfinished marker 清理提示的基础路径接到当前 rootID FFI 模型。
- `lib/widgets/home_shell.dart` 已承接主界面视觉组合；`HomePage` 仍负责 root 和 transfer 工作流编排，尚未完成状态管理拆分。
- 主界面列表和网格均已接鼠标 secondary click。右键菜单与触屏操作面板共用类型化动作定义：文本编辑、原子重命名、应用内复制/粘贴、明文导出确认、文件删除、复制明文名称/逻辑路径、属性和刷新均有整页 widget 执行链测试。`sec_copy_entry` 通过逻辑路径在两个已打开 root 间解密/重加密，目录递归复制；冲突可取消、保留两者或显式替换。剪切/移动、批量复制和系统文件管理器互通仍未开放。
- 安全记事本已拆为 controller、状态/查找/编辑区和页面协调层。单元/widget 测试覆盖首步撤销、查找替换、只读切换、定时保存及保存失败关闭保护；真实 FFI 测试覆盖加密中文路径下保存、关闭 root、重新认证读取。
- `lib/services/directory_service.dart` 的目录导出/导入已调用 `NativeLib` 的 Transfer V3 FFI 封装；有无 progress listener 都走后台 worker isolate，且完成计数不再保存在 service 共享字段中。
- `lib/services/file_service.dart` 和 `lib/services/crypto_service.dart` 提供 rootID 底层封装，并额外提供 UI 旧绝对虚拟路径到 root 相对路径的兼容适配。

### FFI

- `native/ffi_sec_fs/exports.go` 导出了根目录、文件、目录、快速操作和 Transfer V3；旧 transfer/task ABI 已删除。
- `lib/native/bindings.dart` 只绑定当前 Dart service 使用的 V3 transfer、operation callback 和 cancel 符号。
- `lib/native/bindings.dart` 已绑定 `sec_clear_secure_memory`；Dart 字符串清理仅能清理派生 byte copy，不能证明 VM 内部 String 已原地清零。
- sec root close 已通过强制 `IKeyInfo.Destroy` 和 `INameCryptorContext.Close` 清零可控 key slice；打开失败与 shallow clone 使用独立所有权。该结论不覆盖 Go cipher 内部不可寻址副本。
- `native/ffi_sec_fs/ffi.go` 已解析 `configFileName` 和 `ignoreMatcher` 打开选项；`ignoreMatcher` 支持 before/after 名称与 glob pattern。
- `native/ffi_sec_fs/stores.go` 提供 root、file 的 ID 存储；V3 transfer 不再保存 task 对象。
- `lib/native/native_lib.dart` 在 worker isolate 内执行同步 C ABI 并持有 callback，通过 isolate 消息把进度和结果送回调用方；这不引入持久化 task。
- Transfer V3 的 Go `Manager` 和公共 operation request 已实现 `none/data/full` durability policy，默认 `full`；CLI 已提供请求级 `--durability`，FFI 有意固定 `full` 且不使用全局 setter。Linux/Unix 会同步临时文件与目录提交点，Windows 的目录 metadata flush 仍是明确的平台缺口。
- `ISecFile` 基础接口已包含 `Sync()`，`secRoot`、`PlainFS` 和测试 mock 由编译器统一校验；Transfer V3 不再运行时猜测文件是否支持落盘。
- `OpenFile().Stat()` 已使用打开的 store 文件句柄返回真实 mode/mtime，同时保留解密后 size；与 root/walker 的 metadata 视图一致，且 store 文件 rename 后仍可查询。
- 新建 sec root/config/密文与 Transfer marker/work/export 使用 `0700/0600`；Transfer 明确不传播源 owner/mode/mtime，已有 root 目录不被递归 chmod，PlainFS 保持通用明文语义。
- convert 校验会汇总并持久化结构化 verification report；内容不一致转为 `needs_attention/failed`，recovery 保留 source/work/backup，CLI 错误输出计数与样本。
- `native/ffi_sec_fs/runtime_operations.go` 只保存活动 operation 的 `context.CancelFunc`，结束即删除；sec V3 在扫描、复制和原子提交前检查取消。
- Transfer V3 目录 import/export 已改为计数遍与逐项执行遍，不保存整树路径；convert 校验使用双向逐项存在性、类型和摘要检查，报告每类只保存 16 条稳定样本。secure root walker 的待处理子目录栈仍没有硬上限，不能据此宣称端到端目录扫描内存完全有界。

### Go 后端

- `native/sec_fs` 里存在真实后端实现，包括加密注册表、根目录处理、文件访问和 transfer 代码。
- `native/sec_fs/password_verifier.go` 负责统一 password verifier；`OpenRootQuick` 在任何 walker、FFI handle 创建前认证密码。
- `native/sec_fs/crypto_all` 已注册当前全部数据、名称和 KDF 实现；其中 HKDF/RC4 虽已注册，但不代表适合作为普通用户密码/新数据的安全默认算法。
- `native/sec_fs/sec_transfer/v3` 是当前 CLI/FFI/Dart 主路径使用的 transfer 实现。
- `native/sec_fs/sec_root.go` 与 `plainfs.go` 会在 root 操作前校验规范化后的相对 view/store path；绝对路径、URI、UNC 和逃逸 root 的 `..` 会失败关闭，且 `none`/`aes-gcm-name`、PlainFS 与 FFI/Transfer 入口均有回归测试。该结论仅指词法 containment，不包含抗本地并发符号链接替换。
- `native/sec_fs/sec_transfer/v2` 与旧 task 公共接口已从活跃源码删除；受保护 `_archived` 不参与 Go 构建。
- V3 使用 `RegisterTransferV3Factory/GetDefaultTransferV3`；遗漏注册或 factory 返回 nil 时操作返回 `ErrTransferV3NotRegistered`，不 panic。

## 当前不宜再声称已完成的内容

- 安全记事本已完成。
- 图片浏览器已完成。
- 目录导入/导出 UI 已有可注入选择器的 `HomePage` 整页测试，覆盖未认证 root 不提前读取、错误/正确密码、文件 import 冲突取消/替换、目录保留两者/合并确认、导入异常恢复和 unfinished operation 全量重跑；marker 保存 overwrite 决策。这些证据只证明当前 transfer 交互闭环，不代表整个 UI 已完成。
- 增量加密 FFI 已发布并可从 Flutter 实际使用；当前没有活跃 Dart API 或原生导出。
- 整个 UI 已完成。

## 使用规则

活跃进度统一维护在 [TODO.md](TODO.md)、[TODO_REFACTOR.md](TODO_REFACTOR.md)、[ROADMAP.md](ROADMAP.md) 和 [FEATURES.md](FEATURES.md)。100% 项只进入 `docs/completed/`，不得同时保留在活跃清单。

当某个文档写 `已完成` 时，至少要检查以下三项：

1. `lib/` 或 `native/` 中是否真的有实现
2. 是否存在匹配的公开入口
3. 是否有测试或可运行验证路径

如果三项中有任意一项缺失，就应标记为 `部分完成` 或 `仅设计/规划`。
