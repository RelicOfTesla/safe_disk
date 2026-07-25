# Stream V3 设计文档

## 项目信息
- **项目名称**: Safe Disk 加密文件浏览器
- **功能模块**: Stream 格式重构
- **设计日期**: 2026-04-04
- **版本**: V3

## 设计目标

1. **优化追加写入**：新块直接追加到文件末尾，不需要重新计算偏移量
2. **优化删除操作**：使用标记删除，支持垃圾回收
3. **降低元数据开销**：使用固定块大小，简化索引结构
4. **保持 O(1) 随机访问**：继续支持快速随机定位
5. **向后兼容**：支持读取 V2 格式文件

## V2 设计问题分析

### 当前文件格式（V2）
```
+------------------+
| Header (48 B)    | 魔数、版本、标志、块数量、块大小等
+------------------+
| Merkle Tree      | 数据完整性验证（2n-1 个节点）
+------------------+
| Index Table      | 块索引表（每块 12 bytes）
+------------------+
| Block 0          | IV(12) + Ciphertext + Tag(16)
+------------------+
| Block 1          |
+------------------+
| ...              |
+------------------+
```

### 问题列表

| 问题 | 影响 | 严重程度 |
|------|------|---------|
| 删除块需要移动后续所有数据 | 性能差，写入量大 | 高 |
| 添加块需要重新计算所有偏移量 | 性能差，写入量大 | 高 |
| Merkle Tree 占用空间大（2n-1 个节点） | 元数据开销大 | 中 |
| Index Table 在文件中间，更新需要移动数据 | 性能差 | 中 |
| 块大小固定，最后一块可能浪费空间 | 存储浪费 | 低 |

## V3 设计方案

### 核心设计理念

**追加写入（Append-Only）**：
- 新块总是追加到文件末尾
- 删除使用标记删除（tombstone）
- 定期垃圾回收整理碎片

**固定块大小**：
- 使用固定块大小，简化索引计算
- 偏移量 = HeaderSize + BlockIndex * BlockSize
- 不需要存储每个块的大小

**可选完整性验证**：
- Merkle Tree 改为可选
- 小文件可以不启用
- 降低元数据开销

### 文件格式（V3）

```
+------------------+
| Header (64 B)    | 魔数、版本、标志、块数量、块大小等
+------------------+
| Block 0          | IV(12) + Ciphertext + Tag(16)
+------------------+
| Block 1          |
+------------------+
| ...              |
+------------------+
| Block N-1        |
+------------------+
| Tombstone Bitmap | 标记已删除的块（可选）
+------------------+
| Merkle Tree      | 可选的完整性验证（仅叶子节点）
+------------------+
```

### Header 格式（64 bytes）

```go
type FileHeaderV3 struct {
    Magic            [4]byte  // "SDC3"
    Version          uint32   // 3
    Flags            uint32   // 标志位
    BlockCount       uint32   // 有效块数量（不包括已删除）
    TotalBlockCount  uint32   // 总块数量（包括已删除）
    BlockSize        uint32   // 块大小（固定）
    TotalSize        uint64   // 原始文件总大小（明文）
    TombstoneOffset  uint64   // Tombstone Bitmap 偏移量
    MerkleOffset     uint64   // Merkle Tree 偏移量
    Reserved         [16]byte // 保留字段
}
```

### 块格式

**固定大小块**：
- 每个块大小固定为 BlockSize
- 块格式：IV(12) + Ciphertext + Tag(16) + Padding
- Padding 用于填充到固定大小

**块定位**：
```
BlockOffset = HeaderSize + BlockIndex * TotalBlockSize
TotalBlockSize = BlockSize + IVSize + TagSize
```

### Tombstone Bitmap

**作用**：标记已删除的块，支持标记删除

**格式**：
- 每个块 1 bit，1 表示已删除，0 表示有效
- 大小：ceil(TotalBlockCount / 8) bytes
- 位于文件末尾

**示例**：
```
TotalBlockCount = 1600
BitmapSize = ceil(1600 / 8) = 200 bytes
```

### Merkle Tree（简化版）

**优化**：只存储叶子节点，降低开销

**格式**：
- 仅存储叶子节点的哈希值
- 大小：BlockCount * 32 bytes
- 内部节点可以实时计算

**对比**：
```
V2: 2n-1 个节点
V3: n 个节点（仅叶子）

100MB 文件（1600 块）：
  V2: 3199 * 32 = 102,368 bytes
  V3: 1600 * 32 = 51,200 bytes
  
节省：50%
```

### 标志位定义

```go
const (
    FlagV3TombstoneEnabled uint32 = 1 << iota  // 启用 Tombstone
    FlagV3MerkleEnabled                         // 启用 Merkle Tree
    FlagV3Reserved1                             // 保留
    FlagV3Reserved2                             // 保留
)
```

## 操作设计

### 1. 创建文件

```go
func CreateV3(path string, key []byte, blockSize int) error {
    // 1. 创建 Header
    header := FileHeaderV3{
        Magic:   [4]byte{'S', 'D', 'C', '3'},
        Version: 3,
        BlockSize: uint32(blockSize),
    }
    
    // 2. 写入 Header
    WriteHeader(path, &header)
    
    // 3. 追加写入块（后续）
}
```

### 2. 添加块

```go
func AddBlock(path string, data []byte) error {
    // 1. 读取 Header
    header := ReadHeader(path)
    
    // 2. 计算新块偏移量
    offset := HeaderSize + header.TotalBlockCount * TotalBlockSize
    
    // 3. 加密块
    encryptedBlock := EncryptBlock(data)
    
    // 4. 追加写入文件末尾
    file, _ := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
    file.WriteAt(encryptedBlock, offset)
    
    // 5. 更新 Header（块数量 +1）
    header.TotalBlockCount++
    header.BlockCount++
    WriteHeader(path, &header)
}
```

**优势**：
- ✅ O(1) 追加操作
- ✅ 不需要重新计算偏移量
- ✅ 不需要移动数据

### 3. 删除块

```go
func DeleteBlock(path string, index int) error {
    // 1. 读取 Header
    header := ReadHeader(path)
    
    // 2. 检查 Tombstone Bitmap
    if IsTombstone(header, index) {
        return ErrBlockAlreadyDeleted
    }
    
    // 3. 标记删除
    SetTombstone(header, index, true)
    
    // 4. 更新 Header（有效块数量 -1）
    header.BlockCount--
    
    // 5. 写回 Header 和 Tombstone Bitmap
    WriteHeader(path, &header)
    WriteTombstoneBitmap(path, header)
}
```

**优势**：
- ✅ O(1) 删除操作
- ✅ 不需要移动数据
- ✅ 标记删除，可恢复

### 4. 随机访问

```go
func ReadBlock(path string, index int) ([]byte, error) {
    // 1. 读取 Header
    header := ReadHeader(path)
    
    // 2. 检查 Tombstone
    if IsTombstone(header, index) {
        return nil, ErrBlockDeleted
    }
    
    // 3. 计算块偏移量（O(1)）
    offset := HeaderSize + index * TotalBlockSize
    
    // 4. 读取块
    file, _ := os.Open(path)
    blockData := make([]byte, TotalBlockSize)
    file.ReadAt(blockData, offset)
    
    // 5. 解密块
    return DecryptBlock(blockData)
}
```

**优势**：
- ✅ O(1) 定位复杂度
- ✅ 与 V2 相同的随机访问性能

### 5. 垃圾回收

```go
func GarbageCollect(path string) error {
    // 1. 读取 Header 和 Tombstone Bitmap
    header := ReadHeader(path)
    bitmap := ReadTombstoneBitmap(path, header)
    
    // 2. 创建临时文件
    tempPath := path + ".tmp"
    CreateV3(tempPath, key, header.BlockSize)
    
    // 3. 复制有效块
    newBlockIndex := 0
    for i := 0; i < header.TotalBlockCount; i++ {
        if !IsTombstone(bitmap, i) {
            blockData := ReadBlock(path, i)
            AddBlock(tempPath, blockData)
            newBlockIndex++
        }
    }
    
    // 4. 替换原文件
    os.Rename(tempPath, path)
}
```

**触发条件**：
- 手动触发
- 碎片率超过阈值（如 30%）
- 文件关闭时（可选）

## 向后兼容

### 读取 V2 格式

```go
func OpenFile(path string) (FileFormat, error) {
    // 1. 读取魔数
    magic := ReadMagic(path)
    
    // 2. 判断格式
    switch string(magic) {
    case "SDC2":
        return OpenV2File(path)
    case "SDC3":
        return OpenV3File(path)
    default:
        return nil, ErrUnknownFormat
    }
}
```

### V2 到 V3 转换

```go
func ConvertV2ToV3(v2Path, v3Path string) error {
    // 1. 打开 V2 文件
    v2File := OpenV2File(v2Path)
    
    // 2. 创建 V3 文件
    CreateV3(v3Path, key, v2File.Header.BlockSize)
    
    // 3. 复制所有块
    for i := 0; i < v2File.Header.ChunkCount; i++ {
        blockData := v2File.DecryptBlock(i)
        AddBlock(v3Path, blockData)
    }
}
```

## 性能对比

### 追加操作

| 操作 | V2 | V3 | 改进 |
|------|----|----|------|
| 添加 1 个块 | 重写整个文件 | 追加 64KB | **99.9%+** |
| 添加 10 个块 | 重写整个文件 | 追加 640KB | **99.9%+** |

### 删除操作

| 操作 | V2 | V3 | 改进 |
|------|----|----|------|
| 删除 1 个块 | 重写整个文件 | 更新 Header + Bitmap | **99.9%+** |
| 删除 10 个块 | 重写整个文件 | 更新 Header + Bitmap | **99.9%+** |

### 随机访问

| 操作 | V2 | V3 | 改进 |
|------|----|----|------|
| 定位复杂度 | O(1) | O(1) | 相同 |
| 平均延迟 | < 0.5ms | < 0.5ms | 相同 |
| 吞吐量 | ~150 MB/s | ~150 MB/s | 相同 |

### 元数据开销

| 文件大小 | V2 Merkle | V3 Merkle | 节省 |
|---------|-----------|-----------|------|
| 100MB | 102 KB | 51 KB | 50% |
| 1GB | 1.02 MB | 512 KB | 50% |
| 10GB | 10.2 MB | 5.12 MB | 50% |

## 实现计划

### 阶段 1：核心实现
1. 定义 V3 文件格式结构
2. 实现 Header、Block、Tombstone Bitmap 操作
3. 实现基础的创建、添加、读取功能

### 阶段 2：优化实现
1. 实现删除操作（标记删除）
2. 实现垃圾回收功能
3. 实现简化的 Merkle Tree

### 阶段 3：向后兼容
1. 实现 V2 格式检测和读取
2. 实现 V2 到 V3 转换功能
3. 测试兼容性

### 阶段 4：测试和优化
1. 单元测试
2. 性能测试
3. 压力测试
4. 内存占用测试

## 验收标准

- ✅ 支持 O(1) 追加操作
- ✅ 支持 O(1) 删除操作（标记删除）
- ✅ 支持 O(1) 随机访问
- ✅ 元数据开销降低 50%
- ✅ 向后兼容 V2 格式
- ✅ 所有测试通过

## 风险和限制

### 风险
1. **文件碎片**：频繁的删除和添加可能导致碎片，需要定期垃圾回收
2. **块大小固定**：不支持动态块大小，可能不适合所有场景
3. **兼容性**：需要同时支持 V2 和 V3 格式

### 限制
1. **最后一块浪费空间**：固定块大小可能导致最后一块空间浪费
2. **垃圾回收开销**：需要额外的垃圾回收操作
3. **Tombstone Bitmap 大小**：超大文件可能导致 Bitmap 过大

## 总结

V3 设计通过以下关键优化解决了 V2 的主要问题：

1. **追加写入**：O(1) 添加操作，不需要重写文件
2. **标记删除**：O(1) 删除操作，不需要移动数据
3. **简化 Merkle Tree**：元数据开销降低 50%
4. **保持 O(1) 随机访问**：与 V2 相同的性能

---

**下一步**：实现 V3 核心功能

---

## 实施现状与路线图


## 当前证据

| 项目 | 进度 | 证据 |
|---|---:|---|
| 格式设计草案 | 70% | [STREAM_V3_DESIGN.md](STREAM_V3_DESIGN.md) 存在，但完整性、崩溃一致性和 key/nonce 生命周期仍需评审 |
| sec_fs 数据层实现 | 10% | crypto_data 有随机访问基础，但没有经评审的 Stream V3 格式实现 |
| FFI ABI | 0% | 当前 C ABI 无活跃 incremental exports |
| Dart binding/service | 20% | model/service 残留；`NativeLib` 所有 incremental 方法返回 unsupported |
| Flutter UI | 0% | 无可用入口 |
| 自动化实际功能测试 | 0% | 当前 test 目录无 Stream V3 真 FFI 随机编辑测试 |

## 阶段 1：设计冻结

**进度：35%**

| 任务 | 进度 | 验收条件 |
|---|---:|---|
| 明确非兼容策略 | 80% | 文档、CLI/FFI 不再要求读取 V1/V2；迁移仅作为显式离线工具另行决策 |
| 文件格式与版本字段 | 60% | header/index/tombstone 布局定稿，定义大小端、上限和损坏行为 |
| AEAD nonce/key 模型 | 30% | 证明块重写、追加、GC 不复用 nonce，key 派生域分离 |
| 完整性模型 | 25% | 定义单块验证、全文件认证、metadata 防篡改和截断攻击处理 |
| 崩溃一致性模型 | 20% | 定义 append/index commit、fsync 点、恢复和 GC 原子切换 |
| 资源预算 | 20% | 定义内存、FD、单次写放大和最大文件/块数量 |

阶段退出条件：设计评审通过，测试 oracle 和故障注入点可以从格式规范直接推导。

## 阶段 2：sec_fs 原型

**进度：10%**

| 任务 | 进度 | 验收条件 |
|---|---:|---|
| Stream V3 reader/writer | 10% | create/open/read/write/append/close 实现且不全文件入内存 |
| 随机位置修改 | 5% | 5 个随机位置增删改 1-2000 bytes，结果与明文 oracle 一致 |
| tombstone 与 GC | 0% | 删除、碎片统计、GC 到新文件并原子切换 |
| 完整性验证 | 0% | metadata、块、截断和重排篡改均可检测 |
| 崩溃恢复 | 0% | 每个 commit checkpoint 的真实 kill 测试 |

阶段退出条件：sec_fs 层自动化实际功能与故障测试全部通过，才可达到 100% 并迁档。

## 阶段 3：FFI/Dart

**进度：5%**

| 任务 | 进度 | 验收条件 |
|---|---:|---|
| C ABI 设计 | 10% | handle 所有权、错误码、cancel/progress 和 buffer 释放明确 |
| Go exports 与 header | 0% | 单一来源生成并通过 ABI 检查 |
| Dart bindings | 0% | 移除 unsupported stub，worker isolate 执行 |
| 真动态库测试 | 0% | Dart 创建/修改/关闭/重开，Go/CLI 反向读取并校验 |

## 阶段 4：CLI/UI 与性能

**进度：0%**

| 任务 | 进度 | 验收条件 |
|---|---:|---|
| CLI 检查/GC/转换工具 | 0% | 明确是否属于 MVP，真实二进制测试 |
| 编辑器接入 | 0% | 保存不重写整个大文件，异常退出可恢复 |
| 性能基线 | 0% | 与全量重写比较时间、写放大、内存和空间放大 |
| 跨平台 | 0% | Linux/Windows 实际文件系统测试 |

## 风险

1. append-only 与“固定偏移 O(1)”不能同时无条件成立；变长编辑需要索引或 copy-on-write。
2. 仅叶子 hash 不能自动证明 metadata、顺序和文件长度完整性。
3. tombstone/GC 会引入第二套提交与恢复协议，必须先于 UI 接入完成故障测试。
4. Dart 残留 service/model 容易制造“已经接入”的错觉；在 ABI 未实现前必须继续显式 unsupported。

## 当前下一步

1. 修订 [STREAM_V3_DESIGN.md](STREAM_V3_DESIGN.md)，删除旧兼容假设和不存在实现的描述。
2. 完成 nonce、完整性、崩溃一致性评审。
3. 先实现 sec_fs 原型和真实 kill/篡改测试，再设计 FFI；不从 UI stub 反推底层格式。
