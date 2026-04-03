# Safe Disk TODO List

> 本文档记录所有待办任务和已完成任务，按优先级分类

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

### 安全问题

- [x] **内存清零可能不彻底**（优先级 1，实施成本：中） ✅ 2026-04-03
  - 已创建 `native/crypto/memzero.go` 工具函数
  - Go 层：`aes_gcm.go`, `key_derive.go`, `temp_key_manager.go`, `encryption_service.go` 已添加清零
  - FFI 层：`main.go` 已添加清零
  - Flutter 层：`file_service.dart` 已添加清零
  - 所有测试通过，功能正常

- [x] **大文件（>100 MB）解密可能占用大量内存**（优先级 2，实施成本：高） ✅ 2026-04-03
  - 已实现分块加密/解密功能
  - 新增 `native/crypto/stream.go` - 流式加密/解密模块
  - 新增 FFI 接口：`DecryptFileToPath`, `EncryptFileChunked`, `IsChunkedFile`, `GetEncryptedFileInfo`
  - 新增 Flutter 绑定和 API
  - 文件格式：`[Header(20)] + [Chunks: IV(12) + Size(4) + Ciphertext + Tag(16)]`
  - 内存占用有界，不随文件大小增长
  - 基准测试：10 MB 文件加密/解密正常
  - 注意：新加密的文件使用分块格式，旧文件仍使用标准 AES-GCM

- [x] **超大目录（>1000 文件）加载可能缓慢**（优先级 3，实施成本：中） ✅ 2026-04-03
  - 已实现后台遍历：使用 `Isolate.run()` 在后台线程遍历目录
  - 已实现分页加载：添加 `offset` 和 `limit` 参数支持分页
  - 已实现 UI 分页：树形视图支持分页加载，添加"Load more"按钮
  - 修改文件：`lib/services/file_service.dart`, `lib/widgets/directory_tree.dart`
  - 创建测试脚本：`scripts/test_large_directory.py`
  - Flutter 应用编译成功
  - 注意：列表/网格视图仍一次性加载所有文件，建议超大目录使用树形视图
  
- [x] **输入正确密码后无提醒（有日志）** ✅ 2026-04-03
  - **问题**：输入正确密码后无提醒，但日志中有错误 `No temporary key ID returned`
  - **原因**：Go 层 `MakeTemporaryKeyID` 返回的 JSON 格式不正确
    - Go 层返回：`{"success":true,"data":{"tempKeyID":"xxx"}}`
    - Flutter 期望：`{"success":true,"tempKeyID":"xxx"}`
  - **修复**：修改 `native/main.go` 中的 `MakeTemporaryKeyID` 函数，返回扁平化的 JSON
  - **测试**：
    - 单元测试通过：验证 JSON 格式正确
    - 测试 vault 创建成功：`/tmp/test_vault_fix`，密码：`test123`
    - Flutter 应用编译成功，运行正常
  - **修改文件**：`native/main.go`
---

## 🟡 P1 - 高优先级任务

### 用户体验改进

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
    - 修改 native/main.go 添加错误包装和上下文
    - 新建 docs/error_handling.md 错误处理文档
  - [x] 统一 JSON 响应格式（jsonSuccessResponse/jsonErrorResponse） ✅ 2026-04-03
    - 新建 native/service/result.go 统一响应格式模块
    - 定义 JSONResponse 统一响应结构
    - 实现 jsonSuccess/jsonError/jsonSuccessWithData/jsonSuccessWithID 等辅助函数
    - 修改 native/main.go 使用新响应格式
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
  - 新增 Go 层 FFI 实现：native/main.go (+471 行)
  - 新增文档：docs/FFI_INCREMENTAL_ENCRYPTION.md
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
  - 新增性能报告：docs/performance_report.md
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

### 2026-04-03

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
