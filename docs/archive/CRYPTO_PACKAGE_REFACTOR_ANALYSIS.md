# Crypto Package 重构分析报告

**创建时间**: 2026-04-04
**分析范围**: native/crypto, sec_fs/crypto, service 包
**状态**: 分析完成

---

## 一、执行摘要

### 核心发现

1. **native/crypto 已被移除** ✅ - 旧的 crypto package 已经不存在了
2. **sec_fs/crypto 已完成** ✅ - 包含完整的加密功能
3. **service 包仍需清理** ⚠️ - sec_fs 和 main.go 仍在使用 service 包

### 重构进度

| 阶段 | 状态 | 完成度 |
|------|------|--------|
| 移除 native/crypto | ✅ 已完成 | 100% |
| 创建 sec_fs/crypto | ✅ 已完成 | 100% |
| 清理 service 包依赖 | ⚠️ 进行中 | 30% |
| 删除 service 包 | ❌ 未开始 | 0% |

---

## 二、当前状态详细分析

### 2.1 native/crypto 的现状

**位置**: `native/crypto/`

**状态**: ❌ **已删除**

**结论**: 旧的 crypto package 已经被完全移除，没有任何代码引用 `"safe_disk/native/crypto"`。

```bash
$ grep -r "\"safe_disk/native/crypto\"" --include="*.go"
(no output)
```

### 2.2 sec_fs/crypto 的现状

**位置**: `native/sec_fs/crypto/`

**状态**: ✅ **已完成，功能完整**

**核心文件**（排除测试）：

| 文件 | 大小 | 功能描述 |
|------|------|----------|
| `interfaces.go` | 11.8 KB | 核心接口定义（ICryptorMaker, IEncryptor, IDecryptor, IIncrementalCryptor） |
| `cryptor_maker.go` | 20.1 KB | CryptorMaker 实现（工厂模式） |
| `incremental_encrypt.go` | 36.6 KB | 增量加密实现（支持随机访问和修改） |
| `incremental_encrypt_optimized.go` | 10.9 KB | 优化的增量加密 |
| `stream.go` | 10.2 KB | 流式加密 |
| `stream_v3.go` | 17.2 KB | 流式加密 v3 |
| `aes_gcm.go` | 2.3 KB | AES-GCM 加密 |
| `key_derive.go` | 9.0 KB | 密钥派生（PBKDF2） |
| `memzero.go` | 1.0 KB | 内存清零（安全清除） |
| `registry.go` | 10.9 KB | 加密实现注册表 |
| `crypt_source.go` | 5.1 KB | 加密源抽象（文件/数据/Reader） |
| `iter_benchmark.go` | 7.4 KB | 迭代次数基准测试 |

**核心接口**：

```go
// 加密模式
type CryptMode int
const (
    CryptModeNormal      // 标准加密
    CryptModeChunked     // 分块加密
    CryptModeIncremental // 增量加密
)

// 核心工厂接口
type ICryptorMaker interface {
    GetMode() CryptMode
    GetCapabilities() CryptorCapabilities
    GetConfigJson() string
    NewEncryptor(source IEncryptSource) IEncryptor
    NewDecryptor(source IDecryptSource) IDecryptor
    // ...
}

// 加密器接口
type IEncryptor interface {
    EncryptToFile(path string) error
    EncryptToData() ([]byte, error)
    EncryptToWriter(w io.Writer) error
}

// 解密器接口
type IDecryptor interface {
    DecryptToFile(path string) error
    DecryptToData() ([]byte, error)
    DecryptToWriter(w io.Writer) error
}

// 增量加密接口（支持随机访问和修改）
type IIncrementalCryptor interface {
    GetBlockCount() int
    GetBlockSize() int
    GetBlock(index int) ([]byte, error)
    ModifyBlock(index int, data []byte) error
    AddBlock(index int, data []byte) error
    DeleteBlock(index int) error
    Flush() error
}

// 加密实现注册表
type CryptImplCreator interface {
    Name() string
    Create(config *CryptorConfig, password string) (ICryptorMaker, error)
    CreateWithKey(key []byte, config *CryptorConfig) ICryptorMaker
    SupportedModes() []CryptMode
    // ...
}
```

**关键特性**：

1. ✅ **工厂模式**: 通过 `ICryptorMaker` 创建加密器
2. ✅ **注册表机制**: 支持动态注册加密实现（AES-GCM, ChaCha20 等）
3. ✅ **多种加密模式**: Normal, Chunked, Incremental
4. ✅ **增量加密**: 支持随机访问和修改，O(1) 定位
5. ✅ **流式加密**: 支持大文件加密
6. ✅ **内存安全**: `MemZero` 清除敏感数据
7. ✅ **性能优化**: 增量加密 99.6% 修改量减少

### 2.3 sec_fs 对 crypto 的重新导出

**位置**: `native/sec_fs/crypto_reexport.go`

**状态**: ✅ **已实现**

**目的**: 外部包（cli, service）应该通过 `sec_fs` 访问加密功能，而不是直接导入 `sec_fs/crypto`。

**重新导出的内容**：

```go
// 类型
type ICryptorMaker = crypto.ICryptorMaker
type IEncryptor = crypto.IEncryptor
type IDecryptor = crypto.IDecryptor
type IIncrementalCryptor = crypto.IIncrementalCryptor
// ...

// 函数
func DeriveKeyPBKDF2(password string, salt []byte, iterN int) ([]byte, error)
func AESGCMEncrypt(plaintext, key []byte) ([]byte, error)
func MemZero(b []byte)
func NewCryptorMakerWithKey(key []byte) ICryptorMaker
// ...
```

**问题**: ⚠️ service 包仍然直接导入 `sec_fs/crypto`，而不是通过 `sec_fs` 重新导出的接口。

---

## 三、service 包分析

### 3.1 service 包的当前状态

**位置**: `native/service/`

**状态**: ⚠️ **需要清理和删除**

**核心文件**（排除测试）：

| 文件 | 大小 | 主要功能 | 是否被使用 |
|------|------|----------|------------|
| `temp_key_manager.go` | 2.6 KB | 临时密钥管理 | ✅ sec_fs, main.go |
| `password_service.go` | 3.9 KB | 密码验证和密钥派生 | ✅ sec_fs |
| `crypto_service.go` | 14.5 KB | 加密服务（对 crypto 的封装） | ✅ sec_fs |
| `config_service.go` | 7.2 KB | 加密配置生成 | ✅ main.go |
| `encryption_service.go` | 10.9 KB | 文件/数据加密解密 | ✅ main.go |
| `directory_service.go` | 18.6 KB | 目录加密解密 | ❌ 未使用 |
| `cryptor_service.go` | 5.1 KB | 基于 ICryptorMaker 的高级操作 | ❌ 未使用 |
| `result.go` | 5.1 KB | JSON 响应结构 | ⚠️ 应移至 ffi_comm |

**依赖关系**：

```
service 包被以下包使用：
├── native/sec_fs/          (3个文件)
│   ├── session.go          (TemporaryKeyManager, PasswordService, CryptoService)
│   ├── root.go             (CryptoService)
│   └── file.go             (CryptoService)
├── native/main.go（已迁移至 native/ffi_sec_fs/）(4个服务)
│   ├── TemporaryKeyManager
│   ├── PasswordService
│   ├── EncryptionService
│   └── ConfigService
└── native/cli/             (通过 sec_fs 间接使用)
```

### 3.2 service 包的功能分析

#### 3.2.1 TemporaryKeyManager

**位置**: `service/temp_key_manager.go`

**功能**:
- 管理临时密钥（带过期时间）
- 生成随机 key ID
- 存储、获取、删除密钥
- 清理过期密钥
- 使用 `crypto.MemZero` 清零密钥

**使用位置**:
- `sec_fs/session.go`: `SessionManager` 使用
- `main.go`: 全局变量

**迁移建议**: 
- ✅ 移入 `sec_fs/internal/key_manager.go`
- 原因：这是 sec_fs SessionManager 的内部实现细节
- 或者移入 `sec_fs/crypto/key_manager.go`（如果 crypto 层需要）

#### 3.2.2 PasswordService

**位置**: `service/password_service.go`

**功能**:
- 密码验证（支持 legacy HMAC 和 PBKDF2）
- 文件密钥派生
- 从配置 JSON 解析

**使用位置**:
- `sec_fs/session.go`: `SessionManager.OpenRoot()` 使用

**迁移建议**: 
- ✅ 功能移入 `sec_fs/crypto/` 或 `sec_fs/internal/`
- 原因：密码验证和密钥派生是加密核心功能

#### 3.2.3 CryptoService

**位置**: `service/crypto_service.go`

**功能**:
- 对 `crypto` 包的封装
- 提供密码验证、密钥派生、文件密钥加密/解密
- `MemZero` 等内存安全功能

**使用位置**:
- `sec_fs/session.go`: `SessionManager` 使用（MemZero）
- `sec_fs/root.go`: `SecRoot` 使用（MemZero）
- `sec_fs/file.go`: `SecFile` 使用（MemZero）

**迁移建议**: 
- ✅ **删除**，直接使用 `sec_fs/crypto.MemZero()`
- 原因：只是对 crypto 的封装，不必要

#### 3.2.4 ConfigService

**位置**: `service/config_service.go`

**功能**:
- 生成加密配置（salt, iterN, encryptedChallengeId）
- 计算最优迭代次数（基于设备性能）
- 支持 mutable 模式（唯一文件密钥）

**使用位置**:
- `main.go`: `GenerateEncryptionConfig` FFI 接口

**迁移建议**: 
- ✅ 功能移入 `sec_fs/config_manage/`
- 或者：直接在 main.go 中实现（因为是 FFI 特有的逻辑）

#### 3.2.5 EncryptionService

**位置**: `service/encryption_service.go`

**功能**:
- 文件/数据加密解密
- 依赖 TemporaryKeyManager

**使用位置**:
- `main.go`: 全局变量（但可能未实际使用）

**迁移建议**: 
- ✅ **删除**
- 原因：功能已被 `sec_fs` 和 `sec_transfer` 替代

#### 3.2.6 DirectoryService

**位置**: `service/directory_service.go`

**功能**:
- 目录加密解密的异步任务管理

**使用位置**:
- ❌ 未被使用

**迁移建议**: 
- ✅ **删除**
- 原因：功能已被 `sec_transfer` 替代

#### 3.2.7 CryptorService

**位置**: `service/cryptor_service.go`

**功能**:
- 基于 ICryptorMaker 的高级加密操作

**使用位置**:
- ❌ 未被使用

**迁移建议**: 
- ✅ **删除**
- 原因：不必要，直接使用 ICryptorMaker 即可

#### 3.2.8 result.go

**位置**: `service/result.go`

**功能**:
- JSON 响应结构（`Response`, `JsonResult` 等）

**使用位置**:
- ⚠️ 应该移至 `ffi_comm`

**迁移建议**: 
- ✅ 移入 `ffi_comm/response.go`
- 原因：这是 FFI 专用的响应格式

---

## 四、重构方案

### 4.1 总体重构思路

根据 ARCHITECTURE_REFACTOR_PLAN.md 的阶段 4（清理旧代码），service 包应该被重构并最终删除。

**重构原则**：
1. ✅ 大重构原则：可以不考虑旧数据、代码、接口、用法等兼容，允许彻底重写
2. ✅ 架构约束：crypto package 应当移入 sec_fs/crypto 内，外部避免使用
3. ✅ 减少 service 包的调用：sec_fs 和 main.go 应该减少对 service 的依赖

**重构后的依赖关系**：

```
┌─────────────────────────────────────────────────────────────┐
│                     External Consumers                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   CLI    │  │   FFI    │  │  Flutter │  │   main   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      New API Layer                           │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  sec_fs  │  │ sec_transfer │  │  ffi_comm    │          │
│  │(文件操作)│  │ (目录传输)   │  │ (ID映射管理) │          │
│  └──────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Core Crypto Layer                         │
│  ┌────────────────────────────────────────────────────┐    │
│  │              sec_fs/crypto                          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 分阶段迁移计划

#### 阶段 1: 迁移 TemporaryKeyManager（优先级：P0）

**目标**: 将 TemporaryKeyManager 移入 sec_fs/internal/

**步骤**:
1. 创建 `sec_fs/internal/key_manager.go`
2. 复制 `service/temp_key_manager.go` 的内容
3. 更新 `sec_fs/session.go` 的导入路径
4. 更新 `main.go`，移除对 service.TemporaryKeyManager 的使用
5. 删除 `service/temp_key_manager.go`

**预计时间**: 1-2 小时

**风险评估**: 低风险
- TemporaryKeyManager 是独立组件，不依赖其他 service
- 只是位置迁移，不改变功能

#### 阶段 2: 迁移 PasswordService（优先级：P0）

**目标**: 将 PasswordService 的功能移入 sec_fs/crypto/

**步骤**:
1. 在 `sec_fs/crypto/password.go` 中添加密码验证和密钥派生函数
2. 更新 `sec_fs/session.go`，使用新的函数
3. 删除 `service/password_service.go`

**预计时间**: 2-3 小时

**风险评估**: 中等风险
- 需要确保密码验证逻辑正确
- 需要测试 PBKDF2 和 legacy HMAC 两种模式

#### 阶段 3: 删除 CryptoService（优先级：P0）

**目标**: 移除 CryptoService，直接使用 sec_fs/crypto

**步骤**:
1. 更新 `sec_fs/session.go`，使用 `crypto.MemZero()`
2. 更新 `sec_fs/root.go`，使用 `crypto.MemZero()`
3. 更新 `sec_fs/file.go`，使用 `crypto.MemZero()`
4. 删除 `service/crypto_service.go`

**预计时间**: 1 小时

**风险评估**: 低风险
- 只是替换函数调用，不改变逻辑

#### 阶段 4: 迁移 ConfigService（优先级：P1）

**目标**: 将 ConfigService 的功能移入 sec_fs 或 main.go

**步骤**:
1. 选项 A：创建 `sec_fs/config_manage/generate.go`
   - 移入 `GenerateEncryptionConfig` 函数
2. 选项 B：直接在 main.go 中实现
   - 因为是 FFI 特有的逻辑
3. 删除 `service/config_service.go`

**推荐**: 选项 A（创建 sec_fs/config_manage/）

**预计时间**: 2-3 小时

**风险评估**: 中等风险
- 需要确保配置生成逻辑正确
- 需要测试迭代次数计算

#### 阶段 5: 删除未使用的 service（优先级：P1）

**目标**: 删除 EncryptionService, DirectoryService, CryptorService

**步骤**:
1. 确认这些 service 未被使用
2. 删除 `service/encryption_service.go`
3. 删除 `service/directory_service.go`
4. 删除 `service/cryptor_service.go`

**预计时间**: 30 分钟

**风险评估**: 低风险
- 这些 service 未被使用

#### 阶段 6: 迁移 result.go（优先级：P1）

**目标**: 将 result.go 移入 ffi_comm

**步骤**:
1. 创建 `ffi_comm/response.go`
2. 移入 `Response`, `JsonResult` 等类型
3. 更新所有使用这些类型的代码
4. 删除 `service/result.go`

**预计时间**: 1 小时

**风险评估**: 低风险
- 只是位置迁移，不改变功能

#### 阶段 7: 删除 service 包（优先级：P2）

**目标**: 删除整个 service 包

**前置条件**:
- 阶段 1-6 全部完成
- 所有测试通过

**步骤**:
```bash
rm -rf native/service/
```

**预计时间**: 5 分钟

**风险评估**: 低风险（前提是前面阶段都完成）

---

## 五、风险评估

### 5.1 高风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| PasswordService 迁移可能破坏密码验证 | 高 | 完整测试 PBKDF2 和 legacy HMAC 模式 |
| ConfigService 迁移可能影响配置生成 | 中 | 确保配置格式不变，测试迭代次数计算 |

### 5.2 中等风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| TemporaryKeyManager 迁移可能影响会话管理 | 中 | 测试会话创建、获取、关闭流程 |
| main.go 大量修改可能影响 FFI 接口 | 中 | 逐步迁移，每步都进行测试 |

### 5.3 低风险项

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| CryptoService 删除 | 低 | 只是替换函数调用 |
| result.go 迁移 | 低 | 只是位置迁移 |
| 删除未使用的 service | 低 | 未被使用 |

---

## 六、验收标准

### 6.1 功能验收

- [ ] sec_fs 不再依赖 service 包
- [ ] main.go 不再依赖 service 包（或最小化依赖）
- [ ] 所有加密功能正常工作
- [ ] 密码验证正确
- [ ] 文件加密/解密正确
- [ ] 目录传输正确
- [ ] FFI 接口正常工作

### 6.2 性能验收

- [ ] 增量加密性能不下降
- [ ] 内存占用不增加
- [ ] FFI 接口响应时间不增加

### 6.3 架构验收

- [ ] 依赖关系符合 ARCHITECTURE_REFACTOR_PLAN.md
- [ ] sec_fs 只依赖 sec_fs/crypto
- [ ] sec_transfer 只依赖 sec_fs
- [ ] ffi_sec_fs 只依赖 sec_fs
- [ ] ffi_sec_transfer 只依赖 sec_transfer
- [ ] service 包已删除

---

## 七、时间估算

| 阶段 | 任务 | 预计时间 | 优先级 |
|------|------|----------|--------|
| 阶段 1 | 迁移 TemporaryKeyManager | 1-2 小时 | P0 |
| 阶段 2 | 迁移 PasswordService | 2-3 小时 | P0 |
| 阶段 3 | 删除 CryptoService | 1 小时 | P0 |
| 阶段 4 | 迁移 ConfigService | 2-3 小时 | P1 |
| 阶段 5 | 删除未使用的 service | 30 分钟 | P1 |
| 阶段 6 | 迁移 result.go | 1 小时 | P1 |
| 阶段 7 | 删除 service 包 | 5 分钟 | P2 |
| **总计** | | **8-11 小时** | |

---

## 八、总结

### 8.1 已完成的工作

1. ✅ **native/crypto 已被移除** - 旧的 crypto package 已经完全删除
2. ✅ **sec_fs/crypto 已完成** - 包含完整的加密功能，支持多种加密模式
3. ✅ **sec_fs 和 sec_transfer 包已创建** - 核心功能已实现
4. ✅ **FFI 封装层已创建** - ffi_sec_fs 和 ffi_sec_transfer 已实现

### 8.2 需要完成的工作

1. ⚠️ **清理 service 包** - 需要迁移或删除 8 个服务
2. ⚠️ **sec_fs 包依赖 service 包** - 违反架构约束，需要重构
3. ⚠️ **main.go 使用 service 包** - 需要更新为使用 sec_fs 和 sec_transfer

### 8.3 下一步行动

1. **优先执行阶段 1-3**（P0）：
   - 迁移 TemporaryKeyManager
   - 迁移 PasswordService
   - 删除 CryptoService

2. **然后执行阶段 4-6**（P1）：
   - 迁移 ConfigService
   - 删除未使用的 service
   - 迁移 result.go

3. **最后执行阶段 7**（P2）：
   - 删除整个 service 包

---

## 九、参考文档

- [ARCHITECTURE_REFACTOR_PLAN_V2.md](ARCHITECTURE_REFACTOR_PLAN_V2.md) - 架构重构计划（历史参考）
- [ARCHITECTURE.md](../ARCHITECTURE.md) - 当前架构文档
- [TODO.md](../TODO.md) - 任务列表

---

**文档状态**: 分析完成
**下一步**: 按照迁移计划执行重构
