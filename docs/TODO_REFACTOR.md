# Safe Disk 活跃重构任务

> 只记录未达到 100% 的重构。已验收重构见 [completed/REFACTOR_COMPLETED.md](completed/REFACTOR_COMPLETED.md)。
>
> 百分比规则与 [TODO.md](TODO.md) 相同：没有自动化实际功能测试，最高 90%。

## P0 基础设施

| 重构任务 | 进度 | 当前状态 | 验收缺口 |
|---|---:|---|---|
| secure root walker 工作集重构 | 55% | 每批读取 100 entries，但同层待处理目录可无限累计 | 设计受控 DFS/句柄预算；超宽、超深、取消、错误传播和 FD 上限测试 |
| PlainFS walker 流式化 | 30% | 当前 plainDirWalker 初始化时递归收集全部 entries | 改为流式 walker，统一 sec/plain 语义并补大目录资源测试 |
| walker 错误传播统一 | 35% | 部分 entry 解密或 info 错误仍被跳过 | 明确 ignore 与 corruption 的边界；错误必须可观测；补损坏 backing tree 实测 |
| Transfer 进度模型收敛 | 70% | 文件数进度稳定，源在两遍间变化时允许 done/total 不同 | 定义扫描阶段、未知/变化 total、字节级进度兼容策略并覆盖 CLI/FFI/Dart |

## P1 边界与构建

| 重构任务 | 进度 | 当前状态 | 验收缺口 |
|---|---:|---|---|
| FFI ABI 单一来源 | 65% | C header、Go export、Dart binding 可工作，但存在多份生成/复制头文件 | 建立生成命令和 ABI diff 检查，删除重复源，Linux/Windows 构建实测 |
| Flutter service/rootID 模型收敛 | 60% | 新 rootID API 与旧绝对虚拟路径适配并存 | 移除页面层旧路径假设，统一 error/result，真实桌面 E2E |
| build/run 脚本收敛 | 45% | 当前有 Makefile、多个 shell 脚本和备份脚本并存 | 定义唯一开发/测试/发布入口，干净环境自动化验证 |
| 文档旧 V2/task 叙述清理 | 75% | Transfer 主设计已切 V3，部分 ARCHITECTURE/CLAUDE/历史清单仍描述持久 task | 活跃文档只保留 V3，历史内容移 archive，链接检查通过 |
| 错误类型与跨层映射 | 50% | Go/FFI/Dart 各层已有错误处理，但仍依赖字符串判断 | 建立稳定错误码、FFI JSON schema、UI 文案映射和跨层测试 |

## P2 后续架构

| 重构任务 | 进度 | 当前状态 | 验收缺口 |
|---|---:|---|---|
| Stream V3 架构重做 | 15% | 仅设计，旧增量接口不在活跃 ABI | 完成格式/完整性/原子提交设计评审，再实施 sec 到 UI 全链路 |
| UI 状态管理拆分 | 55% | HomeShell 已从 HomePage 抽离，记事本状态/编辑区/查找区已拆分；HomePage 仍承担较多 root、transfer、progress 和错误流程 | 继续拆 transfer/use-case 与 root session 状态，保持 widget 行为并增加真实 E2E |
| 可测试平台抽象 | 25% | Linux 本地测试较强，Windows/macOS 依赖条件编译 | 文件系统故障、锁、durability、选择器和桌面 runner 可注入且有平台实测 |

## 明确废弃，不再作为待办

- TaskManager 持久化、ActionTask、ImportDirectoryAsync/ExportDirectoryAsync、逐文件 task 进度和断点续传属于已废弃 V1/V2 方向。
- import/export 仅保留 operation marker 状态感知，后续全量重跑；convert 仅按 phase 处理安全 rename 窗口。
- 废弃决策及删除公共接口的证据记录在 [completed/REFACTOR_COMPLETED.md](completed/REFACTOR_COMPLETED.md)，不得重新放回活跃任务。
