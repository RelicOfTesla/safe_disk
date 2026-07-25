# Safe Disk 活跃任务清单


> 本文件只保留仍需实现、修复或补自动化证据的任务。
> 当前 Linux 已验收、仅待 Windows/macOS 等其它系统复验的条目已移至 [跨平台验收清单](PLATFORM_ACCEPTANCE.md)，不再稀释主线实现进度。
> 已完成并有自动化实际功能测试证明的任务见 [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md)。
> 本轮及跨模块验证证据见 [VERIFICATION_STATUS.md](VERIFICATION_STATUS.md)；本文件不记录验证流水。
> 审计日期：2026-07-25。状态以当前代码、公开入口、当前系统验收和测试为准，不继承历史勾选。

## 当前轮 WebDAV 互操作修复
| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|---|
| WEB-19 | macOS WebDAV 系统挂载 | Feature/macOS | 70% | mount_darwin.go: 基于 mount_webdav + 临时 keychain 凭据实现 Digest/Basic 认证挂载；keychain 条目会话粒度（-A 免提示）卸载时清理；支持 -S 抑制 Finder 侧边栏；健康检查带重试退避；umount 失败时 fallback diskutil force unmount；含 extractURLHost 单元测试。go cross-compile 通过。需 macOS 实机验证 mount_webdav keychain 鉴权流程、Finder 可见性、卸载清理和异常恢复。 |

| WEB-18 | Linux Digest davfs 挂载后目录为空（Invalid argument） | Bug/Linux/互操作 | 90% | mount_linux.go: 改用 pkexec/sudo mount.davfs；添加 dir_refresh=0 (禁止 FUSE readdir 时实时刷新 PROPFIND，避免 EINVAL)、table_size=4096；健康检查增加重试退避（5 次 x 100ms 步进）。go vet/build/test 通过。需 Linux 实机验证 davfs2 挂载后可正常 ls/读写目录。若仍失败，请挂载时加 davfs2 debug 参数抓 HTTP 交互日志。 |



---

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

## 当前轮 UI 与安全修复

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---:|---|
| WEB-01 | WebDAV 第三方工具交接实现 | P1/第三方工具 | 85% | Go 已完成 loopback 只读会话、Bearer/Digest SHA-256/Basic 全链路认证、TLS 自签名证书、异步挂载/卸载（开始/轮询/取消）、协议范围、访问监视、root 撤销、凭据策略和 root 内持久会话；FFI/Dart/CLI 已接选项/状态/恢复/挂载/卸载/TLS 开关；Go 测试覆盖 57 项（auth_test.go 非网络单元测试全通过）。仍缺编辑协议与冲突控制、常见系统工具认证兼容矩阵验证（rclone/davfs2/Win WebClient/macOS Finder）、Linux 实际挂载验收、真实第三方互操作和三平台攻击/异常生命周期测试；不宣称第三方工具交接整体完成。 |
| WEB-02 | WebDAV 凭据显示策略 | P1/第三方工具/凭据 | 85% | Go `reveal`、FFI ABI、Dart/Flutter 选择与持久会话列表入口已实现；一次性策略不返回秘密，持久策略有风险提示且不进入 list/status。仍需 CLI 的独立 reveal 管理入口和三平台凭据泄露/日志审计。 |
| WEB-03 | WebDAV 持久会话 | P1/第三方工具/持久化 | 75% | Go 已实现 root 内加密状态、稳定 root 关联、固定端口、ID/凭据恢复、root 重开 warning、显式撤销删除；FFI/Dart/CLI 已接配置，Go/FFI 有关闭重开和端口生命周期测试。仍需暂停/轮换、恢复失败 UI、跨进程管理、系统客户端重启恢复和三平台异常生命周期测试。 |
| TR-01 | Transfer 操作锁不污染用户目录 | Bug/并发/数据安全 | 90% | stable lock 已迁至用户私有缓存 `safe_disk/transfer-locks/`，root 与其父目录不再写 `.safe_disk.transfer.*.lock`；Go 覆盖跨进程互斥、symlink alias、等待取消和真实 import 后无相邻残留。仍待 Windows `LockFileEx` 实机与缓存目录生命周期验收。 |
| WEB-04 | 合并 WebDAV 共享配置弹窗 | P1/UI | 90% | 保留一次明确的只读暴露确认；认证方式、凭据显示方式、会话保留方式已在同一个可滚动配置弹窗完成选择，创建共享不再连续弹出多个配置框；默认值、警告、取消语义和 HomePage/widget 回归已通过。仍需三平台视觉与键盘验收。 |
| WEB-05 | 修复 davfs 系统挂载目录枚举 | P1/互操作 | 25% | 已确认只读包装器继续准确声明 `DAV: 1`，并补 `davfs2` 风格 `OPTIONS`、`PROPFIND Depth: 1`、XML 请求和中文/空格文件名 URL 编码测试；没有用不支持的锁能力伪装兼容。当前环境无挂载权限，尚未完成真实 `mount.davfs` 挂载、`ls` 和 rclone 对照验收；不能宣称问题已修复。 |
| WEB-06 | Windows WebDAV 系统挂载 | P1/Windows | 50% | Go 已接入 Windows WebDAV Redirector：校验 loopback Digest、分配空闲盘符、通过 `net.exe use` 的 stdin 输入密码、检查盘符、卸载和失败清理；Windows 交叉编译通过。仍需 Windows WebClient 服务、Digest 实机兼容、盘符访问/复制和异常退出验收；Bearer 明确拒绝。 |
| WEB-07 | 复制已挂载系统目录路径 | P2/UI | 70% | WebDAV 会话显示系统挂载路径时已提供独立复制按钮、可选择文本和控件内复制反馈，并有 widget 测试；不把挂载目录误当作安全 root 内部文件剪贴板。仍需 Linux/Windows/macOS 系统剪贴板和实际文件管理器验收。 |
| UI-92 | Linux 属性弹窗首次打开卡顿 | Bug/Linux UI | 100% | 已完成：字体预热。用户实测确认。 |
| UI-94 | 删除目录列表中的"0 个项目" | P2/UI 文案 | 100% | 已完成：目录列表项没有子项时不渲染。用户实测确认。 |
| WEB-08 | WebDAV 总开关 | P1/安全设置 | 90% | 已接入设置持久化、主页入口控制、关闭时撤销当前 root 会话和解锁后清理恢复会话；中英文 UI、设置服务和设置页测试已完成。剩余真实平台验收：关闭开关时已有 Linux/Windows 系统挂载的实机回收提示。 |
| WEB-09 | WebDAV 系统挂载请求取消 | P1/平台/并发 | 90% | 已增加 Go 异步操作存储、FFI 开始/轮询/取消 ABI、Dart 服务和会话页取消按钮；取消会中止平台命令并按真实状态刷新，Go 操作和 UI 回调已有测试。剩余真实平台验收：Linux davfs、Windows Redirector 的命令取消和临时凭据/挂载点回收。 |
| WEB-10 | WebDAV Basic Auth 与 TLS 支持 | P1/互操作 | 90% | Go 已实现 AuthModeBasic（独立随机凭据、恒定时间比较、持久化恢复）和 TLS 自签名证书（RSA 2048 + SHA-256，24h 有效期，TLS 1.2）；Dart 模型/UI/l10n 已接入 Basic Auth 选项、TLS 开关、凭据描述和风险提示；Go 单元测试 57 项全部通过（含 Basic 解析/持久化/拒止 9 项、TLS 证书生成 1 项、OpenOptions 全组合 20 项、Digest nonce 验证 7 项）。分阶段：WEB-10c TLS（80%→90%：含 Basic+TLS Dart 解析测试），WEB-10d 三方客户端认证兼容矩阵验证。 |
| UI-96 | Grid 视图图标半宽问题 | Bug/UI | 90% | 已修复：`_FileGridCard` 中 `Card` 改用 `Positioned.fill` 包裹以填充网格 tile 全部空间，并添加 `margin: EdgeInsets.zero` 移除 Card 默认边距；dart analyze 通过。仍需桌面视觉验收。 |
| UI-97 | 图片浏览器滚轮缩放位置漂移 | Bug/UI | 90% | 已修复：滚轮缩放改为保留当前 focal point，通过提取平移量等比缩放后重建矩阵；dart analyze 通过。仍需桌面实测验收。 | 图片浏览器使用鼠标滚轮缩放时，图片位置会发生漂移，与按钮缩放行为不一致。需修复滚轮缩放时的锚点计算，确保以鼠标位置或视口中心为基准缩放。 |
| WEB-14 | WebDAV CA 证书体系（静态CA签发leaf） | Feature/Go | 90% | Go CA/leaf 证书生成、持久化、导出全部完成；`EnsureTLSConfig` 先确保 CA 再签发 leaf；`ExportCACertPEM`/`ExportTLSCertPEM` 均可用；Go TLS 测试通过。仍需三平台真实 WebDAV 客户端 CA 安装后验证。 |
| WEB-15 | WebDAV CA 证书导出 Dart/UI 接入 | Feature/Dart+UI | 90% | FFI 层 `sec_webdav_export_ca_cert_pem`、Dart binding/native_lib/crypto_service/webdav_service 逐层接入完成；`exportCACertPEM()` 可用于 UI 调用；UI 导出按钮已在 WebDAV 共享配置对话框 TLS 选项中显示。仍需各平台导入指南弹窗实测验收。 |
| WEB-16 | WebDAV CA 证书下载与导入提示 | Feature/UI | 90% | l10n 中英文覆盖平台导入步骤；CA 证书导出后弹窗显示文件路径、安全提示和各平台安装指南（Windows/Linux/macOS）。仍需三平台实测验收。 |
| UX-01 | 防截屏设置文案通用化 | Bug/UX文案 | 90% | 中英文防截屏文案已简化：去除 WDA_EXCLUDEFROMCAPTURE 等技术细节、Windows 版本号；实测 Win10 1607 PrintScreen 已黑屏，文案准确反映现状。仍需桌面测评确认新文案在各平台表述通顺。 |
| WEB-12 | WebDAV TLS/HTTP listener 按会话独立选择 | Bug/Go | 90% | Go Manager 已重构为独立的 `httpState`/`httpsState` listener，每会话按 TLS 选项分配对应 scheme 的 listener；`ensureServerLocked` 按需创建，`stopIfIdleLocked` 分别释放。仍需三平台 TLS/非 TLS 混用实测。 |



## 当前轮 CLI 与 WebDAV 写入

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|
| CLI-02 | CLI passwd 命令 | Feature/CLI | 90% | 已完成：`passwd` 子命令，仅 TTY 交互输入（不暴露任何密码参数），验证当前密码后输入新密码并确认，复用 `sec_fs.ChangeRootPasswordQuick`，go build 通过。不计划增加参数化密码输入。待补自动化测试。 |
| WEB-20 | WebDAV 写入协议（PUT/DELETE/MKCOL/MOVE） | Feature/WebDAV | 70% | Go：`rootResourceProvider` 已实现 Mkdir/Create/RemoveAll/Rename；HTTP handler 按 WritePolicy 路由 PUT/DELETE/MKCOL/MOVE/COPY 到 webdav.Handler；`methodAllowReadWrite` 声明完整 DAV 方法。Dart：`native_lib` / `crypto_service` / `webdav_service` 已透传 `writePolicy` 到 FFI。go vet / dart analyze 通过。待补 Go 写入集成测试与三方客户端 CRUD 互操作验收。 |
| WEB-21 | WebDAV 授权模式（只读/静默编辑/审核修改） | Feature/WebDAV/安全 | 50% | Go：`WritePolicy` 枚举（readOnly/reviewCreate/silent）已定义并在 OpenOptions/Session/HTTP handler/filesystem 中生效。Dart：`WebDavWritePolicy` 枚举、`WebDavOpenedSession`/`WebDavSessionStatus` 已解除 read_only 硬约束并正确解析 write_policy；`native_lib`/`crypto_service`/`webdav_service` 已透传。l10n 中英文 ARB 已添加。待补：UI 设置页 writePolicy 选项控件；reviewCreate 的 Go commitQueue + FFI poll/approve/reject 机制。 |

---

## 当前轮 自动锁定修复与 UI

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|---|
| SL-02 | 自动锁定后打开 root 输入密码时 UI 卡死 | Bug | 60% | 诊断：auto-lock sync FFI 阻塞 event loop。修复：_replaceWithLockedDirectory 提前+Duration.zero 让出渲染帧；_verifyPassword 守卫 30s 超时；debugPrint 追踪；补充 in-process 图片浏览器自动锁定关闭（之前缺 _inProcessImageViewerSessionID 追踪）。待用户实测。 |
| WEB-22 | WebDAV Dart 层 WritePolicy 集成测试 | Test | 0% | Dart 层 Basic Auth 会话创建与列表、writePolicy 字段解析定向 widget 测试。 |
| WEB-23 | WebDAV 设置页 WritePolicy 选项控件 | Feature/UI | 90% | 在 WebDAV 共享配置弹窗中增加 WritePolicy Radio 按钮组（只读/静默编辑/审核修改），使用已就绪的 l10n key。仅 UI 接入；reviewCreate 的完整后台审核机制由 WEB-21 单独跟踪。 |
| WEB-24 | WebDAV Go 写入集成测试 | Test | 0% | 补充 filesystem.go 中 Mkdir/Create/RemoveAll/Rename 的 Go 测试（CRUD + 冲突 + 父目录不存在 + WritePolicy 权限）。 |
| CLI-03 | CLI passwd 自动化测试 | Test/CLI | 0% | 补 passwd 命令的自动化测试。 |

## P0 正确性与数据安全

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| secure root walker 错误语义与资源上限 | 78% | 已实现默认 1024/绝对 4096 个待处理目录上限、正确 stack depth、关闭清理和名称/metadata 错误传播；FFI 与 CLI 均不再以 `HasNext` 吞错误。sec 超宽/超深、真实 FFI 和 CLI 明文 store corruption 回归通过，见 [WALKER_RESOURCE_DESIGN.md](design/WALKER_RESOURCE_DESIGN.md) | 补底层 `ReadDir` 故障注入、取消语义与 FD 上限实测；完成无损分页/外部工作队列设计前，不宣称任意超宽目录可完整扫描 |
| Windows durability 与跨进程锁 | 60% | Windows lock 实现和交叉编译路径存在；文件 Sync 已实现 | 真实 Windows 上验证目录 metadata flush、LockFileEx 竞争、进程退出释放、rename/占用句柄故障 |
| 本地并发符号链接替换防护 | 75% | openRegularFile/createRegularFile 已接入 importFileAtomic/exportFileAtomic (Unix O_NOFOLLOW + Windows CREATE_NEW)；go build/vet 通过 | 补 os.Stat 预检 TOCTOU 消除与攻击进程实测 |

## P1 核心基础设施

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| sec_fs 完整错误传播与损坏数据策略 | 90% | 密码认证、路径约束、key 生命周期、metadata、权限均有测试； `ErrCorruptedEntry` sentinel 从 crypto 经 walker 到 FFI/Dart 全链路贯通并测试 | 确定 corruption tolerance 边界（skip+report vs abort）；真实损坏 root CLI/UI 端到端验收 |
| Transfer V3 平台完整性 | 88% | 原子 temp/backup、marker、取消、convert phase/recovery、真实 kill checkpoint 测试 | Windows 故障测试、walker 上限、源并发修改策略；convert 预恢复必须不掩盖非 convert marker 的 unfinished 策略错误，并在损坏 marker 中保留具体字段原因；明确字节进度/限速是否进入当前版本 |
| CLI 产品命令集 | 88% | create/list/import/export/info/passwd、JSON Lines、安全密码来源、unfinished 处理有真实子进程测试 | passwd 仅 TTY 交互，不计划参数化；补真实 TTY 隐藏输入、Windows 路径与打包后二进制测试 |
| FFI/Dart 完整绑定面 | 92% | root/file/dir、Transfer V3 callback/cancel、per-operation durability options ABI（Go/Dart 全链路完成）、真实动态库互通测试存在；corruptedEntry 错误码已接入 Dart ErrorType 分类 | worker isolate 退出、Windows 动态库实测矩阵 |
| Flutter Transfer UI 闭环 | 90% | HomePage widget 测试覆盖解锁、文件/目录 import 冲突、单文件/批量导出冲突决策、失败恢复和 unfinished rerun；目录导出现在在目标同名时显示冲突对话框并禁止替换，只允许取消或保留两者，避免无语义的目录覆盖。 | 真实桌面 E2E、目录导出保留两者/取消/重开完整链路、错误信息分层和可访问性 |
| 测试矩阵与持续集成 | 76% | Go 多 module、CLI 子进程、FFI C ABI、Dart 真库和 widget 测试已存在 | 固化 Linux CI；增加 Windows/macOS runner、桌面 E2E、故障注入、资源上限和覆盖率基线 |
| 文档真实性与分类 | 80% | 主体中文，设计/审计/历史已分层；本轮重做任务百分比 | 清理 ARCHITECTURE/CLI/FEATURES 的旧 V2 描述和失效命令；增加文档链接检查 |

## P2 产品功能

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| 安全记事本 | 95% | 状态/controller 与 UI 分区已拆分；编辑、加密草稿、剪贴板监视、broker 冲突及远程子窗口均有测试，Linux 已实测原生窗口。主/子窗口打开均传递 16 MiB 文本上限，已知超过上限和未知大小均在解密前拒绝；未知大小使用独立错误文案，主页的记事本和图片独立窗口入口均有错误映射。 | 补三平台桌面键盘/关闭/系统剪贴板 E2E、平台压力测试；流式大文件编辑不属于当前版本范围 |
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
| 第三方工具安全文件交接（WEB-01，P1） | 82% | [THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md](design/THIRD_PARTY_WEBDAV_HANDOFF_DESIGN.md)；Go 已实现只读协议、Bearer/Digest `SHA-256`、重放防护、限定范围、监视快照、root close 撤销、凭据策略和 root 内持久会话；FFI/Dart/CLI 已接选项、状态、恢复和挂载/卸载；Windows Go Redirector 适配已交叉编译 | 编辑协议、冲突控制、常见系统工具认证兼容矩阵/必要的 Basic 兼容模式、Linux davfs 实际挂载、Windows 实机盘符映射、macOS 挂载适配和第三方客户端互操作、CLI 独立 reveal 管理、三平台实机与攻击/异常生命周期测试 |

## P3 发布与平台

| 任务 | 进度 | 当前证据 | 到 100% 还缺什么 |
|---|---:|---|---|
| Windows 产品验收 | 20% | 有交叉编译和部分平台代码 | Windows runner、GUI/CLI/FFI 实机测试、安装包、升级/卸载 |
| macOS 支持 | 0% | 无当前验收证据 | 构建、签名、公证、FFI 和 UI 实测 |
| Linux 安装包 | 15% | 可开发运行 | deb/rpm 或其他发布格式、desktop 集成、干净环境安装测试 |
| 多语言与可访问性 | 55% | `zh`/`en` ARB、语言偏好和主/内容窗口 locale 传递已接入；`tool/audit_i18n_strings.dart` 当前对产品 `lib` 报告 0 候选，`app_en.arb` 无中文值，设置页不再显示过期的“英文仍在迁移”提示。该证据只覆盖源级迁移。 | 补逐页中英文交互/Semantics 基线、键盘导航、读屏、对比度和三平台字号/截断验收 |
| 可配置 config 文件名 | 0% | 当前固定 `_cryption.json` | 评估发现机制、冲突与兼容成本；决定取消或实现 |
| API/开发者/贡献文档 | 30% | 已有设计与使用文档 | Go API reference、构建/测试/贡献流程及链接自动检查 |
| 代码与测试硬编码复查（DEV-01，P3） | 10% | 已有本地化词法审计；尚未系统覆盖测试定位器、硬编码参数和可替换重复值 | 先以只读脚本提取候选及上下文，按“必须保留/应抽取/需人工判断”分类；优先处理 `find` 定位器、重复用户文案、路径、超时、大小限制和协议字符串；只生成安全预览补丁，逐项复核后再替换，不能机械全量改写。 |
| 发布安全审计 | 10% | 有局部安全测试和设计说明 | 威胁模型冻结、依赖审计、模糊测试、发布构建复现、第三方评审 |

## 当前轮防截屏修复

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|---|
| SC-01 | 防截屏选项合并 | P2/安全设置 | 90% | 已实现：移除 Linux 独立选项，合并为单一开关；Windows < 19041 降级使用 WDA_MONITOR（仅防录屏）并有明确文案说明；支持 `SAFE_DISK_NO_ANTI_SCREENSHOT=1` 环境变量强制关闭以恢复；设置页和主界面均使用共享 `AntiScreenshotCountdownDialog`。待三平台桌面实测验收。 |
| SC-02 | 防截屏安全确认倒计时 | P2/安全设置 | 90% | 已实现：`AntiScreenshotCountdownDialog` 含 15 秒倒计时进度条，超时或取消自动恢复关闭；含风险说明文案。待三平台桌面实测验收。 |
| SC-03 | 防截屏首次启动确认 | P2/安全设置 | 90% | 已实现：HomePage 启动时检测 `anti_screenshot_first_confirmed`，未确认则弹窗；确认结果持久化；取消/超时自动关闭防截屏。待三平台桌面实测验收。 |
| SC-04 | Platform 能力检测 | P2/安全设置 | 90% | 已实现：`getAntiScreenshotCapability()` 通过 wmic/ver 检测 Windows build，Linux 直接返回不支持，macOS 标记为支持。检测结果驱动 `_antiScreenshotHint` 显示。待 Windows 实机 build 检测和 macOS 实测验收。 |
| WEB-10a | WebDAV Basic Auth Go 实现 | P1/互操作 | 90% | AuthModeBasic、newAuthLocked、basicAuthorized()、normalizeOpenOptions、authFromPersistent、persistentRecordFromActive 均已实现；go vet/build 通过。仍需 Go 层面 Basic Auth 实际 HTTP 请求测试。 |
| WEB-10b | WebDAV Basic Auth Dart 适配 | P1/互操作 | 90% | WebDavAuthMode 已含 basic 枚举值、wireName；fromNative 两个工厂已解析 basic 模式，credential 字段正确映射为 username+password 不含 token/realm；UI 对话框已含 Basic radio 选项、风险提示和凭据描述；l10n 已生成。仍需 Dart 层 Basic Auth 会话创建与列表定向测试。 |
| WEB-10c | WebDAV TLS 支持 | P1/互操作 | 90% | Go 自签名证书生成（RSA 2048 + SHA-256，24h 有效期）、TLS listener、`webdavURLScheme`、session/persistent 记录 TLS 字段均已完成；TLS 证书生成单元测试已通过。Dart 模型（WebDavOpenedSession/WebDavSessionStatus）、WebDavService.open、CryptoService.openWebDavSession、UI 对话框 TLS 开关、l10n 中英文均已接入。仍需：TLS 持久会话恢复实际验证、三平台桌面实测 TLS 握手与客户端兼容性。 |
| WEB-10d | WebDAV 三方客户端认证兼容矩阵验证 | P2/互操作 | 0% | 按平台验证 rclone/davfs2/Windows WebClient/macOS Finder 的 Bearer/Digest/Basic 兼容性与已知限制。 |

## 当前轮安全锁定修复

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|---|
| SL-01 | 闲置锁定设计修复：只读记事本未自动关闭 | Bug/安全 | 85% | 设计：ContentWindowHostBridge 接收 document.touchActivity 并用 onActivity 回调通知 HomePage；HomePage 通过 DocumentSessionBroker.rootSessionForToken 映射 token→rootSessionID 并 reset idle timer；SecureNotepad (native) 在用户键盘输入时发送 touchActivity；DocumentWindowClient 新增 touchActivity()。_dismissInProcessNotepad 修复：现已正确调用 Navigator.of(context).pop() 关闭进程内记事本。onActivity 回调已接入进程内记事本以重置 TTL。剩余：三平台桌面实测。验收条件：设置闲置超时，所有通过该 root 会话打开的只读记事本（独立窗口）应随 root 锁定一并关闭。 |

## 当前轮自动锁定修复（补充拆分）

| ID | 任务 | 类型 | 当前进度 | 验收条件 |
|---|---|---|---|---|
| SL-01a | 进程内记事本阻断自动锁定修复 | Bug/安全 | 100% | 原 `decision.windowCount != nativeWindowCount` 检查已移除，现使用 disposition 判定（仅 blockedBy* 跳过）。_dismissInProcessNotepad 已修复，锁定前正确弹出进程内记事本路由。验收：闲置超时 + 只读进程内记事本 → root 锁定、记事本路由已弹出。 |
| SL-01b | 进程内记事本活跃时重置 TTL | 功能 | 100% | onActivity 回调已接入进程内 SecureNotepad（传递 _touchCurrentRoot），输入活动时 reset idle timer。验收：编辑进程内记事本 → TTL 重置不触发锁定。 |
| SL-01c | `_lockEligibleRoots` 错误处理审计 | 质量 | 100% | 已区分 StateError（跳过）/FormatException（失败）/通用异常（失败+debugPrint 日志）。 |
| SL-01d | 原生只读记事本 prepareForLock 幂等性确认 | 验证 | 100% | 确认 `_hasChanges`=false 时立即返回 true（SecureNotepadController.prepareForLock line 285），不触发草稿写入循环。 |
