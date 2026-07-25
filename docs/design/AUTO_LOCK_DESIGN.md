# 自动锁定与会话密钥清理设计

> 状态：应用隐藏锁定和 per-root TTL 已实现并有 widget 证据；自动锁定的 native 子窗口现会先执行草稿确认协议，成功后才撤销 capability 并关闭。自动、手动结束会话和改密关闭已按 session 共用 FIFO close gate；重新解锁竞争、真实桌面与跨平台验收仍未完成。本文不能作为跨平台完成证明。

## 目标与非目标

启用“应用隐藏时自动锁定”后，应用进入 `hidden` 或 `paused` 生命周期状态时，应关闭可安全关闭的 secure root，使 native root 内的密钥和目录 cursor 不再可用。

第一阶段目标：锁定没有内容窗口、没有脏文档、没有活动写入的 root；清理该 root 的应用内文件剪贴板；保留侧边栏历史，并把当前目录恢复为未验证状态。

第一阶段不做：在后台强制关闭有脏内容窗口、将明文写到应用私有目录、或假装 overlay 屏幕锁等同于密钥清理。TTL 在第二阶段独立接入，不能借此绕过相同的关闭规则。

## 生命周期策略

- 只响应 `hidden` 和 `paused`。`inactive` 在桌面上可能只表示焦点切换，不能把一次短暂切换误判为离开应用。
- 设置默认关闭，值使用已有的 `auto_close_session` 偏好键，产品文案改为“应用隐藏时自动锁定”。
- 回调可重入。一次自动锁定未完成前忽略后续生命周期通知；每个候选 root 在关闭前必须再次确认 session ID 仍匹配，防止旧异步回调关闭重新解锁的 root。
- 若主窗口主动关闭带有内容窗口的 root，必须先撤销对应文档 capability，再等待原生窗口退出。撤销后的迟到 RPC 一律失败；原先已经进入保存队列的写入允许收尾，并继续由活动写入规则阻断 root 关闭。

## Root 关闭规则

对每个已验证 root 先调用 `RootCloseCoordinator.inspect`：

| 状态 | 第一阶段动作 |
|---|---|
| 无窗口、无脏文档、无活动写入 | 关闭目录 cursor，关闭 native root，清除该 root 剪贴板项，释放 broker session，保留历史并标为未验证 |
| 仅有 native 内容窗口 | 请求每个窗口锁定预处理；记事本成功写同目录加密草稿后，统一撤销 capability、关闭窗口及 root |
| 主窗口内嵌编辑器、草稿失败、窗口拒绝/消失或无法由 native 子窗口收尾的活动写入 | 不关闭；已冻结子窗口收到取消后恢复编辑。不得为了自动锁定丢弃内存修改或中断写入 |
| native close 失败 | 保持原会话，记录脱敏错误并在恢复可见后提示 |

自动锁定不弹出阻塞确认框。若有被跳过的 root，应用恢复可见后只显示摘要提示，用户可保存内容后手动结束会话。

## 当前目录与资源

- 当前 root 被锁定时，清空当前条目和选择状态，保留 root 的历史/别名及当前路径；随后必须按未验证目录要求重新输入密码。
- 关闭 root 前应释放其 `DirectoryPageSession`，避免 Dart 侧保留已失效的 cursor ID。
- root 关闭路径必须与现有手动“结束会话”共用 key/clipboard/broker 清理顺序，不能直接调用 FFI 绕开上层状态。

## 后续阶段

1. 为内容窗口协议加入“写入加密草稿并确认锁定”请求；收到所有确认后才能锁定含窗口 root。
2. per-root 空闲计时和可选 TTL 已接入；活动事件和到期锁定复用同一关闭协调器。Home 已覆盖内容窗口、脏文档和活动写入的 TTL 阻断；仍需真实桌面验收。
3. 在 Windows/macOS/Linux 真实桌面验证 hidden/paused 事件、系统休眠和多窗口切换。

## 当前实施证据

- `SettingsPage` 已提供“应用隐藏时自动锁定”开关，并通过 `auto_close_session` 持久化；离开设置页后 HomePage 会重新读取该值。
- HomePage 已作为 `WidgetsBindingObserver` 监听 `hidden` 和 `paused`。满足关闭条件的 root 会先释放当前 Dart 目录 cursor，随后关闭 native root、清理应用内剪贴板和 broker lease，并保留侧边栏条目为未验证状态。
- 每个 root 的关闭异常会被隔离为失败计数，避免一个 cursor 或 native close 失败阻断其他 root；`resumed` 后显示锁定、跳过或失败摘要。前台 TTL 到期也会显示首次摘要；相同摘要会去重，避免按计时检查周期重复提示。
- widget 覆盖设置保存、默认不锁、合格 root 在 `paused` 后关闭且恢复后需重新验证、两个已解锁 root 逐一关闭且不泄露旧条目，以及已打开 clean 图片内容窗口后的预处理锁定/拒绝保持打开。
- broker/controller 覆盖脏内嵌记事本与不可收尾活动写入阻断关闭；per-root TTL 已使用独立活动时钟并复用同一关闭路径，设置页可持久化、无效值回退到默认值且返回主页后重载。Home widget 覆盖 TTL 到期、当前 root 活动重置、native 内容窗口确认后关闭/拒绝保留，以及设置返回后的新 deadline。bridge 回归覆盖撤销先于原生关闭、已接受的保存先收尾、拒绝后取消已冻结窗口。重新解锁竞争、迟到/窗口消失、原生 close 失败，以及真实 FFI 或桌面平台验收仍未覆盖。

## 验收

- Settings：开关读取、修改、放弃修改和保存持久化。
- Home：开启时 `hidden`/`paused` 关闭合格 root；关闭时无动作；多个 root 独立处理；当前 root 锁定后无法继续文件操作。
- 安全：关闭调用 native root close，剪贴板项和 broker session 都释放；有脏窗口/活动写入时不关闭、不丢数据。
- 竞争：生命周期回调与重新解锁/手动结束会话并发时，旧回调不能关闭新 session。
- 平台：Linux widget/真实 FFI 自动化；Windows/macOS 生命周期实机验收留在跨平台清单。

## 内容窗口收敛协议

此协议实现在自动锁定时，主窗口向所有内容子窗口发送 `document.prepareLock`，由子窗口先将脏内容落草稿后再确认关闭，避免直接撤销窗口能力造成内存文本丢失。

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
- Home：hidden/paused、TTL 成功关闭 clean 内容窗口、拒绝或 close 失败时保持 root，以及手动关闭子窗口期间后台锁定到达时只关闭一次 root 的 gate 行为已覆盖；重新解锁主动竞争仍缺。
- 桌面：Linux、Windows、macOS 实测多窗口、标题栏关闭、休眠恢复和强制关闭子窗口。
