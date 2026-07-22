# 技术架构

> 这是架构说明，不是实现完成证明。当前真实可用能力以代码审计状态为准。

## 整体架构

```
┌─────────────────────────────────────────┐
│   Flutter UI App    │    Go CLI Tool    │
│  ┌──────────────────┼─────────────────┐ │
│  │ 文件浏览│记事本  │  create/export  │ │
│  │ 图片浏览器        │  import/list    │ │
│  └──────────────────┼─────────────────┘ │
└─────────────────┬──┴───────────────────┘
                  │ FFI (Flutter) / 直接调用 (CLI)
┌─────────────────▼───────────────────────┐
│           Go Core Library (共享)         │
│  ┌──────────┬──────────┬──────────────┐ │
│  │ 加解密   │ 文件操作 │ 密钥管理     │ │
│  └──────────┴──────────┴──────────────┘ │
└─────────────────────────────────────────┘
```

**架构说明**：
- **Flutter UI App**: 图形界面应用，通过 FFI 调用 Go 库
- **Go CLI Tool**: 独立命令行工具，直接调用 Go 库
- **Go Core Library**: 共享的加密/文件操作库，采用插件化设计

---

## Flutter 前端

### 职责
- 文件浏览器界面（列表视图、面包屑导航、搜索）
- 安全记事本（Flutter 渲染，防木马探测）
- 加密图片浏览器（内存解密、缩放、翻页、旋转）
- 加密目录创建/打开/导入

> 以上职责描述的是目标形态，不能直接视为当前 Flutter 代码已经全部实现。

### 目录结构

```
lib/
├── main.dart
├── native/
│   ├── bindings.dart         # FFI 底层绑定（C 函数声明）
│   └── native_lib.dart       # FFI 高层封装（Dart API）
├── models/
│   └── cryption_config.dart  # 加密配置模型
├── pages/
│   └── home_page.dart        # 主页面（文件浏览器、侧边栏）
├── services/
│   ├── crypto_service.dart   # 加密服务（无状态，tempKeyID 机制）
│   ├── directory_service.dart      # 目录服务
│   ├── directory_persistence_service.dart  # 目录持久化
│   ├── file_service.dart     # 文件服务
│   └── settings_service.dart # 设置服务
└── utils/
    └── error_messages.dart   # 错误消息定义
```

### 关键设计

**CryptoService 无状态化**
- 不缓存密钥，所有加密/解密操作显式传入 `tempKeyID`
- `tempKeyID` 由 Go 侧生成，Dart 侧仅持有 ID
- 密钥生命周期由 Go 侧管理

**内存安全**
- 图片/文本解密仅在内存中进行（`Uint8List`）
- 关闭时调用 `ClearSecureMemory` FFI 接口清零敏感内存
- 禁止内部操作写临时解密文件到磁盘（除用户主动导出外）

---

## Go 后端

### 目录结构

```
native/
├── cli/                      # CLI 工具
│   ├── cmd/                 # 子命令实现
│   │   ├── export.go
│   │   ├── import.go
│   │   ├── list.go
│   │   └── version.go
│   └── main.go              # CLI 入口
├── config/                   # 配置管理
│   ├── interface.go         # IConfig 接口
│   ├── file_config.go       # 文件配置
│   ├── memory_config.go     # 内存配置
│   └── prefixed.go          # 带前缀配置
├── ffi_sec_fs/              # FFI 导出层
│   ├── main.go              # FFI 入口（c-shared 编译目标）
│   ├── exports.go           # FFI 导出函数
│   ├── ffi.go               # FFI 核心逻辑
│   ├── callback.go          # 进度回调
│   ├── response.go          # 统一响应格式
│   ├── idstore.go           # ID 存储管理
│   └── stores.go            # 存储管理
└── sec_fs/                  # 核心加密文件系统
    ├── define.go            # 核心类型定义
    ├── file.go              # 安全文件操作
    ├── plainfs.go           # 明文文件系统适配
    ├── sec_root.go          # 加密根目录
    ├── sec_root_factory.go  # 根目录工厂
    ├── sec_path.go          # 安全路径
    ├── sec_dir_walker.go    # 目录遍历
    ├── errors.go            # 错误定义
    ├── crypto_data/         # 数据加密算法
    │   ├── interface.go     # ICryptoDataContext 接口
    │   ├── registry.go      # 算法注册表
    │   └── algorithm_impl/  # 具体实现
    │       ├── aes_ctr/
    │       ├── aes_xts/
    │       ├── chacha20/
    │       └── rc4/
    ├── crypto_hkdf/         # 密钥派生
    │   ├── interface.go     # IKeyDeriver 接口
    │   ├── registry.go      # 算法注册表
    │   └── algorithm_impl/  # 具体实现
    │       ├── pbkdf2/
    │       ├── argon2/
    │       ├── scrypt/
    │       └── hkdf/
    ├── crypto_name/         # 文件名加密
    │   ├── interface.go     # ICryptoNameContext 接口
    │   ├── registry.go      # 算法注册表
    │   └── algorithm_impl/  # 具体实现
    │       ├── aes_gcm_name/
    │       ├── rc4/
    │       └── none/
    ├── sec_transfer/        # 安全传输
    │   ├── interface.go     # ITransferManager 接口
    │   └── v2/              # V2 实现（原子化 + 断电恢复）
    │       ├── atomic_file.go
    │       ├── manager.go
    │       ├── task.go
    │       └── task_persist.go
    └── sec_utils/           # 工具
        ├── path_utils.go    # 路径工具
        └── path_comm.go     # 路径通用函数
```

---

## 插件化加密架构

### 设计原则

算法选择通过配置文件指定，运行时从注册表查找实现。新增算法无需修改现有代码，只需：
1. 实现对应接口
2. 在 `init()` 中注册
3. CLI 入口 blank import

### 三层加密

| 层级 | 包路径 | 接口 | 典型实现 |
|------|--------|------|----------|
| 数据加密 | `crypto_data` | `ICryptoDataContext` | AES-256-CTR |
| 密钥派生 | `crypto_hkdf` | `IKeyDeriver` | PBKDF2, Argon2 |
| 文件名加密 | `crypto_name` | `ICryptoNameContext` | AES-256-GCM |

### 统一配置传递

所有算法初始化接受 `config.IConfig` 参数，通过 `config.WithPrefix("algorithmName")` 实现命名空间隔离：

```go
nameCtx, err := nameRegistry.NewContext(config, config.WithPrefix("name"))
dataCtx, err := dataRegistry.NewContext(config, config.WithPrefix("data"))
keyDeriver, err := hkdfRegistry.LoadKey(config, config.WithPrefix("key"))
```

---

## 安全传输（TransferService V2）

### 原子化文件替换流程

```
Step 1: 扫描所有文件，保存进度 → _progress_task_<task_id>.json
Step 2: 加密/解密文件到 .tmp
Step 3: 备份原始文件：rename(原始 → .bak)
Step 4: 替换：rename(.tmp → 原始)
Step 5: 保存进度（更新 JSON）← 先更新进度
Step 6: 删除备份：remove(.bak) ← 后删除临时文件
```

### 断电恢复

启动时检查 `_pending_task_list.json` 和 `_progress_task_<task_id>.json`：
- 若进度文件存在且任务未标记完成，根据进度继续或回滚
- 回滚：将 .bak 恢复为原始文件，删除未完成的 .tmp

### 路径类型安全

TransferService 内禁止裸 `string` 路径，强制使用四种类型：
- `ExternalPath` — 外部文件系统绝对路径
- `RelativeViewPath` — 加密视图内的相对路径
- `SafeDiskPath` — 安全磁盘内部路径
- `StoragePath` — 存储层路径

---

## 通信方式

### FFI（Flutter ↔ Go）

详细设计见 [FFI_DESIGN.md](FFI_DESIGN.md)。

**实现**：
- Go 编译为共享库（.so / .dll / .dylib）
- Flutter 通过 `dart:ffi` 调用 C 函数
- 内存管理：Go 侧分配 C 字符串，Dart 侧调用 `freeCString` 释放

**关键 FFI 函数类别**：
- 目录操作：创建、打开、扫描、关闭
- 文件操作：读取、写入、删除、重命名
- 加密操作：加密文件、解密文件
- 传输操作：目录导入、目录导出（异步，带回调）
- 内存管理：`ClearSecureMemory`

> `ClearSecureMemory` 已有当前 FFI 绑定；增量加密仅保留历史设计归档，不属于当前 FFI API。具体以代码审计状态和 `exports.go` / `bindings.dart` 为准。

### CLI（直接调用）

CLI 直接链接 Go 库，无需 FFI 开销。命令：
- `version` — 查看版本
- `list` — 列出加密目录内容
- `export` — 导出解密
- `import` — 导入加密

> `create`、`info`、`passwd` 当前不能当作已完成命令处理。

---

## 跨平台策略

### 当前支持
- **Linux**: 主要开发平台，完整支持
- **Windows**: Flutter 项目已配置，待测试优化
- **macOS**: Flutter 项目已配置，待测试

### 构建差异

```bash
# Linux
go build -buildmode=c-shared -o libsafedisk_native.so

# Windows
go build -buildmode=c-shared -o safedisk_native.dll

# macOS
go build -buildmode=c-shared -o libsafedisk_native.dylib
```

---

## 性能考虑

1. **密钥缓存**: Go 侧通过 tempKeyID 机制缓存密钥
2. **懒加载**: 目录按需扫描，不预加载全部文件
3. **异步传输**: 大文件 import/export 通过 Transfer V3 worker isolate 执行，不在 Flutter 主 isolate 全量缓冲
4. **内存保护**: 敏感数据用后立即通过 MemZero 清零
5. **原子化传输**: 避免全文件缓冲，边处理边持久化进度
