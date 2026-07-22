# 历史设计归档 - 增量加密 FFI 模块

> **状态：未实现且已从活跃 Dart API 清理（2026-07-23）。** `native/ffi_sec_fs` 没有这些接口导出；此前的 Dart 服务和 `NativeLib` 占位桩均无调用且会返回失败。本文件保留原始设想，供未来重新设计时参考，不得作为当前能力或 API 约定。

## 概述

本文档描述了 Safe Disk 项目中增量加密模块的 FFI（Foreign Function Interface）接口。这些接口允许 Flutter 端调用 Go 语言实现的增量加密功能。

## 设计原则

1. **句柄管理**: 使用句柄 ID 来管理加密器/解密器实例，避免传递指针
2. **JSON 响应**: 所有 FFI 函数返回 JSON 格式的统一响应
3. **Base64 编码**: 二进制数据使用 Base64 编码传递
4. **内存安全**: Go 端使用全局 map 存储实例，Flutter 端通过句柄 ID 访问

## FFI 函数列表

### 1. 增量加密器操作

#### IncrementalEncryptorCreate

创建增量加密器并初始化目标文件。

**参数:**
- `dstPath`: 目标文件路径
- `keyBase64`: Base64 编码的 32 字节密钥（AES-256）
- `chunkSizeKB`: 块大小（KB），0 表示使用默认值 64 KB

**返回:**
```json
{
  "success": true,
  "code": 0,
  "handleID": 1
}
```

**错误:**
- `ErrInvalidKeySize`: 密钥长度不正确
- `ErrBase64Decode`: Base64 解码失败
- `ErrFileWrite`: 文件创建失败

---

#### IncrementalEncryptorAddBlock

向增量加密器添加一个数据块。

**参数:**
- `handleID`: 加密器句柄 ID
- `dataBase64`: Base64 编码的块数据

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrBase64Decode`: Base64 解码失败
- `ErrEncryptionFailed`: 加密失败

---

#### IncrementalEncryptorFinalize

完成增量加密并写入文件。

**参数:**
- `handleID`: 加密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrFileWrite`: 文件写入失败

---

#### IncrementalEncryptorClose

关闭增量加密器（不完成写入）。

**参数:**
- `handleID`: 加密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID

---

### 2. 增量解密器操作

#### IncrementalDecryptorOpen

打开增量加密文件并初始化解密器。

**参数:**
- `srcPath`: 源加密文件路径
- `keyBase64`: Base64 编码的 32 字节密钥（AES-256）

**返回:**
```json
{
  "success": true,
  "code": 0,
  "handleID": 2,
  "chunkCount": 10,
  "totalSize": 655360,
  "chunkSize": 65536
}
```

**错误:**
- `ErrInvalidKeySize`: 密钥长度不正确
- `ErrBase64Decode`: Base64 解码失败
- `ErrFileOpen`: 文件打开失败
- `ErrInvalidStreamFormat`: 文件格式无效

---

#### IncrementalDecryptorDecryptBlock

解密指定索引的块。

**参数:**
- `handleID`: 解密器句柄 ID
- `blockIndex`: 块索引（从 0 开始）

**返回:**
```json
{
  "success": true,
  "code": 0,
  "data": "SGVsbG8gV29ybGQh..."
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrInvalidChunkFormat`: 块索引越界
- `ErrDecryptionFailed`: 解密失败

---

#### IncrementalDecryptorDecryptRange

解密指定字节范围的数据。

**参数:**
- `handleID`: 解密器句柄 ID
- `offset`: 明文数据的字节偏移
- `length`: 要解密的字节数

**返回:**
```json
{
  "success": true,
  "code": 0,
  "data": "SGVsbG8gV29ybGQh..."
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrInvalidChunkFormat`: 偏移超出文件大小
- `ErrDecryptionFailed`: 解密失败

---

#### IncrementalDecryptorDecryptAll

解密整个文件。

**参数:**
- `handleID`: 解密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0,
  "data": "SGVsbG8gV29ybGQh..."
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrDecryptionFailed`: 解密失败

---

#### IncrementalDecryptorVerifyBlockIntegrity

验证指定块的完整性（使用 Merkle 树）。

**参数:**
- `handleID`: 解密器句柄 ID
- `blockIndex`: 块索引（从 0 开始）

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrInvalidChunkFormat`: 块索引越界
- `ErrDataCorrupted`: 数据损坏或被篡改

---

#### IncrementalDecryptorVerifyIntegrity

验证整个文件的完整性（使用 Merkle 树）。

**参数:**
- `handleID`: 解密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrDataCorrupted`: 数据损坏或被篡改

---

#### IncrementalDecryptorGetBlockInfo

获取指定块的信息。

**参数:**
- `handleID`: 解密器句柄 ID
- `blockIndex`: 块索引（从 0 开始）

**返回:**
```json
{
  "success": true,
  "code": 0,
  "blockInfo": {
    "index": 0,
    "offset": 1234,
    "size": 65600,
    "plaintextSize": 65536,
    "hash": "YWJjZGVmZ2hpamtsbW5vcA=="
  }
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID
- `ErrInvalidChunkFormat`: 块索引越界

---

#### IncrementalDecryptorGetAllBlockInfo

获取所有块的信息。

**参数:**
- `handleID`: 解密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0,
  "blockInfos": [
    {
      "index": 0,
      "offset": 1234,
      "size": 65600,
      "plaintextSize": 65536,
      "hash": "YWJjZGVmZ2hpamtsbW5vcA=="
    },
    ...
  ]
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID

---

#### IncrementalDecryptorClose

关闭增量解密器。

**参数:**
- `handleID`: 解密器句柄 ID

**返回:**
```json
{
  "success": true,
  "code": 0
}
```

**错误:**
- `ErrInvalidParameter`: 无效的句柄 ID

---

### 3. 文件信息查询

#### IsIncrementalFile

检查文件是否为增量加密格式。

**参数:**
- `path`: 文件路径

**返回:**
```json
{
  "success": true,
  "code": 0,
  "isIncremental": true
}
```

**错误:**
- `ErrFileOpen`: 文件打开失败
- `ErrFileRead`: 文件读取失败

---

#### GetIncrementalFileInfo

获取增量加密文件的元数据。

**参数:**
- `path`: 文件路径

**返回:**
```json
{
  "success": true,
  "code": 0,
  "header": {
    "version": 2,
    "flags": 3,
    "chunkCount": 10,
    "chunkSize": 65536,
    "totalSize": 655360,
    "merkleRootOffset": 48,
    "indexTableOffset": 368
  }
}
```

**错误:**
- `ErrFileOpen`: 文件打开失败
- `ErrInvalidStreamFormat`: 文件格式无效

---

## 使用示例

### Dart/Flutter 端使用示例

```dart
import 'package:safedisk/native/native_lib.dart';

// 创建增量加密器
final nativeLib = NativeLib.instance;

// 创建加密器
final createResult = nativeLib.incrementalEncryptorCreate(
  '/path/to/output.enc',
  keyBase64,
  64, // 64 KB chunks
);
final createJson = jsonDecode(createResult);
final handleID = createJson['handleID'];

// 添加数据块
final data = utf8.encode('Hello, World!');
final dataBase64 = base64.encode(data);
nativeLib.incrementalEncryptorAddBlock(handleID, dataBase64);

// 完成加密
nativeLib.incrementalEncryptorFinalize(handleID);

// 解密文件
final openResult = nativeLib.incrementalDecryptorOpen(
  '/path/to/output.enc',
  keyBase64,
);
final openJson = jsonDecode(openResult);
final decHandleID = openJson['handleID'];

// 解密第一个块
final decryptResult = nativeLib.incrementalDecryptorDecryptBlock(decHandleID, 0);
final decryptJson = jsonDecode(decryptResult);
final decryptedData = base64.decode(decryptJson['data']);

// 关闭解密器
nativeLib.incrementalDecryptorClose(decHandleID);
```

---

## 错误代码

所有错误代码定义在 `native/errors/errors.go` 中。常用的错误代码包括：

| 错误代码 | 名称 | 描述 |
|---------|------|------|
| 0 | ErrSuccess | 操作成功 |
| 1 | ErrUnknown | 未知错误 |
| 2 | ErrInvalidParameter | 无效参数 |
| 100 | ErrInvalidKeySize | 密钥长度不正确 |
| 200 | ErrEncryptionFailed | 加密失败 |
| 201 | ErrDecryptionFailed | 解密失败 |
| 204 | ErrAuthTagMismatch | 认证标签不匹配 |
| 205 | ErrDataCorrupted | 数据损坏 |
| 300 | ErrInvalidStreamFormat | 无效的流格式 |
| 301 | ErrInvalidChunkFormat | 无效的块格式 |
| 400 | ErrFileNotFound | 文件未找到 |
| 401 | ErrFileRead | 文件读取失败 |
| 402 | ErrFileWrite | 文件写入失败 |
| 600 | ErrBase64Decode | Base64 解码失败 |

---

## 编译说明

### 编译 Go 动态库

```bash
cd native
go build -buildmode=c-shared -o linux/libsafedisk_native.so .
```

### Flutter 端使用

Flutter 端会自动加载动态库，路径在 `bindings.dart` 中定义：

```dart
final paths = [
  '/home/john/Desktop/dev/safe_disk/linux/libsafedisk_native.so',
  './linux/libsafedisk_native.so',
  'libsafedisk_native.so',
];
```

---

## 注意事项

1. **内存管理**: Go 端使用全局 map 存储加密器/解密器实例，使用完成后必须调用 Close 方法释放资源
2. **线程安全**: Go 端使用 sync.RWMutex 保护全局 map，支持多线程访问
3. **数据大小**: 对于大文件，建议使用较小的块大小（如 64 KB）以减少内存使用
4. **完整性验证**: 只有在文件创建时启用了 Merkle 树的文件才能进行完整性验证

---

## 更新历史

- 2026-04-03: 初始版本，实现增量加密模块的 FFI 接口
