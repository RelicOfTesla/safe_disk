# 自动锁定内容窗口收敛协议

## 状态

设计阶段。`UI-39` 当前只能自动锁定没有内容窗口、脏文档或活动写入的 root。手动结束会话可关闭干净内容窗口；自动锁定不能复用该路径，因为它不能向子窗口请求草稿持久化确认。

## 当前边界与可用能力

- 子窗口通过 `WindowMethodChannel` 单向调用主窗口：读取、保存、草稿写入、脏状态和关闭通知。
- 当前产品的全局文档 channel 仅用于子窗口调用主窗口；主窗口目前仅能按 token 请求原生窗口关闭。
- 本地 `desktop_multi_window` 路径依赖已提供 `WindowController.invokeMethod` 与子窗口当前 controller 的 `setWindowMethodHandler`，可建立逐窗口双向 RPC。
- `DocumentSessionBroker.revokeRootSessions` 能撤销 token 并等待已接受的保存收尾，但不能把子窗口内尚未发送的编辑内容写成草稿。

因此，自动锁定不得直接调用 `closeRootWindows` 或 `revokeRootSessions` 处理脏窗口；应先使用独立的逐窗口锁定 RPC 收集确认，否则会让内存中尚未同步的文本丢失。

## 目标协议

自动锁定含内容窗口的 root 应分两阶段执行：

1. 主窗口为该 root 创建一次性的 `lockRequestID`，向每个内容窗口发送 `document.prepareLock` 请求。
2. 记事本收到请求后停止新的编辑提交，等待本地保存队列结束；若有未保存内容，使用既有安全 root 接口写入同目录草稿。
3. 子窗口仅在草稿写入成功或本身无脏内容时回复 `document.lockPrepared`；回复包含 token、`lockRequestID` 与结果枚举，不携带明文。
4. 主窗口收齐所有 token 的成功确认后，撤销 capability，等待已接受的主保存收尾，关闭原生窗口，再关闭 native root。
5. 任一窗口拒绝、超时、窗口消失或草稿写入失败时，取消本轮自动锁定：root 保持打开，恢复可见后显示脱敏摘要；不得关闭已确认窗口以外的 token。

图片窗口无可编辑状态，可直接确认；只读记事本也可直接确认。协议只针对已建立内容窗口 lease 的 root。

## 所需平台能力

使用每个 `WindowController` 的专用方法通道：主窗口按 token 找到 controller 并调用 `document.prepareLock`，子窗口在自身 controller 注册 handler 后返回结果。不得复用全局单向文档 channel，也不得通过全局广播、文件轮询或明文临时文件绕过。

新增请求与响应必须绑定：

- `rootSessionID` 只在主窗口保存，子窗口只接收 capability token 和 `lockRequestID`。
- `lockRequestID` 为随机、单次、短时有效；旧请求、重复回复和 token 已撤销时一律拒绝。
- 子窗口关闭前的回复不代表 root 已关闭；主窗口仍须重新检查 token、脏状态和活动写入。

## 竞争与超时

- 生命周期回调按 root session ID 建立关闭计划；每个异步阶段前后均验证该 path 仍指向同一 session ID。重新解锁获得新 session ID 时，旧计划不得关闭新 root。
- 手动结束会话、改密关闭和 TTL 关闭与自动锁定共用每 root 串行 close gate；同一 root 同时只能有一个关闭计划。
- 请求超时后不撤销 token，防止迟到草稿写入落到已关闭 root；主窗口只记录失败并等待用户处理。

## 测试门槛

- broker：脏/干净/只读窗口的 prepare 结果、草稿失败、迟到回复、重复回复和正在保存的顺序。
- bridge：按 token 请求、超时取消、收到全部确认后才 revoke/close，任何失败不关闭 root。
- Home：hidden/paused、TTL、手动关闭和重新解锁竞争；旧计划不能关闭新 session。
- 桌面：Linux、Windows、macOS 实测多窗口、标题栏关闭、休眠恢复和强制关闭子窗口。
