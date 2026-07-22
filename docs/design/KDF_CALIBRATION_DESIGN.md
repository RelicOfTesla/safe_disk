# KDF 成本校准设计

> 状态：仅完成设计。当前 `keyStrengthMs` 只是创建时传给各 KDF 的粗略映射，不是实测校准值；设置页、FFI 和 UI 均未提供校准功能。

## 1. 问题与目标

当前 Argon2id、scrypt、PBKDF2 各自解释 `KeyStrengthMs`：

- Argon2id 同时改变 time 与 memory；
- scrypt 用几个阈值选择 `N`；
- PBKDF2 只区分是否大于零。

相同毫秒值没有跨算法、跨设备的一致含义，且 UI 的“派生强度”会让用户误以为它是实测耗时。

首版目标是为**新建 root**生成一组已在当前设备测量、受安全上限保护的 KDF 参数。已有 root 永远读取其已保存参数，不在打开时重新校准或修改。

非目标：

- 不自动迁移旧 root。
- 不在解锁路径实时 benchmark。
- 不承诺不同设备得到相同参数或相同精确耗时。
- 不以浏览器、Flutter 或 JavaScript 计时替代 sec 层测量。

## 2. 安全与资源边界

- 校准只能由 sec 层执行，使用单次临时 salt 和固定短测试密码；测试密码、派生 key 和中间 buffer 必须在调用结束时清零。
- 校准结果只允许写入创建配置；不得覆盖已经存在的 root config。
- 目标耗时是建议值，不是无上限指令。所有算法都有固定最小值、最大值、最大内存和最大试验次数。
- 低内存、超时、取消或算法不可用时返回结构化失败，UI 必须改用明确的安全默认参数，并说明“未校准”，不能静默降到弱参数。
- 校准期间不记录密码、原始性能数据、CPU 型号或可识别设备信息。持久化的仅是用户选择的目标档位，不是 benchmark 轨迹。

## 3. 配置模型

创建请求从单一 `keyStrengthMs` 迁移为：

```json
{
  "deriverFactory": "Argon2id",
  "kdfProfile": "balanced",
  "kdfCalibration": {
    "targetMs": 1000,
    "mode": "device-calibrated"
  }
}
```

- `kdfProfile`: `fast`、`balanced`、`strong`；仅映射目标耗时和资源政策，不直接映射算法参数。
- `mode`: `device-calibrated` 或 `safe-default`。前者仅在显式校准成功后使用；后者是可审计的固定参数。
- 兼容期 FFI 仍接受 `keyStrengthMs`，但它只映射到 profile，不能声称已校准。待所有活跃调用迁移后再删除。
- root config 继续保存算法原生参数（例如 `argon2_time`）；新增可选元数据 `sec_kdf_profile`、`sec_kdf_calibrated` 和 `sec_kdf_target_ms` 只用于属性展示，不参与解锁。

## 4. sec 接口

```text
CalibrateKDF(ctx, factoryName, profile, limits) -> KDFCalibrationResult
CreateRootConfigQuick(..., WithKDFParameters(result.Parameters))
```

`KDFCalibrationResult` 必须包含算法名、最终原生参数、测量耗时、是否命中上限和可展示的失败分类。sec 层按以下步骤执行：

1. 校验 factory/profile/limits。
2. 从该算法的最低安全参数开始测量。
3. 以有界的单调搜索提高成本，直到目标区间或上限；每次试验检查 context。
4. 复测最终候选一次，拒绝明显抖动或超时结果。
5. 返回参数，不写磁盘；只有 root 创建成功后才持久化参数。

算法策略必须分别定义，不允许把毫秒换算公式散落在各 factory：

- Argon2id：先选择可承受的 memory，再增长 time；线程数受 CPU 数和上限约束。
- scrypt：只在安全可分级集合中提高 `N`，固定或受限 `r/p`，先估算内存再执行。
- PBKDF2：仅增加 iterations；必须有足够高的最小 iterations，且明确其内存硬度较弱。

## 5. FFI、Dart 与 UI

```text
创建对话框
  -> KdfCalibrationService（异步、取消、结果缓存仅本进程）
  -> FFI sec_kdf_calibrate
  -> sec_fs CalibrateKDF
```

- 创建对话框默认展示“平衡，约 1 秒（未校准）”。用户可在高级参数中主动点击“在此设备校准”。
- 校准运行时显示算法、目标档位、取消按钮和“不写入密码或文件”的说明；不能阻塞主线程。
- 成功后显示实际测量区间和资源提示，用户仍可选择固定安全默认值。
- 设置页仅保存新建目录的默认 profile；不保存机器性能结果，也不影响已有目录。
- root 属性页展示已存原生参数和“创建时已校准/安全默认”，但不把它解释为当前设备性能。

## 6. 验收

自动化：

- 三种可用 KDF 的最小/目标/上限/取消/超时/内存预算测试。
- 参数单调性、持久化后可重新打开、旧 root 兼容和错误密码拒绝。
- FFI 结构化结果、Dart isolate 取消、创建页面进度/错误/回退和设置事务测试。
- 故障注入：配置写入失败不能留下已校准但不可打开的 root。

桌面实测：

- Linux、Windows、macOS 的低端/高端设备；内存压力、睡眠恢复、取消和窗口关闭。
- 每个平台确认校准不会卡死 UI、不会写出密码/性能日志，且创建后的 root 可被 CLI、FFI、Dart 互开。
