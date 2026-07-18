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
| UI-39 | 应用隐藏时的安全自动锁定 | 安全/生命周期 | 76% | 设计见 [AUTO_LOCK_DESIGN.md](design/AUTO_LOCK_DESIGN.md)。设置开关已持久化；HomePage 监听 `hidden`/`paused`，对无内容窗口、无脏文档、无活动写入的 root 依次释放当前目录 cursor、关闭 native root、清除该 root 的应用内剪贴板/broker 并保留侧边栏历史。恢复可见后会提示锁定/跳过/失败摘要。widget 覆盖开关保存、默认关闭、单 root 锁定并重新验证、两个已解锁 root 逐一关闭且恢复后不泄露旧条目，以及内容窗口阻断锁定；broker/controller 覆盖脏记事本和活动写入的关闭判定。仍缺 Home 与子窗口协议的重解锁竞态、真实 FFI 与三平台 `hidden`/`paused` 验收；子窗口草稿确认协议未实现。per-root TTL 见 UI-44。 |
| UI-41 | Flutter UI 中文文案规范化 | UX/可访问性 | 85% | 已统一主工具栏、批量菜单、侧边栏、设置、图片浏览器、记事本、路径选择、导入与欢迎页的大部分用户文案：去除英文遗留与“所选文件”等不准确表述，短标签使用动作/对象名。密码页现为“请输入密码以解锁”“密码”，目录路径字段现为“目录路径”“输入目录路径或浏览选择”，主页解锁与路径选择 widget 回归通过。错误建议已改为用户可执行的步骤，不再引用不存在的按钮、内部配置名或 root 初始化术语；安全限制保留在说明和确认中。仍需低频状态页复查、读屏语义与三平台字号/截断验收。 |
| UI-43 | 增量目录的筛选与排序边界 | UX/正确性 | 88% | 未完成 cursor 的 list/grid 现保持 walker 页顺序，不再对局部页排序；工具栏显示已加载项并禁用排序。筛选框提示“仅筛选已加载条目”，无匹配时不会宣称整个目录为空，且可继续加载下一页；EOF 后恢复既有排序。widget 覆盖 list/grid 页顺序、筛选范围/空态、继续加载和完成后排序菜单；真实 FFI 全量 Flutter 回归通过。仍缺 10 万条真实 root 的性能基线、筛选时自动滚动加载的桌面可用性与跨平台验收。 |
| UI-44 | root 空闲 TTL 自动锁定 | 安全/生命周期 | 88% | `session_ttl` 已接入设置页和 HomePage。每个已解锁 root 有独立活动时钟；解锁、鼠标操作、导航和 F5/Ctrl+V/F2 文件快捷键会刷新当前 root，设置页返回后重载 TTL；关闭值改为有限值时，以设置生效时刻为现有已解锁 root 建立新的 deadline，避免无 deadline 或按旧策略立即锁定。到期时复用 root close coordinator，仅关闭无内容窗口、无脏文档和无活动写入的 root，并在关闭/会话结束时移除计时。无效持久化 TTL 回退到安全默认值。tracker 覆盖独立截止和关闭值，Home widget 覆盖到期锁定、活动重置、内容窗口/脏记事本/活动保存阻断和设置返回 live deadline，设置页覆盖持久化与无效值回退。仍缺 Home 与子窗口协议的重解锁竞态、真实 FFI 与桌面 TTL 验收。 |
| UI-45 | 图片浏览器滚轮缩放下限一致 | Bug/交互一致性 | 90% | 已将鼠标滚轮监听移到 `InteractiveViewer` 子层，使它优先于默认滚动处理并调用与工具栏相同的缩放函数。widget 覆盖重置后滚轮放大/缩小、低于 100% 和连续缩小到 10% 下限，以及按钮缩放、旋转和关闭清理。仍缺 Linux/Windows/macOS 真实鼠标和触控板手势验收。 |
| UI-46 | Flutter UI 文案通俗化复查 | UX/可访问性 | 35% | 本轮已将图片动画状态改为“动画（N 帧）”、记事本操作改为常见的“查找/替换”，文件选择器改为“所有文件”，进度面板统一中文标点；未完成导入/导出提示不再暴露 V3/断点续传等实现术语，直接说明可执行操作。加密目录属性与改密说明不再向用户展示 `salt`、`verifier`、`root`、`convert` 等内部术语，名称不加密提示明确显示为“不加密（None）”。图片、进度面板、文件选择器、未完成传输、属性页和创建目录 widget 回归通过。仍需按对象逐页复查图片浏览器、文件操作、设置和安全记事本的低频提示，并进行读屏、字号与三平台截断验收。 |
| UI-47 | 安全记事本撤销/重做交互重设计 | UX/编辑正确性 | 90% | 复核当前源码后确认不渲染“撤销:N / 重做:M”：采用标准撤销/重做图标、禁用态和 `Ctrl/Cmd+Z`、`Ctrl/Cmd+Shift+Z`，不暴露历史文本或内部计数。本轮 widget 已验证初始/编辑后/撤销后/重做后的可用状态和快捷键一致。仍缺 Linux/Windows/macOS 实机键盘、工具提示和读屏语义验收；若用户仍看到计数，应先核对实际运行 bundle 是否为当前构建。 |
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
| 安全记事本 | 94% | 状态/controller 与 UI 分区已拆分；编辑、加密草稿、剪贴板监视、broker 冲突及远程子窗口均有测试，Linux 已实测原生窗口 | 补三平台桌面键盘/关闭/系统剪贴板 E2E、大文件策略和可验证内存边界 |
| 图片浏览器 | 92% | JPEG/PNG/GIF/BMP/WebP 真实 codec 与渲染、GIF 动画识别、缩放旋转、键盘翻页、重试、64 MiB/100 MP 资源边界、异步竞态清零和只读子窗口 lease 均有自动化测试；真实 FFI 验证中文加密目录 WebP，Linux 已实测跨 engine PNG | 三平台真实窗口键盘/手势 E2E、超大图片内存压力与平台 codec 差异验收 |
| Stream V3/增量编辑 | 15% | 有设计文档；Dart 活跃入口明确返回 unsupported | 确定格式、完整性和崩溃一致性模型，完成 sec/FFI/Dart/UI 实现及随机编辑实际测试 |
| 大目录 UI 虚拟化 | 70% | Flutter list/grid 已使用 sliver 虚拟构建。当前目录的 native cursor、Dart binding/session 与 FileService 路径映射已接入 HomePage 的 list/grid；tree 的 root 与每个展开节点现在也使用独立 cursor。tree session 不累计普通文件，只保留当前页，并会越过纯文件页继续读取直到发现目录或 EOF；刷新/节点销毁会关闭 cursor，失败改为从头刷新。未完成目录会保持 walker 页顺序、禁用全目录排序，筛选明确限定为已加载条目且空态可继续加载。真实 name-encrypted root 两页 FFI、session 保留模式、tree 纯文件页和筛选/排序边界 widget 回归已通过。现有 `listCurrentDirectory(offset/limit)` 仍只是兼容回退的本地 `skip/take`。分页边界见 [DIRECTORY_PAGINATION_DESIGN.md](design/DIRECTORY_PAGINATION_DESIGN.md) | 补 10 万 entry、取消/错误/导航/关闭 root 的真实跨层回归；评估筛选时自动加载的性能与可访问性 |
| 自动锁定与密钥缓存超时 | 80% | 应用隐藏自动锁定已接入设置和 HomePage：合格 root 会关闭 native session、目录 cursor、应用内剪贴板和 broker 能力，历史保留；widget 覆盖默认关闭、单 root 和两个已解锁 root 逐一关闭、恢复后不泄露旧条目及内容窗口跳过。per-root TTL 已接入设置、独立活动时钟和同一关闭协调器，且有 tracker/Home/设置页定向测试。broker/controller 已覆盖脏文档和活动写入的关闭判定 | Home 与子窗口协议的重解锁竞态、TTL 活动/阻断/live 重载 widget 回归、真实 FFI 与三平台 `hidden`/`paused`/TTL 验收；实现子窗口草稿确认后锁定 |
| KDF 成本动态校准 | 15% | 当前迭代/参数由配置与默认值决定 | 按设备目标耗时校准、参数上限、防 DoS 和跨设备测试 |
| 文件排序/过滤/批量操作 | 92% | 当前目录筛选、目录优先排序、批量文件复制/剪切/粘贴/导出/删除已实现；批量冲突支持仅此项/全部应用，取消、失败和未处理项保留重试，并有结构化结果面板 | 超大目录分页排序、真实桌面大批次与跨 root 页面 E2E；全 root 搜索另立任务 |
| 主界面右键菜单 | 98% | 应用内单项及批量文件复制/粘贴、剪切/移动、冲突询问、跨 root 重加密、图片新窗口和右键选择/批量导出/删除已有测试；跨 root 文件移动有真实 FFI 验证 | 跨 root 目录移动与系统剪贴板互通；三平台鼠标 E2E、键盘菜单键、焦点和读屏测试 |
| 剪贴板 | 78% | 应用内文件剪贴板支持有序多条复制/剪切队列、同 root rename 移动和跨 root 文件 copy→delete；逐项成功后移除，失败、取消和未处理项保留；批量冲突策略与结果摘要已有回归；记事本短文本监视已实现 | 跨 root 目录移动、系统文件剪贴板安全边界、分平台实现和桌面自动化测试 |
| 拖放 | 0% | 拖放仍为规划，拖放文件应当支持方向设置，默认为单向外到内，内到外需要设置开启  | 应规划|
| 备份恢复与可选密码提示 | 0% | 无活跃实现 | 先定义威胁模型和加密格式，再实现与测试 |
| 安全记事本草稿间隔与只读模式 | 92% | 间隔设置已接入加密草稿而非原文件；默认只读、默认剪贴板监视、编辑切换、恢复与状态保护有主/子窗口测试 | 保存冲突、快捷键、系统剪贴板、进程级崩溃与跨平台桌面实测 |
| 第三方工具安全文件交接 | 5% | 只有 FUSE/memfd/临时文件方向讨论 | 威胁模型、平台方案、权限隔离、生命周期和泄漏测试 |

## P3 发布与平台

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| Windows 产品验收 | 20% | 有交叉编译和部分平台代码 | Windows runner、GUI/CLI/FFI 实机测试、安装包、升级/卸载 |
| macOS 支持 | 0% | 无当前验收证据 | 构建、签名、公证、FFI 和 UI 实测 |
| Linux 安装包 | 15% | 可开发运行 | deb/rpm 或其他发布格式、desktop 集成、干净环境安装测试 |
| 多语言与可访问性 | 5% | 中文 UI 为主 | i18n 资源、键盘导航、读屏和对比度测试 |
| 多标签页、预览与快捷键 | 5% | 零散组件/快捷键存在 | 统一导航状态、预览安全边界和桌面实际测试 |
| 可配置 config 文件名 | 0% | 当前固定 `_cryption.json` | 评估发现机制、冲突与兼容成本；决定取消或实现 |
| API/开发者/贡献文档 | 30% | 已有设计与使用文档 | Go API reference、构建/测试/贡献流程及链接自动检查 |
| 发布安全审计 | 10% | 有局部安全测试和设计说明 | 威胁模型冻结、依赖审计、模糊测试、发布构建复现、第三方评审 |

## 本轮验证状态

- 2026-07-18 Flutter 回归：`flutter analyze --no-pub` 零问题；主页完整 widget 回归 39 项通过；真实 FFI 动态库 `/tmp/safe_disk_ffi/libffi_sec_fs.so` 下完整 `flutter test --no-pub --timeout 180s` 共 185 项通过。本轮直接覆盖图片滚轮缩放 10%--1000% 边界、记事本撤销/重做状态、TTL 设置持久化/无效值回退、独立计时、活动刷新、内容窗口/脏记事本/活动保存阻断、设置返回新 deadline 和到期锁定。
- 2026-07-14 Flutter UI 回归：`flutter analyze --no-pub` 零问题；默认入口 Linux debug 构建通过；真实 FFI 动态库下完整 `flutter test --no-pub` 共 130 项通过，覆盖 root 三种关闭语义、记事本默认项、属性首击、批量粘贴冲突/取消/部分失败、五种图片 codec/资源边界/只读子窗口 lease、中文加密目录 WebP 实际渲染、错误详情开关/脱敏、Windows 字体主题、不存在与非空 root 路径语义，以及既有 CLI/Dart FFI 互通和多窗口协议回归。
- 2026-07-14 Windows 静态/交叉验证：构建脚本 Windows DLL 规范名单测通过，`scripts/build.go` 和 sec_fs 测试二进制均通过 Windows amd64 交叉编译；当前 Linux 环境没有 Windows runner toolchain/Wine，因此这些证据不替代 Win10 bundle 与界面实测。
- 2026-07-14 Linux X11 实测：同一进程成功创建独立主窗口与安全记事本、图片查看器子 Flutter engine；另以 `GDK_SYNCHRONIZE=1` 连续创建/关闭五个记事本原生窗口，进程正常退出且无 implicit view 移除、engine 销毁后 messenger 或 GLX BadAccess 错误。仍观察到一次 compositor shader 上下文警告，且该自动化路径不能替代用户标题栏关闭复验、Windows/macOS 与完整桌面 E2E。
- 已通过：Transfer V3 定向测试；Go 四个 workspace module 的完整测试；Go vet；Transfer/CLI/FFI race；Go 1.25 Windows 交叉编译；真实 Dart FFI 集成测试。
- “Transfer V3 路径流式消费”已按上述证据迁入完成档案；secure walker 工作集硬上限仍是独立未完成任务。
- Flutter 手工观察不能替代自动化实际功能测试，但应转成回归用例后再提升进度。
