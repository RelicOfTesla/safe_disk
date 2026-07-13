# Stream V3 实施路线图

> 状态：产品功能 15%。当前只有设计资料和残留 Dart service/model；活跃 NativeLib 明确返回 unsupported。历史文档声称的 `native/crypto/stream_v3.go` 当前不存在，不能作为实现证据。
>
> 本路线图不要求兼容旧 V1/V2 stream 格式。百分比遵循 [../TODO.md](../TODO.md)，没有自动化实际功能测试时最高 90%。

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
