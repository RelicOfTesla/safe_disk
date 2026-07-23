# 第三方工具 WebDAV 文件交接设计

> 状态：已完成 Go 只读 loopback、Bearer/Digest（SHA-256）会话鉴权、`x/net/webdav` 协议适配、FFI/Dart/CLI 鉴权与挂载控制、凭据显示策略和持久会话的代码链路。Flutter 的共享配置已合并为单一配置框；Linux 已补 davfs 请求形状和标准 DAV 能力声明测试，但真实系统挂载仍未验收；Windows 已接入 Go WebDAV Redirector 适配但未做 Windows 实机验收。编辑模式、Basic 兼容模式、macOS 自动挂载和完整第三方互操作仍未完成。

## 1. 目标

让用户把已解锁 root 中**明确选择的文件或目录**临时暴露给第三方工具。

- Safe Disk 不写明文临时文件。
- 默认只读；用户可明确允许编辑。
- 可选使用系统 WebDAV 挂载，让只接受文件路径的工具访问。
- 主界面能看到当前暴露范围、挂载状态和最近活动，并可随时撤销。
- CLI 能以相同安全边界启动和撤销临时只读会话，供脚本或无界面环境使用。

当前实现边界：Go 原生层提供只读 loopback 会话、每会话 Bearer 或 Digest 凭据、`x/net/webdav`
协议 handler、限定子树、请求监视和 root 关闭撤销；`ffi_sec_fs` 提供 Bearer 兼容 ABI、带
`auth_mode` 的新 ABI 以及 Go-owned mount/unmount ABI。Flutter 已接入鉴权选择、一次性凭据展示、状态列表、挂载和撤销；CLI 已提供
前台 `webdav serve`、JSON Lines 生命周期事件和 `--auth`、`--credential-visibility`、
`--session-lifetime`、`--port`。Linux 下 Go 已接入 Digest/davfs 挂载适配，但真实挂载和卸载尚未验收；Windows 已接入 Digest/WebDAV Redirector 适配，但真实盘符映射尚未验收。编辑会话和 macOS 自动挂载仍未实现，
因此当前切片仍不是完整的编辑型 WebDAV 交接功能。

实现分层约束：loopback HTTP 服务、系统磁盘挂载/卸载、平台命令调用和挂载生命周期全部由
Go 原生层负责。Dart 只通过 FFI 请求操作并展示结果，不直接启动 WebDAV server、不拼接平台
挂载命令，也不维护挂载点状态。CLI 直接调用同一个 Go 会话管理器和平台适配接口，不通过 FFI，
也不得自行起第二套 HTTP server 或调用平台挂载命令。平台适配必须提供统一的
`mount/unmount/status` 接口，失败时返回稳定错误码，并在 root 关闭、会话撤销和应用退出时由 Go
负责卸载或报告未卸载状态。

会话状态同样以 Go 为唯一事实来源。Go 管理会话范围、只读/编辑权限、鉴权凭据、最近访问时间、
活跃请求数、撤销和 root 关闭回收；Dart 只能调用 `open/list/revoke` 并渲染返回快照，不能以
本地列表决定会话是否有效、权限是否存在或挂载是否成功。`open` 只可一次性返回与所选鉴权方式
对应的凭据供用户交给第三方；后续 `list/status` 不得返回 token、密码、摘要中间值或 nonce，也不
记录文件内容或请求体。

这不是“第三方工具仍然安全”的承诺。第三方工具可能自行缓存或导出明文，用户必须只向可信工具暴露必要范围。

## 2. 最小模型

每次“暴露”创建一个临时会话：

```text
已解锁 root
  -> WebDAV 会话
  -> 选中的文件或目录
  -> 第三方工具 / 可选系统挂载
```

临时会话只在 Safe Disk 运行且 root 仍已解锁时有效。关闭会话、锁定 root、结束 root 会话或应用退出后，
临时 WebDAV 访问立即失效；持久会话只保存恢复材料，服务仍会在 root 未解锁时停止，重新解锁后才恢复。

WebDAV 服务只监听本机 loopback，并使用随机会话地址。密码、内容密钥和真实加密路径不交给第三方。

## 3. 鉴权机制

### 3.1 当前状态与支持范围

当前代码支持每会话独立的 **Bearer** 或 **Digest** 凭据。协议、Go FFI、CLI 和 Dart 模型/UI
已有定向回归；真实第三方 Digest 客户端互操作仍未验收。

完成后的会话必须显式选择一种鉴权机制，而不是同时接受多种机制或在失败后静默降级：

| `auth_mode` | 状态 | 凭据与用途 |
| --- | --- | --- |
| `bearer` | 当前已实现 | 随机会话 token，通过 `Authorization: Bearer` 传递；适用于脚本和支持 Bearer 的客户端，不作为常见系统挂载的默认认证。 |
| `digest` | 已实现，互操作待验收 | RFC 7616 `SHA-256` + `qop=auth`，使用每会话随机用户名、密码、realm 和 nonce；用于需要 Digest 的 WebDAV 客户端。 |
| `basic` | 兼容性候选，当前未实现 | 仅为不支持 Digest 的常见系统工具评估；必须是显式高风险选项，使用独立随机密码，不能复用 root 密码，也不能静默从 Digest 降级。 |

不默认启用 Basic：本服务虽然只监听 loopback，但 Basic 会以可逆形式传递密码，其他本机进程仍可能
观察请求。若互操作实测证明 Windows/macOS/Linux 常见系统工具确实需要 Basic，必须新增显式的
兼容模式、风险确认、独立随机凭据和最小生命周期；不能静默从 Digest 降级。Digest `MD5`、
`MD5-sess` 或未定义的算法回退始终拒绝；root 密码、内容密钥和已有密码校验材料绝不能复用为任何
WebDAV 凭据。

### 3.1.1 常见系统工具兼容策略

- 系统挂载不使用 Bearer 作为默认方案；Linux davfs 和 Windows WebClient 当前只允许 Go 适配器尝试 Digest，优先验证 Digest `SHA-256`，再按平台客户端矩阵评估 Basic
  兼容模式。认证方式是否“已实现”与是否“被某平台客户端实测支持”分开记录。
- Linux `davfs2`、Windows WebClient、macOS Finder/系统挂载和常见编辑器分别建立最小互操作矩阵：
  连接、目录枚举、读取、断开、撤销、重启恢复和凭据失败都要独立验证。
- 客户端不支持当前强度的 Digest 且未明确开启 Basic 兼容模式时，返回“不支持该认证方式”，不改用
  Bearer 或明文临时目录伪装成功。
- Basic 兼容模式必须绑定 loopback、只读会话和短生命周期；在持久会话下默认禁用，除非用户再次确认
  “本机进程可观察可逆传输的认证信息”。

### 3.2 Digest 协议约束

- 每个 Digest 会话生成独立的随机用户名、密码、realm 和服务器密钥；这些值不得跨会话复用。
- 仅接受 `algorithm=SHA-256` 与 `qop=auth`。缺失、重复或不支持的关键参数一律拒绝。
- nonce 必须由会话 ID、签发时间和服务器密钥构成可验证的非透明值，并设置短期失效时间；失效 nonce
  返回带 `stale=true` 的新 challenge。
- 服务器按 `(session_id, username, nonce, cnonce)` 跟踪递增 `nc`，拒绝重放、倒退或跨会话使用的
  请求；比较认证结果使用恒定时间比较。
- 认证通过后才进入现有的会话范围、只读权限和访问监视路径。Bearer 与 Digest 必须共享这条授权后
  路径，避免出现不同机制可访问不同范围的分叉。
- 状态和审计只可记录 `auth_mode` 与认证结果。不得保存或返回 token、用户名密码、HA1、nonce、
  `cnonce`、`nc` 或完整 `Authorization` 头。

### 3.3 凭据交付与 ABI 演进

`open` 的秘密默认只显示一次：Bearer 返回 URL 与 token；Digest 返回 URL、用户名、密码和 realm。
两种模式均不得把 root 密码交给第三方，也不得在会话列表、日志、错误、测试快照或崩溃转储中重复
输出秘密。

凭据显示策略是**会话创建时捕获的会话属性**，与服务是否持久化无关：

| `credential_visibility` | 语义 |
| --- | --- |
| `once` | 默认。`open` 成功时显示一次，关闭凭据窗口后不再从列表恢复；需要再次交付时撤销并创建新会话。 |
| `persistent` | 用户明确选择后，允许在会话仍有效时通过 Go 的受保护 `reveal` 操作再次显示原凭据；不会把秘密放进 `list/status`，也不会写日志。应显示持续风险提示。 |

该属性只影响新建会话。修改默认值不改变已存在会话的显示策略，也不轮换、撤销或改变已经发出的
链接；要改变旧链接必须显式撤销并重新创建。应用退出后，当前非持久会话都会失效，持久显示也不能
把已经结束的会话凭据恢复出来。

现有 `sec_webdav_open` 语义保持为 Bearer，不能静默改变参数含义。Digest 通过带 options 的
`sec_webdav_open_with_options` ABI 传入，由 Go 解析唯一的 `auth_mode` 枚举；未知、重复或缺失的
选项按闭合失败处理。状态 ABI 在完成后增加非秘密的 `auth_mode` 字段。Dart 只能透传 Go 定义的选项
并渲染快照，不能生成 Digest challenge、保存凭据或自行实现回退逻辑。

GUI 已显示鉴权方式、凭据显示方式和会话保留方式选择；CLI 以 `--auth=bearer|digest`、
`--credential-visibility=once|persistent`、`--session-lifetime=ephemeral|persistent` 显式传给 Go，默认值保持临时、一次性和 `bearer`；
未来兼容模式再增加 `basic`，不得复用现有 Digest ABI 的默认语义。真实客户端互操作完成前，
不把任何认证方式标记为跨平台兼容。

## 4. 协议引擎与安全适配层

### 4.1 选型结论

协议处理已迁移到 Go 官方扩展包
[`golang.org/x/net/webdav`](https://pkg.go.dev/golang.org/x/net/webdav)。它提供 WebDAV HTTP
handler、`FileSystem`、`LockSystem` 和标准 DAV 方法处理，可减少自行维护 XML、条件请求、锁和
状态码的代码。当前只读阶段已使用该依赖；编辑和更复杂 LOCK 语义仍需单独设计，不能因使用协议库而宣称编辑已完成。

不采用直接映射本机目录的 filesystem，也不把权限交给库的默认目录实现。协议库只负责 HTTP/WebDAV
语义，root 范围、加密名称、权限、鉴权、监视、撤销和生命周期仍由 Safe Disk 的 Go 层负责。

### 4.2 中间层结构

每个 WebDAV 会话创建一个绑定单一 root 和暴露子树的 `SecureWebDAVFS`，作为协议 handler 的
`FileSystem`；它不是临时明文目录，也不暴露真实加密路径：

```text
loopback HTTP server
  -> session router：URL、root、暴露范围、撤销
  -> auth middleware：Bearer / Digest
  -> monitor middleware：认证成功后的访问统计与审计
  -> WebDAV handler：标准 HTTP/DAV 语义
  -> SecureWebDAVFS：路径边界、只读/编辑权限、sec 操作
```

`SecureWebDAVFS` 必须满足：

- 所有路径先按 WebDAV 的 `/` 规则规范化，再映射为 root 内相对路径；拒绝 `..`、绝对路径、跨 root
  和超出暴露子树的访问。
- `Stat`、目录枚举和文件读取调用已打开 root 的 sec 接口，不调用 `os.Open` 读取明文路径。
- 只读会话在 `OpenFile` 的写标志、`Mkdir`、`RemoveAll`、`Rename` 等入口拒绝写操作，并统一返回
  稳定的 WebDAV 状态；拒绝请求不能触碰底层数据。
- 编辑会话也只能调用现有加密文件/目录操作、冲突检测和加密名称逻辑；不得因为协议库需要
  `io/fs` 或本机文件接口而绕过 sec 层。
- root 关闭、会话撤销或应用退出后，adapter 和 handler 都必须失效；不能仅依赖 HTTP server
  仍在运行来判断会话有效。

`LockSystem` 同样由 Go 提供。只读阶段可以明确拒绝 `LOCK`；编辑阶段再根据外部编辑冲突设计实现
锁，并与安全记事本的草稿/保存冲突策略统一。不能直接使用无范围约束的内存锁就宣称已经解决跨进程
或跨会话编辑冲突。

### 4.3 鉴权与监视的调用顺序

鉴权 middleware 必须位于 WebDAV handler 之前。只有认证通过且会话仍有效，才允许进入
`SecureWebDAVFS`；监视层在同一条成功授权路径上更新最近访问、活跃请求和可选审计。Bearer 与
Digest 共享这条路径，避免某种鉴权绕过范围检查或产生不同的监视结果。

### 4.4 迁移门槛

引入协议库不是单纯替换 handler。实现前必须先以黑盒回归固定当前行为，再逐项切换：

1. 现有 `OPTIONS/GET/HEAD/PROPFIND`、Bearer、子树隔离、撤销和 token-free 状态测试继续通过。
2. `SecureWebDAVFS` 通过越界、符号链接语义、只读写拒绝、加密文件名和 root close 测试。
3. 比较现有实现和协议库对 `Depth`、URL 前缀、错误状态和目录 XML 的差异；差异必须有明确设计，
   不能以“客户端刚好能用”作为兼容依据。
4. Digest 实现与协议 handler 集成后，再验证 `SHA-256`、nonce 失效、重放拒绝和实际客户端互操作。
5. 以上通过后才移除旧的自定义协议分支；FFI、Dart 和 CLI 的会话模型不随协议库改变。

## 5. 暴露范围与权限

支持两种范围：

- 文件：仅选择的一个文件。
- 目录：选择的目录及其子项，不包含父目录和同级目录。

支持两种权限：

| 权限 | 行为 |
| --- | --- |
| 只读 | 可查看目录、读取已暴露文件。 |
| 编辑 | 可读取、修改、创建、删除、重命名或移动已暴露范围内的文件和目录。 |

创建、删除、重命名和移动必须满足：

- 创建、删除和目标路径都在已暴露目录树内。
- 移动和重命名只允许在同一已暴露目录树、同一 root 内完成。
- 禁止通过 WebDAV 跨 root 移动，也禁止移动到未暴露的父目录或同级目录。
- 目标重名时沿用现有“取消、保留两者、替换”策略，不静默覆盖。

目录暴露允许第三方在该目录树内完成正常文件管理；文件暴露仅允许操作该文件本身，不能借此创建同级条目。

默认使用只读权限。启用编辑时，创建会话前明确提示“第三方工具将获得明文编辑能力”。

## 6. 编辑行为

第三方保存、创建、删除、重命名或移动时，Safe Disk 直接通过现有加密文件与目录操作能力更新对应逻辑条目，不生成明文中转文件。

为避免覆盖内部编辑：

- 同一文件已有安全记事本等未保存编辑时，拒绝创建外部编辑会话。
- 外部修改、删除、重命名或移动前检查相关文件和目录版本；版本已变化时拒绝操作，不静默覆盖。
- root 关闭时，若存在活跃外部编辑会话，要求用户先撤销会话。

首版不做复杂的外部变更审阅、版本合并或断点恢复；发生冲突时由用户重新加载后再操作。

## 7. 可选系统挂载

默认只提供 WebDAV 地址，适合能直接打开 WebDAV URL 的工具。

用户可请求 Go 原生层执行平台 WebDAV 挂载，以支持只接受本地路径的工具。Linux 使用
`mount.davfs`，Windows 使用 WebDAV Redirector/`net.exe use` 映射空闲盘符；Flutter 通过
`mount/unmount` FFI 请求 Go 执行，Dart 不拼接平台命令。该能力是可选项：

- 挂载前提示系统和第三方工具可能缓存明文。
- 平台没有可靠挂载方式时由 Go 返回“不支持”，不退化为普通明文临时目录。
- 关闭会话时由 Go 请求卸载；若卸载失败，FFI 返回明确状态，界面保留警告和重试入口。
- 挂载不是额外的安全隔离，同一系统用户下其他进程可能访问挂载点。
- Windows 映射使用 `\\127.0.0.1@port\DavWWWRoot\webdav\session-id` 形式的 loopback UNC 路径，密码通过
  `net.exe use` 的标准输入传递，不放进命令行；若 WebClient 未启用、盘符不足或认证不兼容，Go 必须失败并清理已建立的映射。
- 会话列表中的系统挂载路径是普通系统路径，可选择、复制到系统剪贴板；这不是 Safe Disk 内部文件剪贴板，也不复制凭据。

### 7.1 会话持久化模式

默认会话仍是临时模式：应用退出、root 锁定或会话撤销后，旧地址立即失效。为满足需要固定挂载
地址的系统工具，会话创建时可选 `persistent` 模式；当前 Go、FFI、Dart 和 CLI 已实现保存与恢复，
跨平台客户端和桌面异常生命周期仍待验收。

持久模式的约束：

- 只对新建会话生效。修改默认设置不改变已有链接、端口、会话 ID、认证方式、凭据显示策略或暴露范围；
  旧链接必须通过显式撤销/轮换处理。
- 持久化 `port` 和高熵 `session_id`，重启后由 Go 在 root 成功解锁且用户明确启用服务时恢复监听；
  未解锁时不得启动 WebDAV 服务。端口被占用时必须失败并提示，不能偷偷换端口破坏已有链接。
- 持久化材料由 Go 写入 root 内部的加密文件 `.safe_disk.webdav.sessions.json`，该文件被默认 walker
  隐藏。记录包括版本、root 绑定、暴露相对路径、认证方式、端口、session ID 和恢复所需的会话凭据；
  Digest 只保存会话随机密钥，不保存明文 root 密码、明文内容、完整 Authorization、HA1 或 nonce。
  root 解锁后重新验证暴露路径和认证材料，记录损坏会以 root 打开 warning 返回。
- 只监听 loopback；持久端口不等于对外网开放，也不等于系统级权限隔离。挂载点、客户端缓存和本机其他
  进程仍可能暴露明文。
- 创建持久会话前必须显示高风险确认：以后每次满足恢复条件时，同一个地址都可能重新提供该范围；
  任何拿到长期凭据的本机工具都可能持续访问。默认建议使用临时模式和 `credential_visibility=once`。
- 持久模式已支持启用、root 重新解锁恢复、状态查看和显式撤销；暂停、凭据轮换和恢复失败后的 UI
  处理仍需补齐，不能只依赖“应用启动时自动恢复”而让用户不知道哪些外部链接正在生效。

建议的创建参数为 `credential_visibility=once|persistent` 与
`session_lifetime=ephemeral|persistent`。两者必须独立保存和展示：前者控制凭据是否可再次显示，后者
控制地址与会话是否跨重启恢复；任何一个开关变化都只影响新建会话。

## 全局开关

设置中的“允许 WebDAV 共享”是本机持久化的安全开关，默认开启以保持既有行为。关闭后：

- 主页不显示 WebDAV 会话入口，文件菜单不能新建共享；
- 当前已打开 root 的 WebDAV 会话会被逐个撤销，正在进行的系统挂载请求会收到取消请求；
- 后续解锁 root 时不会保留或恢复 WebDAV 会话；
- 再次开启只恢复创建共享的能力，不恢复已经撤销的会话。

该开关由 Dart 设置页保存，由 Go 会话管理器执行撤销；Go/FFI 仍是会话状态的最终来源。

## 系统挂载取消

系统挂载不再要求 Dart 同步等待系统命令。Go 暴露开始、轮询和取消操作入口，Dart 只保存不透明的操作 ID：

1. `sec_webdav_mount_start` 或 `sec_webdav_unmount_start` 创建带 30 秒上限的 Go 操作；
2. `sec_webdav_operation_poll` 返回 `running`、`completed`、`cancelled` 或 `failed`；
3. `sec_webdav_operation_cancel` 取消 Go context，使 Linux `mount/umount` 和 Windows `net.exe` 的子进程收到取消信号；
4. Linux 临时配置、凭据文件和挂载目录由平台挂载对象统一清理；Windows 盘符由 Go 统一回收；
5. 取消与命令成功的竞态由 Go 以真实挂载状态为准，必要时执行补偿卸载，不向 UI 报告虚假的成功。

取消后 UI 必须重新 list 会话，不能仅依据本地按钮状态判断是否已卸载。

## 8. 状态与日志

主界面提供“外部交接”列表，每个会话显示：

- 暴露的文件或目录名称。
- 只读或编辑权限。
- WebDAV 是否运行、是否已挂载。
- 最近访问时间和当前是否有请求。
- 撤销按钮。

完成多鉴权后，状态 ABI 至少提供 `id`、显示名称、暴露路径、URL、只读权限、`auth_mode`、
`credential_visibility`、`session_lifetime`、端口、最近访问时间和活跃请求数。
所有字段由 Go 在认证成功的请求路径上更新；Dart 可以短暂缓存快照用于渲染，但每次打开列表、
创建、撤销或用户显式刷新后必须重新请求 Go，不能从缓存恢复 token 或会话；首期不在 Dart
做轮询或本地访问计数。

访问日志默认关闭。用户开启后，只在内存中显示最近操作时间、读写类型、结果和字节数；不记录 token、密码、文件内容或请求体。关闭会话即清除日志。

“最近活跃”只表示收到 WebDAV 请求，不能表示第三方窗口仍在前台或用户一定正在编辑。

## 9. 主界面流程

1. 用户在文件或目录菜单选择“向第三方工具暴露”。
2. 选择只读或编辑；多鉴权完成后再选择 Bearer 或 Digest，并确认第三方明文风险。
3. Safe Disk 创建会话，按鉴权方式仅一次显示 WebDAV 地址和凭据；CLI 或 Flutter 可额外请求系统挂载。
4. 用户在会话卡片查看最近活动、打开挂载位置或撤销会话。
5. 使用结束后用户撤销；锁定或关闭 root 时系统自动撤销。

## 10. CLI 流程

当前 CLI 提供前台服务命令：

```bash
safe-disk webdav serve --path /abs/encrypted/root/or/selected-item
safe-disk webdav serve --path /abs/encrypted/root/or/selected-item --mount
safe-disk webdav serve --path /abs/encrypted/root/or/selected-item --auth=digest
safe-disk webdav serve --path /abs/encrypted/root/or/selected-item --auth=digest --credential-visibility=persistent --session-lifetime=persistent --port=0
safe-disk webdav serve --path /abs/encrypted/root/or/selected-item --json
```

`--path` 遵循 CLI 的绝对路径和统一 root 打开规则。若路径是文件，仅暴露该文件；若是目录，
仅暴露该目录树。密码来源、未完成 operation 的处理和 root 打开错误必须复用普通 CLI 的统一
helper，不能另建弱化路径。

命令必须保持前台运行：启动成功后将会话地址、只读状态、鉴权方式和对应访问凭据输出一次，并继续报告运行、
挂载和撤销状态；收到 `Ctrl-C`、正常退出或 root 打开失败时，Go 必须先撤销会话并尝试卸载。
地址和访问凭据都是敏感能力信息：不得写入日志或 stderr；人类模式只在用户终端显示，`--json`
模式仅向 stdout 输出结构化事件，供明确调用它的进程读取。Bearer 事件仅含 token；Digest 事件仅含
用户名、密码和 realm；两者不得混合输出。

当前 CLI 启动时会读取同一 root 内的持久 WebDAV 记录并恢复；退出时只结束当前进程内会话，持久记录
仍保留。CLI 仍不定义独立的 `list`、`close`、`mount` 或 `unmount` 子命令，也不允许 CLI 连接或接管 GUI
进程创建的会话。当前会话管理器是进程内对象，短命令退出后服务会随之失效；若未来需要跨进程
管理，必须先设计带本地认证的常驻 Go daemon/IPC，不能假定另一次 CLI 调用能看到前一进程的内存。

`--mount` 仅请求 Go 平台适配层挂载。平台不支持或挂载失败时返回稳定错误，不得退化为明文临时
目录。当前固定只读，不提供 `--edit`；编辑协议、冲突控制和跨平台验收完成前不得扩大权限。

## 11. 验收条件

- Safe Disk 交接过程不在 `/tmp`、应用缓存或 root 相邻目录写入明文文件。
- 第三方只能访问用户明确暴露的文件/目录，不能枚举整个 root。
- 只读会话不能写入、创建、删除、重命名或移动；编辑会话不能越权操作未暴露文件。
- 创建、删除和重命名/移动不能越出已暴露目录树，不能跨 root。
- 撤销、锁定 root 或关闭应用后，旧地址和挂载访问均失败。
- 内部编辑与外部编辑冲突时不静默覆盖。
- Bearer 会话仅接受正确 token；Digest 会话仅接受正确的 `SHA-256` + `qop=auth` challenge 响应。
  缺失/错误凭据、MD5 或其他弱算法、nonce 过期、nonce-count 重放、跨会话凭据、越界路径和写请求均失败。
- CLI `webdav serve` 通过真实子进程启动后，可使用所选机制的一次性输出凭据读取限定范围；状态、
  日志、错误和会话列表不泄露任一机制的秘密。
- CLI 收到 `Ctrl-C` 或启动后异常退出时，旧地址立即失效；若指定 `--mount`，Go 会尝试卸载并
  将失败以稳定状态报告。
- Linux、Windows、macOS 分别验证 Go WebDAV 访问、撤销和可选挂载的实际行为，并以各平台常用
  WebDAV 客户端验证 Digest `SHA-256` 互操作；当前 Linux/Windows 只有请求形状测试和 Windows
  交叉编译证据，未验证的平台不宣称支持自动挂载或 Digest 兼容。
