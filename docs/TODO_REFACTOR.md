# Safe Disk 重构任务清单

**创建时间**: 2026-04-05
**状态**: 待用户确认

---

参考细节文档： [ARCHITECTURE_REFACTOR_PLAN_V2.md](ARCHITECTURE_REFACTOR_PLAN_V2.md)

## 核心目标

从零开始构建三层架构：
```
应用层（CLI/Flutter）→ 适配层（FFI）→ 核心层（sec_fs/sec_transfer）
```

**核心原则**：
- ✅ 核心层独立可用，不依赖 FFI
- ✅ 适配层仅做类型转换，不包含业务逻辑
- ✅ 彻底重写，不考虑旧代码兼容

---

## 阶段 1: 核心层 - sec_fs 包（P0）

### 任务 1.1: 包基础结构
- [x] 创建 native/sec_fs/ 目录 ✅ 2026-04-05
- [x] 创建 define.go：定义 Path 类型 ✅
- [x] 创建 errors.go：定义错误类型 ✅

**验收标准**：
- ✅ 目录结构创建
- ✅ Path 类型定义完成
- ✅ 编译通过

---

### 任务 1.2: 接口定义
- [x] 创建 define.go：定义 ISecFile 接口 ✅ 2026-04-05
- [x] 创建 define.go：定义 ISecRoot 接口 ✅
- [x] 创建 define.go：定义 IDirWalker 接口 ✅

**验收标准**：
- ✅ ISecFile 接口完整（Read/Write/Seek/Close/Size/Truncate 等）
- ✅ ISecRoot 接口完整（OpenFile/Close/Delete/Exists/MkdirAll 等）
- ✅ IDirWalker 接口完整（Next/HasNext/Close 等）
- ✅ 编译通过

---

### 任务 1.3: crypto_data 接口
- [x] 创建 sec_fs/crypto_data/ 目录 ✅ 2026-04-05
- [x] 创建 interface.go：定义 IDataCryptorContext 接口 ✅
- [x] 创建 interface.go：定义 ICryptoDataFactory 接口 ✅
- [x] 创建 interface.go：定义 IKeyInfo 接口 ✅

**验收标准**：
- ✅ IDataCryptorContext 接口完整（Read/Write/Seek/Close/Size/Truncate/Sync）
- ✅ ICryptoDataFactory 接口完整（NewContext/GetName/GetCapabilities）
- ✅ IKeyInfo 接口完整（GetKey/GetSalt/GetInitConfig）
- ✅ FactoryRegistry 实现完整（Register/Get/GetByMode）
- ✅ 编译通过

---

### 任务 1.4: secFileImpl 实现
- [x] 创建 file.go：实现 secFileImpl 结构体 ✅ 2026-04-05
- [x] secFileImpl 添加 `impl IDataCryptorContext` 字段（**私有**）✅
- [x] 实现 ISecFile 接口的所有方法 ✅

**验收标准**：
- ✅ secFileImpl 结构体定义（首字母小写，私有）
- ✅ impl 字段为私有
- ✅ 所有 ISecFile 方法实现
- ✅ 操作委托给 impl
- ✅ 编译通过

---

### 任务 1.5: secRootImpl 实现
- [x] 创建 root.go：实现 secRootImpl 结构体 ✅ 2026-04-05
- [x] secRootImpl 添加 factory 字段 ✅
- [x] 实现 ISecRoot 接口的所有方法 ✅

**验收标准**：
- ✅ secRootImpl 结构体定义（首字母小写，私有）
- ✅ factory 字段正确设置
- ✅ OpenFile 完整实现
- ✅ 所有 ISecRoot 方法实现
- ✅ 编译通过

---

### 任务 1.6: secDirWalker 实现
- [x] 已在任务 1.5 中完成 ✅ 2026-04-05

**验收标准**：
- ✅ secDirWalker 结构体定义（首字母小写，私有）
- ✅ 所有 IDirWalker 方法实现
- ✅ 编译通过

---

### 任务 1.7: 工厂函数
- [x] 已在任务 1.5 中完成 ✅ 2026-04-05

**验收标准**：
- ✅ OpenRoot 工厂函数实现
- ✅ 返回 ISecRoot 接口（具体类型隐藏）
- ✅ 编译通过

---

### 任务 1.8: crypto_name 接口
- [x] 创建 sec_fs/crypto_name/ 目录 ✅ 2026-04-05
- [x] 创建 interface.go：定义 INameCryptorContext 接口 ✅
- [x] 创建 interface.go：定义 ICryptoNameFactory 接口 ✅

**验收标准**：
- ✅ INameCryptorContext 接口完整（EncryptName/DecryptName）
- ✅ ICryptoNameFactory 接口完整（NewContext）
- ✅ 编译通过

---

### 任务 1.9: crypto_key 接口
- [x] 创建 sec_fs/crypto_key/ 目录 ✅ 2026-04-05
- [x] 创建 interface.go：定义 IKeyDeriver 接口 ✅
- [x] 创建 interface.go：定义 IKeyInfo 接口 ✅

**验收标准**：
- ✅ IKeyDeriver 接口完整（LoadKey/NewKey）
- ✅ IKeyInfo 接口完整
- ✅ 编译通过


### 任务 1.10: 总结验收
- [x] 阶段 1 验收通过 ✅ 2026-04-05
- [x] 目录结构完整 ✅
- [x] 14 个接口定义完整 ✅
- [x] 5 个核心实现完整 ✅
- [x] 3 个注册表完整 ✅
- [x] 编译通过 ✅

**验收标准**：
- ✅ 测试框架创建
- ✅ Mock 工厂实现
- ✅ 测试用例覆盖不同 implType（Normal/Chunked/Incremental）
- ✅ 测试通过

---

---

## 阶段 2: 适配层 - FFI 包（P0）

### 任务 2.1: ffi_comm 包
- [ ] 创建 native/ffi_comm/ 目录
- [ ] 创建 store.go：实现 Store[T] 泛型（ID 映射管理）
- [ ] 创建 response.go：实现 Response 结构
- [ ] 创建 response.go：实现辅助函数（SuccessWithData/ErrorResponse/JsonResult 等）
- [ ] 编译通过

**验收标准**：
- ✅ Store[T] 线程安全实现（Add/Get/Remove/Contains 等）
- ✅ Response 结构定义
- ✅ 辅助函数完整
- ✅ 编译通过

---

### 任务 2.2: ffi_sec_fs 包
- [ ] 创建 native/ffi_sec_fs/ 目录
- [ ] 创建 stores.go：实例存储管理（Store[ISecRoot], Store[ISecFile] 等）
- [ ] 创建 ffi.go：FFI 接口实现（Go 层）
- [ ] 创建 exports.go：C 导出函数（CGO 层）
- [ ] 实现 FFI 接口：
  - OpenRoot_FFI / CloseRoot_FFI
  - OpenFile_FFI / CloseFile_FFI
  - ReadFile_FFI / WriteFile_FFI
  - SeekFile_FFI / TruncateFile_FFI
  - DeleteFile_FFI / FileExists_FFI
  - MkdirAll_FFI / ReadDir_FFI
- [ ] 编译通过

**验收标准**：
- ✅ FFI 接口实现（对应 sec_fs 的所有方法）
- ✅ 使用 ffi_comm.Store 管理 ID 映射
- ✅ 编译通过

---

### 任务 2.3: ffi_sec_transfer 包
- [ ] 创建 native/ffi_sec_transfer/ 目录
- [ ] 创建 ffi.go：FFI 接口实现（Go 层）
- [ ] 创建 exports.go：C 导出函数（CGO 层）
- [ ] 实现 FFI 接口：
  - ExportDirectory_FFI / ImportDirectory_FFI
  - ExportFile_FFI / ImportFile_FFI
- [ ] 编译通过

**验收标准**：
- ✅ FFI 接口实现（对应 sec_transfer 的所有方法）
- ✅ 异步接口实现
- ✅ 编译通过

---

## 阶段 3: 核心层 - sec_transfer 包（P1）

### 任务 3.1: sec_transfer 包
- [ ] 创建 native/sec_transfer/ 目录
- [ ] 创建 transfer.go：实现 TransferService
- [ ] 实现核心方法：
  - ExportDirectoryAsync
  - ImportDirectoryAsync
  - ExportFileAsync
  - ImportFileAsync
- [ ] 底层调用 sec_fs
- [ ] 只接受路径参数，不接受二进制数据
- [ ] 编译通过

**验收标准**：
- ✅ TransferService 实现
- ✅ 底层调用 sec_fs
- ✅ 只接受路径参数
- ✅ 编译通过

---

## 阶段 4: 应用层（P1）

### 任务 4.1: CLI 集成
- [ ] 创建 native/cli/ 目录
- [ ] CLI 使用 sec_fs 和 sec_transfer
- [ ] 编译通过

**验收标准**：
- ✅ CLI 编译通过
- ✅ CLI 调用 sec_fs/sec_transfer

---

### 任务 4.2: Flutter 端集成
- [ ] Flutter 使用 FFI 接口
- [ ] Flutter 端和 CLI 行为一致
- [ ] 编译通过

**验收标准**：
- ✅ Flutter 编译通过
- ✅ Flutter 调用 FFI 接口

---

## 验收标准总览

### 核心层验收
- ✅ 编译通过
- ✅ 所有接口定义完整
- ✅ 所有具体类型隐藏（首字母小写）
- ✅ secFileImpl.impl 字段为私有
- ✅ OpenFile 完整实现（动态选择加密实现）
- ✅ 测试通过

### 适配层验收
- ✅ 编译通过
- ✅ FFI 接口与核心层对应
- ✅ 使用 ffi_comm.Store 管理 ID 映射
- ✅ 只调用 sec_fs/sec_transfer（不直接调用 crypto）

### 应用层验收
- ✅ 编译通过
- ✅ CLI/Flutter 调用核心层或适配层

---

## 执行顺序

```
阶段 1（P0）:
  1.1 → 1.2 → 1.3 → 1.4 → 1.5 → 1.6 → 1.7 → 1.8 → 1.9 → 1.10

阶段 2（P0）:
  2.1 → 2.2 → 2.3

阶段 3（P1）:
  3.1

阶段 4（P1）:
  4.1 → 4.2
```

---

**待用户确认后开始执行**
