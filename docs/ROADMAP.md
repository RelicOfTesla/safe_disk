# Safe Disk 开发路线图

> 路线图只展示未完成阶段，进度按 [TODO.md](TODO.md) 的统一口径审计。100% 子任务已迁入 [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md)。
>
> 最后审计：2026-07-13。

## 总体状态

| 阶段 | 进度 | 结论 |
|---|---:|---|
| Phase 1：sec_fs 安全基础 | 84% | 核心 root/file/crypto 可用且测试较多；walker 错误语义、损坏策略和符号链接竞态未完成 |
| Phase 2：Transfer V3 / CLI / FFI | 89% | Linux 主链路与跨入口互通较完整；Windows durability、walker 上限和 ABI 收敛未完成 |
| Phase 3：Flutter 文件管理主流程 | 72% | rootID 基础读写、导入导出、progress/cancel 已接；缺真实桌面 E2E 与完整产品交互 |
| Phase 4：编辑器与媒体查看 | 52% | 有实现代码；当前缺自动化实际功能测试，不能按完成处理 |
| Phase 5：性能与增量编辑 | 18% | 大文件单次流式 copy 已有；Stream V3、UI 虚拟化和资源预算主要仍是设计 |
| Phase 6：系统集成与发布 | 8% | 尚无多平台安装、升级和发布验收闭环 |

## Phase 1：sec_fs 安全基础

目标：形成可独立验证的加密 root、文件访问、路径与密钥生命周期基础。

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| walker 正确性与资源上限 | 55% | 损坏 entry 错误传播、超宽/超深资源测试 |
| 本地竞态防护 | 35% | dirfd/openat 或等价实现与攻击测试 |

退出条件：

- walker 不静默吞掉不可恢复错误。
- sec/plain walker 都有明确工作集和 FD 上限。
- 损坏 root、取消、并发替换有自动化实际测试。

## Phase 2：Transfer V3 / CLI / FFI

目标：同一格式与操作模型贯通 Go、CLI、C ABI 和 Dart。

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| Windows durability/lock/rename | 60% | Windows runner 实际故障测试 |
| CLI info/passwd 与发行二进制 | 45% | 明确 passwd 产品策略；实现 info；真实 TTY/Windows 测试 |
| FFI ABI 单一来源与 options | 65% | 生成 header/binding、ABI diff、per-operation options |

退出条件：

- Linux/Windows 上同一实际功能矩阵通过。
- CLI 创建 root 与 Dart 创建 root 双向互通。
- 运行时取消、marker、convert recovery、加密名称和错误码跨层一致。

## Phase 3：Flutter 文件管理主流程

目标：真实桌面应用可创建、打开、浏览、导入、导出和恢复未完成操作。

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| root 解锁与基础目录列表 | 82% | 正确密码真实桌面 E2E、重启重开和损坏配置 |
| 文件/目录导入与目录导出 | 87% | 真实选择器、并发冲突、取消、失败重试、重启 marker E2E |
| 错误展示和可复制诊断 | 70% | 稳定错误码映射、可访问性和桌面测试 |
| 导航、排序、过滤、批量操作 | 30% | 明确 MVP 范围并补 service/UI 测试 |
| 自动锁定与 session 生命周期 | 20% | 前后台、超时、root close 和 UI 状态测试 |

退出条件：

- 不使用 mock service 的桌面自动化覆盖主用户旅程。
- 错误密码、正确密码、空目录、加密名称和 unfinished operation 均在真实动态库下可回归。

## Phase 4：编辑器与媒体查看

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| 安全记事本 | 82% | 真实桌面键盘/关闭 E2E、大文件策略、临时文件审计和可验证内存边界 |
| 图片浏览器 | 50% | 多格式、翻页、清理、大图资源实测 |
| 内存清理声明边界 | 65% | 区分可控 byte buffer 与 VM/cipher 内部副本，补生命周期测试 |

退出条件：

- 两项产品功能均有自动化实际功能测试，而非仅实现代码或历史报告。
- 安全声明只覆盖可观测、可验证的内存与临时文件边界。

## Phase 5：性能与增量编辑

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| 大文件顺序流式 import/export | 80% | 资源基线、限速/字节进度策略、跨平台测试 |
| 超大目录扫描与 UI 虚拟化 | 20% | walker 硬上限、分页 API、10 万 entry 测试 |
| Stream V3 随机增量编辑 | 15% | 格式与完整性设计评审，随后 sec/FFI/Dart/UI 实现 |

## Phase 6：系统集成与发布

| 工作包 | 进度 | 下一验收点 |
|---|---:|---|
| Linux 安装与桌面集成 | 15% | 干净系统安装/卸载测试 |
| Windows 产品化 | 20% | 实机 CI、安装包、文件锁与目录 durability |
| macOS 产品化 | 0% | 构建、签名、公证、运行测试 |
| 主界面右键菜单 | 97% | 剪切/移动、批量与系统剪贴板互通；三平台真实鼠标 E2E、键盘菜单键、焦点和可访问性 |
| 剪贴板与拖放 | 5% | 威胁边界、分平台实现、桌面自动化 |
| 发布安全审计 | 10% | 依赖/模糊/复现构建/第三方审计 |

## 当前执行顺序

1. 完成本批 Transfer 流式消费验证并提交。
2. 修复 secure walker 静默错误与待处理目录上限。
3. 建立真实 Flutter 桌面主流程 E2E，优先锁定“正确密码可见目录内容”。
4. 收敛 FFI ABI 与构建入口。
5. 再进入 Stream V3 和非 MVP 产品功能。
