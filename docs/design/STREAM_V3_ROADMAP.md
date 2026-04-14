# Stream V3 实施路线图

## 项目信息
- **项目名称**: Safe Disk 加密文件浏览器
- **功能模块**: Stream 格式重构
- **日期**: 2026-04-04

## 当前状态

### 已完成
- ✅ V3 设计文档（`docs/design/STREAM_V3_DESIGN.md`）
- ✅ V3 核心实现（`native/crypto/stream_v3.go`）
  - StreamEncryptorV3：追加写入、固定块大小
  - StreamDecryptorV3：O(1) 随机访问
  - Tombstone Bitmap：标记删除

### 待完成

根据用户强调的架构约束，还需要以下工作：

## 阶段 1：架构调整（高优先级）

### 1.1 移动 crypto 到 sec_fs/crypto

**目标**：将 `native/crypto` 移动到 `native/sec_fs/crypto`

**影响文件**：
- 所有导入 `github.com/safedisk/native/crypto` 的文件
- 需要更新导入路径为 `github.com/safedisk/native/sec_fs/crypto`

**步骤**：
```bash
# 1. 创建目标目录
mkdir -p native/sec_fs/crypto

# 2. 移动文件
mv native/crypto/* native/sec_fs/crypto/

# 3. 更新所有导入路径（需要修改很多文件）
# - native/sec_fs/*.go
# - native/ffs_sec_fs/*.go
# - native/service/*.go
# - native/ffi_sec_fs/
# 等等...
```

**风险**：大量文件需要修改，可能引入错误

### 1.2 重构 SecFile

**目标**：SecFile 使用 crypt impl interface 调用实际算法，不用内存模拟

**当前实现问题**：
```go
// root.go - OpenFile()
case "r":
    // 问题：解密整个文件到内存
    data, err := decryptor.DecryptToData()
    handle.data = data  // 存储在内存中
```

**应该的做法**：
```go
type SecFile struct {
    decryptor crypto.IIncrementalCryptor  // 持有加密器接口
    encryptor crypto.IIncrementalCryptor
    offset    int64
    // 不存储 data []byte
}

func (f *SecFile) Read(size int) ([]byte, int, error) {
    // 直接调用 decryptor.DecryptRange(f.offset, size)
    data, err := f.decryptor.(crypto.IIncrementalCryptor).GetBlock(blockIndex)
    // 或使用 DecryptRange（如果接口支持）
}
```

**影响文件**：
- `native/sec_fs/file.go` - 完全重写
- `native/sec_fs/root.go` - OpenFile 方法重写

### 1.3 集成 V3 实现

**目标**：将 V3 实现集成到 cryptor_maker

**当前问题**：
- `cryptor_maker.go` 中的 incrementalEncryptor/incrementalDecryptor 是 stub
- 内部使用 chunkedEncryptor/chunkedDecryptor
- 没有使用真正的 IncrementalEncryptor/IncrementalDecryptor

**应该的做法**：
```go
type incrementalEncryptor struct {
    source    IEncryptSource
    key       []byte
    blockSize int
    impl      *IncrementalEncryptor  // 使用真正的实现
}

func (e *incrementalEncryptor) EncryptToFile(path string) error {
    // 使用 IncrementalEncryptor
    e.impl.Create(path, e.key, e.blockSize)
    // ... 分块写入
    e.impl.Finalize()
}
```

**影响文件**：
- `native/sec_fs/crypto/cryptor_maker.go`（移动后）

## 阶段 2：完善 V3 实现（中优先级）

### 2.1 实现完整 IIncrementalCryptor 接口

**当前缺失**：
- ModifyBlock(index int, data []byte) error
- DeleteBlock(index int) error
- Flush() error

**需要添加到**：
- `StreamEncryptorV3`
- 或创建统一的 `StreamCryptorV3` 同时支持读写

### 2.2 实现 Merkle Tree

**当前状态**：
- V3 设计支持简化的 Merkle Tree（仅叶子节点）
- 当前实现写入 placeholder（全零）

**需要实现**：
- 构建 Merkle Tree
- 写入叶子节点哈希
- 验证完整性

### 2.3 实现垃圾回收

**当前状态**：
- V3 设计支持标记删除
- 但没有垃圾回收机制

**需要实现**：
- GarbageCollect() 方法
- 整理碎片，移除已删除块
- 更新索引

## 阶段 3：测试和优化（中优先级）

### 3.1 单元测试
- V3 格式创建和读取
- 追加写入测试
- 标记删除测试
- 随机访问测试

### 3.2 性能测试
- 追加写入性能（应该 O(1)）
- 删除性能（应该 O(1)）
- 随机访问性能（应该 O(1)，延迟 < 1ms）
- 元数据开销对比

### 3.3 兼容性测试
- V2 格式读取
- V2 到 V3 转换

## 阶段 4：集成和部署（低优先级）

### 4.1 FFI 接口
- 添加 V3 相关 FFI 函数
- 更新 Flutter 绑定

### 4.2 CLI 命令
- 添加 V3 格式转换命令
- 添加垃圾回收命令

### 4.3 UI 集成
- 自动选择 V3 格式（新文件）
- 支持 V2 格式读取
- 支持 V2 到 V3 转换

## 架构约束检查清单

根据用户强调的架构约束：

- [ ] crypto package 移入 sec_fs/crypto 内
- [ ] ffi/cli 禁止调用 crypto/service，应该调用 sec_fs
- [ ] service 禁止调用 crypto，应该调用 sec_fs
- [ ] SecFile 使用 crypt impl interface，不用内存模拟
- [ ] MemImplCrypto 移除（如果存在）
- [ ] MemZero 放入 sec_fs close 内清除
- [ ] service.Response 移入 /ffs_comm
- [ ] /ffs_comm 内添加 store（SecRoot/SecDirWalker/SecFile 的 int_id 转换器）

## 风险和注意事项

### 高风险
1. **移动 crypto 包**：大量文件需要修改，可能引入错误
2. **重构 SecFile**：影响所有文件操作，需要充分测试
3. **向后兼容**：需要确保 V2 格式文件仍然可以读取

### 建议
1. **分步实施**：不要一次性完成所有重构
2. **充分测试**：每个阶段都要有完整的测试
3. **保留回退**：保留旧代码，便于回退
4. **文档更新**：及时更新架构文档

## 时间估算

| 阶段 | 工作量 | 优先级 |
|------|--------|--------|
| 阶段 1.1：移动 crypto | 2-3 天 | 高 |
| 阶段 1.2：重构 SecFile | 3-5 天 | 高 |
| 阶段 1.3：集成 V3 | 2-3 天 | 高 |
| 阶段 2：完善 V3 | 3-5 天 | 中 |
| 阶段 3：测试 | 2-3 天 | 中 |
| 阶段 4：集成 | 2-3 天 | 低 |

**总计**：14-22 天

## 总结

Stream V3 设计已完成，核心实现已创建。后续工作主要是架构调整和集成，需要：

1. **遵守架构约束**：crypto 移入 sec_fs，SecFile 使用接口
2. **完善实现**：完整实现 IIncrementalCryptor 接口
3. **充分测试**：确保功能和性能符合要求
4. **向后兼容**：支持 V2 格式读取

---

**下一步**：根据优先级，选择从阶段 1.1 或 1.2 开始实施。
