# Safe Disk

跨平台加密目录管理工具。支持 Windows、Linux、macOS。

[English](README.md)

## 项目状态

当前阶段：核心后端已成型，Flutter UI 持续迭代。

- Flutter 主 UI：root 解锁、文件浏览、导入/导出、安全记事本、图片浏览器、WebDAV 共享已接入。
- Go 加密模块 (`sec_fs`)：AES-CTR/XTS、ChaCha20 数据加密，AES-GCM 文件名加密，PBKDF2/Argon2/scrypt 密钥派生。
- FFI 绑定：root 管理、文件操作、复制、Transfer V3 导入/导出、convert。
- CLI 工具：已支持 root 管理、导入导出、WebDAV 服务。
- 详细进度以 [文档目录](docs/README.md) 和 [代码审计状态](docs/CODE_AUDIT_STATUS.md) 为准。

## 核心特性

- 多加密目录浏览管理
- 仿原生文件浏览器（网格 / 列表 / 树视图）
- 安全记事本（Flutter 渲染，防木马探测）
- 加密图片浏览器（支持缩放、平移、多图导航）
- 安全导入/导出（Transfer V3，原地加密/解密，原子迁移）
- WebDAV 只读共享（支持 Basic Auth、Digest、TLS）
- 跨平台剪贴板支持
- 可插拔加密算法（AES-CTR / XTS / ChaCha20，PBKDF2 / Argon2 / scrypt）
- 文件名/目录名加密
- 自动锁定与密钥内存清理
- 多窗口安全记事本与图片浏览
- 暗色/亮色主题、多语言（中文 / English）

## 技术栈

| 层 | 技术 |
|---|---|
| UI | Flutter (Dart) |
| 后端 | Go（加密、文件操作、WebDAV） |
| 通信 | FFI (C 共享库) |
| 构建 | Go 交叉编译 + CMake / Flutter build |

## 项目结构

```
safe_disk/
├── lib/                      # Flutter 代码
│   ├── native/              # FFI 绑定
│   ├── models/              # 数据模型
│   ├── services/            # 服务层 (加密、设置、WebDAV、多窗口)
│   ├── pages/               # UI 页面
│   ├── widgets/             # UI 组件 (记事本、图片浏览器、文件浏览器)
│   └── utils/               # 工具类
├── native/                   # Go 代码
│   ├── cli/                 # 命令行工具
│   ├── config/              # 配置管理
│   ├── ffi_sec_fs/          # FFI 导出层
│   └── sec_fs/              # 核心加密文件系统
│       ├── crypto_data/     # 数据加密
│       ├── crypto_hkdf/     # 密钥派生
│       ├── crypto_name/     # 文件名加密
│       ├── sec_transfer/    # 安全传输（原子化导入导出）
│       └── sec_utils/       # 路径工具
├── docs/                     # 文档
└── scripts/                  # 构建脚本
```

## 快速开始

### 环境依赖

- Flutter SDK (^3.5.4)
- Go 1.25+
- Linux: GTK 开发库
- Windows: Visual Studio 生成工具

### 构建与运行

```bash
# 推荐：使用构建脚本
./scripts/build_and_run.sh

# 手动构建
cd native
go build -buildmode=c-shared -o libsafedisk_native.so
cp libsafedisk_native.so ../linux/
flutter pub get
flutter run -d linux
```

### 构建 CLI 工具

```bash
cd native
go build -o safe-disk ./cli/
```

### 运行测试

```bash
# Go 测试
cd native && go test ./...

# Flutter 测试
flutter test
```

## 加密方案

| 组件 | 默认算法 | 可插拔 |
|---|---|---|
| 数据加密 | AES-256-CTR | AES-XTS, ChaCha20, RC4 |
| 文件名加密 | AES-256-GCM | — |
| 密钥派生 | PBKDF2 | Argon2, scrypt |
| 密钥交换 | HKDF-SHA256 | — |

配置文件 `_cryption.json` 存储校验值、迭代次数、算法选择等参数。

## 安全威胁模型

- **防窥探**：记事本使用 Flutter 渲染，禁用系统原生文本框，防止木马读取屏幕内容。
- **防文件系统扫描**：所有解密在内存中进行，不写临时文件到磁盘，严禁在硬盘存储明文。
- **防截屏**（可选）：窗口内容保护（非 100% 可靠）。
- **防内存扫描**（可选）：内存数据用完立即清零。

## 文档

- [文档目录](docs/README.md) — 架构、设计、任务清单入口
- [代码审计状态](docs/CODE_AUDIT_STATUS.md)
- [技术架构](docs/ARCHITECTURE.md)
- [FFI 设计](docs/FFI_DESIGN.md)
- [CLI 设计](docs/CLI_DESIGN.md)
- [加密方案](docs/ENCRYPTION.md)
- [Transfer 设计](docs/TRANSFER_DESIGN.md)
- [开发规范](docs/DEVELOPMENT_STANDARDS.md)
- [活跃任务](docs/TODO.md)
- [跨平台验收](docs/PLATFORM_ACCEPTANCE.md)

## License

TBD
