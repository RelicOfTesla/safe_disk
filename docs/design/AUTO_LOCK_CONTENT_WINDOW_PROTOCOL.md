# 自动锁定内容窗口收敛协议

## 状态

第一批实现已完成自动锁定的子窗口预处理链路：主窗口使用每个 `WindowController` 的专用通道请求 `document.prepareLock`；记事本把脏文本写为同目录加密草稿后冻结编辑；桥接层收齐确认后先可逆冻结 broker、等待已接受保存，再关闭窗口。只有原生关闭成功后才撤销 capability。自动、手动结束会话和改密关闭现按 root session 使用同一 FIFO gate。此状态不代表 `UI-39` 完成，仍缺重新解锁竞争和三平台真实窗口验收。

## 当前边界与可用能力

- 子窗口通过 `WindowMethodChannel` 单向调用主窗口：读取、保存、草稿写入、脏状态和关闭通知。
- 全局文档 channel 仍只用于子窗口调用主窗口；锁定预处理使用独立的逐窗口 channel，不复用全局 channel。
- 本地 `desktop_multi_window` 路径依赖已提供 `WindowController.invokeMethod` 与子窗口当前 controller 的 `setWindowMethodHandler`，可建立逐窗口双向 RPC。
- `DocumentSessionBroker.revokeRootSessions` 能撤销 token 并等待已接受的保存收尾，但不能把子窗口内尚未发送的编辑内容写成草稿。

因此，自动锁定不得直接调用 `closeRootWindows` 或 `revokeRootSessions` 处理脏窗口；应先使用独立的逐窗口锁定 RPC 收集确认，否则会让内存中尚未同步的文本丢失。

## 目标协议

自动锁定含内容窗口的 root 应分两阶段执行：

1. 主窗口为该 root 创建一次性的 `lockRequestID`，向每个内容窗口发送 `document.prepareLock` 请求。
2. 记事本收到请求后停止新的编辑提交，等待本地保存队列结束；若有未保存内容，使用既有安全 root 接口写入同目录草稿。
3. 子窗口仅在草稿写入成功或本身无脏内容时回复 `document.prepareLock` 的结果；回复包含 token、`lockRequestID` 与 `prepared`/`failed` 状态，不携带明文。
4. 主窗口收齐所有 token 的成功确认后，可逆冻结 broker（拒绝新调用、保留 lease），等待已接受的主保存收尾并再次核对 token 集合，关闭原生窗口，再不可逆撤销 capability 和 native root。
5. 任一窗口拒绝、超时、窗口消失、草稿写入失败或冻结期间 token 集合变化时，主窗口向所有候选子窗口发送同一 `lockRequestID` 的 `document.cancelLock`；已冻结的记事本恢复编辑，root 保持打开，恢复可见后显示脱敏摘要；不得主动关闭任一 token。
6. 原生关闭调用失败时，主窗口同样取消预处理并解除 broker 冻结，root 和仍存活的 lease 保持可用。多窗口平台的逐个关闭并非原子操作；若平台已关闭部分窗口后才报错，该子窗口的后续生命周期通知仍会单独释放其 lease，不能把“root 未关闭”表述为“所有子窗口都仍打开”。

图片窗口无可编辑状态，可直接确认；只读记事本也可直接确认。协议只针对已建立内容窗口 lease 的 root。

## 已实现边界

- `ContentWindowLockEndpoint` 按 capability token 校验请求；未知 token、空请求 ID 和未知方法均拒绝。
- `SecureNotepadController.prepareForLock` 冻结编辑，等待已有保存/草稿写入，再循环写入最新脏文本的安全草稿；草稿失败会取消冻结并回复 `failed`。
- 图片窗口直接回复 `prepared`；主窗口内嵌记事本不具备该 RPC，自动锁定会继续跳过整个 root。
- `ContentWindowHostBridge.prepareAndCloseRootWindows` 对所有 native token 并发请求，校验完整且无重复的回复集合；超时、窗口消失、拒绝或新增窗口会向全部候选 token 发出取消，保持 root 打开。保存排空期间会再次比对 token 集合，避免对过期快照关闭。
- `DocumentSessionBroker.freezeRootSessions` 在原生关闭前拒绝新的 document 调用，但保留 capability 并等待已接受保存；原生关闭成功后才执行不可逆 `revokeRootSessions`。关闭失败会取消子窗口预处理并恢复 broker lease。
- 子窗口 endpoint 对同一 `lockRequestID` 的重复 `prepareLock` 必须共享同一次准备结果；当已有不同请求处于准备或已确认状态时，不得再次触发草稿写入或覆盖锁定状态。

## 所需平台能力

使用每个 `WindowController` 的专用方法通道：主窗口按 token 找到 controller 并调用 `document.prepareLock`，子窗口在自身 controller 注册 handler 后返回结果。不得复用全局单向文档 channel，也不得通过全局广播、文件轮询或明文临时文件绕过。

新增请求与响应必须绑定：

- `rootSessionID` 只在主窗口保存，子窗口只接收 capability token 和 `lockRequestID`。
- `lockRequestID` 为随机、单次、短时有效；旧请求、重复回复和 token 已撤销时一律拒绝。
- 子窗口关闭前的回复不代表 root 已关闭；主窗口仍须重新检查 token、脏状态和活动写入。

## 竞争与超时

- 当前生命周期回调在关闭 root 前后验证 path/session ID；重新解锁获得新 session ID 时，旧计划不得关闭新 root。预处理期间的重新解锁竞争尚缺专门回归。
- 自动锁定、手动结束会话和改密关闭共用每 root session 的 FIFO close gate；进入 gate 后重新验证 path/session 身份并读取关闭决策。该实现尚缺真实重新解锁、子窗口标题栏关闭及多操作交错的桌面 E2E。
- 请求超时后不撤销 token，防止迟到草稿写入落到已关闭 root；主窗口只记录失败并等待用户处理。

## 测试门槛

- controller/endpoint：脏文本落草稿、草稿失败不确认、token/request ID 校验、同请求重复幂等、冲突请求拒绝，以及超时后迟到完成取消冻结均须覆盖。
- bridge：按 token 请求、确认后冻结/revoke/close、拒绝时不关闭、保存排空期间集合变化和原生 close 失败恢复 lease 已覆盖；真实窗口消失事件与部分关闭失败仍缺。
- Home：hidden/paused、TTL 成功关闭 clean 内容窗口、拒绝或 close 失败时保持 root，以及 gate 重构后的既有关闭行为已覆盖；手动关闭与重新解锁的主动竞争仍缺。
- 桌面：Linux、Windows、macOS 实测多窗口、标题栏关闭、休眠恢复和强制关闭子窗口。
