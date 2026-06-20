# Safe Disk TODO List

> 本文档记录所有待办任务和已完成任务，按优先级分类
>
> 注意：这里包含历史完成记录，不等于当前活跃代码状态。请以 [CODE_AUDIT_STATUS.md](CODE_AUDIT_STATUS.md) 为准，尤其是 Flutter UI 和 FFI 相关条目。

**相关文档**：
- [FEATURES.md](FEATURES.md) - 功能规划
- [ROADMAP.md](ROADMAP.md) - 开发路线图

---

## 📊 优先级说明

- **P0（紧急）**：必须立即处理，影响安全或核心功能
- **P1（高）**：尽快处理，影响用户体验或代码质量
- **P2（中）**：后续改进，性能优化和功能增强
- **P3（低）**：锦上添花，平台扩展和可选功能

---

## 🔴 P0 - 紧急任务

### [CLI/Transfer V3] 补齐 create、安全密码输入和未完成操作感知

**优先级**：1（最高）

**背景**：CLI 当前只有 `version/list/import/export` 基础能力，缺少创建 root、安全密码输入、打开 root 时的 unfinished operation 检查。完整设计见 [CLI_DESIGN.md](CLI_DESIGN.md) 和 [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md)。

**底层前置任务**：
- [x] 重新设计 `sec_transfer` V3，不兼容 v1/v2 task/progress 持久化模型
- [x] import/export 增加 operation marker：开始写入，成功清理，中断后可被 open root 发现
- [x] import/export 只做运行时进度 callback，不做进度持久化和断点续传
- [x] convert 增加 phase marker：creating_work、copying_to_work、verifying_work、renaming_root_to_backup、renaming_work_to_root、completed、needs_attention
- [x] convert 使用 work/backup 同级目录切换模型，底层复用 import/export 全量复制
- [x] 实现 unfinished operation query，供 CLI/FFI 在 open root 时调用
- [x] 完善 convert recover，根据 phase 和 root/work/backup 实际存在状态继续、重跑或报告人工处理

**CLI 任务**：
- [x] CLI 入口改为完整算法注册，使用 `crypto_all` 和 transfer V3 实现
- [x] 实现统一密码读取 helper：`--password`、`--password-env`、`--password-stdin`、隐藏交互输入
- [x] 实现统一 root open helper：绝对路径规范化、`FindRootConfig`、`OpenRootQuick`、unfinished operation 检查
- [x] 增加 `create --path /abs/root`
- [x] `create` 默认只允许不存在目录或空目录；已存在非空目录默认拒绝
- [x] 交互式非空目录 create 可提示是否原地加密，非交互模式必须拒绝
- [x] 增加 `create --in-place`，使用 convert work/backup 目录切换模型
- [x] `import/export` 接入 V3 import/export API 和 `--unfinished=ask|rerun|clean|skip`
- [x] 增加 `--json` JSON Lines 输出
- [x] 明确不新增单独 `recover/resume` 命令，unfinished operation 处理由 open root 流程触发

**验收标准**：
- [x] CLI 创建的 root 可被 FFI/Flutter 打开
- [x] FFI/Flutter 创建的 root 可被 CLI 打开
- [x] 不同算法配置的 root 可被 CLI 打开
- [x] 中断 import/export 后，再次执行 CLI 命令能发现 operation marker，并可全量重跑/清理/跳过
- [x] 中断 convert 的 copy/verify/rename 阶段后，再次 open root 能按 phase 给出恢复或人工处理建议
- [x] convert 成功后 backup 默认保留，不自动删除
- [x] 密码不出现在日志、进度、JSON 输出中
- [ ] 完整实践测试矩阵覆盖 create、import/export、progress、unfinished operation、安全输入和兼容性
  - [x] sec/walker/transfer/CLI/FFI/Dart 覆盖 `aes-gcm-name` 文件名/目录名加密场景
  - [x] Dart FFI 集成测试覆盖 root create/open、quick read/write、V3 import/export、unfinished marker
  - [x] CLI `import/export --json` 覆盖 JSON Lines started/progress/completed 事件
  - [x] FFI Go 与 Dart FFI 集成测试覆盖 CLI-created root 由 FFI/Dart 写读并由 CLI export、FFI/Dart-created root 由 CLI import/export 使用
  - [x] Transfer V3 测试覆盖 convert encrypt 成功后 backup 目录保留且 marker 清理
  - [x] CLI 集成测试覆盖 create/import/list/export 普通输出和 JSON 输出不泄漏密码
  - [x] CLI 单元/集成测试覆盖非空目录 create 交互确认逻辑、非交互拒绝和 JSON 模式拒绝提示污染

### [BUG] UI 新创建的加密目录，侧边栏与解密栏标题为一段 json 字符串

**优先级**：1（最高）

**问题**：创建加密目录后，侧边栏和解密栏显示的不是目录名，而是一段 JSON 字符串

**影响**：严重影响用户体验

**验收标准**：
- [ ] 侧边栏显示正确的目录名
- [ ] 解密栏显示正确的目录名

---

## 🟡 P1 - 高优先级任务

**优先级**：2

**背景**：TransferService 需要支持断电恢复、幂等性、数据安全

**核心设计**（详见 V2 文档）：
- 进度持久化：`_progress_files.json`
- 原子化文件替换：`rename -> rename -> update progress -> remove temp`
- 断电恢复：启动时检查进度文件，清理临时文件

**流程**（Import/Export 统一）：
```
Step 1: 扫描所有文件，保存 -> _progress_files.json
Step 2: 加密/解密文件
Step 3: 安全替换（原子操作）：rename(a.txt -> a.txt.raw), rename(a.txt.enc -> a.txt)
Step 4: 保存进度（更新 _progress_files.json）← 先更新进度
Step 5: 清理临时文件：remove(a.txt.raw) ← 后删除临时文件
Step 6: 返回 Step 2 处理下一个文件
```

**验收标准**：
- [ ] ImportDirectoryAsync 实现原子化流程
- [ ] ExportDirectoryAsync 实现原子化流程
- [ ] 断电恢复测试通过
- [ ] 幂等性测试通过

---

## 🟡 P1 - 高优先级任务

### 用户体验改进

- [ ] **安全记事本自动保存时间间隔可选**（优先级：中）
  - 默认不保存
  - 可选时间间隔：30秒、3分钟、10分钟、30分钟、2小时
  - 添加设置选项框

- [x] **统一加密目录入口**：侧边栏改成打开/创建按钮，去掉右上角和启动页的重复按钮 ✅ 2026-04-03
  - 侧边栏："打开加密目录" → "打开/创建加密目录"
  - 去掉右上角的打开/创建加密目录按钮
  - 去掉启动页中间的打开加密目录按钮
  - 记得更新相关测试
  - 修改文件：lib/widgets/sidebar.dart, lib/pages/home_page.dart, test/widgets/sidebar_test.dart
  - 编译成功，测试通过，功能正常

- [x] **首次使用缺少引导** ✅ 2026-04-03
  - 已创建 `WelcomeGuideDialog` 欢迎引导对话框
  - 引导内容包括：欢迎信息、加密目录介绍、核心功能、安全提示
  - 已添加首次使用检测逻辑（检查是否已打开过加密目录）
  - 已添加"跳过"和"不再显示"选项
  - 修改文件：`lib/pages/dialogs.dart`, `lib/pages/home_page.dart`, `lib/services/directory_persistence_service.dart`
  - Flutter 应用编译成功
- [x] 错误提示不够友好 ✅ 2026-04-03
  - 已创建错误提示常量文件：`lib/utils/error_messages.dart`
    - 定义 ErrorType 枚举（20+ 种错误类型）
    - 定义 ErrorMessage 类（标题、描述、建议操作、是否严重）
    - 定义 ErrorMessages 工具类（获取错误提示、完整信息等）
  - 已创建错误提示组件：`lib/widgets/error_dialog.dart`, `lib/widgets/enhanced_snackbar.dart`
  - 已修改 `lib/widgets/copyable_snackbar.dart`，添加 ErrorSnackBar 和 ErrorHelper
  - 已修改 `lib/pages/home_page.dart` 中的所有错误提示
  - 已修改 `lib/pages/dialogs.dart` 中的所有错误提示
  - 已修改 `lib/widgets/secure_notepad.dart` 中的所有错误提示
  - 所有错误提示均包含：清晰的标题、详细的描述、建议操作
  - Flutter 应用编译成功
- [x] 进度显示缺失 ✅ 2026-04-03
  - 已创建进度显示组件：`lib/widgets/progress_dialog.dart`
    - ProgressInfo 类：包含当前进度、总数、文件名、状态、预计剩余时间
    - ProgressDialog 组件：显示进度条、百分比、文件名、已处理数量、取消按钮
    - ProgressController 控制器：用于更新进度、取消操作、预估剩余时间
    - ProgressHelper 工具类：显示/隐藏进度对话框
  - 已修改 `lib/pages/home_page.dart`：
    - 新增 `_countFilesInDirectory()` 方法：计算目录中文件总数
    - 修改 `_exportDirectory()` 方法：使用 ProgressDialog 显示导出进度
    - 修改 `_exportDirectoryRecursive()` 方法：添加进度更新和取消检查
    - 修改 `_batchExport()` 方法：使用 ProgressDialog 显示批量导出进度
  - 功能特性：
    - ✅ 进度条显示百分比
    - ✅ 显示当前处理的文件名
    - ✅ 显示已处理文件数/总文件数
    - ✅ 预计剩余时间（可选）
    - ✅ 用户可以取消操作
    - ✅ 进度显示不阻塞 UI
  - Flutter 应用编译成功
- [x] 创建新加密目录后，没有添加到侧边栏 ✅ 2026-04-03
  - 修改 `_createEncryptedDirectory()` 方法，成功后自动调用 `_loadDirectory(selectedPath)`
  - 自动打开新创建的加密目录，从而自动添加到侧边栏
  - 修改文件：`lib/pages/home_page.dart`
  - Flutter 应用编译成功
- [x] 创建加密目录/导入加密目录可以合并成一个按钮 ✅ 2026-04-03
  - 判断目录是否已存在 `_cryption.json`，自动选择创建或导入模式
  - 已实现 `_openOrCreateEncryptedDirectory()` 方法
  - 已提取 `_createEncryptedDirectoryWithPath()` 方法，接受路径参数
  - 编译成功，功能正常
- [x] 删除侧边栏加密目录时，应弹窗让用户选择是否删除磁盘目录 ✅ 2026-04-03
  - 已创建 DeleteDirectoryDialog 删除确认对话框
  - 已修改 _closeDirectory 方法，添加删除确认逻辑
  - 用户可以选择：仅从侧边栏移除、同时删除磁盘目录、取消
  - 删除磁盘目录失败时会显示错误提示
  - 修改文件：lib/pages/dialogs.dart, lib/pages/home_page.dart
  - Flutter 应用编译成功
- [x] 顶部目录导航栏乱了 ✅ 2026-04-03
  - **问题**：`_buildBreadcrumb()` 方法被调用了两次，导致面包屑导航显示重复
  - **原因**：在 `_buildBody()` 和 `_buildFileBrowser()` 中都调用了 `_buildBreadcrumb()`
  - **修复**：从 `_buildFileBrowser()` 中移除重复的 `_buildBreadcrumb()` 调用
  - **修改文件**：`lib/pages/home_page.dart`
  - **编译结果**：Flutter 应用编译成功，无错误

### 代码质量

- [x] Dart/Flutter 代码质量 Review ✅ 2026-04-03（部分完成）
  - [x] 修复所有 warning 和 info 级别的问题（9/9 warning，26/43 info）
  - [x] 配置 `analysis_options.yaml` 规则集
  - [x] 使用 `dart format` 统一代码格式
  - [x] 添加必要的注释和文档
  - [x] 检查 Widget 使用是否合理
  - [x] 检查性能问题（不必要的 rebuild）
  - [x] 使用 const constructor 优化
  - [x] 检查是否有敏感信息硬编码
  - [ ] 剩余 17 个 info 级别问题（主要是 avoid_print 和 use_build_context_synchronously）

- [x] 测试覆盖率达到 60%+ ⚠️ 部分完成 2026-04-03
  - **目标**：60%
  - **实际**：37.4%（+6.9%）
  - [x] 添加 mocktail 测试依赖
  - [x] 添加 secure_notepad.dart 测试（0% → 62.7%）
  - [x] 添加 secure_image_viewer.dart 测试（0% → 88.4%）
  - [ ] 未达成目标，需要继续添加测试

- [x] Go 核心库优化 ✅ 2026-04-03
  - [x] 更完善的错误处理 ✅ 2026-04-03
    - 新建 native/errors/errors.go 统一错误处理模块
    - 修改 native/crypto/、native/service/、native/config/ 包使用新错误类型
    - 修改 native/ffi_sec_fs 添加错误包装和上下文
    - 新建 docs/reference/error_handling.md 错误处理文档
  - [x] 统一 JSON 响应格式（jsonSuccessResponse/jsonErrorResponse） ✅ 2026-04-03
    - 新建 native/service/result.go 统一响应格式模块
    - 定义 JSONResponse 统一响应结构
    - 实现 jsonSuccess/jsonError/jsonSuccessWithData/jsonSuccessWithID 等辅助函数
    - 修改 native/ffi_sec_fs 使用新响应格式
    - 修改 native/service/encryption_service.go 使用新响应格式
    - 所有测试通过，功能正常
  - [x] GenerateEncryptionConfig 提取到 service 供 CLI 复用 ✅ 2026-04-03
    - Commit: da6f582d
    - 提取 GenerateEncryptionConfig 到 service 层
    - CLI 和 FFI 均可复用

- [x] FFI 增加目录异步加解密功能 ✅ 2026-04-03
  - Commit: fe2ba2c
  - 实现 encryptDir/decryptDir(srcDir, targetDir, tempKeyID, callback)
  - 支持复用，CLI 也可调用
  - srcDir==targetDir 时原子安全

- [x] 密钥派生测试覆盖率优化 ✅ 2026-04-03
  - **目标**：提升 native/crypto 密钥派生相关函数测试覆盖率
  - **结果**：覆盖率 79.9%，全部测试通过
  - **新增测试文件**：`native/crypto/key_derive_test.go`（替代旧的 key_derivation_test.go）
  - **测试覆盖**：
    - DeriveKeyFromPasswordPBKDF2
    - VerifyPasswordPBKDF2
    - GenerateRandomSalt
    - GenerateEncryptionConfig
    - 等密钥派生核心函数
  - **修改文件**：native/crypto/key_derive_test.go

- [ ] Go 核心库优化

---

## 🟢 P2 - 中优先级任务

### 性能优化


#### 大文件增量加密优化
- [x] **实现增量加密 FFI 接口** ✅ 2026-04-03
  - 新增 FFI 函数：IncrementalEncryptorCreate/AddBlock/Finalize/Close
  - 新增 FFI 函数：IncrementalDecryptorOpen/DecryptBlock/DecryptRange/DecryptAll/Close
  - 新增 FFI 函数：IncrementalDecryptorVerifyBlockIntegrity/VerifyIntegrity/GetBlockInfo/GetAllBlockInfo
  - 新增 FFI 函数：IsIncrementalFile/GetIncrementalFileInfo
  - 新增 Flutter FFI 绑定：lib/native/bindings.dart (+150 行)
  - 新增 Flutter 端 API：lib/native/native_lib.dart (+172 行)
  - 新增 Go 层 FFI 实现：native/ffi_sec_fs (+471 行)
  - 新增文档：docs/design/FFI_INCREMENTAL_ENCRYPTION.md
  - 新增测试：test/incremental_encrypt_ffi_test.dart

- [x] **实现 Flutter 端 UI 集成** ✅ 2026-04-03
  - 新增结果类：lib/models/ffi_results.dart (+247 行)
    - IncrementalEncryptorResult、IncrementalDecryptorResult
    - IncrementalBlockResult、IncrementalBlockInfo
    - IsIncrementalResult、IncrementalFileHeader 等
  - 新增服务层：lib/services/incremental_encrypt_service.dart (+735 行)
    - IncrementalEncryptor：流式加密器，支持分块加密
    - IncrementalDecryptor：流式解密器，支持随机访问解密
    - IncrementalEncryptService：高级服务接口
  - 新增单元测试：test/services/incremental_encrypt_service_test.dart
  - 支持进度回调和错误处理
  - 支持大文件流式加密/解密，内存占用有界
  - Commit: e75c6e9

- [x] **性能测试和优化** ✅ 2026-04-03
  - 新增性能测试：native/crypto/incremental_encrypt_bench_test.go
  - 新增性能测试：test/performance/incremental_encrypt_perf_test.dart
  - 新增性能报告：docs/archive/performance_report.md
  - 测试结果：
    - 加密吞吐量：167 MB/s (100MB 文件)
    - 解密吞吐量：659 MB/s (100MB 文件)
    - 随机访问延迟：35-90 µs (P50-P95)
    - 存储开销：0.16%
  - 优化建议：调整默认块大小至 256KB-512KB

- [ ] **增量加密**：100MB 已加密文件，随机在 5 个位置添加/编辑/删除 1-2000byte 数据，再保存时文件修改量低于 8MB
  - 测试要求：创建 100MB 测试文件，验证修改量
  - 目标：避免全文件重新加密
- [ ] **随机定位快速解密**：支持任意位置定位的快速解密
  - 测试要求：测试随机位置解密性能
  - 目标：O(1) 或 O(log n) 定位复杂度

- [ ] **重构 stream 设计**：允许重构掉原来 V2 的 stream 设计，允许不兼容
  - 可以重新设计加密文件格式
  - 优先满足增量加密和随机定位需求

- [ ] 大文件流式解密（避免内存溢出）
### UI性能优化
- [ ] 文件列表虚拟滚动（处理超大目录）
- [ ] 内存占用优化
- [ ] 启动速度优化
- [ ] 批量加密解密任务后台安全处理

### 功能增强

- [ ] 剪贴板复制/粘贴
- [ ] 软件内右键菜单增强
- [ ] 设置界面
- [ ] 批量操作（批量导出、批量删除）
- [ ] 文件排序（按名称、大小、日期）
- [ ] 文件过滤（按类型）
- [ ] 数据恢复功能（可选密码提示）
- [ ] 备份恢复功能

### UI 增强

- [ ] 拖拽上传
- [ ] 主题定制（暗色/亮色模式）

### 数据管理

- [ ] **迭代次数（iterN）应动态调整**
  - 根据当前安全标准自动推荐最小迭代次数（如PBKDF2推荐100000+）
  - 根据硬件性能自动调整（测试加密时间，确保用户体验）
  - 提供安全等级选项（快速/标准/高安全）
## 代码模块化
- [ ] 拆解代码
  
## 其他文档
-  [ ] FEATURES.md
-  [ ] ROADMAP.md

---

## 🔵 P3 - 低优先级任务

### 平台扩展

- [ ] macOS 平台支持
- [ ] Windows 平台优化
- [ ] 安装包制作（Windows .exe, Linux .deb/.rpm）

### 功能增强

- [ ] 多语言支持（中文、英文）
- [ ] 快捷键支持
- [ ] 触摸屏优化
- [ ] _cryption.json 文件名可设置自定义
- [ ] 仿 Windows/Ubuntu 文件管理器界面
- [ ] 快捷清单、收藏夹功能
- [ ] 多标签页浏览
- [ ] 文件预览窗口
- [ ] 密钥缓存 N 小时自动清除
- [ ] 拖拽上传

### 文档完善

- [ ] API 文档（Go 库）
- [ ] 架构文档
- [ ] 贡献指南
- [ ] 开发者文档

### 优化
- [ ] 图片缩略图预览
- [ ] 图片缩略图缓存

---

## ✅ 已完成任务

> 以下任务已完成，保留作为历史记录

### 2026-04-06

- [x] **架构重构：统一配置传递** ✅ 2026-04-06
  - **目标**：统一配置传递方式，避免硬编码和重复配置
  - **实现**：
    - `name.NewContext(..., config.WithPrefix("name"))`
    - `data.NewContext(..., config.WithPrefix("data"))`
    - `IKeyDeriver.LoadKey(..., config.WithPrefix("key"))`
    - 内部 factory 选择：`{algorithmName}Impl.NewContext(..., config.WithPrefix("{algorithmName}"))`
  - **修改文件**：crypto_name/interface.go, crypto_data/interface.go, crypto_key/interface.go
  - **Commit**: 27b2051

- [x] **架构重构：路径类型安全强制** ✅ 2026-04-06
  - **目标**：TransferService 内禁止 `path string`，遵从四种路径类型强制要求
  - **实现**：
    - 定义 `ExternalPath` 类型（外部文件系统路径）
    - Export 方法：`srcPath RelativeViewPath`, `destPath ExternalPath`
    - Import 方法：`srcPath ExternalPath`, `destPath RelativeViewPath`
  - **修改文件**：sec_transfer/define.go, sec_transfer/transfer.go, ffi_sec_fs/ffi.go
  - **Commit**: 117da20

- [x] **架构重构：修复过度设计** ✅ 2026-04-06
  - **问题**：ffi_comm 和 ffi_stores 是不必要的间接层
  - **解决**：合并 ffi_comm 和 ffi_stores 到 ffi_sec_fs
  - **删除**：ffi_comm/, ffi_stores/ 目录
  - **新增**：ffi_sec_fs/response.go, ffi_sec_fs/idstore.go, ffi_sec_fs/stores.go
  - **Commit**: b452578

- [x] **架构重构：移动 sec_transfer 到 sec_fs** ✅ 2026-04-06
  - **目标**：简化模块结构，sec_transfer 是 sec_fs 的一部分
  - **实现**：移动 `native/sec_transfer` → `native/sec_fs/sec_transfer`
  - **更新导入**：`safe_disk/native/sec_transfer` → `safe_disk/native/sec_fs/sec_transfer`
  - **Commit**: aee3f8d

### 2026-04-03

- [x] **图片浏览器功能实现** ✅ 2026-04-03
  - **核心特性**：
    - ✅ 支持格式：JPG/JPEG/PNG/GIF/BMP/WebP
    - ✅ 内存中解密显示（不写临时文件）
    - ✅ 缩放（手势、按钮、快捷键）
    - ✅ 翻页（导航按钮、手势、快捷键）
    - ✅ 旋转功能
    - ✅ 快捷键支持（← → 翻页，+ - 缩放，R 旋转，N 重置，ESC 关闭）
    - ✅ 手势支持（双击重置，滑动翻页，捏合缩放）
    - ✅ 安全内存清零（关闭时和切换图片时）
  - **修改文件**：
    - lib/widgets/secure_image_viewer.dart（完全重写，新增所有功能）
    - lib/pages/home_page.dart（传递 directoryPath 和 fileService 参数）
  - **新增文件**：
    - docs/archive/secure_image_viewer_report.md（实现报告）
  - **测试**：Flutter 应用编译成功

- [x] **安全记事本功能实现** ✅ 2026-04-03
  - **核心特性**：
    - ✅ Flutter 渲染文本（防木马探测）
    - ✅ 基础文本编辑
    - ✅ 撤销/重做（最多50步）
    - ✅ 查找/替换
    - ✅ 自动加密保存（30秒）
    - ✅ 部分文本复制
    - ✅ 内存中处理，不写临时文件
    - ✅ 关闭后清零内存（通过 FFI 调用 Go MemZero）
  - **修改文件**：
    - native/ffi_sec_fs/exports.go（添加 ClearSecureMemory FFI 函数）
    - lib/native/bindings.dart（添加 clearSecureMemory 绑定）
    - lib/native/native_lib.dart（添加 clearSecureMemory 调用接口）
    - lib/widgets/secure_notepad.dart（实现完整的安全记事本功能）
  - **新增文件**：
    - test/secure_notepad_test.dart（单元测试）
    - docs/usage/secure_notepad_usage.md（使用文档）
  - **未实现**：行号显示/跳转（可选功能）

- [x] **底部弹出的错误提示，应当可以点击复制** ✅ 2026-04-03
- [x] **Dart/Flutter 代码质量 Review - 安全性检查** ✅ 2026-04-03
- [x] **密码输入可能被记录（CLI 模式）** ✅ 2026-04-03（已验证安全）
- [x] **创建加密目录功能缺失** ✅ 2026-04-03（已添加按钮，需要添加 FFI 绑定）

### 2026-04-02

- [x] **打开加密目录应当使用目录选择器** ✅ 2026-04-02（使用 `getDirectoryPath()` 替代文本输入）
- [x] **[BUG] 目录导出菜单缺失** ✅ 2026-04-02（添加了目录导出功能，支持递归导出）
- [x] **多级目录导航不支持快捷跳转到2级3级等子级目录** ✅ 2026-04-02（添加了路径导航栏 breadcrumb）
- [x] **[BUG] 有两个search按钮** ✅ 2026-04-02（删除了重复的搜索按钮）
- [x] **[BUG] 树形UI界面缺少显示文件** ✅ 2026-04-02（修改了树形UI，现在可以显示文件和目录）
- [x] **输入错误密码后，密码输入框应保持焦点，方便继续输入** ✅ 2026-04-02
- [x] **侧边栏打开目录应记录，关闭重开后自动恢复** ✅ 2026-04-02
- [x] **侧边栏应有"固定"功能，固定后点击内容区域不自动隐藏** ✅ 2026-04-02
- [x] **文件搜索功能** ✅ 2026-04-02

### 安全问题修复

- [x] **🚨 CLI 无法解密 UI 的加密目录** ✅ 2026-04-03
  - **问题**：`safedisk-cli export` 命令执行失败
  - **原因**：CLI 工具使用旧架构，与 UI 的新架构不兼容
  - **解决方案**：更新 CLI 工具到新版架构设计（tempKeyID 机制）
  - **修复**：在 `LoadCryptionJSON` 中添加向后兼容逻辑，将旧版 `check` 字段映射到新版 `EncryptedChallengeId` 字段

- [x] **[严重] UI 和 CLI 加密/解密不兼容** ✅ 2026-04-02
  - UI 创建的目录打不开（密码错误）
  - UI 创建的，CLI 也解密不了
  - CLI 创建的，UI 也打不开
  - **根本原因**：UI 的 `generateCheckValuePBKDF2` 方法缺少 `challengeId` 参数
  - **修复**：添加 `challengeId` 参数到 FFI 接口，UI 调用时传递正确的值
  - **字段重命名**：`check` → `encryptedChallengeId`, `checkIdentifier` → `challengeId`

- [x] **🚨 高危泄密风险：严禁在内部解密时保存临时文件到硬盘** ✅ 2026-04-03
  - **规定**：除了用户主动点击"导出解密"功能外，其他所有内部操作严禁将临时解密文件保存到本地硬盘
  - **解决方案**：所有解密操作必须在内存中完成，使用 `Uint8List` 或内存流

### 技术债务清理

- [x] **🔴 高优先级：密钥派生应使用标准 PBKDF2/Argon2，而非自定义 HMAC 迭代** ✅ 2026-04-02
- [x] **🔴 高优先级：密钥派生应添加盐值（Salt）支持** ✅ 2026-04-02
- [x] **🔴 高优先级：VerifyPassword 不应硬编码检查值** ✅ 2026-04-02
  - 每个加密目录现在有独立的随机挑战值标识符 `challengeId`
- [x] 使用 `dart analyze` 检查代码规范问题 ✅ 2026-04-03
- [x] 修复所有 error 级别的问题 ✅ 2026-04-03
- [x] 检查并移除未使用的 import ✅ 2026-04-03
- [x] 检查并移除未使用的变量和函数 ✅ 2026-04-03
- [x] 优化代码结构，减少重复代码 ✅ 2026-04-03（架构重构）
- [x] 优化 State 管理 ✅ 2026-04-03（CryptoService 无状态化）
- [x] 检查密码输入框是否使用 obscureText ✅ 2026-04-03
- [x] **[严重] ConvertRootAsync 加密/解密后文件被删除** ✅ 2026-04-17
  - **问题**：ConvertRootAsync 加密/解密转换后，文件不存在
  - **根本原因**：`encryptFileInPlace` 和 `decryptFileInPlace` 在处理文件备份时有逻辑错误
  - **encryptFileInPlace 问题**：
    - 当磁盘上有明文文件时，`root.Stat("file1.txt")` 返回成功
    - 备份明文文件：`root.Rename("file1.txt", "file1.txt.bak")`
    - 重命名加密文件：`root.Rename("file1.txt.tmp", "file1.txt")`
    - 删除备份：`root.DeleteFile("file1.txt.bak")`
    - **错误**：`os.Remove(srcPath)` 又删除了加密文件！
  - **decryptFileInPlace 问题**：
    - 当磁盘上有加密文件时，`os.Stat("file1.txt")` 返回成功
    - 备份加密文件：`os.Rename("file1.txt", "file1.txt.bak")`
    - 重命名明文文件：`os.Rename("file1.txt.tmp", "file1.txt")`
    - 删除备份：`os.Remove("file1.txt.bak")`
    - **错误**：`root.DeleteFile("file1.txt")` 又删除了明文文件！
  - **修复**：只有当没有备份时，才删除原始文件
  - **修改文件**：`native/sec_fs/sec_transfer/v2/atomic_file.go`
  - **验证**：加密/解密功能正常，文件存在且内容正确

---

## 📝 任务依赖关系

1. **大文件流式解密** 依赖 **FFI 异步加解密功能**
2. **文件列表虚拟滚动** 需要先完成 **文件排序/过滤功能**
3. **图片缩略图预览** 依赖 **图片缩略图缓存**
4. **数据恢复功能** 依赖 **备份恢复功能**

---

## 🎯 建议执行顺序

**第一批（P0）**：安全问题 + 核心功能稳定性
1. 修复内存清零问题（5-8 天）
2. 优化大文件/大目录性能（6-10 天 + 3-5 天）

**第二批（P1）**：用户体验改进
1. 添加首次使用引导
2. 优化错误提示和进度显示
3. 修复侧边栏和导航栏问题
4. 完成代码质量检查和测试覆盖

**第三批（P2）**：性能优化和功能增强
1. 实现流式解密和虚拟滚动
2. 添加剪贴板和右键菜单支持
3. 完善设置界面和批量操作

**第四批（P3）**：平台扩展和锦上添花
1. macOS 支持和安装包制作
2. 多语言和主题定制
3. 文档完善

**总预计工作量**：14-23 天

---

**最后更新**: 2026-04-03
