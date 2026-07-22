# 跨 root 目录剪切/移动设计

## 状态

设计阶段。当前跨 root 文件剪切可执行 `copy -> delete`；目录剪切被 `SecureEntryMoveService` 明确拒绝，原因是现有 sec/FFI 只有 `DeleteFile`，没有可安全递归删除目录的公开原语。

## 目标与非目标

目标：应用内剪贴板把目录从一个已解锁 root 移动到另一个已解锁 root。目标目录完整复制成功后，才删除源目录；源删除失败时两端都保留并显示部分完成。

非目标：

- 不接入系统文件剪贴板或拖放。
- 不在移动中持久化逐项进度或支持断点续跑。
- 不支持把目录移动到自身、其后代或未打开 root。
- 不在本任务中加入隐式覆盖；冲突仍复用现有 UI 决策。

## 当前事实

- `sec_copy_entry` 可跨 root 递归复制并在目标 root 重新加密。
- `CryptoService.copyBySession` 已封装该调用。
- `sec_file_delete` 对应 `ISecRoot.DeleteFile`，仅适用于文件；不能用于目录删除。
- `SecureEntryMoveService` 对跨 root 目录抛出 `SecureEntryMoveDirectoryUnsupported`。

## 删除原语

新增 sec 层接口 `DeleteDirectoryTree(relativePath)`，并通过 FFI 暴露 `sec_directory_delete_tree(rootID, path)`。接口要求：

1. 仅接受规范化相对 view path；空路径、`.`、绝对路径、URI、UNC 和 root 逃逸失败关闭。
2. 目录必须存在且不是 root 本身；文件路径返回类型错误。
3. 名称加密 root 通过现有 view-to-store 路径转换处理每一级目录，不把明文路径传给底层 `os.RemoveAll`。
4. 删除过程中不跟随符号链接；发现不允许的链接或路径类型时失败并返回稳定错误码。
5. 删除失败返回稳定错误码和可用于详细诊断的已脱敏原因，不把 store 绝对路径传到 UI。
6. 不承诺跨文件系统原子性。调用方只能在目标 `sec_copy_entry` 成功返回后调用；删除失败视为部分完成。

## Dart/UI 协议

1. 同 root 且无替换仍使用原子 rename。
2. 其他目录移动使用 `copyBySession` 后的 `deleteDirectoryBySession`。
3. 源删除抛错时使用既有 `SecureEntryMovePartialFailure`，队列不移除该条目，结果面板提示用户核验目标后手动处理源目录。
4. 目标复制失败时不得触碰源目录。
5. 冲突、取消和批量队列沿用现有单项/全部策略；目录替换语义必须由 `sec_copy_entry` 的当前合并/替换行为明确覆盖。

## 测试门槛

- sec：空目录、嵌套目录、加密名称、非法/root 路径、文件类型、损坏/链接和删除失败。
- FFI：真实 root 中跨 root 目录 copy 后删除源，目标完整、源不可见；删除失败两端保留。
- Dart：同 root rename、跨 root 成功、目标 copy 失败不删源、源删失败部分完成。
- UI：目录剪切不再显示“不支持”；批量结果、冲突取消和失败队列保留均有 widget 回归。
- 桌面：Linux、Windows、macOS 验证目录树、取消/冲突和错误反馈；Windows 另验占用目录行为。
