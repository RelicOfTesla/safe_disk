# Safe Disk - 加密目录浏览工具

跨平台加密目录管理工具，支持 Windows、Linux 和 macOS。

## 文档

- [文档目录](docs/README.md)
- [代码审计状态](docs/CODE_AUDIT_STATUS.md)
- [技术架构](docs/ARCHITECTURE.md)
- [FFI 设计](docs/FFI_DESIGN.md)

## 项目状态

**当前阶段：核心后端已成型，Flutter UI 与部分 FFI 集成仍在整理**

- Flutter 入口已接入，但主 UI 仍是占位页
- Go 加密模块与 `sec_fs` 后端已存在
- FFI 基础绑定已存在，但公开接口与文档还未完全对齐
- 目录导入/导出在 Dart 侧仍有未完成实现
- 安全记事本、图片浏览器、完整文件浏览器需要以代码审计状态为准
- Go CLI 工具存在，但部分命令路径仍需核实

## 核心特性

- 多加密目录浏览管理
- 仿原生文件浏览器界面
- 安全记事本（Flutter 渲染，防木马探测）
- 加密图片浏览器
- 跨平台剪贴板支持
- 智能加密目录检测（类似 .git 向上查找逻辑）

## 技术栈

- **前端**: Flutter (Dart)
- **后端**: Go (加密解密、文件操作)
- **通信**: FFI (共享库)

## 项目结构

```
safe_disk/
├── lib/                         # Flutter 代码
│   ├── native/                 # FFI 绑定
│   ├── models/                 # 数据模型
│   ├── services/               # 服务层
│   ├── pages/                  # UI 页面
│   └── utils/                  # 工具类
├── native/                      # Go 代码
│   ├── cli/                    # 命令行工具
│   ├── config/                 # 配置管理
│   ├── ffi_sec_fs/             # FFI 导出层
│   └── sec_fs/                 # 核心加密文件系统
│       ├── crypto_data/        # 数据加密算法 (AES-CTR/XTS, ChaCha20, RC4)
│       ├── crypto_hkdf/        # 密钥派生 (PBKDF2, Argon2, scrypt, HKDF)
│       ├── crypto_name/        # 文件名加密 (AES-GCM)
│       ├── sec_transfer/       # 安全传输 (原子化导入导出)
│       └── sec_utils/          # 路径工具
├── docs/                        # 文档
└── scripts/                     # 构建脚本
```

## 快速开始

### 依赖

- Flutter SDK (^3.5.4)
- Go (1.25+)
- Linux: GTK 开发库

### 构建并运行

```bash
# 使用构建脚本（推荐）
./scripts/build_and_run.sh

# 或手动构建
# 1. 编译 Go 共享库
cd native
go build -buildmode=c-shared -o libsafedisk_native.so

# 2. 复制到 Flutter 目录
cp libsafedisk_native.so ../linux/

# 3. 获取 Flutter 依赖
flutter pub get

# 4. 运行
flutter run -d linux
```

### 构建 CLI 工具

```bash
cd native
go build -o safe-disk ./cli/main.go
```

### 运行测试

```bash
# Go 测试
cd native
go test ./...

# Flutter 测试
flutter test
```

## 加密方案

- **数据加密**: AES-256-CTR（默认，可插拔：AES-XTS, ChaCha20, RC4）
- **文件名加密**: AES-256-GCM
- **密钥派生**: PBKDF2 / Argon2 / scrypt（可插拔）
- **配置文件**: `_cryption.json`（包含校验值、迭代次数、算法配置等）
