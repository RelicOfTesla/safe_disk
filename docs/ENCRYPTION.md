# 加密方案

## 概述

采用**插件化加密架构**，数据加密与文件名加密分离，密钥派生可插拔：

- **数据加密**：AES-256-CTR（默认），可替换为 AES-XTS、ChaCha20、RC4
- **文件名加密**：AES-256-GCM
- **密钥派生**：PBKDF2（默认），可替换为 Argon2、scrypt、HKDF

支持两种密码模式：

**模式 1：不可变密码模式**（默认推荐）
- 密钥由用户密码派生，不存储在本地
- 安全性最高，无法修改密码
- ✅ **数据恢复能力强**：即使丢失 `_cryption.json`，只要记得密码就能解密文件

**模式 2：可变密码模式**
- 存储被用户密码保护的文件密钥
- 支持修改密码，无需重新加密文件
- ⚠️ **数据恢复风险**：丢失 `_cryption.json` 将导致文件**无法解密**（即使记得密码）

**✅ 状态**: 两种密码模式均已实现

---

## 加密目录结构

```
/xxx/
├── _cryption.json        # 加密元数据
├── aaa/
│   └── bbb/
│       └── ccc.txt       # 加密文件
└── ddd/
    └── file.pdf          # 加密文件
```

### _cryption.json 格式

```json
{
  "version": "1.0",
  "mutable": true,
  "encryptedChallengeId": "base64加密后的挑战值",
  "challengeId": "safe_disk",
  "salt": "base64盐值",
  "iterN": 100000,
  "dataAlgorithm": "aes-ctr",
  "nameAlgorithm": "aes-gcm-name",
  "hkdfAlgorithm": "pbkdf2",
  "created": "2026-04-01T00:00:00Z"
}
```

**字段说明**：
- `mutable`: 密码模式（true=可变密码, false=不可变密码）
- `encryptedChallengeId`: 加密后的挑战值（用于密码验证）
- `challengeId`: 明文挑战值标识符（默认 "safe_disk"）
- `salt`: 盐值（base64 编码）
- `iterN`: 密钥派生迭代次数
- `dataAlgorithm`: 数据加密算法（aes-ctr / aes-xts / chacha20 / rc4）
- `nameAlgorithm`: 文件名加密算法（aes-gcm-name / rc4 / none）
- `hkdfAlgorithm`: 密钥派生算法（pbkdf2 / argon2 / scrypt / hkdf）
- 旧版字段 `check` 已映射到 `encryptedChallengeId`（向后兼容）

---

## 密钥派生流程

默认使用 **PBKDF2-HMAC-SHA256**（可配置为 Argon2、scrypt、HKDF）：

```
用户密码 (inputPass)
      ↓
   PBKDF2(password, salt, iterN, 32)  // 密钥派生
      ↓
   cryptKey                // 文件加密密钥（32字节）
```

### 模式 1：不可变密码模式

```
用户密码 (inputPass)
      ↓
   PBKDF2(password, salt, iterN, 32)
      ↓
   cryptKey                // 直接从密码派生，本地不存储
```

**特点**：
- ✅ 本地无任何密钥存储
- ✅ 安全性最高
- ❌ 无法修改密码（需要重新加密所有文件）

### 模式 2：可变密码模式

**创建时**：
```
1. 生成随机文件密钥 fileKey (32字节)
2. 用户密码 + salt + iterN → PBKDF2 → userKey
3. 用 userKey 加密 fileKey
4. 存储加密后的 fileKey（当前存储在 _cryption.json 的加密字段中）
5. 用 fileKey 加密所有文件
```

**使用时**：
```
用户密码 (inputPass)
      ↓
   PBKDF2(password, salt, iterN, 32) → userKey
      ↓
   解密存储的 fileKey
      ↓
   fileKey                // 实际的文件加密密钥
```

**修改密码**：
```
1. 用旧密码派生 userKey，解密 fileKey
2. 用新密码派生 newUserKey，重新加密 fileKey
3. 更新存储的加密 fileKey 和 encryptedChallengeId
4. 文件无需重新加密
```

**特点**：
- ✅ 支持修改密码
- ✅ 修改密码时不需要重新加密文件
- ⚠️ 本地存储加密后的 fileKey（有一定风险）
- ⚠️ 丢失 _cryption.json 即无法解密文件（有一定风险）

---

## 密码校验

### 原理
每个加密目录有独立的挑战值标识符 `challengeId`（默认 "safe_disk"）。密码校验通过验证能否正确解密 `encryptedChallengeId` 来实现。

### 流程
```
1. 用户输入密码
2. 用 salt + iterN 派生密钥 cryptKey
3. 用 cryptKey 解密 _cryption.json 中的 encryptedChallengeId
4. 比较解密结果是否等于 challengeId
5. 相等则密码正确
```

**向后兼容**：旧版 `check` 字段自动映射到 `encryptedChallengeId`。

---

## 文件加密

### 数据加密（文件内容）
- **默认算法**: AES-256-CTR（支持随机访问，O(1) 内存开销）
- **可插拔算法**: AES-XTS、ChaCha20、RC4
- **密钥长度**: 32 字节（256 bits）
- **IV/Nonce**: 12–16 字节（因算法而异）

### 文件名加密
- **算法**: AES-256-GCM
- **密钥长度**: 32 字节（256 bits）
- **Tag 长度**: 16 字节（128 bits）

### 文件格式（数据加密，以 AES-CTR 为例）
```
[IV(12 bytes)] + [Ciphertext(N bytes)]
```

文件名经过加密后存储为 Base64 编码的密文。实际格式因算法配置而异。

---

## 加密目录检测

### 类似 .git 的向上查找逻辑
```
当前目录: /home/user/vault/docs/work/
查找顺序:
1. /home/user/vault/docs/work/_cryption.json  ← 不存在
2. /home/user/vault/docs/_cryption.json       ← 不存在
3. /home/user/vault/_cryption.json            ← 存在！
→ 加密根目录: /home/user/vault/
```

### 嵌套加密目录
每个加密目录有**独立的密钥**：
```
/home/user/
├── vault1/              <- 加密目录A（密钥A）
│   ├── _cryption.json
│   └── docs/
│       └── vault2/      <- 加密目录B（密钥B，独立于A）
│           └── _cryption.json
```

---

## FFI 接口

### Go 导出的 C 函数

主要函数：
- `DeriveKey` - 密钥派生
- `VerifyPassword` - 密码验证
- `EncryptData` - 数据加密
- `DecryptData` - 数据解密
- `LoadCryptionConfig` - 加载配置

**实现细节**: 参见 `_archived/detail.md` 中的 Go 和 Dart FFI 绑定代码

---

## 密钥缓存策略

Go 后端采用 **tempKeyID 机制** 管理密钥：

```
┌─────────────────────────────────────────┐
│           Go Key Store (内存)            │
│  ┌───────────────────────────────────┐  │
│  │ tempKeyID → 密钥 (受 Go GC 管理)  │  │
│  │ 创建时间                           │  │
│  └───────────────────────────────────┘  │
│  TTL: 由应用层控制（建议 1 小时）        │
│  清零: 显式调用 ClearSecureMemory       │
└─────────────────────────────────────────┘
```

**设计要点**：
- CryptoService 完全无状态化，Dart 侧仅持有 `tempKeyID`
- 所有加密/解密操作显式传入 `tempKeyID`
- 敏感数据通过 FFI `ClearSecureMemory` 接口主动清零

---

## 两种模式对比

| 特性 | 不可变密码模式 | 可变密码模式 |
|------|--------------|------------|
| 本地存储 | 无密钥 | 加密后的 fileKey |
| 安全性 | 最高 | 高 |
| 修改密码 | 需重新加密所有文件 | 只改密钥密文 |
| 适用场景 | 极度安全需求 | 需要定期修改密码 |
| 创建时选择 | 默认推荐 | 可选 |

---

## 推荐使用场景

**可变密码模式**（默认推荐）：
- ✅ 支持修改密码，无需重新加密文件
- ✅ 适合需要定期修改密码的场景
- ✅ 便利性优先

**不可变密码模式**（高级选项）：
- 敏感数据，不希望本地存储任何密钥信息
- 极度安全需求
- 安全性优先，需显式启用

**默认行为**：创建加密目录时，默认为**不可变密码模式**（`mutable: false`），只有在显式指定参数时才使用可变密码模式。

> **注意**：旧版文档中部分描述可变密码模式为默认，但当前代码实现中 `mutable` 字段默认值为 `false`。两种模式的 UI 支持可能仍在完善中。

---

## 安全考虑

### 1. 内存安全
- 敏感数据使用后立即清零
- 避免字符串拷贝
- 使用 `runtime.KeepAlive` 防止过早 GC

### 2. 防木马探测
- **记事本必须用 Flutter 渲染**，不用系统文本框
- 图片浏览器在内存中解密，不写临时文件
- 避免使用系统剪贴板存储明文

### 3. 文件系统安全
- ⚠️ **严禁解密到 /tmp 等临时目录**
- ⚠️ **严禁在硬盘里存储明文信息**
- ✅ 加密文件权限设置为 600
- ✅ 所有解密在内存中进行，不写临时文件
- ✅ 避免日志泄露敏感信息

### 4. 用户体验安全
- **文件打开提示**: 如果用户在系统文件管理器中打开加密文件，显示提示：
  > "此文件已加密，请在 Safe Disk 中查看"
- **导出解密提示**: 当用户导出解密文件时，显示确认对话框：
  > "导出解密文件将在硬盘上存储明文，确认继续？"
- **文件名显示**: 在 Safe Disk 中显示原始文件名（解密后的文件名），而不是加密后的文件名

---

## 已实现功能

- ✅ 插件化密钥派生（PBKDF2 / Argon2 / scrypt / HKDF）
- ✅ 插件化数据加密（AES-256-CTR / AES-XTS / ChaCha20 / RC4）
- ✅ 文件名加密（AES-256-GCM）
- ✅ 密码验证（challengeId 机制）
- ✅ 加密目录检测（向上查找）
- ✅ 嵌套加密目录支持（独立密钥）
- ✅ FFI 接口
- ✅ Dart 绑定

**最后更新**: 2026-06-02
