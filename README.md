# Safe Disk - 加密目录浏览工具

跨平台加密目录管理工具，支持 Windows、Linux 和 macOS。

## 文档

- [技术架构](docs/ARCHITECTURE.md)
- [加密方案](docs/ENCRYPTION.md)
- [功能规划](docs/FEATURES.md)
- [开发路线](docs/ROADMAP.md)
- [需求文档](docs/REQUIREMENTS.md)
- [开发进度/TODO](docs/TODO.md)

## 🎯 项目状态

**当前阶段：P0 项目初始化完成**

- ✅ Flutter 项目创建（Windows/Linux/macOS 支持）
- ✅ Go 加密模块（AES-256-GCM）
- ✅ FFI 绑定完成
- ✅ 基础 UI 框架搭建
- ✅ 应用成功运行

## 核心特性

- 🔐 多加密目录浏览管理
- 📁 仿原生文件浏览器界面
- 📝 安全记事本（Flutter 渲染，防木马探测）
- 🖼️ 加密图片浏览器
- 📋 跨平台剪贴板支持
- 🔍 智能加密目录检测（类似 .git 向上查找逻辑）

## 技术栈

- **前端**: Flutter (必须，用于安全渲染)
- **后端**: Go (加密解密、文件操作)
- **通信**: FFI (共享库)

## 项目结构

```
safe_disk/
├── lib/                    # Flutter 代码
│   ├── native/            # FFI 绑定
│   ├── models/            # 数据模型
│   ├── services/          # 服务层
│   └── pages/             # UI 页面
├── native/                 # Go 加密模块
│   ├── crypto/            # 加密算法
│   │   ├── key_derive.go  # 密钥派生
│   │   └── aes_gcm.go     # AES-256-GCM
│   ├── config/            # 配置解析
│   └── main.go            # FFI 导出
└── docs/                   # 文档
```

## 快速开始

```bash
# Flutter 依赖
flutter pub get

# 编译 Go 共享库
cd native && go build -buildmode=c-shared -o libsafedisk_native.so

# 运行 Flutter 应用
cd .. && flutter run -d linux

# 或者构建生产版本
flutter build linux
```

## 加密方案

- **算法**: AES-256-GCM
- **密钥派生**: HMAC-SHA256 + IterN 迭代
- **配置文件**: `_cryption.json` (包含校验值、迭代次数等)
