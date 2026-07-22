# Safe Disk 活跃任务清单

> 本文件只保留仍需实现、修复或补自动化证据的任务。当前 Linux 已验收、仅待 Windows/macOS 等其它系统复验的条目已移至 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)，不再稀释主线实现进度。已完成并有自动化实际功能测试证明的任务见 [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md)。
>
> 审计日期：2026-07-18。状态以当前代码、公开入口、当前系统验收和测试为准，不继承历史勾选。

## 进度口径

| 进度 | 判定 |
|---:|---|
| 0% | 尚未开始，没有可执行代码 |
| 10% | 只有需求或设计 |
| 30% | 已有接口/骨架，主路径不可用 |
| 50% | 主路径部分可用，缺关键边界 |
| 70% | 已接入主要调用层，仍有明显缺口 |
| 90% | 实现基本完整，但缺自动化实际功能测试、平台验收或剩余边界 |
| 100% | 验收范围全部实现，公开入口可用，并有自动化实际功能测试 |

规则：

- 新增功能需求或 bug 修复必须先登记到本文件，写明验收条件和初始状态，再开始修改业务代码；实现、测试和文档同步完成后才允许提高进度或迁入完成档案。
- 没有自动化实际功能测试的任务最高 90%。
- 单元测试、mock service 和静态分析不能单独证明跨层功能完成。
- “设计完成”只代表设计任务，可为 100%；不代表设计中的产品功能完成。
- 任务到 100% 后必须从本文件移入完成档案，不能继续留在活跃清单。

- 仅待其它系统验证的已实现功能必须迁入 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)，不能继续以高完成度混入主线实现任务。

## 当前轮活跃修复（2026-07-18）

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---:|---|
| UI-39 | 应用隐藏时的安全自动锁定 | 安全/生命周期 | 78% | 设计见 [AUTO_LOCK_DESIGN.md](design/AUTO_LOCK_DESIGN.md)。设置开关已持久化；HomePage 监听 `hidden`/`paused`，对无内容窗口、无脏文档、无活动写入的 root 依次释放当前目录 cursor、关闭 native root、清除该 root 的应用内剪贴板/broker 并保留侧边栏历史。恢复可见后会提示锁定/跳过/失败摘要。widget 覆盖开关保存、默认关闭、单 root 锁定并重新验证、两个已解锁 root 逐一关闭且恢复后不泄露旧条目，以及内容窗口阻断锁定；broker/controller 覆盖脏记事本和活动写入的关闭判定。主动关闭带子窗口 root 时，bridge 会先撤销该 root 的 token、拒绝迟到 RPC，等待已接受的保存完成后再关闭原生窗口；定向测试覆盖该顺序。仍缺 Home 与子窗口协议的完整重解锁竞态、真实 FFI 与三平台 `hidden`/`paused` 验收；子窗口草稿确认协议未实现。per-root TTL 见 UI-44。 |
| UI-41 | Flutter UI 中文文案规范化 | UX/可访问性 | 85% | 已统一主工具栏、批量菜单、侧边栏、设置、图片浏览器、记事本、路径选择、导入与欢迎页的大部分用户文案：去除英文遗留与“所选文件”等不准确表述，短标签使用动作/对象名。密码页现为“请输入密码以解锁”“密码”，目录路径字段现为“目录路径”“输入目录路径或浏览选择”，主页解锁与路径选择 widget 回归通过。错误建议已改为用户可执行的步骤，不再引用不存在的按钮、内部配置名或 root 初始化术语；安全限制保留在说明和确认中。仍需低频状态页复查、读屏语义与三平台字号/截断验收。 |
| UI-43 | 增量目录的筛选与排序边界 | UX/正确性 | 88% | 未完成 cursor 的 list/grid 现保持 walker 页顺序，不再对局部页排序；工具栏显示已加载项并禁用排序。筛选框提示“仅筛选已加载条目”，无匹配时不会宣称整个目录为空，且可继续加载下一页；EOF 后恢复既有排序。widget 覆盖 list/grid 页顺序、筛选范围/空态、继续加载和完成后排序菜单；真实 FFI 全量 Flutter 回归通过。仍缺 10 万条真实 root 的性能基线、筛选时自动滚动加载的桌面可用性与跨平台验收。 |
| UI-44 | root 空闲 TTL 自动锁定 | 安全/生命周期 | 90% | `session_ttl` 已接入设置页和 HomePage。每个已解锁 root 有独立活动时钟；解锁、鼠标操作、导航和 F5/Ctrl+V/F2 文件快捷键会刷新当前 root，设置页返回后重载 TTL；关闭值改为有限值时，以设置生效时刻为现有已解锁 root 建立新的 deadline，避免无 deadline 或按旧策略立即锁定。到期时复用 root close coordinator，仅关闭无内容窗口、无脏文档和无活动写入的 root，并在关闭/会话结束时移除计时。无效持久化 TTL 回退到安全默认值。tracker 覆盖独立截止和关闭值，Home widget 覆盖到期锁定、活动重置、内容窗口/脏记事本/活动保存阻断、设置返回 live deadline，以及前台首次到期的摘要提示；相同摘要不按检查周期重复。设置页覆盖持久化与无效值回退。仍缺 Home 与子窗口协议的重解锁竞态、真实 FFI 与桌面 TTL 验收。 |
| UI-45 | 图片浏览器滚轮缩放下限一致 | Bug/交互一致性 | 90% | 已将鼠标滚轮监听移到 `InteractiveViewer` 子层，使它优先于默认滚动处理并调用与工具栏相同的缩放函数。widget 覆盖重置后滚轮放大/缩小、低于 100% 和连续缩小到 10% 下限，以及按钮缩放、旋转和关闭清理。仍缺 Linux/Windows/macOS 真实鼠标和触控板手势验收。 |
| UI-46 | Flutter UI 文案通俗化复查 | UX/可访问性 | 45% | 本轮已将图片动画状态改为“动画（N 帧）”、记事本操作改为常见的“查找/替换”，文件选择器改为“所有文件”，进度面板统一中文标点；未完成导入/导出提示不再暴露 V3/断点续传等实现术语，直接说明可执行操作。加密目录属性与改密说明不再向用户展示 `salt`、`verifier`、`root`、`convert` 等内部术语，名称不加密在提示及下拉选项中均明确显示为“不加密（None）”，但提交值仍为内部值 `None`。属性页、旧格式改密提示和改密确认语现改为状态、限制和下一步，不要求用户理解格式或密钥；记事本草稿状态明确为恢复用途。导入来源在当前加密目录内部时使用独立中文限制说明和建议，不显示内部英文。设置加载和保存失败现复用统一脱敏错误组件：关闭详细错误时不显示原始异常，已保存开启后才显示经脱敏的技术详情；widget 覆盖两个失败路径及开关边界。图片、进度面板、文件选择器、未完成传输、属性页、改密对话框、记事本和创建目录 widget 回归通过。仍需按对象逐页复查图片浏览器、文件操作、设置和安全记事本的低频提示，并进行读屏、字号与三平台截断验收。 |
| UI-47 | 安全记事本撤销/重做交互重设计 | UX/编辑正确性 | 90% | 复核当前源码后确认不渲染“撤销:N / 重做:M”：采用标准撤销/重做图标、禁用态和 `Ctrl/Cmd+Z`、`Ctrl/Cmd+Shift+Z`，不暴露历史文本或内部计数。本轮 widget 已验证初始/编辑后/撤销后/重做后的可用状态和快捷键一致。仍缺 Linux/Windows/macOS 实机键盘、工具提示和读屏语义验收；若用户仍看到计数，应先核对实际运行 bundle 是否为当前构建。 |
| UI-48 | 可改密码加密目录创建与改密链路 | 安全/格式演进 | 90% | 新格式设计见 [PASSWORD_CHANGEABLE_ROOT_DESIGN.md](design/PASSWORD_CHANGEABLE_ROOT_DESIGN.md)。Flutter 创建对话框默认启用“允许以后修改密码”，并允许用户在创建前明确关闭；以随机内容密钥和密码派生包装密钥创建新 root；`sec_root_change_password` 通过 staged 配置文件同步后替换正式配置，改密不重写文件或名称。改密前以用户缓存中的跨进程文件锁串行化同一 root，等待可取消且锁文件不写入用户目录。侧边栏按配置版本区分新旧格式：新格式显示改密对话框，成功前关闭无未保存内容的旧会话并要求新密码重新解锁，旧格式继续明确拒绝。创建、解锁与改密密码框明确关闭拼写联想和自动更正、使用密码键盘；创建框的显示/隐藏按钮提供读屏标签。sec、Go FFI、Dart FFI 与 widget 覆盖 AES-XTS/加密名称保留、旧密码拒绝、错误旧密码不变、损坏 envelope 失败关闭、临时配置无法创建时旧密码保持可用、替换失败时正式配置字节不变、跨进程锁等待/释放、旧格式拒绝、创建开关默认与关闭值、会话关闭和密码输入属性；Windows/macOS sec 测试二进制交叉编译通过。仍缺进程在 replace 前后被强制中断的故障注入，以及 Linux/Windows/macOS 原子替换、锁与 UI 实机验收。 |
| UI-49 | 安全记事本搜索数字键盘 Enter | Bug/键盘交互 | 65% | 已为搜索栏补 `LogicalKeyboardKey.numpadEnter` 及 Shift+数字键盘 Enter 的快捷键绑定；widget 直接发送该按键，覆盖下一个/上一个匹配、选择更新与查询框持续聚焦。仍缺 Linux/Windows/macOS 实机物理数字键盘布局验收。 |
| UI-50 | 图片浏览器状态读屏语义 | 可访问性 | 90% | 加载、策略拒绝、解码器失败、无可显示图片和已打开图片均提供中文语义；状态变化使用 live region，图像语义包含当前文件名。widget 覆盖加载中、成功、策略拒绝和解码器失败；“无可显示图片”是防御性分支，当前公开加载流程不可达，未虚构运行证据。仍需 Linux/Windows/macOS 读屏实测。 |
| UI-51 | 安全记事本错误信息脱敏 | 安全/UX | 90% | 加载和草稿错误现分离为安全的中文状态说明与独立技术诊断；保存状态只显示“保存失败”。加载失败页面经统一错误组件在详细错误关闭时不显示异常原文，开启后仅显示经脱敏的诊断；草稿放弃也传递独立诊断字段。controller 与主窗口 widget 覆盖二进制内容、一般读取失败、草稿保存失败、主保存失败及详细错误开关。仍缺子窗口与 Linux/Windows/macOS 真实错误展示验收。 |
| UI-52 | 多语言基础设施与中文/英文首批界面 | i18n/产品基础 | 80% | 当前已有 ARB 生成、`system`/`zh`/`en` 偏好和三个 `MaterialApp` 的 locale 注入；默认值为中文，统一受支持语言 resolver，内容窗口参数 v2 携带语言快照并兼容 v1。所有 `ErrorType` 已经 ARB 呈现；设置页全部用户文案、时长和保存/离开流程已迁移，service 不再返回中文时长；原生库与内容窗口启动错误也已中英文呈现，内容窗口默认不显示原始异常；主壳批量选择/剪贴板状态、侧边栏、导入入口、解锁提示、Root 对话框与属性、目录浏览器、目录树、文件/目录右键、冲突确认、创建加密目录、路径选择、目录移除确认和批量结果对话框均已迁移。欢迎引导四页、进度取消按钮、进度面板的时间、计数和当前文件标签，以及重跑、导入、导出和批量删除的标题、阶段状态、取消/完成摘要均已迁移；未完成传输确认也已迁移并有英文 widget 覆盖。图片浏览器的工具栏、导航、动图、错误/空态、重试和读屏标签均已迁移。安全记事本主窗口的草稿恢复、关闭确认、编辑工具栏、加载重试、保存/草稿状态、剪贴板监视和查找替换已迁移；子窗口启动错误壳也已使用 locale 快照渲染。2026-07-22 静态复核发现：`home_page.dart` 的别名、关闭会话、导入导出、文件剪贴板、新建/重命名/删除和成功/失败提示仍有大量用户可见硬编码；此前将主页描述为已完成不准确，现回退进度并分批处理。批量删除确认尚缺英文专门断言；安全记事本和图片浏览器仍缺 Linux/Windows/macOS 的英文视觉、截断与读屏实测；不得对外称为完整多语言。 |
| UI-53 | 错误 descriptor 与 ARB 呈现 | i18n/安全/UX | 100% | `ErrorType` 已保留为稳定领域语义，`ErrorMessages` 已改为不含可见文案的 `ErrorDescriptor`；SnackBar、对话框和页面错误态通过 `BuildContext` 解析 ARB 的标题、说明、建议和复制内容。技术诊断仍由 `ErrorDiagnostics` 脱敏并受详细错误开关控制。覆盖中文、英文、诊断开关及主页/记事本/设置/创建目录错误路径；`flutter analyze --no-pub` 零问题，完整 Flutter 测试 201 通过、12 个缺少原生 FFI 库的集成测试跳过。 |
| UI-54 | 用户可见文案清点与迁移门槛 | i18n/工程治理 | 62% | 已建立 [I18N_STRING_INVENTORY.md](design/I18N_STRING_INVENTORY.md)：当前产品 UI 有 27 个文件、269 个候选构造点，按模块定义审核范围、迁移批次、完成条件和防回退规则。`l10n.yaml` 已以中文 ARB 为模板；设置、侧边栏、Root 操作与属性、目录浏览器、目录树、文件/目录右键、冲突确认、创建/路径/删除通用对话框和批量结果对话框的首批文案均已迁移，并有中英文 widget 覆盖。进度面板、安全记事本、图片浏览器、欢迎引导及其已列出的用户可见文案已完成迁移；记事本、图片浏览器和欢迎引导均有英文 widget 覆盖。2026-07-22 对 `lib` 静态复核发现 `home_page.dart` 仍有未登记硬编码，故撤回“应用壳已完成”的旧结论。尚未实现基线检查脚本，低频页面未完成逐项复核，且没有三平台英文视觉与读屏验收；不得把清点文档计为完整英文产品。 |
| DOC-I18N-01 | 多语言架构与迁移框架 | 设计/治理 | 100% | [I18N_DESIGN.md](design/I18N_DESIGN.md) 已以当前 ARB、设置服务、三类 `MaterialApp`、静态错误映射和内容窗口协议为依据，定义翻译边界、模块 API、语言回退、子窗口一致性、安全诊断、迁移批次、测试与发布门槛。设计完成不代表英文产品功能完成。 |
| TR-01 | Transfer 操作锁不污染用户目录 | Bug/并发/数据安全 | 90% | stable lock 已迁至用户私有缓存 `safe_disk/transfer-locks/`，root 与其父目录不再写 `.safe_disk.transfer.*.lock`；Go 覆盖跨进程互斥、symlink alias、等待取消和真实 import 后无相邻残留。仍待 Windows `LockFileEx` 实机与缓存目录生命周期验收。 |


## P0 正确性与数据安全

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| secure root walker 错误语义与资源上限 | 78% | 已实现默认 1024/绝对 4096 个待处理目录上限、正确 stack depth、关闭清理和名称/metadata 错误传播；FFI 与 CLI 均不再以 `HasNext` 吞错误。sec 超宽/超深、真实 FFI 和 CLI 明文 store corruption 回归通过，见 [WALKER_RESOURCE_DESIGN.md](design/WALKER_RESOURCE_DESIGN.md) | 补底层 `ReadDir` 故障注入、取消语义与 FD 上限实测；完成无损分页/外部工作队列设计前，不宣称任意超宽目录可完整扫描 |
| Windows durability 与跨进程锁 | 60% | Windows lock 实现和交叉编译路径存在；文件 Sync 已实现 | 真实 Windows 上验证目录 metadata flush、LockFileEx 竞争、进程退出释放、rename/占用句柄故障 |
| 本地并发符号链接替换防护 | 35% | 有词法 containment 和 import 符号链接拒绝 | 使用 dirfd/openat 或等价方案消除检查与打开间竞态；补攻击进程实测 |

## P1 核心基础设施

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| sec_fs 完整错误传播与损坏数据策略 | 82% | 密码认证、路径约束、key 生命周期、metadata、权限均有测试 | 统一 walker/crypto 损坏错误；确定 corruption tolerance 边界；真实损坏 root 端到端验收 |
| Transfer V3 平台完整性 | 88% | 原子 temp/backup、marker、取消、convert phase/recovery、真实 kill checkpoint 测试 | Windows 故障测试、walker 上限、源并发修改策略；convert 预恢复必须不掩盖非 convert marker 的 unfinished 策略错误，并在损坏 marker 中保留具体字段原因；明确字节进度/限速是否进入当前版本 |
| CLI 产品命令集 | 82% | create/list/import/export、JSON Lines、安全密码来源、unfinished 处理有真实子进程测试 | 实现并实测 info；决定并实现或明确取消 passwd；补真实 TTY 隐藏输入、Windows 路径与打包后二进制测试 |
| FFI/Dart 完整绑定面 | 88% | root/file/dir、Transfer V3 callback/cancel、真实动态库互通测试存在 | per-operation durability options ABI；损坏 marker/配置、worker isolate 退出、Windows 动态库实测矩阵 |
| Flutter Transfer UI 闭环 | 89% | HomePage widget 测试覆盖解锁、文件/目录 import 冲突、单文件/批量导出冲突决策、失败恢复和 unfinished rerun；底层文件导出默认拒绝覆盖 | 真实桌面 E2E、目录导出冲突/取消/重开完整链路、错误信息分层和可访问性 |
| 测试矩阵与持续集成 | 76% | Go 多 module、CLI 子进程、FFI C ABI、Dart 真库和 widget 测试已存在 | 固化 Linux CI；增加 Windows/macOS runner、桌面 E2E、故障注入、资源上限和覆盖率基线 |
| 文档真实性与分类 | 80% | 主体中文，设计/审计/历史已分层；本轮重做任务百分比 | 清理 ARCHITECTURE/CLI/FEATURES 的旧 V2 描述和失效命令；增加文档链接检查 |

## P2 产品功能

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| 安全记事本 | 95% | 状态/controller 与 UI 分区已拆分；编辑、加密草稿、剪贴板监视、broker 冲突及远程子窗口均有测试，Linux 已实测原生窗口。主/子窗口打开均传递 16 MiB 文本上限，已知大小在解密前拒绝，未知大小仍由 broker 读取后拒绝并清零临时字节；主页 widget 覆盖两种入口不解密也不创建子窗口。 | 补三平台桌面键盘/关闭/系统剪贴板 E2E、未知大小读取的可验证内存边界、流式大文件编辑策略和平台压力测试 |
| 图片浏览器 | 92% | JPEG/PNG/GIF/BMP/WebP 真实 codec 与渲染、GIF 动画识别、缩放旋转、键盘翻页、重试、64 MiB/100 MP 资源边界、异步竞态清零和只读子窗口 lease 均有自动化测试；真实 FFI 验证中文加密目录 WebP，Linux 已实测跨 engine PNG | 三平台真实窗口键盘/手势 E2E、超大图片内存压力与平台 codec 差异验收 |
| Stream V3/增量编辑 | 15% | 有设计文档；Dart 活跃入口明确返回 unsupported | 确定格式、完整性和崩溃一致性模型，完成 sec/FFI/Dart/UI 实现及随机编辑实际测试 |
| 大目录 UI 虚拟化 | 70% | Flutter list/grid 已使用 sliver 虚拟构建。当前目录的 native cursor、Dart binding/session 与 FileService 路径映射已接入 HomePage 的 list/grid；tree 的 root 与每个展开节点现在也使用独立 cursor。tree session 不累计普通文件，只保留当前页，并会越过纯文件页继续读取直到发现目录或 EOF；刷新/节点销毁会关闭 cursor，失败改为从头刷新。未完成目录会保持 walker 页顺序、禁用全目录排序，筛选明确限定为已加载条目且空态可继续加载。真实 name-encrypted root 两页 FFI、session 保留模式、tree 纯文件页和筛选/排序边界 widget 回归已通过。现有 `listCurrentDirectory(offset/limit)` 仍只是兼容回退的本地 `skip/take`。分页边界见 [DIRECTORY_PAGINATION_DESIGN.md](design/DIRECTORY_PAGINATION_DESIGN.md) | 补 10 万 entry、取消/错误/导航/关闭 root 的真实跨层回归；评估筛选时自动加载的性能与可访问性 |
| 自动锁定与密钥缓存超时 | 80% | 应用隐藏自动锁定已接入设置和 HomePage：合格 root 会关闭 native session、目录 cursor、应用内剪贴板和 broker 能力，历史保留；widget 覆盖默认关闭、单 root 和两个已解锁 root 逐一关闭、恢复后不泄露旧条目及内容窗口跳过。per-root TTL 已接入设置、独立活动时钟和同一关闭协调器，且有 tracker/Home/设置页定向测试。broker/controller 已覆盖脏文档和活动写入的关闭判定 | Home 与子窗口协议的重解锁竞态、TTL 活动/阻断/live 重载 widget 回归、真实 FFI 与三平台 `hidden`/`paused`/TTL 验收；实现子窗口草稿确认后锁定 |
| KDF 成本动态校准 | 15% | 当前迭代/参数由配置与默认值决定 | 按设备目标耗时校准、参数上限、防 DoS 和跨设备测试 |
| 文件排序/过滤/批量操作 | 92% | 当前目录筛选、目录优先排序、批量文件复制/剪切/粘贴/导出/删除已实现；批量冲突支持仅此项/全部应用，取消、失败和未处理项保留重试，并有结构化结果面板 | 超大目录分页排序、真实桌面大批次与跨 root 页面 E2E；全 root 搜索另立任务 |
| 主界面右键菜单 | 99% | 应用内单项及批量文件复制/粘贴、剪切/移动、冲突询问、跨 root 重加密、图片新窗口和右键选择/批量导出/删除已有测试；跨 root 文件移动有真实 FFI 验证。`Menu` 和 `Shift+F10` 复用当前选中项或最近键盘目标的菜单；没有目标时打开目录空白处菜单。list/grid 条目向读屏声明名称、文件或目录类型及右键选中态，widget 覆盖两种菜单键焦点恢复、无目标目录菜单和条目语义。 | 跨 root 目录移动与系统文件剪贴板互通；三平台鼠标 E2E、键盘菜单键、焦点和读屏测试 |
| 剪贴板 | 78% | 应用内文件剪贴板支持有序多条复制/剪切队列、同 root rename 移动和跨 root 文件 copy→delete；逐项成功后移除，失败、取消和未处理项保留；批量冲突策略与结果摘要已有回归；记事本短文本监视已实现 | 跨 root 目录移动、系统文件剪贴板安全边界、分平台实现和桌面自动化测试 |
| 拖放 | 5% | 设计见 [DRAG_DROP_DESIGN.md](design/DRAG_DROP_DESIGN.md)：外部拖入复用现有导入/冲突/Transfer 链路；默认禁止拖出，显式开启后仍需明文确认和目标冲突决策；不支持虚拟载荷、跨 root 目录移动或持久化拖放路径。当前没有平台实现或依赖。 | 完成平台方案调研；实现 controller、设置和桌面适配；三平台导入/导出/取消/权限/临时明文泄漏验收 |
| 备份恢复与可选密码提示 | 5% | 设计见 [BACKUP_RECOVERY_AND_PASSWORD_HINT_DESIGN.md](design/BACKUP_RECOVERY_AND_PASSWORD_HINT_DESIGN.md)：提示是可选公开信息而非找回凭据；备份/恢复只处理认证加密快照，禁止明文、密码重置和未验证覆盖。当前没有格式、FFI 或 UI 实现。 | 定义 sec snapshot/manifest 与提示配置格式；实现锁、FFI、UI、故障注入和三平台灾难测试 |
| 安全记事本草稿间隔与只读模式 | 92% | 间隔设置已接入加密草稿而非原文件；默认只读、默认剪贴板监视、编辑切换、恢复与状态保护有主/子窗口测试 | 保存冲突、快捷键、系统剪贴板、进程级崩溃与跨平台桌面实测 |
| 第三方工具安全文件交接 | 5% | 思考 FUSE/memfd/临时文件/WebDAV(主要倾向)/cgofuse/go-winfsp+go2fuse方向讨论 | 威胁模型、平台方案、权限隔离、生命周期和泄漏测试 |

## P3 发布与平台

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| Windows 产品验收 | 20% | 有交叉编译和部分平台代码 | Windows runner、GUI/CLI/FFI 实机测试、安装包、升级/卸载 |
| macOS 支持 | 0% | 无当前验收证据 | 构建、签名、公证、FFI 和 UI 实测 |
| Linux 安装包 | 15% | 可开发运行 | deb/rpm 或其他发布格式、desktop 集成、干净环境安装测试 |
| 多语言与可访问性 | 30% | 已有 `zh`/`en` ARB、语言偏好、主窗口/内容窗口 locale 传递，以及目录浏览与文件操作等首批英文界面；英文设置页明确提示仍在迁移，不能视为完整英文产品 | 完成其余页面 ARB 迁移与基线检查；补键盘导航、读屏、对比度和三平台字号/截断验收 |
| 多标签页、预览与快捷键 | 5% | 零散组件/快捷键存在 | 统一导航状态、预览安全边界和桌面实际测试 |
| 可配置 config 文件名 | 0% | 当前固定 `_cryption.json` | 评估发现机制、冲突与兼容成本；决定取消或实现 |
| API/开发者/贡献文档 | 30% | 已有设计与使用文档 | Go API reference、构建/测试/贡献流程及链接自动检查 |
| 发布安全审计 | 10% | 有局部安全测试和设计说明 | 威胁模型冻结、依赖审计、模糊测试、发布构建复现、第三方评审 |

## 本轮验证状态

- 2026-07-22 多语言目录别名回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/sidebar_widget_test.dart test/home_page_unlock_widget_test.dart -r compact` 共 50 项通过。新增英文侧边栏别名入口断言，目录别名弹窗的标题、字段和提示均已改由 ARB 呈现；主页的会话关闭、导入导出和文件操作提示仍待迁移。
- 2026-07-22 多语言欢迎引导与进度取消回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/dialogs_localization_test.dart test/progress_dialog_widget_test.dart -r compact` 共 6 项通过。覆盖欢迎引导第一页和下一页的英文标题/动作，以及可取消进度框的英文 `Cancel`。主页操作提示尚未迁移。
- 2026-07-22 多语言安全记事本分区回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/secure_notepad_widget_test.dart -r compact` 共 14 项通过，`document_window_client_test.dart` 4 项通过，完整 `flutter test --no-pub --timeout 180s -r compact` 为 223 项通过、12 项跳过。新增英文用例覆盖只读状态、剪贴板监视、刷新操作和查找替换栏；子窗口测试覆盖启动错误页的英文 locale 快照及英文编辑/保存工具提示。安全记事本仍缺 Linux/Windows/macOS 英文视觉、截断与读屏实测。
- 2026-07-22 多语言图片浏览器回归：`flutter gen-l10n`、`flutter analyze --no-pub`、`flutter test --no-pub test/secure_image_viewer_test.dart` 共 11 项通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 225 项通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。覆盖中文缩放/旋转/滚轮、加载和解码失败语义，以及英文工具栏快捷键和查看文件语义；测试夹具明确注入 locale，原生图片子窗口断言继续验证 locale 透传。真实桌面读屏和字号/截断验收未完成。
- 2026-07-22 多语言主页确认对话框回归：`flutter gen-l10n`、`flutter analyze --no-pub`、`flutter test --no-pub test/home_page_unlock_widget_test.dart` 共 46 项通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 224 项通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。未完成传输确认覆盖英文标题、不可继续说明和“全量重跑”动作；批量删除确认保留中文行为回归，尚缺英文专门断言。
- 2026-07-22 多语言进度面板与传输状态回归：`flutter gen-l10n`、`flutter analyze --no-pub`、`flutter test --no-pub test/progress_dialog_widget_test.dart test/home_page_unlock_widget_test.dart` 共 47 项通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 223 项通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。覆盖中文既有进度取消、英文的时间/计数/当前文件标签，以及主页导入、导出、重跑未完成传输的回归路径；进度的 title/status/result 均从当前 locale 构建。未完成传输确认和批量删除确认仍未迁移。
- 2026-07-22 多语言通用对话框回归：`flutter gen-l10n`、`flutter analyze --no-pub`、`flutter test --no-pub test/create_root_ui_test.dart test/dialogs_localization_test.dart test/path_selection_dialog_test.dart` 共 6 项通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 222 项通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。覆盖创建加密目录的中英文密码/高级参数/改密开关、路径选择的字段和操作，以及目录移除确认的英文标题与危险操作；保留“文件名加密”而不误用属性页的泛称“名称加密”。进度面板、记事本和图片浏览器仍未完成英文。
- 2026-07-22 多语言目录浏览增量回归：`flutter gen-l10n`、`flutter test --no-pub test/file_sort_test.dart test/file_browser_widget_test.dart` 共 14 项通过，`flutter analyze --no-pub` 零问题。覆盖中文默认、英文工具栏/状态/条目读屏标签、筛选范围、分页、排序、list/grid 和右键高亮；英文排序菜单在固定宽度下不溢出。侧边栏、导入入口、主页解锁和 Root 操作也已迁移；文件/目录操作、通用对话框、记事本和图片浏览器仍未翻译。
- 2026-07-22 多语言文件操作增量回归：`flutter test --no-pub test/file_item_actions_test.dart test/directory_background_actions_test.dart` 共 9 项通过，`flutter analyze --no-pub` 零问题。覆盖中文/英文动作标签、属性、重命名校验、文件操作面板滚动、目录空白处菜单与新建项校验；文件名校验领域函数不再返回中文。目录树、冲突和通用对话框、记事本和图片浏览器仍未翻译。
- 2026-07-22 多语言目录树增量回归：`flutter gen-l10n`、`flutter test --no-pub test/directory_tree_widget_test.dart` 共 2 项通过，`flutter analyze --no-pub` 零问题。覆盖分页跳过文件条目，以及英文目录树读取失败和重试提示。冲突和通用对话框、记事本和图片浏览器仍未翻译。
- 2026-07-22 多语言冲突处理增量回归：`flutter gen-l10n`、`flutter test --no-pub test/entry_conflict_dialog_test.dart` 共 5 项通过，`flutter analyze --no-pub` 零问题。覆盖中文/英文冲突操作、批量策略和自动命名；“副本/copy”后缀不再硬编码在领域函数中。通用对话框、记事本和图片浏览器仍未翻译。
- 2026-07-22 多语言批量结果对话框增量回归：`flutter test --no-pub test/batch_operation_result_dialog_test.dart` 共 1 项通过，`flutter analyze --no-pub` 零问题。覆盖英文局部失败标题、统计、失败详情和关闭操作。创建/路径/删除对话框、进度面板、记事本和图片浏览器仍未翻译。
- 2026-07-22 错误 descriptor 与中文模板回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 201 通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。所有 `ErrorType` 已由 locale 解析标题、说明、建议和复制内容；主页面、记事本、设置和创建目录的错误测试显式注入 locale。主体页面文案迁移仍由 UI-54 跟踪。
- 2026-07-22 多语言预览约束回归：`flutter test --no-pub test/app_locale_test.dart test/settings_service_test.dart test/settings_page_widget_test.dart` 共 29 项通过；`flutter analyze --no-pub` 零问题。英文偏好下设置页显示“英文仍在翻译”的明确提示；不以局部翻译伪装完整英文。
- 2026-07-22 多语言框架修正回归：`flutter test --no-pub test/app_locale_test.dart test/content_window_host_bridge_test.dart` 共 10 项通过；`flutter analyze --no-pub` 零问题。验证中文默认、系统语言仅解析受支持语言并回退中文、显式偏好，以及内容窗口 v2 语言快照与 v1 兼容解析；未覆盖错误 descriptor 或页面全量翻译。
- 2026-07-22 多语言基础设施回归：`flutter test --no-pub test/settings_service_test.dart test/settings_page_widget_test.dart test/remote_document_crypto_service_test.dart test/secure_image_viewer_test.dart` 共 31 项通过；`flutter analyze --no-pub` 零问题。ARB 中文/英文生成、非法 locale 回退、设置页即时预览/保存、根应用重启和记事本/图片内容子窗口 locale 继承均有覆盖；英文设置页核心文本实测渲染。首页、错误体系和编辑器仍未全量迁移，未计为完整英文。
- 2026-07-22 安全记事本错误脱敏回归：`flutter test --no-pub test/secure_notepad_controller_test.dart test/secure_notepad_widget_test.dart test/error_reporting_test.dart` 共 25 项通过；`flutter analyze --no-pub` 零问题。加载与草稿异常原文和用户说明分离；默认界面不显示内部路径，详细错误开启后由统一组件显示脱敏诊断；主保存失败状态也不泄露异常原文。子窗口和三平台实测仍未完成。
- 2026-07-22 图片浏览器读屏语义回归：`flutter test --no-pub test/secure_image_viewer_test.dart` 共 10 项通过；`flutter analyze --no-pub` 零问题。覆盖加载中、正常图片、大小/内容策略拒绝和延迟解码失败的独立语义状态；无数据防御分支当前无公开触发路径，未将其列为运行通过。仍待三平台读屏实测。
- 2026-07-22 设置错误信息回归：`flutter test --no-pub test/settings_page_widget_test.dart test/error_reporting_test.dart` 共 13 项通过；`flutter analyze --no-pub` 零问题。设置加载与保存失败均使用统一错误提示；默认不显示异常原文，详细错误开启后仅显示经脱敏的诊断信息。未替代读屏和三平台桌面验收。
- 2026-07-22 创建可改密码目录与数字键盘 Enter 回归：`flutter test --no-pub test/create_root_ui_test.dart test/root_password_change_dialog_test.dart test/secure_notepad_widget_test.dart` 共 14 项通过；`flutter analyze --no-pub` 零问题。创建对话框覆盖“允许以后修改密码”默认开启与手动关闭后的请求值；记事本覆盖普通 Enter、数字键盘 Enter 及 Shift+数字键盘 Enter 的查找方向、选区与查询框焦点。Linux/Windows/macOS 物理键盘和真实桌面 UI 验收仍未完成。
- 2026-07-22 可改密码与键盘回归：`go test ./sec_fs ./ffi_sec_fs`、`go vet ./sec_fs ./ffi_sec_fs` 通过；`flutter analyze --no-pub` 零问题；使用新构建的 `/tmp/safe_disk_ffi_change_password/libffi_sec_fs.so` 运行 `native_ffi_integration_test.dart`、主页和记事本 widget 测试共 63 项通过。覆盖随机内容密钥改密、AES-XTS/加密名称保留、旧/错误密码拒绝、损坏 envelope 失败关闭、临时配置创建失败时旧密码可用、替换失败时正式配置字节不变、跨进程锁等待/释放、Flutter 会话关闭和数字键盘 Enter。Windows/macOS sec 测试二进制交叉编译通过；本轮完整 `flutter test --no-pub --timeout 180s -r compact` 为 219 通过、12 项因未设置 `SAFE_DISK_FFI_LIBRARY` 跳过。
- 2026-07-22 子窗口关闭竞态回归：`flutter test --no-pub test/document_session_broker_test.dart test/content_window_host_bridge_test.dart test/home_page_unlock_widget_test.dart` 共 54 项通过。覆盖关闭开始即撤销旧 token、迟到 RPC 返回 `session_not_found`，以及已进入保存队列的操作完成后才请求原生子窗口关闭。
- 2026-07-22 UI 文案回归：`flutter test --no-pub test/root_directory_properties_test.dart test/root_password_change_dialog_test.dart test/secure_notepad_widget_test.dart` 共 15 项通过；`flutter analyze --no-pub` 零问题。覆盖目录属性脱敏、旧格式改密的可执行提示、改密输入校验、草稿恢复与记事本查找/键盘行为。
- 2026-07-22 密码输入回归：`flutter test --no-pub test/create_root_ui_test.dart test/root_password_change_dialog_test.dart test/home_page_unlock_widget_test.dart` 共 44 项通过。创建、解锁和改密密码框均断言关闭自动更正/输入联想并使用密码键盘；创建框显示/隐藏密码按钮具有读屏标签。
- 2026-07-22 键盘菜单回归：`flutter test --no-pub test/home_page_unlock_widget_test.dart` 共 43 项通过。覆盖鼠标右键设定键盘目标后，`Menu` 与 `Shift+F10` 在焦点恢复后均能再次打开同一文件的上下文菜单；无文件目标时 `Menu` 打开目录操作菜单。
- 2026-07-22 文件浏览器语义回归：`flutter test --no-pub test/file_browser_widget_test.dart` 共 11 项通过。list/grid 条目均暴露“名称、文件或目录类型”语义；右键高亮后语义节点带 `selected` 状态。
- 2026-07-22 安全记事本大文件回归：`flutter test --no-pub test/home_page_unlock_widget_test.dart` 共 44 项通过。超过 16 MiB 的普通文本在主窗口和新窗口入口均于解密前拒绝，不创建 document lease 或原生子窗口。
- 2026-07-22 导入限制文案回归：`flutter test --no-pub test/home_page_unlock_widget_test.dart` 共 45 项通过。来源在当前加密目录内部时，路径判断阻止导入服务调用；错误定义提供中文限制说明和“选择加密目录外来源”的建议。
- 2026-07-18 Flutter 回归：`flutter analyze --no-pub` 零问题；主页完整 widget 回归 39 项通过；真实 FFI 动态库 `/tmp/safe_disk_ffi/libffi_sec_fs.so` 下完整 `flutter test --no-pub --timeout 180s` 共 185 项通过。本轮直接覆盖图片滚轮缩放 10%--1000% 边界、记事本撤销/重做状态、TTL 设置持久化/无效值回退、独立计时、活动刷新、内容窗口/脏记事本/活动保存阻断、设置返回新 deadline 和到期锁定。
- 2026-07-14 Flutter UI 回归：`flutter analyze --no-pub` 零问题；默认入口 Linux debug 构建通过；真实 FFI 动态库下完整 `flutter test --no-pub` 共 130 项通过，覆盖 root 三种关闭语义、记事本默认项、属性首击、批量粘贴冲突/取消/部分失败、五种图片 codec/资源边界/只读子窗口 lease、中文加密目录 WebP 实际渲染、错误详情开关/脱敏、Windows 字体主题、不存在与非空 root 路径语义，以及既有 CLI/Dart FFI 互通和多窗口协议回归。
- 2026-07-14 Windows 静态/交叉验证：构建脚本 Windows DLL 规范名单测通过，`scripts/build.go` 和 sec_fs 测试二进制均通过 Windows amd64 交叉编译；当前 Linux 环境没有 Windows runner toolchain/Wine，因此这些证据不替代 Win10 bundle 与界面实测。
- 2026-07-14 Linux X11 实测：同一进程成功创建独立主窗口与安全记事本、图片查看器子 Flutter engine；另以 `GDK_SYNCHRONIZE=1` 连续创建/关闭五个记事本原生窗口，进程正常退出且无 implicit view 移除、engine 销毁后 messenger 或 GLX BadAccess 错误。仍观察到一次 compositor shader 上下文警告，且该自动化路径不能替代用户标题栏关闭复验、Windows/macOS 与完整桌面 E2E。
- 已通过：Transfer V3 定向测试；Go 四个 workspace module 的完整测试；Go vet；Transfer/CLI/FFI race；Go 1.25 Windows 交叉编译；真实 Dart FFI 集成测试。
- “Transfer V3 路径流式消费”已按上述证据迁入完成档案；secure walker 工作集硬上限仍是独立未完成任务。
- Flutter 手工观察不能替代自动化实际功能测试，但应转成回归用例后再提升进度。
