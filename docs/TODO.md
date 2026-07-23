# Safe Disk 活跃任务清单

> 本文件只保留仍需实现、修复或补自动化证据的任务。当前 Linux 已验收、仅待 Windows/macOS 等其它系统复验的条目已移至 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)，不再稀释主线实现进度。已完成并有自动化实际功能测试证明的任务见 [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md)。
>
> 审计日期：2026-07-23。状态以当前代码、公开入口、当前系统验收和测试为准，不继承历史勾选。

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
| UI-68 | 安全记事本小键盘回车后的空格输入 | Bug/编辑器 | 20% | 查找栏已覆盖普通 Enter、数字键盘 Enter 和 Shift+数字键盘 Enter 的查找方向；但用户报告的“编辑器小键盘 Enter → 输入文字 → 连续空格 → 输入英文”路径仍未在真实 Linux 诊断环境复现，未修改编辑器输入链路。仍需在用户出现问题的键盘布局/输入法环境复现，再补编辑器文本值、选区、composing 状态回归后修复。此前重复登记的 UI-73 已合并到本任务。 |
| UI-85 | 安全记事本未知大小内容的安全拒绝 | Bug/编辑器安全 | 90% | broker 当前在内容大小未知且配置了 16 MiB 上限时仍先解密再检查；改为解密前拒绝，并通过独立错误文案说明“无法确认大小，出于安全原因无法打开”，覆盖 broker、主页和子窗口入口。不扩大为流式读取实现。broker 6 项、主页未知大小入口 1 项、主页与记事本定向回归及完整 analyzer 已通过；仍缺独立窗口未知大小的专门 widget 断言和平台实测。 |
| UI-86 | 双击打开模式下首次单击选中 | Bug/文件浏览 | 90% | 设置为“双击打开”时，首次单击文件或目录必须更新并保持选中/焦点视觉；第二次单击才执行打开或进入目录。list/grid/tree 的选择语义不能因打开模式改变。list/grid widget 已断言首击选中，真实平台输入仍待验收。 |
| UI-87 | 属性页快捷复制范围收敛 | UI/属性 | 70% | 名称和路径保留明确快捷复制按钮；其它普通值可通过文本选择和右键复制，不再为每个值显示按钮；密码、密钥材料等敏感值不得出现复制入口。公共属性、文件属性和 root 属性已接入该策略，属性定向回归通过；真实鼠标选择/右键复制仍待验收。 |
| UI-88 | 侧边栏 root 属性行距 | UI/布局 | 70% | root 属性弹窗在不牺牲可读性和长文本换行的前提下缩小行间距；窄屏、宽屏和中英文布局均不溢出。root 属性使用紧凑行距，属性与英文布局回归通过；不同平台字号仍待验收。 |
| UI-89 | 侧边栏 root 右键选中效果 | Bug/侧边栏 | 90% | root 右键菜单打开前，当前 root 项立即显示明确选中/激活态；菜单关闭后保留正常当前项状态，不误改变解锁、历史或会话状态。侧边栏 widget 已覆盖非当前 root 右键时的临时选中和菜单关闭恢复；真实平台视觉仍待验收。 |
| UI-90 | 侧边栏 root 上下移动 | UI/侧边栏 | 70% | 侧边栏 root 支持向上/向下调整顺序，边界项禁用对应动作；顺序持久化，重启后保持，不能改变 root 路径、会话和磁盘内容。右键动作、边界菜单和主页持久化接线已完成，侧边栏/壳层/本地化回归通过；重启恢复和真实桌面操作仍待补测。 |
| UI-91 | 网格模式图标宽度异常 | Bug/文件浏览 | 10% | grid 模式下图标在固定单元格内保持完整可见且居中，不出现只有约半个宽度的图标；list/grid/tree 和不同窗口宽度均需有布局回归。 |
| WEB-01 | WebDAV 第三方工具交接实现 | P1/第三方工具 | 20% | 将 [第三方工具 WebDAV 文件交接设计](design/THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md) 提升为 P1 主线；先完成 loopback 会话、token、只读文件访问、root 锁定/结束会话撤销和明文生命周期边界，再实现可选编辑与系统挂载，不宣称未验收平台支持。 |
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
| Flutter Transfer UI 闭环 | 90% | HomePage widget 测试覆盖解锁、文件/目录 import 冲突、单文件/批量导出冲突决策、失败恢复和 unfinished rerun；目录导出现在在目标同名时显示冲突对话框并禁止替换，只允许取消或保留两者，避免无语义的目录覆盖。 | 真实桌面 E2E、目录导出保留两者/取消/重开完整链路、错误信息分层和可访问性 |
| 测试矩阵与持续集成 | 76% | Go 多 module、CLI 子进程、FFI C ABI、Dart 真库和 widget 测试已存在 | 固化 Linux CI；增加 Windows/macOS runner、桌面 E2E、故障注入、资源上限和覆盖率基线 |
| 文档真实性与分类 | 80% | 主体中文，设计/审计/历史已分层；本轮重做任务百分比 | 清理 ARCHITECTURE/CLI/FEATURES 的旧 V2 描述和失效命令；增加文档链接检查 |

## P2 产品功能

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| 安全记事本 | 95% | 状态/controller 与 UI 分区已拆分；编辑、加密草稿、剪贴板监视、broker 冲突及远程子窗口均有测试，Linux 已实测原生窗口。主/子窗口打开均传递 16 MiB 文本上限，已知大小和未知大小均在解密前拒绝；未知大小使用独立错误文案，主页的记事本和图片独立窗口入口均有错误映射。UI-85 的 Flutter 测试尚因本机 Flutter SDK 启动前置失败未运行。 | 补三平台桌面键盘/关闭/系统剪贴板 E2E、未知大小的跨层回归和流式大文件编辑策略、平台压力测试 |
| 图片浏览器 | 92% | JPEG/PNG/GIF/BMP/WebP 真实 codec 与渲染、GIF 动画识别、缩放旋转、键盘翻页、重试、64 MiB/100 MP 资源边界、异步竞态清零和只读子窗口 lease 均有自动化测试；真实 FFI 验证中文加密目录 WebP，Linux 已实测跨 engine PNG | 三平台真实窗口键盘/手势 E2E、超大图片内存压力与平台 codec 差异验收 |
| Stream V3/增量编辑 | 15% | 有设计文档；Dart 活跃入口明确返回 unsupported | 确定格式、完整性和崩溃一致性模型，完成 sec/FFI/Dart/UI 实现及随机编辑实际测试 |
| 大目录 UI 虚拟化 | 75% | Flutter list/grid 已使用 sliver 虚拟构建。当前目录的 native cursor、Dart binding/session 与 FileService 路径映射已接入 HomePage 的 list/grid；tree 的 root 与每个展开节点现在也使用独立 cursor。tree session 不累计普通文件，只保留当前页，并会越过纯文件页继续读取直到发现目录或 EOF；刷新/节点销毁会关闭 cursor，失败改为从头刷新。未完成目录会保持 walker 页顺序、禁用全目录排序，筛选明确限定为已加载条目且空态可继续加载。真实 name-encrypted root 两页 FFI、session 保留模式、tree 纯文件页和筛选/排序边界 widget 回归已通过；当前提交重新完成 100000 条真实 FFI 基准，首屏 200 条 8ms、完整 501 页 776ms、单页最大 8ms、分页后 RSS 采样上界 239362048 bytes。现有 `listCurrentDirectory(offset/limit)` 仍只是兼容回退的本地 `skip/take`。分页边界见 [DIRECTORY_PAGINATION_DESIGN.md](design/DIRECTORY_PAGINATION_DESIGN.md) | 补 10 万 entry 的 Flutter 实际滚动/内存基线、取消/错误/导航/关闭 root 的真实跨层回归；评估筛选时自动加载的性能与可访问性 |
| 自动锁定与密钥缓存超时 | 92% | 应用隐藏自动锁定已接入设置和 HomePage：合格 root 会关闭 native session、目录 cursor、应用内剪贴板和 broker 能力，历史保留；native 内容窗口在自动锁定前会按 token 确认并安全落草稿。bridge 在原生关闭前可逆冻结 broker 并等待已接受保存，成功后才撤销能力；关闭失败或保存排空期间窗口集合变化会取消预处理、恢复仍存活 lease 并保留 root。子窗口 endpoint 对重复锁定请求复用同一准备结果，并拒绝竞争请求。自动、手动结束会话和改密关闭按 root session 使用同一 FIFO gate，并在执行点重新验证 session。per-root TTL 已接入设置、独立活动时钟和同一关闭路径，且有 tracker/Home/设置页定向测试。broker/controller 已覆盖脏文档和活动写入的关闭判定 | Home 与子窗口协议的重解锁/手动关闭主动竞态、真实窗口消失与部分关闭失败、真实 FFI 与三平台 `hidden`/`paused`/TTL 验收 |
| KDF 成本动态校准 | 22% | 当前 `keyStrengthMs` 仅被各 KDF 粗略映射。阶段 A 已将受控的“新建目录默认派生档位”接入设置、主页和创建对话框：非法持久化值回退，用户可在本次创建中覆盖，且不会修改已有 root。改密前置缺口也已修复：Argon2id、scrypt、PBKDF2 在 staged 配置中严格继承原生成本参数并只更新 salt；缺参数失败关闭且不提交配置。边界和验证见 [KDF_CALIBRATION_DESIGN.md](design/KDF_CALIBRATION_DESIGN.md)。这不是设备校准，尚无 sec/FFI 校准实现，也不会声称毫秒值是实测耗时。 | 按设备目标耗时完成真正校准、算法参数/内存上限、防 DoS、取消与跨设备测试 |
| 文件排序/过滤/批量操作 | 92% | 当前目录筛选、目录优先排序、批量文件复制/剪切/粘贴/导出/删除已实现；批量冲突支持仅此项/全部应用，取消、失败和未处理项保留重试，并有结构化结果面板 | 超大目录分页排序、真实桌面大批次与跨 root 页面 E2E；全 root 搜索另立任务 |
| 主界面右键菜单 | 99% | 应用内单项及批量文件复制/粘贴、剪切/移动、冲突询问、跨 root 重加密、图片新窗口和右键选择/批量导出/删除已有测试；跨 root 文件及目录移动均有真实 FFI 和 widget 验证，目录删除失败会显示部分完成并保留剪贴板项。`Menu` 和 `Shift+F10` 复用当前选中项或最近键盘目标的菜单；没有目标时打开目录空白处菜单。list/grid 条目向读屏声明名称、文件或目录类型及右键选中态，widget 覆盖两种菜单键焦点恢复、无目标目录菜单和条目语义。系统文件剪贴板已明确不属于当前版本范围，范围与安全原因见 [SYSTEM_FILE_CLIPBOARD_DESIGN.md](design/SYSTEM_FILE_CLIPBOARD_DESIGN.md)。 | 三平台鼠标 E2E、键盘菜单键、焦点和读屏测试 |
| 剪贴板 | 84% | 应用内文件剪贴板支持有序多条复制/剪切队列、同 root rename 移动和跨 root 文件/目录 copy→delete；目录移动删除失败固定保留源、目标和剪贴板项，逐项失败、取消和未处理项也保持可重试；批量冲突策略与结果摘要已有回归；记事本短文本监视已实现。系统文件剪贴板明确不在当前版本范围，避免隐式明文 staging，见 [SYSTEM_FILE_CLIPBOARD_DESIGN.md](design/SYSTEM_FILE_CLIPBOARD_DESIGN.md)。 | 应用内剪贴板的三平台桌面验收和读屏测试 |
| 拖放 | 70% | 设计见 [DRAG_DROP_DESIGN.md](design/DRAG_DROP_DESIGN.md)。首期已接入 `desktop_drop`：已验证且空闲的当前目录浏览区可接收外部 drop 并显示高亮；插件载荷先经 `DragDropController`，只接受存在的普通绝对文件/目录，拒绝 file promise、内存载荷、链接、相对/失效路径、重复项和当前 root 内部路径，再按顺序复用既有文件/目录导入、冲突、进度、取消和 unfinished 链路。Windows 路径边界现统一 `/` 与 `\\` 分隔符并有注入模式回归。默认仍禁止拖出，未添加拖出设置。策略层与主页 target 有自动化证据；真实平台 drop 事件尚未验收。 | 三平台外部拖入的多文件/目录、取消、权限与临时明文泄漏验收；补平台事件高亮/回调 E2E；在具备可信目标目录协议前不得实现拖出 |
| 备份恢复与可选密码提示 | 12% | 设计见 [BACKUP_RECOVERY_AND_PASSWORD_HINT_DESIGN.md](design/BACKUP_RECOVERY_AND_PASSWORD_HINT_DESIGN.md)：提示是可选公开信息而非找回凭据。密码提示已完成 sec staged replace、FFI/Dart ABI、创建高级选项、默认折叠的解锁展示，以及仅限已解锁属性页的当前密码确认更新/清除；Go、真实 Dart ABI 和 widget 有定向回归。备份/恢复仍无格式和实现。 | 提示补 staged-replace 故障注入、跨进程锁竞争、打开窗口配置刷新和三平台桌面验收；定义并实现 snapshot/manifest、恢复和灾难测试 |
| 安全记事本草稿间隔与只读模式 | 92% | 间隔设置已接入加密草稿而非原文件；默认只读、默认剪贴板监视、编辑切换、恢复与状态保护有主/子窗口测试 | 保存冲突、快捷键、系统剪贴板、进程级崩溃与跨平台桌面实测 |
| 第三方工具安全文件交接（WEB-01，P1） | 20% | [THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md](design/THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md)，本轮已提升为 P1 主线 | 完成 loopback WebDAV 会话、token、只读访问、撤销和明文生命周期；再评估编辑与系统挂载 |

## P3 发布与平台

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| Windows 产品验收 | 20% | 有交叉编译和部分平台代码 | Windows runner、GUI/CLI/FFI 实机测试、安装包、升级/卸载 |
| macOS 支持 | 0% | 无当前验收证据 | 构建、签名、公证、FFI 和 UI 实测 |
| Linux 安装包 | 15% | 可开发运行 | deb/rpm 或其他发布格式、desktop 集成、干净环境安装测试 |
| 多语言与可访问性 | 55% | `zh`/`en` ARB、语言偏好和主/内容窗口 locale 传递已接入；`tool/audit_i18n_strings.dart` 当前对产品 `lib` 报告 0 候选，`app_en.arb` 无中文值，设置页不再显示过期的“英文仍在迁移”提示。该证据只覆盖源级迁移。 | 补逐页中英文交互/Semantics 基线、键盘导航、读屏、对比度和三平台字号/截断验收 |
| 可配置 config 文件名 | 0% | 当前固定 `_cryption.json` | 评估发现机制、冲突与兼容成本；决定取消或实现 |
| API/开发者/贡献文档 | 30% | 已有设计与使用文档 | Go API reference、构建/测试/贡献流程及链接自动检查 |
| 发布安全审计 | 10% | 有局部安全测试和设计说明 | 威胁模型冻结、依赖审计、模糊测试、发布构建复现、第三方评审 |

## 本轮验证状态

- 2026-07-23 UI-75 分类迁移：拖放控制器已完成 Windows 分隔符、大小写和 root 边界处理，Linux 注入 Windows 规则回归与 HomeShell 定向回归通过；剩余仅真实 Windows 资源管理器、盘符/UNC 路径和权限验收，已迁入 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)。
- 2026-07-23 UI-84 多标签页/预览范围决策：当前产品的正式交互是主窗口内显式路由，以及通过 broker/lease 管理的显式内容子窗口；不在文件悬停或单击时隐式解密并创建预览，也不增加标签页状态。快捷键和多窗口平台验收已单独跟踪，范围设计已进入完成档案。
- 2026-07-23 UI-83 后完整 Flutter UI 回归：使用真实 FFI 动态库 `/tmp/safe_disk_ffi/libffi_sec_fs.so` 执行 `flutter test --no-pub --timeout 240s -r compact`，305 项全部通过，退出码 0。该结果覆盖输入字节上限接入后的主界面、文件浏览、设置、记事本、图片、拖放和 FFI 集成回归；不替代平台实机、读屏、压力及 UI-68 问题环境验收。
- 2026-07-23 UI-78/79/80/81/83 分类迁移：代码、自动化测试和 Linux 主线静态验证已完成，剩余仅真实桌面键盘、焦点、输入法和压力验收，已迁入 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)；不再把平台缺口混入活跃实现任务。
- 2026-07-23 UI-83 安全记事本编辑输入字节上限：`SecureTextEditor` 接入 16 MiB UTF-8 字节限制格式化器，超限时按完整 Unicode code point 截断并清除 composing 状态；新增 ASCII、多字节和未超限边界测试，记事本定向回归共 32 项全部通过，`dart analyze` 无问题。该证据不替代真实桌面粘贴、输入法和大文本压力验收，也不代表未知大小文件已流式读取。
- 2026-07-23 UI-85 测试补齐：使用 `/tmp/flutter-copy` 可写 Flutter SDK 副本和真实 FFI 动态库运行 broker、主页和安全记事本相关回归共 86 项全部通过；新增主页未知大小文本入口回归确认未调用解密服务且显示信息提示，`flutter analyze --no-pub` 无问题。原 SDK 仍因只读 engine 缓存不可直接运行；独立窗口未知大小专门断言及平台实测仍未完成。
- 2026-07-23 UI-86/UI-89/UI-90：确认双击打开模式的文件浏览器已有 list/grid 首击选中语义及 widget 覆盖；侧边栏 root 右键新增临时选中态，菜单关闭后恢复当前 root；root 右键菜单新增按边界显示的上移/下移动作，主页调整 `_openedDirs` 后复用 `saveOpenedDirectories` 持久化。侧边栏、HomeShell、本地化定向回归共 8 项通过，`dart analyze` 无问题；UI-90 仍待重启恢复和真实桌面验收。
- 2026-07-23 UI-87/UI-88：属性复制按钮改为默认关闭，仅文件/root 的名称、路径显式开启；普通属性保留 `SelectableText`，敏感值不提供按钮。root 属性弹窗启用紧凑行距，属性、root 属性和文件属性回归共 15 项通过，`dart analyze` 无问题；真实鼠标选择、不同平台字号和长文本布局仍待验收。
- 2026-07-23 UI-82 系统文件剪贴板范围决策：完成中文设计，明确当前版本只支持应用内安全文件剪贴板；不把加密 root 条目转换为系统可读的明文临时文件，不把逻辑路径伪装成文件 URI。后续若立项，必须先定义 staging 生命周期、异常清理、跨平台格式和无明文残留证据。
- 2026-07-23 完整 Flutter UI 回归（含 UI-78/79/80/81）：使用真实 FFI 动态库 `/tmp/safe_disk_ffi/libffi_sec_fs.so` 执行 `flutter test --no-pub --timeout 240s -r compact`，302 项全部通过，退出码 0。该结果覆盖当前已登记的主界面快捷键、当前目录筛选、文件浏览、设置、记事本、图片、拖放和 FFI 集成回归，但不替代 Windows/macOS 实机、读屏、性能及 UI-68 问题环境验收。
- 2026-07-23 UI-81 主界面筛选快捷键：文件浏览器新增公开的 `focusFilter()` 窄接口，HomePage 通过 `Ctrl/Cmd+F` 打开并聚焦现有当前目录筛选；不改变筛选范围或伪装成全 root 搜索。文件浏览器与主页定向回归共 80 项全部通过，`dart analyze` 无问题。该证据不替代真实平台键盘焦点验收。
- 2026-07-23 UI-80 主界面刷新快捷键：补齐 `Ctrl+R` 和 `Cmd+R`，与 `F5` 复用当前目录刷新和活动计时路径；主页解锁/快捷键 widget 回归 62 项全部通过，`dart analyze` 无问题。该证据不替代真实平台键盘和焦点验收。
- 2026-07-23 UI-79 主界面粘贴快捷键：补齐 `Cmd+V` 的 Meta 修饰键绑定，与已有 `Ctrl+V` 共用安全文件剪贴板路径；主页解锁/快捷键 widget 回归 62 项全部通过，`dart analyze` 无问题。该证据不替代真实 macOS 键盘和桌面焦点验收。
- 2026-07-23 UI-78 安全记事本快捷键兼容：补齐 `Ctrl/Cmd+H` 打开查找、`Ctrl/Cmd+Y` 重做，并在查找输入框增加 `onSubmitted` 兜底，使普通回车和数字键盘回车共享提交路径；widget 回归 17 项通过，`dart analyze` 无问题。该证据不替代三平台真实键盘布局和桌面窗口验收。
- 2026-07-23 KDF 安全默认档位阶段 A：设置页新增仅作用于新建目录的四档受控默认值，主页在创建对话框前读取并传递，创建对话框明确提示“尚未按本机性能校准”；非法持久化值回退到平衡档，用户可在创建时覆盖。`flutter analyze --no-pub` 通过；设置服务、设置页和创建目录定向 widget 回归通过；完整 `SAFE_DISK_FFI_LIBRARY=/tmp/safe_disk_ffi/libffi_sec_fs.so flutter test --no-pub --timeout 180s -r compact` 成功结束。未执行设备性能测量或跨平台 KDF 校准验收。
- 2026-07-22 设置服务本地化边界回归：移除未使用且返回中文展示文本的 KDF/主题 API，自动保存间隔校验说明改为稳定技术标识；`flutter test --no-pub test/settings_service_test.dart -r compact` 共 5 项通过。审计候选由 68 降至 59，设置服务已无候选。
- 2026-07-22 本地化审计增强：`tool/audit_i18n_strings.dart` 改为词法扫描，覆盖多行/raw 字符串、忽略注释，并按直接 UI、服务边界、人工复核及英文 fallback 分类；`dart analyze tool/audit_i18n_strings.dart` 通过，默认产品代码报告为 117 项，`--include-test` 可额外生成测试核对清单（811 项，不计入产品债务）。
- 2026-07-23 安全记事本本地化边界回归：加载与草稿错误改为稳定枚举，UI 状态栏按 ARB 映射；剪贴板读取/清空失败不泄露原始异常，保存成功有独立提示。`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/secure_notepad_controller_test.dart test/secure_notepad_widget_test.dart -r compact` 共 26 项通过。审计候选由 117 降至 114，记事本 controller 与 widget 均无候选；子窗口及三平台英文视觉/读屏验收仍未完成。
- 2026-07-23 图片策略本地化边界回归：`SecureImagePolicyException` 改为稳定违规枚举和安全限额参数，viewer 在构建时按 ARB 映射；策略与解密失败均不展示原始异常，图片列表失败日志改为技术标识。`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/secure_image_policy_test.dart test/secure_image_viewer_test.dart -r compact` 共 14 项通过。审计候选由 114 降至 105，图片策略模型与 viewer 均无候选；三平台视觉、截断与读屏验收仍未完成。
- 2026-07-23 内容窗口协议边界回归：bridge 的保存/草稿/脏状态校验、参数校验和未支持调用均改为稳定技术标识；新增无效请求和未支持调用的 `PlatformException` 标识断言。`flutter analyze --no-pub` 通过；`flutter test --no-pub test/content_window_host_bridge_test.dart test/remote_document_crypto_service_test.dart -r compact` 共 11 项通过。审计候选由 105 降至 99，直接中文 UI 候选归零；服务层英文错误与三平台视觉/读屏验收仍未完成。
- 2026-07-23 跨窗口与移动本地化边界批次：应用标题改用 `appTitle`，导出缺少底层错误时使用稳定诊断标识；内容窗口 client/broker/remote crypto 的冲突、时限、草稿和快照诊断均改为稳定标识。移动服务区分“源文件删除失败”和“不支持的目录移动”，主页批量结果按 ARB 呈现。`flutter gen-l10n`、`flutter analyze --no-pub` 通过；跨窗口、移动、记事本 controller 与主页定向测试进程成功结束；完整 `flutter test --no-pub --timeout 180s -r compact` 成功结束，12 个缺少动态 FFI 库的集成测试按预期跳过。审计候选由 99 降至 76，直接 UI 候选归零；人工差异审查已进入本批提交前最后阶段。
- 2026-07-23 废弃剪贴板模块清理：仓库级引用检查确认 `clipboard_service.dart` 与 `clipboard_helper.dart` 无产品、测试或入口引用，现行路径为 `SecureClipboardService`，因此删除两份临时文件剪贴板遗留实现而非对其进行翻译。`flutter analyze --no-pub` 通过；安全剪贴板、移动服务和主壳本地化定向回归共 6 项通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 233 通过、12 跳过。审计候选由 76 降至 60，直接 UI 候选仍为零。
- 2026-07-23 废弃增量加密 Dart API 清理：仓库级引用检查确认 `ffi_results.dart` 仅由无入口的 `incremental_encrypt_service.dart` 引用，原生 `ffi_sec_fs` 没有增量导出，`NativeLib` 占位桩也只会返回失败。因此删除该 Dart 死路径和占位桩，并把架构、FFI 设计、状态与 README 统一为“历史设计归档，无活跃 API”。`flutter analyze --no-pub` 通过；目录/Transfer V3 与 FFI 定向回归 10 通过、12 跳过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 233 通过、12 跳过。审计候选由 60 降至 31；删除不代表增量加密能力完成。
- 2026-07-23 服务诊断稳定标识与详细错误本地化：目录 marker、root 会话、原生加载、Transfer worker 和设置校验的可传播异常改为无路径、无密码的稳定标识；详细诊断的标签、密码/路径替代符和截断提示由 ARB 按当前 locale 生成。新增英文原生启动详细错误脱敏断言。`flutter analyze --no-pub` 通过；错误报告、原生启动、目录 marker、导入目标和创建 root 定向回归共 20 通过；完整 `flutter test --no-pub --timeout 180s -r compact` 为 234 通过、12 跳过。词法审计由 31 降至 0；该静态结果不替代三平台英文视觉、截断和读屏验收。
- 2026-07-23 属性首击 Linux 复现与修复：真实“右键菜单 → 文件/root 属性”首次冷帧分别约 336ms/249ms，完成一次属性挂载后另一种属性降至约 8ms；菜单 route 移除与属性 overlay 同帧导致首次初始化成本叠加。HomePage 的两个属性入口现等待一个 `endOfFrame` 后再插入 overlay；Linux A/B smoke 降至约 7.7ms，`flutter analyze --no-pub`、文件/root 属性与主页右键定向回归通过。Windows/macOS 和真实主界面鼠标路径仍在跨平台验收清单。
- 2026-07-23 主界面复制/剪切快捷键：补齐 `Ctrl/Cmd+C` 与 `Ctrl/Cmd+X`，优先处理当前选中项，无多选时复用最近右键目标，并保持安全文件剪贴板路径。主界面快捷键 widget 回归已通过；三平台真实键盘布局与读屏验收仍在平台清单。
- 2026-07-23 UI-68 小键盘回车初步复现：临时 Linux 桌面诊断程序使用与安全记事本相同的多行 `TextField`，通过真实 `xdotool KP_Enter → 连续空格 → 英文` 输入；观察到光标逐次移动、空格立即进入文本，composing 区域始终为空，未复现用户描述的问题。未修改编辑器代码，仍需在用户出现问题的键盘布局/输入法环境复验。
- 2026-07-23 UI-69 安全记事本剪贴板监视布局：监视条从编辑器上方移到编辑器底部，保留刷新、快速清空、关闭和错误状态；新增布局断言。controller/widget 共 28 项回归与 `flutter analyze --no-pub` 通过。
- 2026-07-23 UI-66 多语言换行转义：确认 ARB 中双反斜杠会让 UI 显示字面量 `\\n`；修正版本说明和无目录空态，保留查找提示的语法示例。重新执行 `flutter gen-l10n`；设置页/侧边栏本地化回归 20 项通过，`flutter analyze --no-pub` 通过。
- 2026-07-23 UI-67 设置界面重排：将原行为卡片拆为行为、安全和安全记事本，外观/行为/安全/记事本在宽屏按 2×2 排列，关于信息单独置底，窄屏保持单列滚动。新增中英文分类文案；设置页回归与宽窄布局断言通过，`flutter analyze --no-pub` 通过。
- 2026-07-23 UI-39/UI-44 竞态修复登记：确认关闭旧 root session 的异步窗口操作完成后，若同一路径已重新解锁，现有按路径替换逻辑可能把新 session 错误覆盖为锁定状态；修复必须按旧 `sessionID` 做条件替换，并覆盖关闭期间重新解锁与迟到结果隔离。
- 2026-07-23 UI-41 文案复查：将错误提示中的“所选目录”改为“选择的目录”，避免暗示必须经过文件选择器；重新生成 ARB 代码，错误本地化与主页定向回归 65 项通过。
- 2026-07-23 UI-46 文案复查登记：本轮只调整导入自身限制、取消后未完成状态、加密目录位置提示和清理结果四类文案，保留原有安全含义；修改前需同步检查中英文占位符与相关确认/错误回归。
- 2026-07-23 UI-46 文案复查完成：中英文 ARB 已同步改写并重新生成；错误、主页、进度和对话框相关回归 71 项通过，`flutter analyze --no-pub` 通过。仍需低频页面的人工语气复核与三平台视觉/读屏验收。
- 2026-07-23 UI 主线分类复查登记：UI-41、UI-54、UI-65 的代码和自动化验收已达到当前实现范围，剩余仅为低频人工文案、读屏/字号、真实平台输入和大目录性能验证；迁移到 `PLATFORM_ACCEPTANCE.md` 前保留原验收条件，不降低完成口径。
- 2026-07-23 UI-46 文案微调登记：导入自身限制提示仍有“它自己内部”的口语歧义；本轮只改为明确的“当前加密目录中的子目录不能再次导入当前加密目录”，同步英文和错误回归，不改变限制逻辑。
- 2026-07-23 UI-46 第二批文案完成：自动锁定、未完成导入/导出和平台回退提示已改用“打开的文件窗口”“重新执行”“清理未完成操作”等用户表达，中英文 ARB 已重新生成；主页、记事本、进度和对话框定向回归 84 项通过，`flutter analyze --no-pub` 通过。仍需低频页面人工复核及三平台视觉/读屏验收。
- 2026-07-23 UI-46 分类完成：`/home/john/flutter/bin/cache/dart-sdk/bin/dart run tool/audit_i18n_strings.dart` 报告产品代码 0 候选；中英文 widget 证据已具备，剩余仅低频人工和平台可访问性验收，已迁移到 `PLATFORM_ACCEPTANCE.md`。
- 2026-07-23 UI-39/UI-44 分类完成：HomePage、root idle tracker 与生命周期相关回归 64 项通过，`flutter analyze --no-pub` 通过；仅剩真实窗口/FFI 和三平台生命周期验收，已迁入 `PLATFORM_ACCEPTANCE.md`，未将模拟窗口测试当作桌面完成证据。
- 2026-07-23 UI-68 回归登记：补充安全记事本编辑器完整序列“已有文字 → 数字键盘 Enter → 连续空格 → 英文”，同时断言文本、光标和 composing 状态；当前只建立问题环境基线，不在未复现前改写 Flutter 输入链路。
- 2026-07-23 UI-68 测试工具边界：widget `sendKeyEvent` 可触发数字键盘 Enter，但不会模拟真实桌面输入法提交后续空格/英文；新增回归得到的 `line` 结果不能作为产品证据，已移除该无效测试。真实 Linux `xdotool` 诊断仍得到 `line\n    x` 且未复现问题，暂不修改编辑器输入链路。
- 2026-07-23 UI-68 输入法环境核对：当前 X11 使用 Flutter GTK 的 `GTK_IM_MODULE=fcitx`，但 `fcitx-remote` 状态为 inactive；Flutter 引擎对 `KP_Enter` 会先调用 `GtkIMContext` 再处理多行换行。该条件解释了问题与输入法相关的可能性，但不是用户报告路径的复现，未关闭/切换用户输入法，也未修改编辑器行为。
- 2026-07-23 UI-70 双击打开首击高亮：确认带 `onDoubleTap` 的 Flutter 手势会延迟第一次 `onTap`，原实现只在 `onTap` 更新高亮，导致双击打开模式首击无视觉反馈；改为在指针按下时记录当前项，第二次点击仍由双击手势打开。新增 list/grid 首击高亮回归，文件浏览器共 18 项通过，Dart analyzer 通过。
- 2026-07-23 UI-39/UI-44 分类登记：自动锁定和 TTL 的 Home/controller/bridge 协议已覆盖 session gate、await 后 session 复核、窗口拒绝/迟到回复/保存排空等代码边界；剩余仅真实窗口消失、部分关闭失败、真实 FFI 及三平台 `hidden`/`paused`/TTL 验收，迁移前保留这些验收条件。
- 2026-07-23 UI-46 分类登记：文案通俗化代码批次、ARB 占位符、静态审计和中英文 widget 回归均已完成；剩余仅低频页面人工语气、读屏、字号、截断和三平台视觉验收，迁移到 `PLATFORM_ACCEPTANCE.md` 时保留完整范围。
- 2026-07-23 UI-46 第二批文案登记：复查发现自动锁定、未完成导入/导出和平台回退提示仍使用“内容窗口”“状态文件”“全量重跑”“清理状态”等偏内部表达；本批只改为用户可理解的文件窗口、重新执行和未完成操作，保持安全限制与操作语义不变，并同步中英文回归。
- 2026-07-23 UI-65 打开方式首批实现：新增单击/双击打开设置，接入 SharedPreferences、设置保存事务、主页和 list/grid 文件浏览器；默认单击，双击模式下首次点击不打开、第二次点击打开。服务、设置事务和文件浏览器回归通过；多选范围、拖选和键盘选择仍未实现。
- 2026-07-23 UI-65 多选交互实现：文件浏览器新增 Ctrl/Meta 点击、Shift 范围、鼠标主键拖选、方向键焦点、Shift+方向键扩展和 Ctrl+Space 切换；HomePage 维护唯一选集并向批量操作复用，list/grid 共享选择状态。文件浏览器与主页定向回归共 72 项通过，`flutter analyze --no-pub` 通过；三平台真实输入、触控/读屏和大目录性能仍待验收。
- 2026-07-23 UI-65 多选范围复核：确认批量目录操作已有入口，但原选择逻辑把目录排除在选择模式、Shift 范围和鼠标框选之外；本次验收口径扩展为文件与目录统一多选，普通非选择模式下目录仍保持导航行为。
- 2026-07-23 UI-65 目录多选实现：Ctrl/Meta 点击、Shift 范围、鼠标框选、Shift+方向键、Ctrl+Space 和全选现均保留目录项；普通模式目录点击仍导航。新增文件浏览器与主页目录多选回归，定向 `flutter test` 共 74 项通过，直接 Dart analyzer 无问题。
- 2026-07-23 UI-65 目录选择可见性：选择模式下 list 视图为目录同样显示复选框，避免目录已进入选集但缺少可操作反馈；新增选中目录复选框断言。
- 2026-07-23 UI-65 桌面选择快捷键：补充 Ctrl/Meta+A 全选与 Esc 退出选择模式，避免多选只能依赖鼠标菜单；待补实际平台键盘和焦点验收。
- 2026-07-23 UI-65 桌面选择快捷键回归：主页验证 Ctrl+A 可一次选中文件与目录，Esc 清空选集并退出选择模式；文件浏览器/主页定向回归待本轮提交前复跑。
- 2026-07-23 UI-65 grid 选择可见性：选择模式下 grid 项目也显示复选框，并复用 list 的选择回调；新增 grid 选中复选框断言。
- 2026-07-23 UI-65 grid 键盘导航：记录实际 grid 列数，方向键上下按列移动、左右按单项移动，避免 grid 视图使用一维列表步长；待补宽窄窗口和真实平台键盘验收。
- 2026-07-23 UI-65 grid 键盘导航回归：500px 内容宽度下浏览器报告 3 列，列数回调 widget 断言通过；主页方向键使用该列数计算上下移动。
- 2026-07-23 UI-65 grid 键盘导航端到端回归：800px 桌面窗口、侧边栏占用后的 3 列 grid 中，焦点从首项按 ArrowDown 移至下一行首项；主页 widget 断言通过。
- 2026-07-23 UI-65 grid 复选框事件回归：点击已选 grid 条目的复选框只切换一次选集，不会与外层条目点击重复触发。
- 2026-07-23 UI-65 首尾键盘导航：补充 Home/End 跳转当前目录首尾条目，Shift+Home/End 复用范围选择；待补实际平台键盘验收。
- 2026-07-23 UI-65 首尾键盘导航回归：主页验证 End 定位末项、Shift+Home 选中包含目录在内的完整当前列表。
- 2026-07-23 UI-65 框选性能边界：鼠标拖选选框改用独立 `ValueNotifier` 绘制状态，指针移动不再触发文件 list/grid 整体 `setState`；保留抬起时的可见条目命中计算。文件浏览器与主页定向回归 78 项通过；真实大目录帧率、内存和平台输入仍待验收。
- 2026-07-23 UI-68 Linux 真实键盘诊断：按“编辑器输入 `line` → `KP_Enter` → 四次空格 → `x`”重跑，日志显示选择偏移 `5→6→7→8→9→10`，`composing` 始终为空，最终文本为 `line\n    x`；当前环境未复现用户报告，未修改编辑器输入链路，仍待问题环境的键盘布局/输入法复现。
- 2026-07-23 UI-68 真实应用复验：在当前 Linux Safe Disk 窗口中按“ff root → 文件右键 → 在新窗口中编辑 → 切换编辑模式 → `KP_Enter` → `a` → 四次空格 → `x`”执行，未保存编辑器实际显示换行、空格和 `x` 均立即进入文本，未复现空格延迟出现；本轮只放弃未保存修改，不调整输入链路。输入过程曾遇到桌面 `xdotool type` 的 XTEST BadValue，改用逐个按键事件完成复验，该输入权限问题不归因于应用。
- 2026-07-23 UI-68 Fcitx 条件复验：当前 X11 环境变量虽为 `XMODIFIERS=@im=fcitx`、`GTK_IM_MODULE=fcitx`，但机器上没有运行 Fcitx 守护进程，`fcitx-remote` 返回 0，无法建立有效 Fcitx 输入法会话；未将该次尝试计为复现，也未启动新的输入法进程或修改编辑器。
- 2026-07-23 大目录 UI 当前提交基线：运行 `benchmark_directory_cursor.dart --entries=100000`，真实 AES-256-GCM 名称 root 创建 5022ms；首屏 200 条 8ms，完整 501 页/100000 条 776ms，单页最大 8ms，分页后 RSS 采样上界 239362048 bytes。该结果只证明 cursor/FFI 分页基线，不替代 Flutter 实际滚动帧率、精确堆峰值或其它平台验收。
- 2026-07-23 UI-75 拖放 Windows 路径边界：发现 Windows 分隔符混用时原控制器只做大小写比较，可能误放行 root 内部路径；新增可注入 Windows 路径规则，统一分隔符后再做边界判断。Linux 注入 Windows 模式的 controller 回归与 HomeShell 定向回归共 4 项通过，Dart analyzer 通过；真实 Windows 资源管理器仍待验收。
- 2026-07-23 完整 Flutter UI 回归：使用真实 FFI 动态库 `/tmp/safe_disk_ffi/libffi_sec_fs.so` 执行 `flutter test --no-pub --timeout 240s -r compact`，299 项全部通过，退出码 0。该结果覆盖当前已登记的主界面、文件浏览、设置、记事本、图片、拖放和 FFI 集成回归，但不替代 Windows/macOS 实机及读屏/性能验收。
- 2026-07-23 UI-39/UI-44 session 边界修复：解锁后的首次目录加载、手动关闭等待子窗口和改密关闭等待子窗口均在异步返回后重新核对 path/session；若旧解锁已失效则关闭其 rootID，不覆盖新 session。主页定向回归新增“首次目录加载期间切换 root”场景，`flutter analyze --no-pub` 通过，主页 widget 回归 62 项通过；真实窗口消失、部分关闭失败和三平台生命周期仍待验收。
- 2026-07-23 UI-67 设置默认值复核：发现恢复默认设置遗漏自动锁定和会话 TTL，已登记为设置功能缺口，补齐后需增加回归。
- 2026-07-23 UI-67 设置默认值修复：恢复默认设置现在同步重置自动锁定开关与会话 TTL；设置页回归验证内存状态和保存后的持久化值。
- 2026-07-23 UI-43 筛选策略决策：当前版本不在输入筛选词时自动枚举未加载目录，继续加载保持显式操作；筛选始终标注作用于已加载条目，避免把局部结果伪装成全目录搜索。
- 2026-07-22 多语言主页剩余操作回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/home_page_unlock_widget_test.dart -r compact` 共 47 项通过。批量粘贴摘要/失败 operation、新建、重命名、删除确认和删除成功均进入 ARB；审计候选总数由 99 降至 68，`home_page.dart` 已无候选。英文路径仍缺覆盖新增提示的专门断言，主页未计为完整英文桌面验收。
- 2026-07-22 多语言主页导入导出与剪贴板首批回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/home_page_unlock_widget_test.dart -r compact` 共 47 项通过。文件选择、文件导入/导出成功、明文导出确认、复制名称/路径、单项与批量复制/剪切提示均已进入 ARB；候选总数由 113 降至 99，主页由 45 降至 31。批量粘贴结果和新建/重命名/删除仍待迁移，新增英文提示尚缺专门断言。
- 2026-07-22 多语言 root 会话与自动锁定回归：`flutter gen-l10n`、`flutter analyze --no-pub` 通过；`flutter test --no-pub test/home_page_unlock_widget_test.dart -r compact` 共 47 项通过。覆盖英文 root 会话移除提示和可滚动的长 root 操作对话框；自动锁定摘要、内容窗口/活动保存阻断、改密前阻断与成功状态均由 ARB 呈现。审计报告由 133 项降至 113 项，主页由 65 项降至 45 项。
- 2026-07-22 本地化硬编码审计基线：`dart run tool/audit_i18n_strings.dart` 生成 [I18N_HARDCODED_STRING_AUDIT.md](I18N_HARDCODED_STRING_AUDIT.md)，扫描到 133 个待分类候选；脚本同时扫描 CJK 字符串和常见 UI 构造位置的 ASCII 字符串，按文件、行号和源码上下文输出。候选不能自动等同于用户文案，后续迁移须逐项分类。
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
