# 跨 root 目录剪切/移动设计

## 状态

已实现，待 Linux、Windows、macOS 桌面验收。跨 root 文件和目录剪切均执行 `copy -> delete`；目录删除使用受路径约束的 sec 原语，不再由 UI 直接尝试删除底层存储路径。

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
- `sec_file_delete` 对应 `ISecRoot.DeleteFile`，仍仅适用于文件。
- `sec_directory_delete_tree` 对应 `ISecRoot.DeleteDirectoryTree`，用于非 root 目录树。
- `SecureEntryMoveService` 同 root 且不替换时使用 rename；其余目录移动在目标复制成功后删除源目录树。

## 删除原语

新增 sec 层接口 `DeleteDirectoryTree(relativePath)`，并通过 FFI 暴露 `sec_directory_delete_tree(rootID, path)`。接口要求：

1. 仅接受规范化相对 view path；空路径、`.`、绝对路径、URI、UNC 和 root 逃逸失败关闭。
2. 目录必须存在且不是 root 本身；文件路径返回类型错误。
3. 名称加密 root 通过现有 view-to-store 路径转换处理每一级目录，不把明文路径传给底层 `os.RemoveAll`。
4. 删除前以 `Lstat` 和 `WalkDir` 验证目录树；发现符号链接或非目录路径即失败，遍历不跟随链接。
5. FFI 对无效路径、逃逸路径、非目录和不支持的链接分别返回稳定码 `1301`、`1302`、`1303`、`1304`。Dart UI 仅通过既有 `ErrorDiagnostics` 显示脱敏诊断，不根据底层错误文本分支。
6. 不承诺跨文件系统原子性。调用方只能在目标 `sec_copy_entry` 成功返回后调用；删除失败视为部分完成。

## Dart/UI 协议

1. 同 root 且无替换仍使用原子 rename。
2. 其他目录移动使用 `copyBySession` 后的 `deleteDirectoryBySession`。
3. 源删除抛错时使用既有 `SecureEntryMovePartialFailure`，队列不移除该条目；单项和批量路径均提示目标已复制、两端保留，要求用户确认后手动处理源项。
4. 目标复制失败时不得触碰源目录。
5. 冲突、取消和批量队列沿用现有单项/全部策略；目录替换语义必须由 `sec_copy_entry` 的当前合并/替换行为明确覆盖。

## 已有自动化证据

- sec：PlainFS 嵌套目录、空/root 路径、路径逃逸、链接拒绝，以及 AES-GCM 名称加密 root 的目录树删除。
- Go FFI：加密名称 root 跨 root 目录复制后删除源目录；root 删除被拒绝且返回 `1301`。
- Dart 真实 FFI：加密名称 root 的跨 root 文件和目录移动、源目录不可见、目标内容完整，以及空相对路径返回 `NativeErrorCode.invalidPath`。
- Dart 服务：同 root rename、文件与目录 `copy -> delete` 顺序、目标复制失败不删源、源文件/目录删除失败均报告部分完成。
- widget：跨 root 目录剪切经过冲突“保留两者”后复制并删除源目录；删除失败时剪贴板保留并显示部分完成提示。

## 待桌面验收

- Linux、Windows、macOS：在两个已解锁 root 间移动空目录、嵌套目录和中文名称目录；确认目标完整且源目录消失。
- Linux、Windows、macOS：冲突的保留两者、替换、取消和批量队列行为；确认取消或复制失败均不删源。
- Windows：打开或占用源目录中的文件后触发删除失败，确认两端保留、剪贴板可重试且提示准确。
