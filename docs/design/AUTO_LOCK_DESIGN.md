# 自动锁定与会话密钥清理设计

> 状态：应用隐藏锁定和 per-root TTL 已实现并有 widget 证据；主动关闭子窗口时会先撤销 capability 并等待已接受的保存收尾。真实桌面、脏子窗口锁定协议与跨平台验收未完成。本文不能作为跨平台完成证明。

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
| 有干净内容窗口 | 不关闭。关闭 native root 会使子窗口持有失效能力，必须由后续子窗口锁定 RPC 统一处理 |
| 有脏文档或活动写入 | 不关闭。不得为了自动锁定丢弃内存修改或中断写入 |
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
- widget 覆盖设置保存、默认不锁、合格 root 在 `paused` 后关闭且恢复后需重新验证、两个已解锁 root 逐一关闭且不泄露旧条目，以及已打开图片内容窗口时跳过锁定。
- broker/controller 覆盖脏记事本与活动写入分别阻断关闭；per-root TTL 已使用独立活动时钟并复用同一关闭协调器，设置页可持久化、无效值回退到默认值且返回主页后重载。Home widget 覆盖 TTL 到期、当前 root 活动重置、内容窗口/脏文档/活动写入阻断和设置返回后的新 deadline。bridge 回归覆盖撤销先于原生关闭、迟到 RPC 被拒绝、已接受的保存先收尾。Home 与子窗口协议的旧生命周期回调/重新解锁竞争，以及真实 FFI 或桌面平台验收仍未覆盖。

## 验收

- Settings：开关读取、修改、放弃修改和保存持久化。
- Home：开启时 `hidden`/`paused` 关闭合格 root；关闭时无动作；多个 root 独立处理；当前 root 锁定后无法继续文件操作。
- 安全：关闭调用 native root close，剪贴板项和 broker session 都释放；有脏窗口/活动写入时不关闭、不丢数据。
- 竞争：生命周期回调与重新解锁/手动结束会话并发时，旧回调不能关闭新 session。
- 平台：Linux widget/真实 FFI 自动化；Windows/macOS 生命周期实机验收留在跨平台清单。
