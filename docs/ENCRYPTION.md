# 加密方案

## 概述

使用 AES-256-GCM 加密，支持两种密码模式：

**模式 1：不可变密码模式**（默认推荐）
- 密钥由用户密码派生，不存储在本地
- 安全性最高，无法修改密码

**模式 2：可变密码模式**
- 存储被用户密码保护的文件密钥
- 支持修改密码，无需重新加密文件

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

#### 模式 1：不可变密码模式（默认）

```json
{
  "version": "1.0",
  "mode": "immutable",
  "check": "AES256加密的校验值",
  "iterN": 12345,
  "algorithm": "AES-256-GCM",
  "created": "2026-04-01T00:00:00Z"
}
```

#### 模式 2：可变密码模式

```json
{
  "version": "1.0",
  "mode": "mutable",
  "check": "AES256加密的校验值",
  "encryptedKey": "AES256加密的文件密钥",
  "iterN": 12345,
  "algorithm": "AES-256-GCM",
  "created": "2026-04-01T00:00:00Z"
}
```

**字段说明**：
- `mode`: 密码模式（immutable/mutable）
- `check`: 密码校验值（两种模式都有）
- `encryptedKey`: 被用户密码保护的文件密钥（仅 mutable 模式）
- `iterN`: 密钥派生迭代次数

## 密钥派生流程

### 模式 1：不可变密码模式

```
用户密码 (inputPass)
      ↓
   hash(inputPass)         // SHA-256
      ↓
   HMAC(hash, iterN)       // 密钥派生
      ↓
   cryptKey                // 文件加密密钥（32字节）
```

**特点**：
- ✅ 本地无任何密钥存储
- ✅ 安全性最高
- ❌ 无法修改密码（需要重新加密所有文件）

### 模式 2：可变密码模式

**创建时**：
```
1. 生成随机文件密钥 fileKey (32字节)
2. 用户密码 → 派生密钥 userKey
3. 用 userKey 加密 fileKey
4. 存储加密后的 fileKey 到 encryptedKey
5. 用 fileKey 加密所有文件
```

**使用时**：
```
用户密码 (inputPass)
      ↓
   派生密钥 userKey
      ↓
   解密 encryptedKey
      ↓
   fileKey                // 实际的文件加密密钥
```

**修改密码**：
```
1. 用旧密码解密 fileKey
2. 用新密码重新加密 fileKey
3. 更新 encryptedKey 和 check
4. 文件无需重新加密
```

**特点**：
- ✅ 支持修改密码
- ✅ 修改密码时不需要重新加密文件
- ⚠️ 本地存储加密后的 fileKey（有一定风险）

### 实际实现（Go 代码）

```go
// native/crypto/key_derive.go
func DeriveKey(inputPass string, iterN int) []byte {
    // Step 1: Hash password with SHA-256
    h := sha256.Sum256([]byte(inputPass))
    
    // Step 2: HMAC-based key derivation
    mac := hmac.New(sha256.New, h[:])
    for i := 0; i < iterN; i++ {
        binary.Write(mac, binary.BigEndian, uint32(i))
    }
    
    return mac.Sum(nil)[:32] // AES-256 key = 32 bytes
}
```

## 密码校验

### 原理
使用固定字符串 `"safe_disk"` 的哈希值作为校验基准。

### 流程
```
1. 用户输入密码
2. 派生密钥 cryptKey
3. 用 cryptKey 解密 _cryption.json 中的 check 字段
4. 比较解密结果是否等于 hash("safe_disk")
5. 相等则密码正确
```

### 实际实现（Go 代码）

```go
// native/crypto/key_derive.go
func VerifyPassword(checkBase64, inputPass string, iterN int) bool {
    // Derive key
    cryptKey := DeriveKey(inputPass, iterN)
    
    // Decode check value
    check, _ := base64.StdEncoding.DecodeString(checkBase64)
    
    // Decrypt check value
    decrypted, err := DecryptAESGCM(check, cryptKey)
    if err != nil {
        return false
    }
    
    // Compare with expected value
    expected := sha256.Sum256([]byte("safe_disk"))
    return hmac.Equal(decrypted, expected[:])
}
```

## 文件加密

### AES-256-GCM 模式
- **算法**: AES-256-GCM（Galois/Counter Mode）
- **密钥长度**: 32 字节（256 bits）
- **IV 长度**: 12 字节（96 bits）
- **Tag 长度**: 16 字节（128 bits）

### 文件格式
```
[IV(12 bytes)] + [Ciphertext(N bytes)] + [Tag(16 bytes)]
```

### 实际实现（Go 代码）

```go
// native/crypto/aes_gcm.go
func EncryptAESGCM(plaintext, key []byte) ([]byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, err
    }
    
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, err
    }
    
    // Generate random IV
    iv := make([]byte, gcm.NonceSize())
    if _, err := io.ReadFull(rand.Reader, iv); err != nil {
        return nil, err
    }
    
    // Encrypt: IV + ciphertext + tag
    ciphertext := gcm.Seal(iv, iv, plaintext, nil)
    return ciphertext, nil
}

func DecryptAESGCM(ciphertext, key []byte) ([]byte, error) {
    block, err := aes.NewCipher(key)
    if err != nil {
        return nil, err
    }
    
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, err
    }
    
    // Extract IV
    ivSize := gcm.NonceSize()
    if len(ciphertext) < ivSize {
        return nil, errors.New("ciphertext too short")
    }
    
    iv := ciphertext[:ivSize]
    ciphertext = ciphertext[ivSize:]
    
    // Decrypt
    plaintext, err := gcm.Open(nil, iv, ciphertext, nil)
    if err != nil {
        return nil, err
    }
    
    return plaintext, nil
}
```

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

## FFI 接口

### Go 导出的 C 函数

```go
// native/main.go
package main

import "C"

//export DeriveKey
func DeriveKey(inputPass *C.char, iterN C.int) *C.char {
    // 返回 base64 编码的 32 字节密钥
}

//export VerifyPassword
func VerifyPassword(checkBase64, inputPass *C.char, iterN C.int) C.int {
    // 返回 1 表示密码正确，0 表示错误
}

//export EncryptData
func EncryptData(plaintextBase64, keyBase64 *C.char) *C.char {
    // 返回 base64 编码的密文
}

//export DecryptData
func DecryptData(ciphertextBase64, keyBase64 *C.char) *C.char {
    // 返回 base64 编码的明文
}

//export LoadCryptionConfig
func LoadCryptionConfig(dirPath *C.char) *C.char {
    // 返回 JSON 字符串或空字符串
}

func main() {}
```

### Dart FFI 绑定

```dart
// lib/native/bindings.dart
typedef DeriveKeyC = Pointer<Utf8> Function(Pointer<Utf8> inputPass, Int32 iterN);
typedef DeriveKeyDart = Pointer<Utf8> Function(Pointer<Utf8> inputPass, int iterN);

class NativeBindings {
  final DynamicLibrary _lib;
  late final DeriveKeyDart deriveKey;
  
  NativeBindings._(this._lib) {
    deriveKey = _lib.lookupFunction<DeriveKeyC, DeriveKeyDart>('DeriveKey');
  }
}
```

## 密钥缓存策略

```
┌─────────────────────────────────┐
│      Key Cache (内存)           │
│  ┌───────────────────────────┐  │
│  │ 目录路径 → 密钥 (Base64)  │  │
│  │ 创建时间                  │  │
│  └───────────────────────────┘  │
│  TTL: 1 小时                    │
│  清零: 退出应用时               │
└─────────────────────────────────┘
```

### 实际实现（Dart 代码）

```dart
// lib/services/crypto_service.dart
class CryptoService {
  final Map<String, String> _keyCache = {}; // path -> keyBase64
  
  String? getCachedKey(String dirPath) => _keyCache[dirPath];
  
  Future<bool> verifyPassword(EncryptedDirectory dir, String password) async {
    final key = deriveKey(password, dir.config.iterN);
    final isValid = _native.verifyPassword(dir.config.check, password, dir.config.iterN);
    
    if (isValid) {
      _keyCache[dir.path] = key; // 缓存密钥
    }
    
    return isValid;
  }
  
  void clearCache() {
    _keyCache.clear();
  }
}
```

## 两种模式对比

| 特性 | 不可变密码模式 | 可变密码模式 |
|------|--------------|------------|
| 本地存储 | 无密钥 | 加密后的 fileKey |
| 安全性 | 最高 | 高 |
| 修改密码 | 需重新加密所有文件 | 只改密钥密文 |
| 适用场景 | 极度安全需求 | 需要定期修改密码 |
| 创建时选择 | 默认推荐 | 可选 |

## 推荐使用场景

**可变密码模式**（默认推荐）：
- ✅ 支持修改密码，无需重新加密文件
- ✅ 适合需要定期修改密码的场景
- ✅ 便利性优先

**不可变密码模式**（高级选项）：
- 敏感数据，不希望本地存储任何密钥信息
- 极度安全需求
- 安全性优先，需显式启用

**默认行为**：创建加密目录时，默认为**可变密码模式**，只有在显式指定参数时才使用不可变密码模式。

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

## 已实现功能

- ✅ 密钥派生（HMAC-SHA256）
- ✅ AES-256-GCM 加解密
- ✅ 密码验证
- ✅ 加密目录检测（向上查找）
- ✅ 嵌套加密目录支持（独立密钥）
- ✅ FFI 接口
- ✅ Dart 绑定
