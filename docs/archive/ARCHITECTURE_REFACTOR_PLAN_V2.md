# Safe Disk 架构重构计划 V2

> **历史文档**：本计划已于 2026-04-06 基本完成并实现。当前架构请参考 [ARCHITECTURE.md](../ARCHITECTURE.md)。本文档保留作为设计决策的历史参考。

**创建时间**: 2026-04-05
**状态**: 已实施完成

---

## 一、核心目标与设计原则

### 1.1 三层架构目标

将 Safe Disk 项目构建为**三层架构**：

```
┌─────────────────────────────────────┐
│        应用层（Application）          │
│   cli + flutter (用户接口)            │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│        适配层（Adapter）              │
│   ffi_sec_fs + ffi_sec_transfer     │
│   (FFI 封装，适配 C 接口)             │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│        核心层（Core）                 │
│   sec_fs + sec_transfer             │
│   (Go 原生包，独立可用)               │
└─────────────────────────────────────┘
```

### 1.2 核心设计原则

- ✅ 核心层独立可用，不依赖 FFI
- ✅ 适配层仅做类型转换，不包含业务逻辑
- ✅ 应用层通过核心层或适配层访问功能
- ✅ 从零开始构建，不考虑旧代码兼容

---

## 二、核心概念定义

### 2.1 Path 类型定义

**强制类型安全**：所有路径参数必须使用明确的类型，禁止使用不确定的 `string` 类型。

```go
// RelativeViewPath 相对视图路径（用户视角的RootDir相对路径）
// 例如："documents/report.pdf"
type RelativeViewPath string

// FullViewPath 完整视图路径
// 例如："/data/safe_disk_root/documents/report.pdf"
type FullViewPath string

// RelativeStorePath 相对存储路径（已加密或未加密的存储视角的相对路径）
// 例如："a1b2c3d4e5f6..."
type RelativeStorePath string

// FullStorePath 完整存储路径（已加密或未加密的加密存储视角的绝对路径）
// 例如："/data/safe_disk_root/a1b2c3d4e5f6..."
type FullStorePath string
```

**强制要求**：
- ✅ ISecFile、ISecDir、sec_fs、TransferService 等所有接口和方法**必须**使用明确的 Path 类型
- ❌ 禁止使用不确定的 `string` 类型作为路径参数
- ✅ 编译时类型检查，避免路径类型混淆

### 2.2 config.json 字段要求

**根据不同算法实现有不同的字段要求**：

```json
// crypto_data 算法配置示例
{
  "crypto_data": {
    "algorithm": "AES-256-GCM",
    "key_size": 32,
    "nonce_size": 12
  }
}

// crypto_name 算法配置示例
{
  "crypto_name": {
    "algorithm": "AES-128-CBC",
    "encoding": "base64"
  }
}

// crypto_key 算法配置示例
{
  "crypto_key": {
    "algorithm": "PBKDF2",
    "iterations": 100000,
    "salt_size": 16
  }
}
```

**关键特性**：
- ✅ 不同算法实现有不同的字段要求
- ✅ 配置验证在 OpenRoot/CreateRoot 时进行
- ✅ 算法特定字段由具体实现定义

### 2.3 crypto 模块结构

**架构**：
- ✅ `sec_fs/crypto_data/` - 数据加解密模块
- ✅ `sec_fs/crypto_name/` - 目录/文件名加解密模块
- ✅ `sec_fs/crypto_key/` - 密钥、证书加解密模块

---

## 三、核心包设计

### 3.1 sec_fs 包

**定位**: Go 原生加密文件系统，独立可用

**核心接口**:

```go
// ==================== 核心接口定义 ====================

// ISecFile 安全文件接口
type ISecFile interface {
    io.Reader
    io.Writer
    io.Seeker
    fs.File           // 包含 fs.File
    Size() int64
    Truncate(size int64) error
}

type ISecFilePlus interface {
    ISecFile
    Mode() os.FileMode
    RelativeViewPath() RelativeViewPath
    FullStorePath() FullStorePath
    IsClosed() bool
    Sync() error
}

// ==================== Root 操作 ====================

// OpenRoot 打开加密根目录
ISecRoot, err := OpenRoot(rootDir FullStorePath, password, config)

// ISecRoot 方法
ISecRoot.ChangePass(newPass) error
ISecRoot.GetInfo() (ISecRootInfo, error)
ISecRoot.GetRootPath() FullStorePath
ISecRoot.Close() error

// ==================== 目录遍历 ====================

// WalkDir 遍历目录
ISecDirWalker, err := ISecRoot.WalkDir(RelativeViewPath, WalkOption...)

// SecDirWalker 方法
entries, err := ISecDirWalker.Next()
entries, err := ISecDirWalker.NextBatch(batchSize)
bool := ISecDirWalker.HasNext()
err := ISecDirWalker.Close()

// ==================== 文件操作 ====================

// OpenFile 打开文件
ISecFile, err := ISecRoot.OpenFile(path RelativeViewPath, mode int)

// ISecFile 方法
data, n, err := ISecFile.Read(size)
n, err := ISecFile.Write(data)
pos, err := ISecFile.Seek(offset, whence)
pos, err := ISecFile.Tell()
err := ISecFile.Truncate(size)
err := ISecFile.Close()
bool := ISecFile.IsClosed()
size := ISecFile.Size()
mode := ISecFile.Mode()
_ := ISecFile.RelativeViewPath()
_ := ISecFile.FullStorePath()

// ISecFilePlus 扩展方法
err := ISecFilePlus.Rewind()
err := ISecFilePlus.Sync()
data, err := ISecFilePlus.ReadAll()
n, err := ISecFilePlus.WriteString(s)
data, err := ISecFilePlus.ReadAt(offset, size)
n, err := ISecFilePlus.WriteAt(offset, data)
n, err := ISecFilePlus.Append(data)
n, err := ISecFilePlus.AppendString(s)

// ==================== 快捷方法 ====================

// OpenRootQuick 快速打开根目录并返回相对视图路径
(ISecRoot, RelativeViewPath) := OpenRootQuick(fullStorePath, password)

// OpenOrCreateRootQuick 快速打开或创建根目录并返回相对视图路径
(ISecRoot, RelativeViewPath) := OpenOrCreateRootQuick(fullStorePath, password)

// ReadFile 读取文件
data, err := SecRoot.ReadFile(path RelativeViewPath)

// WriteFile 写入文件
err := SecRoot.WriteFile(path RelativeViewPath, data []byte)
```

**关键特性**:
- ✅ 动态选择加密实现（通过 IDataCryptorContext/ICryptoDataFactory）
- ✅ secFileImpl.impl 类型为 IDataCryptorContext 接口
- ✅ 支持多种加密模式（Normal, Chunked, Incremental）
- ✅ 性能测试覆盖（特别是增量加密模式）
- ✅ 内存安全（MemZero 在 close 内清除）

**实现细节**:

1. **secFileImpl 核心设计（重要！）**:
   - ✅ secFileImpl 使用 `impl IDataCryptorContext` 字段（**私有**），委托文件操作给实际的加密实现
   - Read/Write/Seek 等操作通过 impl 委托调用
   - **impl 字段必须为私有**，外部不可直接访问

2. **注册工厂集成**:
   - OpenRoot/CreateRoot/NewSecFile 时根据 config+file/data 从注册工厂获取 IDataCryptorContext/ICryptoDataFactory
   - 存入 secFileImpl.impl (interface type IDataCryptorContext)

3. **接口隐藏**:
   - 公开: ISecFile, ISecRoot, IDirWalker 接口
   - 隐藏: secFileImpl, secRootImpl, secDirWalker 具体类型（首字母小写）
   - 只允许从 config+data 的 root.OpenFile 里实际 new impl

4. **测试要求**:
   - 单元测试
   - 性能测试（file_test.go）
   - 内存占用测试

**测试用例格式（file_test.go）**:
```go
testCases := []struct {
    implType      string  // "Incremental", "Normal", "Chunked"
    memUsedMax    int64   // 最大内存占用（字节）
    speedMin      float64 // 最小速度（MB/s）
    testFileSize  int64   // 测试文件大小（字节）
    testPos       int64   // 测试位置（随机）
    testOp        string  // 测试操作："delete", "append", "modify"
    testOpSize    int     // 测试操作大小（随机）
}{
    {implType: "Incremental", memUsedMax: 10*MB, speedMin: 50.0, testFileSize: 500*MB, testPos: rand(), testOp: "delete", testOpSize: rand()},
    {implType: "Normal", memUsedMax: 1000*MB, speedMin: 100.0, testFileSize: 500*MB, testPos: rand(), testOp: "append", testOpSize: rand()},
    {implType: "Normal", memUsedMax: 1000*MB, speedMin: 100.0, testFileSize: 500*MB, testPos: rand(), testOp: "modify", testOpSize: rand()},
}
```

---

### 3.2 sec_transfer 包

**定位**: 安全、异步、原子化的目录/文件导入导出服务

**核心接口**:

```go
// ==================== 全局实例 ====================

var DefaultTransferService TransferService

// ==================== 目录导出/导入（异步） ====================

// ExportDirectoryAsync 导出目录（异步）
// srcRoot, srcSubDir := OpenRootQuick(fullSrcDirPath, password)
err := DefaultTransferService.ExportDirectoryAsync(srcRoot ISecRoot, srcSubDir RelativeViewPath, exportTargetDir FullStorePath, callback ProgressCallback) error

// ImportDirectoryAsync 导入目录（异步）
// targetRoot, targetSubDir := OpenOrCreateRootQuick(fullTargetDirPath, password)
err := DefaultTransferService.ImportDirectoryAsync(srcDir FullStorePath, targetRoot ISecRoot, targetSubDir RelativeViewPath, callback ProgressCallback) error

// ==================== 文件导出/导入（异步） ====================

// ExportFileAsync 导出文件（异步）
err := DefaultTransferService.ExportFileAsync(srcRoot ISecRoot, srcSubPath RelativeViewPath, exportTargetPath FullStorePath, callback ProgressCallback) error

// ImportFileAsync 导入文件（异步）
err := DefaultTransferService.ImportFileAsync(srcFile FullStorePath, targetRoot ISecRoot, targetSubPath RelativeViewPath, callback ProgressCallback) error

// ==================== 阻塞辅助函数（package 内） ====================

// BlockWaitProgress 阻塞等待异步操作完成
// ⚠️ FFI 原则上不应当使用 BlockWaitProgress()，易造成dart ui阻塞
err := BlockWaitProgress(func(callback ProgressCallback)) error
```

**关键特性**:
- ✅ 底层调用 sec_fs（不直接使用 crypto）
- ✅ 只接受路径参数，不接受二进制数据
- ✅ 安全 + 异步 + 原子化 + 持久队列
- ✅ package 内原则上不应当 import base64
- ✅ 通过 sec_root 确定实际算法类型（而非 password）
- ✅ 区分两个路径：srcRoot+srcSubDir 和 targetRoot+targetSubDir
- ✅ 只接收 Async 形式，package 内提供阻塞辅助函数
- ✅ 支持目录和文件级别的导出/导入

**原子化导入导出设计（重要！）**:

#### Import 流程（原子化 + 持久化）

```
Step 1: 扫描所有文件，保存 -> _progress_files.json
  - 记录所有待处理的文件列表
  - 持久化到进度文件中

Step 2-6: 循环处理每个文件：

Step 2: 加密文件
  a.txt -> (encrypt saveAs) -> a.txt.enc

Step 3: 安全替换（原子操作）：
  - rename(a.txt -> a.txt.raw)
  - rename(a.txt.enc -> a.txt)

Step 4: 保存进度（更新 _progress_files.json）← 先更新进度

Step 5: 清理临时文件
  - remove(a.txt.raw)                  ← 后删除临时文件

Step 6: 返回 Step 2 处理下一个文件
```

#### Export 流程（原子化 + 持久化）

```
Step 1: 扫描所有文件，保存 -> _progress_files.json
  - 记录所有待处理的文件列表
  - 持久化到进度文件中

Step 2-6: 循环处理每个文件：

Step 2: 解密文件
  a.txt.enc -> (decrypt saveAs) -> a.txt

Step 3: 安全替换（原子操作）：
  - rename(a.txt -> a.txt.raw)
  - rename(a.txt.enc -> a.txt)

Step 4: 保存进度（更新 _progress_files.json）← 先更新进度

Step 5: 清理临时文件
  - remove(a.txt.raw)                  ← 后删除临时文件

Step 6: 返回 Step 2 处理下一个文件
```

#### 断电恢复机制

启动时检查 `_progress_files.json`：
- 如果存在，说明上次有未完成的任务
- 恢复进度，继续处理未完成的文件
- 清理临时文件（`.raw`, `.enc` 等）

#### 原子安全性保证

1. **Step 2 断电**：
   - `a.txt.enc` 是临时文件
   - 下次启动可以清理临时文件

2. **Step 3 断电**（三种情况）：
   - 情况1：`a.txt` 还存在（rename 还没执行）→ 安全
   - 情况2：`a.txt.raw` 存在，`a.txt.enc` 存在 → 可以恢复
   - 情况3：`a.txt.enc` 已重命名为 `a.txt` → 成功

3. **Step 4 断电**：
   - 进度没有保存
   - 下次会重新处理这个文件（幂等）

#### 进度文件格式

```json
{
  "version": 1,
  "transfer_type": "import",  // 或 "export"
  "total_files": 100,
  "processed_files": [
    {"path": "a.txt", "status": "complete"},
    {"path": "b.txt", "status": "complete"}
  ],
  "pending_files": [
    {"path": "c.txt", "status": "pending"},
    {"path": "d.txt", "status": "pending"}
  ],
  "current_file": {
    "path": "e.txt",
    "status": "processing"
  },
  "started_at": "2026-04-06T12:00:00Z",
  "updated_at": "2026-04-06T12:30:00Z"
}
```

---

### 3.3 ffi_sec_fs 包

**定位**: FFI 封装层，适配 C 接口

**核心接口**:

```c
// ==================== Root 操作 ====================

// sec_root_open 打开加密根目录
{sec_root_id, err} = sec_root_open(const char* root_dir_full_store_path, const char* input_pass, const char* config_json);

// sec_root_change_pass 修改密码
err = sec_root_change_pass(sec_root_id, const char* new_pass);

// sec_root_close 关闭根目录
err = sec_root_close(sec_root_id);

// ==================== 目录遍历 ====================

// sec_dir_walk 开始遍历目录
dir_walker_id = sec_dir_walk(sec_root_id, const char* relative_view_path, const char* opt_json);

// sec_dir_walk_next 获取下一个条目
err = sec_dir_walk_next(dir_walker_id, char** out_entry_json);

// sec_dir_walk_close 关闭遍历器
err = sec_dir_walk_close(dir_walker_id);

// ==================== 文件操作 ====================

// sec_fopen 打开文件
fp_id = sec_fopen(const char* relative_view_path, sec_root_id);

// sec_fread 读取文件
err = sec_fread(fp_id, char** out_data, int64* out_size);

// sec_fwrite 写入文件
err = sec_fwrite(fp_id, const char* data, int64 size);

// sec_fclose 关闭文件
err = sec_fclose(fp_id);

// sec_fstat 获取文件状态
err = sec_fstat(fp_id, char** out_stat_json);

// sec_fseek 设置文件位置
err = sec_fseek(fp_id, int64 offset, whence);

// sec_ftell 获取文件位置
int64 pos = sec_ftell(fp_id);

// ==================== 快捷方法 ====================

// sec_readfile 读取整个文件
err = sec_readfile(const char* relative_view_path, sec_root_id, char** out_data, int64* out_size);

// sec_writefile 写入整个文件
err = sec_writefile(const char* relative_view_path, const char* data, int64 size, sec_root_id);
```

**关键特性**:
- ✅ 使用 `ffi_comm.Store[T]` 管理 ID 映射（`ISecRoot/XXX` ↔ `id`）
- ✅ 函数名与 sec_fs 对应，但参数/返回值适配 FFI
- ✅ 只调用 sec_fs

---

### 3.4 ffi_sec_transfer 包

**定位**: FFI 封装层，适配 C 接口

**核心接口**:

```c
// ==================== 目录导出/导入（异步） ====================

// sec_transfer_export_dir 导出目录（异步）
err = sec_transfer_export_dir(sec_root_id, const char* src_relative_view_path, const char* export_target_full_store_path, ProgressCallback callback);

// sec_transfer_import_dir 导入目录（异步）
err = sec_transfer_import_dir(const char* src_full_store_path, target_root_id, const char* target_relative_view_path, ProgressCallback callback);

// ==================== 文件导出/导入（异步） ====================

// sec_transfer_export_file 导出文件（异步）
err = sec_transfer_export_file(sec_root_id, const char* src_relative_view_path, const char* export_target_full_store_path, ProgressCallback callback);

// sec_transfer_import_file 导入文件（异步）
err = sec_transfer_import_file(const char* src_full_store_path, target_root_id, const char* target_relative_view_path, ProgressCallback callback);
```

**关键特性**:
- ✅ 使用 sec_root_id 参数（通过 ffi_comm.Store 映射）
- ✅ 不再需要 password 参数
- ✅ 改名为 export/import，去掉 encrypt/decrypt
- ✅ 区分路径
- ✅ 只提供异步接口
- ✅ 支持目录和文件级别
- ✅ **不提供 _sync 后缀接口**（避免错误使用，低性能）

---

### 3.5 ffi_comm 包

**定位**: FFI 通信基础设施

**核心内容**:

```go
// ==================== Response 结构 ====================

type Response struct {
    Success bool        `json:"success"`
    Data    any         `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
    Code    int         `json:"code,omitempty"`
}

// ==================== Store[T] (ID 映射管理) ====================

// Store ID 映射管理器，管理 FFI 接口的 ID 与实例映射
var DefaultStoreSecRoot Store[ISecRoot]
var DefaultStoreSecDirWalker Store[ISecDirWalker]
var DefaultStoreSecFile Store[ISecFile]

// ==================== 辅助类型 ====================

func SuccessWithData(data any) string
func ErrorResponse(err error) string
func ErrorResponseWithCode(code int, err error) string
func JsonResult(success bool, data any, err string) string
func SuccessResult(data any) string
func ErrorResult(err error) string
```

**关键特性**:
- ✅ Response 结构
- ✅ Store 实现 ID 映射
- ✅ JsonResult 等辅助类型统一管理

---

### 3.6 crypto_data 包

**定位**：数据加解密

**目录结构**：
```
sec_fs/crypto_data/
├── registry.go                       # 注册表
├── interface.go                      # 接口定义
└── algorithm_impl/                   # 算法实现
    ├── AESXXX/
    ├── rc4/
    ├── normal/                      # 普通加密
    ├── incremental/                 # 增量加密
    └── ...
```

**核心接口**：
```go
// IReadWriterSeeker 加密读写定位器接口
type IReadWriterSeeker interface {
    io.Reader
    io.Writer
    io.Seeker
    io.Closer
}

// IDataCryptorContext 数据加密器上下文接口
type IDataCryptorContext interface {
    IReadWriterSeeker
    // 其他数据加密相关方法...
}

// ICryptoDataFactory 加密数据工厂接口
type ICryptoDataFactory interface {
    NewContext(storeFileIo IReadWriterSeeker, keyInfo IKeyInfo) (IDataCryptorContext, error)
}
```

**关键特性**：
- ✅ 统一接口：read+write+seek
- ✅ 支持多种算法实现
- ✅ 注册表机制：灵活选择算法
- ✅ 上下文模式：通过 NewContext 创建加密器上下文
- ✅ 密钥信息注入：通过 IKeyInfo 接口传递密钥信息

---

### 3.7 crypto_name 包

**定位**：目录/文件名加解密

**目录结构**：
```
sec_fs/crypto_name/
├── registry.go                       # 注册表
├── interface.go                      # 接口定义
└── algorithm_impl/                   # 算法实现
    ├── AESXXX/
    ├── rc4/
    └── ...
```

**核心接口**：
```go
// INameCryptorContext 名称加密器上下文接口
type INameCryptorContext interface {
    EncryptName(name string) (string, error)
    DecryptName(encrypted string) (string, error)
}

// ICryptoNameFactory 名称加密工厂接口
type ICryptoNameFactory interface {
    NewContext(key IKeyInfo) (INameCryptorContext, error)
}
```

**关键特性**：
- ✅ 统一接口：加密/解密文件名
- ✅ 支持多种算法实现
- ✅ 上下文模式：通过 NewContext 创建名称加密器上下文

---

### 3.8 crypto_key 包

**定位**：密钥、证书加解密

**目录结构**：
```
sec_fs/crypto_key/
├── registry.go                       # 注册表
├── interface.go                      # 接口定义
└── algorithm_impl/                   # 算法实现
    ├── PBKDF2/
    ├── AESXXX/
    ├── RSA/
    └── ...
```

**核心接口**：
```go
// MakeKeyParams 创建密钥参数
type MakeKeyParams struct {
    Password      string
    KeyStrengthMs int
    Mutable       bool
    ChallengeId   string
}

// IKeyInfo 密钥信息接口
type IKeyInfo interface {
    GetInitConfig() any
    GetKey() []byte
    GetSalt() []byte
}

// IKeyInfoPlus 扩展密钥信息接口（待定义）
type IKeyInfoPlus interface {
    IKeyInfo
    // 待定义的扩展方法...
}

// IKeyDeriver 密钥派生器接口
type IKeyDeriver interface {
    LoadKey(password string, config *config.CryptionJSON) (IKeyInfo, error)
    NewKey(params *MakeKeyParams) (IKeyInfo, error)
}
```

**关键特性**：
- ✅ 统一接口：密钥派生和创建
- ✅ 支持多种算法实现
- ✅ 密钥信息封装：通过 IKeyInfo 接口传递密钥信息
- ✅ 扩展机制：IKeyInfoPlus 预留扩展能力

---

## 四、架构约束

### 4.1 包依赖规则

```
┌──────────┐
│   cli    │──────────────> sec_fs, sec_transfer
└──────────┘

┌──────────────┐
│ ffi_sec_fs   │──────────────> sec_fs
└──────────────┘

┌──────────────────┐
│ ffi_sec_transfer │──────────────> sec_transfer
└──────────────────┘

┌──────────────┐
│ sec_transfer │──────────────> sec_fs
└──────────────┘

┌─────────┐
│ sec_fs  │──────────────> sec_fs/crypto_data, crypto_name, crypto_key
└─────────┘
```

**禁止**:
- ❌ ffi/cli 禁止调用 crypto package
- ❌ sec_transfer 禁止 import base64（唯一通过 config 内部）
- ❌ sec_fs/sec_transfer 禁止公开 impl/wrap 的具体类型
- ❌ 禁止使用不确定的 `string` 类型作为路径参数（必须使用 RelativeViewPath/RelativeStorePath/FullStorePath）

### 4.2 接口隐藏

**公开**:
- ✅ ISecFile, ISecRoot, IDirWalker 接口
- ✅ OpenRoot 等工厂函数

**隐藏**:
- ❌ secFileImpl, secRootImpl, secDirWalker 具体类型（改为小写）
- ❌ 具体的加密实现类（normalImpl, chunkedImpl, incrementalImpl）
- ❌ 内部的 crypto 操作细节
- ❌ impl 字段（必须为私有，外部不可直接访问）

### 4.3 内存安全

- ✅ MemZero 在 sec_fs close 内清除
- ✅ 确保敏感数据（key, password）在关闭时清零
- ✅ 避免敏感数据在内存中长时间驻留

---

## 五、执行计划

### 阶段 1: 完成 sec_fs 核心接口（P0）

**任务 1.0: 包创建**
- [x] 创建 native/sec_fs 包 ✅ 2026-04-05
- [x] 实现 sec_fs 核心功能 ✅ 2026-04-05

**任务 1.1: secFileImpl.impl 集成**
- [x] secFileImpl 添加 `impl IDataCryptorContext` 字段（**私有**）✅ 2026-04-05
- [x] OpenFile 从注册工厂获取 ICryptoDataFactory ✅ 2026-04-05
- [x] 编译通过 ✅ 2026-04-05
- [ ] 测试通过（需要完整 crypto 实现）

**任务 1.2: 接口完善**
- [x] 完善 ISecFile 定义 ✅ 2026-04-05
- [x] 完善 ISecRoot 定义 ✅ 2026-04-05
- [x] 完善 IDirWalker 定义 ✅ 2026-04-05
- [x] 添加编译时验证：`var _ ISecFile = (*secFileImpl)(nil)` ✅ 2026-04-05

**任务 1.3: 隐藏具体类型**
- [x] SecFile 改为 secFileImpl ✅ 2026-04-05
- [x] SecRoot 改为 secRootImpl ✅ 2026-04-05
- [x] SecDirWalker 改为 secDirWalker ✅ 2026-04-05
- [x] 确保外部只能通过接口访问 ✅ 2026-04-05

**任务 1.4: 加密实现动态选择**
- [ ] 加密实现动态选择（需要完整 crypto 实现）
- [ ] impl 灵活选择实现类（需要完整 crypto 实现）

**任务 1.5: 统一测试框架**
- [x] 创建统一测试框架（支持不同 implType）✅ 2026-04-05
- [x] sec_fs 测试用例 ✅ 2026-04-05
- [ ] 测试参数覆盖：（需要完整 crypto 实现）
  - memUsedMax, speedMin, testFileSize, testPos, testOp, testOpSize
  - rewriteRatio: 修改量/重写量比例
  - seekTime: 寻址时间
  - readWriteSpeed: 读写速度
- [ ] 不同 implType 性能要求：（需要完整 crypto 实现）
  - Incremental: memUsedMax=10MB, speedMin=50MB/s, O(1) 寻址, rewriteRatio<10%
  - Normal: memUsedMax=1000MB, speedMin=100MB/s, O(n) 寻址, rewriteRatio=100%
  - Chunked: memUsedMax=100MB, speedMin=80MB/s, O(1) 块定位, rewriteRatio<30%

---

### 阶段 2: 重构 FFI 层（P0）

**任务 2.0: FFI 接口重设计**
- [x] 设计 sec_* 系列接口 ✅ 2026-04-05
- [x] 创建 native/ffi_sec_fs 包 ✅ 2026-04-05
- [x] 实现 FFI 适配层 ✅ 2026-04-05

**任务 2.1: ffi_comm 包完善**
- [x] 实现 Response 结构 ✅ 2026-04-05
- [x] 实现 Store（ID 映射管理）✅ 2026-04-05
- [x] 实现 JsonResult 等辅助类型 ✅ 2026-04-05
- [x] 实现 SuccessWithData/ErrorResponse 等 ✅ 2026-04-05

**任务 2.2: ffi_sec_fs 包**
- [x] 定义新的 FFI 接口（sec_root_XXX, sec_fopen 等）✅ 2026-04-05
- [x] 使用 Store 管理 ID 映射 ✅ 2026-04-05
- [x] 调用 sec_fs 原生接口 ✅ 2026-04-05

**任务 2.3: ffi_sec_transfer 包**
- [x] 创建 native/ffi_sec_transfer 包 ✅ 2026-04-05
- [x] 定义新的 FFI 接口 ✅ 2026-04-05
- [x] 调用 sec_transfer ✅ 2026-04-05
- [x] 实现异步回调机制 ✅ 2026-04-05

---

### 阶段 3: 重构 sec_transfer（P1）

**任务 3.0: TransferService 实现**
- [x] 创建 native/sec_transfer 包 ✅ 2026-04-05
- [x] 实现 TransferService 核心功能 ✅ 2026-04-05
- [x] 底层调用 sec_fs ✅ 2026-04-05
- [x] 实现安全 + 异步 + 原子化 + 持久队列 ✅ 2026-04-05（异步实现完成，持久队列待实现）
- [x] 禁止导入 base64 ✅ 2026-04-05
- [x] 只接受路径参数 ✅ 2026-04-05
- [x] 创建测试文件 ✅ 2026-04-05

**任务 3.1: 暴露 DefaultTransferService**
- [ ] 提供 var DefaultTransferService（待添加）
- [ ] 供 cli 直接调用（待实现）

---

### 阶段 4: Flutter 端集成（P1）

**任务 4.1: Flutter 端集成**
- [ ] Flutter 的加密目录遍历使用 FFI 的 fs 接口遍历
- [ ] Flutter 端和 CLI/FFI 的行为保持一致

**任务 4.2: 测试完善**
- [ ] FFI 接口的流程测试（不仅仅是 CLI 测试）
- [ ] 端到端测试（UI 模拟调用 FFI）
- [ ] 性能测试（不同 impl 的内存和性能要求）

---

## 六、性能要求

### 6.1 增量加密模式

- **内存占用**: 100MB 文件修改量 < 8MB
- **定位复杂度**: O(1) 随机定位
- **写入性能**: 支持增量写入，避免全量重写

### 6.2 测试覆盖

- **单元测试**: 核心功能 100% 覆盖
- **性能测试**: 大文件（1GB+）测试
- **内存测试**: 监控内存占用，确保有界

### 6.3 加密测试

- **测试文件大小**: 100MB 已加密文件
- **测试操作**: 随机在 5 个位置添加/编辑/删除 1-2000 byte 数据
- **验收标准(简易算法)**: 再保存时文件修改量 （Len-Pos）
- **验收标准(增量算法)**: 再保存时文件修改量 **低于 8MB**

### 6.4 随机定位快速解密

- **验收标准**: O(1) 或 O(log n) 定位复杂度

### 6.5 大文件流式解密

- **要求**: 避免内存溢出
- **实现**: 流式解密到 Writer/文件
- **支持**: 取消操作

---

## 七、风险与缓解

### 7.1 风险识别

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 性能回归 | 中 | 性能测试覆盖，基准对比 |
| 接口设计不合理 | 高 | 充分讨论确认后再执行 |

### 7.2 回滚策略

- 每个 commit 保持原子性
- 使用 git tag 标记稳定版本

---

## 八、关键问题与决策

### 8.1 已确认的设计决策

| 问题 | 决策 | 状态 |
|------|------|------|
| SecFileImpl.impl 字段类型 | IDataCryptorContext 接口 | ✅ 已确认 |
| 注册工厂集成 | OpenRoot/OpenFile 从注册工厂获取 ICryptoDataFactory->IDataCryptorContext | ✅ 已确认 |
| FFI 接口设计 | sec_root_XXX, sec_fopen 等新接口 | ✅ 已确认 |
| cli 目录加解密 | 使用 transfer_service | ✅ 已确认 |
| FullViewPath 类型定义 | 添加 FullViewPath 类型，解决路径类型安全问题 | ✅ 已确认 |

### 8.2 待确认的问题

（暂无）

---

## 九、时间估算

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 阶段 1 | sec_fs 核心接口 | 2-3 天 |
| 阶段 2 | FFI 层重构 | 2-3 天 |
| 阶段 3 | sec_transfer 重构 | 1-2 天 |
| 阶段 4 | Flutter 端集成 | 1-2 天 |
| **总计** | | **6-10 天** |

---

## 十、参考资料

- [ARCHITECTURE.md](../ARCHITECTURE.md) - 当前架构文档
- [TODO_REFACTOR.md](../TODO_REFACTOR.md) - 任务清单

---

**文档状态**: 从零开始构建
**下一步**: 执行 TODO_REFACTOR.md 中的任务
