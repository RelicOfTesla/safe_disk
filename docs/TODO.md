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
| UI-38 | 安全记事本查找结果定位 | Bug/UX/可访问性 | 90% | selection 更新后通过 `RenderEditable` 的真实光标坐标将命中行滚动到编辑器中部；查询输入框保持焦点，主/子窗口共用实现。长文本 widget 已验证 selection、scroll offset 和焦点；仍待 Linux/Windows/macOS 桌面视觉验收。 |
| TR-01 | Transfer 操作锁不污染用户目录 | Bug/并发/数据安全 | 90% | stable lock 已迁至用户私有缓存 `safe_disk/transfer-locks/`，root 与其父目录不再写 `.safe_disk.transfer.*.lock`；Go 覆盖跨进程互斥、symlink alias、等待取消和真实 import 后无相邻残留。仍待 Windows `LockFileEx` 实机与缓存目录生命周期验收。 |


## P0 正确性与数据安全

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| secure root walker 错误语义与资源上限 | 55% | backing entry 分批读取；已有加密名称、并发、关闭测试 | 不得静默吞掉名称解密/entry info 错误；待处理目录工作集需硬上限；补超宽、超深和损坏 backing entry 实测 |
| Windows durability 与跨进程锁 | 60% | Windows lock 实现和交叉编译路径存在；文件 Sync 已实现 | 真实 Windows 上验证目录 metadata flush、LockFileEx 竞争、进程退出释放、rename/占用句柄故障 |
| 本地并发符号链接替换防护 | 35% | 有词法 containment 和 import 符号链接拒绝 | 使用 dirfd/openat 或等价方案消除检查与打开间竞态；补攻击进程实测 |

## P1 核心基础设施

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| sec_fs 完整错误传播与损坏数据策略 | 82% | 密码认证、路径约束、key 生命周期、metadata、权限均有测试 | 统一 walker/crypto 损坏错误；确定 corruption tolerance 边界；真实损坏 root 端到端验收 |
| Transfer V3 平台完整性 | 88% | 原子 temp/backup、marker、取消、convert phase/recovery、真实 kill checkpoint 测试 | Windows 故障测试、walker 上限、源并发修改策略；明确字节进度/限速是否进入当前版本 |
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
| 大目录 UI 虚拟化 | 10% | 只有需求 | 虚拟列表、分页/增量 walker API、10 万 entry 自动化性能测试 |
| 自动锁定与密钥缓存超时 | 20% | 有 root close/key 清理基础 | 生命周期策略、前后台切换、超时清理、真实 UI/FFI 验收 |
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

- 2026-07-14 Flutter UI 回归：`flutter analyze --no-pub` 零问题；默认入口 Linux debug 构建通过；真实 FFI 动态库下完整 `flutter test --no-pub` 共 130 项通过，覆盖 root 三种关闭语义、记事本默认项、属性首击、批量粘贴冲突/取消/部分失败、五种图片 codec/资源边界/只读子窗口 lease、中文加密目录 WebP 实际渲染、错误详情开关/脱敏、Windows 字体主题、不存在与非空 root 路径语义，以及既有 CLI/Dart FFI 互通和多窗口协议回归。
- 2026-07-14 Windows 静态/交叉验证：构建脚本 Windows DLL 规范名单测通过，`scripts/build.go` 和 sec_fs 测试二进制均通过 Windows amd64 交叉编译；当前 Linux 环境没有 Windows runner toolchain/Wine，因此这些证据不替代 Win10 bundle 与界面实测。
- 2026-07-14 Linux X11 实测：同一进程成功创建独立主窗口与安全记事本、图片查看器子 Flutter engine；另以 `GDK_SYNCHRONIZE=1` 连续创建/关闭五个记事本原生窗口，进程正常退出且无 implicit view 移除、engine 销毁后 messenger 或 GLX BadAccess 错误。仍观察到一次 compositor shader 上下文警告，且该自动化路径不能替代用户标题栏关闭复验、Windows/macOS 与完整桌面 E2E。
- 已通过：Transfer V3 定向测试；Go 四个 workspace module 的完整测试；Go vet；Transfer/CLI/FFI race；Go 1.25 Windows 交叉编译；真实 Dart FFI 集成测试。
- “Transfer V3 路径流式消费”已按上述证据迁入完成档案；secure walker 工作集硬上限仍是独立未完成任务。
- Flutter 手工观察不能替代自动化实际功能测试，但应转成回归用例后再提升进度。
