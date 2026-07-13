# 加密与密码认证设计

> 本文以 `native/sec_fs` 当前代码为准。旧版 `mutable`、`check`、`challengeId`、`encryptedChallengeId` 方案不属于当前实现。

## 当前结论

当前根目录由三个可插拔部分组成：

- 数据加密：`aes-ctr`、`aes-xts`、`chacha20`、`rc4`
- 文件名加密：`aes-gcm-name`、`rc4`、`none`
- 密钥派生：`argon2id`、`pbkdf2`、`scrypt`、`hkdf`

CLI 与 FFI 入口通过 `crypto_all` 注册上述实现。`hkdf` 适用于已有高熵密钥材料，不是面向普通用户密码的推荐 KDF；`rc4` 仅为已有实验实现，不应作为新数据的安全默认值。

当前新 root 的确定性默认组合是 `aes-ctr + none + argon2id`。Flutter UI 和 CLI 因此默认不会加密文件名；`aes-gcm-name` 已能工作，并有 sec、transfer、FFI、Dart 真库测试，但还没有成为 UI 默认选项。

## 根目录配置

根目录配置文件默认为 `_cryption.json`。字段由所选算法写入，典型配置如下：

```json
{
  "sec_fs_factory": "aes-ctr",
  "sec_name_factory": "none",
  "sec_deriver_factory": "argon2id",
  "argon2_salt": "每个root独立的随机hex值",
  "argon2_time": 1,
  "argon2_memory": 71936,
  "argon2_threads": 4,
  "argon2_key_length": 32,
  "sec_password_verifier_challenge": "base64...",
  "sec_password_verifier_tag": "base64...",
  "sec_password_verifier_version": 1
}
```

注意：示例只说明字段形态。KDF 参数取决于具体实现，不能假设所有 root 都有 PBKDF2 字段。

## 创建流程

`CreateRootConfigQuick` 的实际流程：

1. 解析并记录数据、文件名和 KDF factory。
2. 由 KDF 创建主密钥并把算法参数写入配置。
3. 初始化文件名加密 context。
4. 生成 32 字节随机认证挑战。
5. 计算 `HMAC-SHA256(derivedKey, domain || challenge)`。
6. 写入 challenge 和 tag，最后写入 verifier version 作为完整记录的提交标记。

密码和派生主密钥不会直接写入配置。verifier 与加密数据一样允许离线猜测密码，因此安全性仍依赖强密码和合适的 KDF 参数。

新 root 一律请求随机 salt；即使两个 root 使用相同密码，也会得到不同 salt、主密钥和 verifier。`StaticSalt` 仅保留给 KDF 底层确定性测试或明确的非生产调用，不是 `CreateRootConfigQuick` 的创建策略。

## 打开与认证流程

`OpenRootQuick` 必须先认证密码，再构造 root：

1. 加载 `_cryption.json`。
2. 按 `sec_deriver_factory` 和对应参数派生候选主密钥。
3. 读取并校验 verifier 版本、challenge 和 tag。
4. 使用候选主密钥重新计算 tag，并以常量时间比较。
5. 不匹配时返回 `ErrInvalidPassword`。
6. 只有认证成功后才创建文件名 context、root 对象或 FFI `root_id`。

这项顺序是安全边界。不能通过“尝试列目录是否有内容”判断密码：空目录、`nameFactory=none` 和非认证型内容加密都无法可靠证明密码正确。

## 旧配置处理

2026-07-10 之前由当前 `sec_fs` 创建的配置可能没有 password verifier。此类 root 无法可靠区分正确和错误密码，当前实现采取失败关闭：

- 缺少 verifier：返回 `ErrPasswordVerifierMissing`
- verifier 字段损坏或版本未知：返回 `ErrInvalidConfig`
- verifier 完整但不匹配：返回 `ErrInvalidPassword`

不做“输入一次密码后自动补 verifier”，因为旧配置没有足够认证证据，自动补写可能把错误密码永久登记为正确密码。开发期目录应重新创建 root，再从可信明文源重新全量 import。

旧 v1/v2 的 `check/challengeId/encryptedChallengeId` 不自动迁移。本项目当前已经明确不要求旧 transfer 与旧 root 格式兼容；如果以后需要迁移，必须设计独立、显式、可审计的迁移工具。

## 文件名加密

`aes-gcm-name` 当前行为：

- 使用主密钥的前 32 字节作为 AES-256 key；更长 key 会先经 SHA-256 收敛。
- nonce 由 key 与明文名称确定性派生，使同一路径名称可稳定映射。
- store name 使用 URL-safe base64。
- GCM tag 能检测错误 key 或名称密文损坏。
- 文件和目录名称都经过同一 context。

确定性名称加密会泄漏同一 key 下的名称相等关系，这是稳定路径查找的现有取舍，不应描述为完全隐藏元数据。

密文 store 的文件大小、目录结构规模和操作时间仍属于可观察 metadata。Transfer 不把源 owner/mode/mtime 复制到 backing file；新对象采用 `0600/0700` 安全基线。若需要恢复原始 metadata，必须使用单独的认证加密格式，不能把 backing file metadata 描述为受加密保护。

`none` 会保留原始文件名；此时只加密文件内容。Flutter UI 与 CLI 当前创建入口采用该模式。

## 数据加密

数据层通过 `ICryptoDataFactory` 创建文件 context。当前 `crypto_all` 完整注册：

| 名称 | 当前状态 | 备注 |
|---|---|---|
| `aes-ctr` | 已实现、已注册、主路径使用 | 支持随机访问，本身不提供认证 |
| `aes-xts` | 已实现、已注册、已有通用测试 | 需要符合实现要求的 key 长度 |
| `chacha20` | 已实现、已注册、已有通用测试 | 本身不等同于 AEAD |
| `rc4` | 已实现、已注册 | 仅保留实验/兼容价值，不建议新数据使用 |

当前数据格式的完整性与篡改检测仍不是统一完成能力。密码 verifier 只认证“打开 root 的密码”，不能替代文件内容认证。

## 密钥派生

| 名称 | 当前状态 | 使用建议 |
|---|---|---|
| `argon2id` | 已实现、已注册 | 普通密码优先考虑 |
| `pbkdf2` | 已实现、已注册 | 可用于互操作和保守环境 |
| `scrypt` | 已实现、已注册 | 可作为内存困难 KDF |
| `hkdf` | 已实现、已注册 | 只适合高熵输入，不应直接作为普通密码哈希 |

每种 KDF 自己负责保存 salt、成本参数和 key length。password verifier 位于 KDF 之上，因此不依赖具体 KDF。

创建时不再从 registry map 中选择“第一个”算法：优先使用固定默认 `argon2id`；仅注册一个替代 KDF 的嵌入场景可使用该唯一实现；多个实现但默认未注册时直接返回配置错误。打开 root 时严格使用配置记录的 factory，不猜测缺失字段。

## Root 路径词法安全边界

`RelativeViewPath` 只能定位当前 root 内的对象。加密 root 的 view-path 操作经过 `viewPathToStorePathCheck`，`RenameByStorePath` 与 `PlainFS` 共用 `fullPathFromRelativeStorePath`；两条路径遵守相同不变量：

- 空路径表示 root 本身；
- `a/../b` 先规范化为 root 内的 `b`，允许使用；
- 绝对路径、URI、UNC、Windows drive 路径不能作为 root 相对路径；
- 规范化后仍以 `..` 开头的路径返回 `ErrPathTraversal`；
- 文件名加密后的 store path 必须重新解析为真实 component，再与 root 组合，不能把含分隔符的整串路径当成单个 component 做前缀判断。

该边界覆盖加密 root 和 `PlainFS` 的 `OpenFile`、`DeleteFile`、`MkdirAll`、`Rename`、`RenameByStorePath`、`Stat`、`WalkDir`，以及 quick FFI 与 Transfer V3。测试同时覆盖 `nameFactory=none` 和 `aes-gcm-name`，并验证失败调用不会在 root 外创建文件或目录。

这里保证的是路径字符串规范化后的词法 containment。若 root 所在目录可被其他进程并发修改，仍缺少基于目录句柄或 Linux `openat2` 的无 TOCTOU 符号链接防护；在完成该设计前，不应声称可抵抗本地同权限攻击者对 store 目录的并发替换。

## 已验证场景

- 四种 KDF 创建空 root 后，正确密码可打开，错误密码被拒绝。
- 四种 KDF 对相同密码创建两个 root 时 salt 均不同。
- CLI 与 FFI 默认创建均记录 `argon2id`，相同密码跨入口创建的 root 使用不同 salt。
- verifier 缺失与损坏时失败关闭。
- FFI 错误密码不分配 `root_id`，也不向 `RootStore` 泄漏对象。
- CLI 的 list/export 错误密码路径失败。
- Dart 真 FFI 覆盖目录 import 完成后关闭 root，错误密码重开失败，正确密码重开并读取原内容。
- CLI 创建 root 后由 Dart 操作、Dart/FFI 创建 root 后由 CLI 操作，双向互通及错误密码拒绝均有真库测试。
- `aes-gcm-name` 的多层目录、文件名、空目录和 transfer 往返已有测试。
- sec root 与 Go FFI 的 quick write/V3 import 均拒绝 `../` 路径逃逸，且根外无副作用。

## 密钥生命周期

- `IKeyInfo` 强制实现 `Destroy()`；Argon2、PBKDF2、scrypt 和 HKDF 的 keyInfo 会覆写自身持有的 key backing slice 并置空引用。
- `INameCryptorContext` 强制实现 `Close()`；AES-GCM name 和 RC4 name context 会清零自有 key 并释放 cipher 引用。
- `secRootImpl.Close()` 先关闭 name context，再销毁 keyInfo；即使 name context Close 返回错误，key 仍必须清零。重复 Close 幂等。
- root 创建/打开的 verifier 失败、factory 失败和 constructor 失败路径会销毁已派生 key。`CloneRootShallow` 使用独立 key copy 和 name context，关闭原 root 不影响 clone。
- 这不等于进程内所有密钥副本可证明地清零：Go 标准库 cipher 的内部展开状态不可由当前代码直接覆写，且 Dart `String` 仍只能 best-effort 处理。

## 尚未完成或需要重构

- Flutter/CLI 创建 UI 尚未提供完整算法选择，当前显式使用 `nameFactory=none`。
- KDF 成本参数的时间标定仍较粗糙，`KeyStrengthMs` 尚未形成跨算法一致基准。
- 主密钥尚未按用途派生独立的 data/name/verifier 子密钥。
- 文件内容认证、配置整体认证、防回滚和配置原子写入尚未形成完整方案。
- root/store 的符号链接与并发路径替换尚未形成跨平台、无 TOCTOU 的完整防护。
- 改密码与可变 file key 模型不在当前实现中；旧文档对此标记“已完成”是不准确的。

## 安全规则

1. 任何入口都必须通过 `OpenRootQuick` 或等价认证路径，不能只调用 `LoadKey` 后直接构造 root。
2. FFI 只能在 sec 认证成功后写入 `RootStore`。
3. walker 的单项解密失败不能用来判断密码；密码必须在遍历前认证。
4. 不在日志、进度、marker 或 JSON 响应中记录密码和派生 key。
5. 新增 KDF 时必须复用统一 verifier，并加入错误密码测试。
6. 新增创建入口时必须验证 CLI、FFI、Dart 创建与打开互通。
