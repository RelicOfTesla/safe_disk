# Flutter 内容多窗口设计

> 状态：核心会话层、原生窗口通道和安全记事本子窗口已实现；Linux X11 已完成手工跨 engine 实测。Windows/macOS 与异常退出自动化 E2E 尚未完成，因此不能视为跨平台完成。

## 当前实施状态（2026-07-14）

已实现：

- `DocumentSessionBroker`：窗口 token、稳定 documentID、root lease 与脏状态；
- 保存前重新读取并与完整字节快照比较，不以时间戳或简化 hash 代替冲突检测；
- `RootCloseCoordinator`：区分无窗口、干净窗口、未保存窗口和活动写入；
- 同一 documentID 的保存已串行化，排队/执行中的写入持有 lease，关闭窗口不会提前释放正在使用的 root；
- HomePage 打开的安全记事本已申请 lease，控制器编辑/保存/dispose 会同步脏状态、revision 和释放；
- broker、控制器同文件冲突及 root 关闭决策已有自动化测试。
- 使用 `desktop_multi_window 0.3.0` 创建同进程独立 Flutter engine，使用 `window_manager 0.5.2` 关闭当前原生窗口；
- Linux、Windows、macOS runner 已注册新 engine 插件回调；
- `ContentWindowHostBridge`、`DocumentWindowClient` 和 `RemoteDocumentCryptoService` 已形成 host/client 边界，启动参数仅含协议版本、窗口类型、token、documentID 和标题；client 请求有统一超时，首次握手失败显示只读错误页而非空白窗口；
- 子窗口复用完整 `SecureNotepad`/`SecureImageViewer`；记事本正文保存、草稿读写、脏状态，以及图片只读字节和两类窗口关闭通知均经 host broker；
- host 会监听原生窗口集合，异常消失时释放 lease；结束 root 会先阻断脏窗口/活动写入，再主动关闭干净窗口；
- Linux 使用仓库内受控 `desktop_multi_window 0.3.0` 补丁：GTK 销毁子窗口时不得显式 unparent engine 的 implicit `FlView`；子 widget dispose 阶段不得再发 platform channel，lease 统一由 host 的窗口集合监听回收；
- Linux X11 已手工看到独立主窗口、记事本和图片子窗口，子 engine 成功读取 broker 正文并解码 PNG；`GDK_SYNCHRONIZE=1` 下五轮记事本创建/销毁探针正常退出；当前完整 Flutter 真 FFI 回归共 105 项通过，静态分析零问题。

尚未实现：

- Windows/macOS 真实窗口运行与打包验证；
- 同文件双窗口编辑冲突、子窗口强杀和主窗口退出的自动化桌面 E2E；
- 更严格的窗口身份绑定；当前已限制请求时长，但尚未把 token 首次握手绑定到不可伪造的原生窗口身份。

当前依赖已固定在产品清单。Linux 证据证明基础同进程多 engine 与通道可行，但不能据此推断 Windows/macOS 已通过。

## 1. 目标与非目标

目标：

- Linux、Windows、macOS 上允许同时打开多个安全记事本或查看器窗口。
- 每个窗口有独立标题、尺寸、焦点和关闭生命周期。
- 关闭任一内容窗口不关闭主界面，也不提前释放其他窗口仍在使用的 root session。
- 密码、派生密钥和明文内容不通过命令行参数、环境变量或磁盘临时文件传递。
- 同一逻辑文件被多个窗口编辑时必须检测冲突，不能静默后写覆盖。

本阶段非目标：

- 移动平台多窗口。
- 子窗口独立打开或创建 root。
- 跨进程恢复未保存明文草稿。
- 将页面内标签页冒充操作系统窗口。

## 2. 当前代码事实

- `HomePage` 持有已打开 root、`tempKeyID` 和导航状态。
- `SecureNotepad` 通过当前 `CryptoService`/root session 直接读写加密文件，不写明文临时文件。
- rootID 存储在 Go 动态库进程内的全局 store 中；它不是可跨进程复用的持久标识。
- 当前 `pubspec.yaml` 已声明 `desktop_multi_window` 与 `window_manager`，三平台 runner 已注册子 engine 插件。

因此，多窗口不能只增加一次 `Navigator.push`，也不能把 rootID 放进子进程启动参数。

## 3. 推荐架构

采用“主窗口 broker + 内容窗口 client”模型：

1. 主窗口是 root session 的唯一所有者，负责认证、rootID 生命周期和关闭策略。
2. 内容窗口只保存不可猜测的 `windowToken`、逻辑 `documentID` 和显示状态。
3. 子窗口通过进程内消息通道向 broker 请求 `read`、`save`、`stat` 和 `closeLease`。
4. broker 将 `documentID` 映射到 `(rootID, relativePath)`，子窗口不能自行拼接物理存储路径。
5. 每个打开的文档窗口持有一份 session lease；root 只有在主界面关闭请求成立且 lease 数为零时才能真正 `sec_root_close`。

当前方案是同进程多 Flutter engine，消息通道仍作为强制边界，不假设不同 Dart isolate 能共享普通 Dart 单例。原生能力创建失败时回退主窗口路由，不能通过启动参数传递 rootID 或密钥。

## 4. 生命周期

### 打开窗口

1. 主界面确认 root 已解锁。
2. broker 创建 `documentID`、窗口 token 和 lease。
3. 创建原生内容窗口，仅传递 token，不传密码、rootID、物理路径或明文。
4. 子窗口就绪后通过 token 握手，再请求文档内容。
5. 握手超时或创建失败时，broker 回收 lease。

### 关闭 root

- 无内容窗口、无未保存内容、无活动写操作：直接关闭。
- 有内容窗口但均已保存：提示“同时关闭 N 个内容窗口”，确认后依次关闭窗口并释放 root。
- 有未保存内容：阻止直接关闭，聚合列出未保存文档；用户可逐个保存、放弃或取消关闭。
- 子窗口异常退出：broker 根据窗口销毁事件回收 lease，但不能把未确认写入视为已保存。

### 主窗口退出

主窗口统一协调所有内容窗口。首版不支持“主窗口退出后子窗口继续运行”，因为 broker 与 root session 均由主窗口拥有。

## 5. 保存与冲突

每次读取返回 `revision`，建议由以下稳定元数据组合生成：

- 逻辑文件大小；
- 精确修改时间或底层单调版本；
- 必要时增加加密内容摘要。

保存请求必须携带读取时的 `baseRevision`。broker 写入前重新读取当前 revision：

- 相同：允许原子写入，返回新 revision。
- 不同：返回冲突，提供“重新加载”“另存为”“确认覆盖”，默认不得覆盖。

同一文件的多个窗口不共享一个 `TextEditingController`，否则窗口生命周期和撤销栈会互相污染。

## 6. 安全边界

- 禁止把密码、rootID、密钥、明文和物理存储路径放入窗口启动参数。
- token 至少 128 位随机数、仅进程生命周期有效、首次握手后绑定窗口身份。
- 窗口标题默认只显示明文文件名；应提供隐私模式隐藏标题中的文件名。
- 剪贴板、崩溃转储、系统截图和输入法仍在应用威胁模型之外，UI 必须保持现有安全声明边界。
- 内容窗口不得自行加载第二份不受 broker 管理的 FFI root session。

## 7. 跨平台策略

| 平台 | 目标能力 | 首版降级 |
|---|---|---|
| Windows | 同进程独立原生窗口、任务栏独立项、窗口关闭事件 | 原生能力不可用时回退主窗口路由 |
| macOS | 独立 `NSWindow`、标准窗口菜单与关闭语义 | 原生能力不可用时回退主窗口路由 |
| Linux | 独立 GTK window；兼容 X11/Wayland 的普通窗口生命周期 | 窗口管理能力不稳定时回退主窗口路由 |

Linux 最小原型已证明同进程多 engine、host/client 消息和独立窗口创建可用。Windows/macOS 仍必须分别验证窗口销毁通知、多窗口并发、打包插件注册和系统关闭语义。

### Linux implicit view 销毁约束

Flutter 3.44 的 `FlView` dispose 会尝试从 engine 移除 view，但 `desktop_multi_window 0.3.0` 创建的是每个子 engine 的 implicit view；implicit view 不能通过 `FlutterEngineRemoveView` 移除。仓库因此固定使用 `third_party/desktop_multi_window` 的受控补丁：GTK window 销毁时先 dispose 子 engine，再从容器解除 `FlView`，并把已销毁窗口的轻量 wrapper 引用保留到进程退出，避免触发错误的 implicit-view dispose。engine、Dart isolate、GPU 和 messenger 资源仍立即释放，代价是每个关闭窗口保留一个小型原生包装对象；这是稳定性修复而非长期理想实现，后续应跟踪 Flutter/plugin 上游的正式生命周期接口。

host 收到 `window_close` 时必须先返回 method-channel 成功，再在下一事件循环关闭窗口；子窗口 widget dispose 不得发送关闭消息，因为此时 messenger 可能已随 engine 销毁。lease 回收统一由 host 对原生窗口集合的监听负责。

## 8. 模块拆分

- `WindowCoordinator`：创建、聚焦、关闭平台窗口。
- `DocumentSessionBroker`：维护 token、documentID、root lease 和请求路由。
- `DocumentRevisionService`：生成 revision、检测保存冲突。
- `NotepadWindowController`：子窗口编辑状态、撤销栈、保存状态。
- `RootCloseCoordinator`：聚合活动窗口和未保存状态，决定 root 是否可关闭。

这些模块不得继续堆入 `HomePage`。主页面只发出打开/关闭意图并展示聚合状态。

## 9. 实施阶段与验收

1. 平台探针：三平台创建两个空窗口、双向消息、异常关闭；没有业务代码。
2. broker：使用内存假数据验证 token、lease、窗口异常退出和 root 关闭阻断。
3. 只读窗口：图片/文本只读查看，多窗口并发，不涉及保存。
4. 记事本写入：revision 冲突、保存失败、关闭确认和自动保存。
5. 桌面 E2E：每个平台真实打开两个窗口，编辑不同文件和同一文件，验证主窗口/root 生命周期。

达到“功能完成”至少需要：三平台真实窗口证据、broker 单元测试、窗口 widget 测试、同文件冲突测试、关闭 root 聚合确认测试和动态库真实读写测试。当前已满足会话层、协议层、widget/真 FFI 回归、Linux 内容读取和五轮窗口销毁探针，仍不满足 Windows/macOS、用户标题栏关闭复验与完整自动化桌面验收条件。
