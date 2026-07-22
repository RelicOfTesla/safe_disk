# 自动锁定内容窗口收敛协议

## 状态

第一批实现已完成自动锁定的子窗口预处理链路：主窗口使用每个 `WindowController` 的专用通道请求 `document.prepareLock`；记事本把脏文本写为同目录加密草稿后冻结编辑；桥接层收齐确认后才撤销 capability 并关闭窗口。此状态不代表 `UI-39` 完成，仍缺统一 close gate、重新解锁竞争和三平台真实窗口验收。

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
4. 主窗口收齐所有 token 的成功确认后，撤销 capability，等待已接受的主保存收尾，关闭原生窗口，再关闭 native root。
5. 任一窗口拒绝、超时、窗口消失或草稿写入失败时，主窗口向所有候选子窗口发送同一 `lockRequestID` 的 `document.cancelLock`；已冻结的记事本恢复编辑，root 保持打开，恢复可见后显示脱敏摘要；不得关闭任一 token。

图片窗口无可编辑状态，可直接确认；只读记事本也可直接确认。协议只针对已建立内容窗口 lease 的 root。

## 已实现边界

- `ContentWindowLockEndpoint` 按 capability token 校验请求；未知 token、空请求 ID 和未知方法均拒绝。
- `SecureNotepadController.prepareForLock` 冻结编辑，等待已有保存/草稿写入，再循环写入最新脏文本的安全草稿；草稿失败会取消冻结并回复 `failed`。
- 图片窗口直接回复 `prepared`；主窗口内嵌记事本不具备该 RPC，自动锁定会继续跳过整个 root。
- `ContentWindowHostBridge.prepareAndCloseRootWindows` 对所有 native token 并发请求，校验完整且无重复的回复集合；超时、窗口消失、拒绝或新增窗口会向全部候选 token 发出取消，保持 token 和 native 窗口不变。
- capability 撤销后才开始原生窗口关闭；撤销会等待已接受的保存收尾。原生关闭本身失败时 token 已被撤销，root 不会继续关闭，须由后续窗口生命周期处理。

## 所需平台能力

使用每个 `WindowController` 的专用方法通道：主窗口按 token 找到 controller 并调用 `document.prepareLock`，子窗口在自身 controller 注册 handler 后返回结果。不得复用全局单向文档 channel，也不得通过全局广播、文件轮询或明文临时文件绕过。

新增请求与响应必须绑定：

- `rootSessionID` 只在主窗口保存，子窗口只接收 capability token 和 `lockRequestID`。
- `lockRequestID` 为随机、单次、短时有效；旧请求、重复回复和 token 已撤销时一律拒绝。
- 子窗口关闭前的回复不代表 root 已关闭；主窗口仍须重新检查 token、脏状态和活动写入。

## 竞争与超时

- 当前生命周期回调在关闭 root 前后验证 path/session ID；重新解锁获得新 session ID 时，旧计划不得关闭新 root。预处理期间的重新解锁竞争尚缺专门回归。
- 手动结束会话、改密关闭和 TTL 关闭共用每 root 串行 close gate仍未实现；目前自动锁定仅以全局运行标志防止自身重入，不能把此限制误记为已完成。
- 请求超时后不撤销 token，防止迟到草稿写入落到已关闭 root；主窗口只记录失败并等待用户处理。

## 测试门槛

- controller/endpoint：脏文本落草稿、草稿失败不确认、token/request ID 校验，以及超时后迟到完成会取消冻结已覆盖；重复请求和保存中的实际子窗口仍缺。
- bridge：按 token 请求、确认后才 revoke/close、拒绝时不关闭已覆盖；超时、窗口消失和原生 close 失败仍缺。
- Home：hidden/paused、TTL 成功关闭 clean 内容窗口、拒绝时保持 root 已覆盖；手动关闭和重新解锁竞争仍缺。
- 桌面：Linux、Windows、macOS 实测多窗口、标题栏关闭、休眠恢复和强制关闭子窗口。
