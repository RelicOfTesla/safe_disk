# Safe Disk 文档目录

> 这是文档入口。当前项目进度以代码审计为准，历史报告和设计文档不能直接作为实现完成证明。

## 推荐阅读顺序

1. [代码审计状态](CODE_AUDIT_STATUS.md)
2. [需求确认](REQUIREMENTS.md)
3. [技术架构](ARCHITECTURE.md)
4. [FFI 设计文档](FFI_DESIGN.md)
5. [sec_transfer 设计文档](TRANSFER_DESIGN.md)
6. [CLI 设计文档](CLI_DESIGN.md)
7. [开发路线图](ROADMAP.md)
8. [任务列表](TODO.md)
9. [跨平台验收清单](PLATFORM_ACCEPTANCE.md)
10. [已完成任务](completed/TASKS_COMPLETED.md)

## 当前状态与项目管理

| 文档 | 用途 | 状态 |
|------|------|------|
| [CODE_AUDIT_STATUS.md](CODE_AUDIT_STATUS.md) | 当前代码真实状态 | 当前有效 |
| [REQUIREMENTS.md](REQUIREMENTS.md) | 需求、威胁模型、功能范围 | 当前有效，需结合代码审计 |
| [ROADMAP.md](ROADMAP.md) | 阶段规划 | 统一百分比，只保留未完成阶段 |
| [TODO.md](TODO.md) | 活跃功能任务 | 统一百分比，不包含 100% 项 |
| [PLATFORM_ACCEPTANCE.md](PLATFORM_ACCEPTANCE.md) | 已实现功能的 Windows/macOS/独立环境验收 | 当前有效，不作为实现完成证明 |
| [FEATURES.md](FEATURES.md) | 活跃功能规划 | 统一百分比，不包含 100% 项 |
| [completed/TASKS_COMPLETED.md](completed/TASKS_COMPLETED.md) | 已完成任务 | 仅包含有自动化实际功能证据的 100% 项 |

## 架构与设计

| 文档 | 用途 | 状态 |
|------|------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | 总体架构 | 当前有效，部分目标态已标注 |
| [ENCRYPTION.md](ENCRYPTION.md) | 加密方案 | 当前有效，需后续代码审计校准 |
| [TRANSFER_DESIGN.md](TRANSFER_DESIGN.md) | sec_transfer 批量任务、恢复与原子迁移设计 | 当前有效 |
| [CLI_DESIGN.md](CLI_DESIGN.md) | CLI 命令与底层 sec 配合设计 | 当前有效 |
| [FFI_DESIGN.md](FFI_DESIGN.md) | Flutter 与 Go 的 FFI 边界设计 | 当前有效 |
| [design/MULTI_WINDOW_DESIGN.md](design/MULTI_WINDOW_DESIGN.md) | Flutter 内容多窗口、root lease 与保存冲突设计 | 设计完成，功能未实现 |
| [design/FILE_BROWSER_DESIGN.md](design/FILE_BROWSER_DESIGN.md) | list/grid 内容视图、tree 目录导航与当前目录筛选设计 | 当前有效 |
| [design/ERROR_REPORTING_DESIGN.md](design/ERROR_REPORTING_DESIGN.md) | 错误分层、详细报告开关、脱敏与 Windows FFI bundle 诊断 | 当前有效，Win10 实机验收未完成 |
| [reference/error_handling.md](reference/error_handling.md) | Go 错误处理机制 | 参考文档，需补中文化 |

## 使用说明

| 文档 | 用途 | 状态 |
|------|------|------|
| [CLI.md](CLI.md) | CLI 使用说明 | 当前有效，已降级过度完成声明 |
| [FAQ.md](FAQ.md) | 常见问题 | 可用，但需要按当前 UI 状态复核 |
| [usage/secure_notepad_usage.md](usage/secure_notepad_usage.md) | 安全记事本使用与实现说明 | 当前有效，包含安全声明边界与剩余验收 |

## 专项设计与重构资料

| 文档 | 用途 | 状态 |
|------|------|------|
| [archive/ARCHITECTURE_REFACTOR_PLAN_V2.md](archive/ARCHITECTURE_REFACTOR_PLAN_V2.md) | 架构重构设计历史 | 历史参考 |
| [TODO_REFACTOR.md](TODO_REFACTOR.md) | 活跃重构任务 | 统一百分比，不包含 100% 项 |
| [completed/REFACTOR_COMPLETED.md](completed/REFACTOR_COMPLETED.md) | 已完成重构 | 100% 重构及验收边界 |
| [archive/CRYPTO_PACKAGE_REFACTOR_ANALYSIS.md](archive/CRYPTO_PACKAGE_REFACTOR_ANALYSIS.md) | crypto 包重构分析 | 历史分析 |
| [design/STREAM_V3_DESIGN.md](design/STREAM_V3_DESIGN.md) | Stream V3 格式设计 | 设计文档 |
| [design/STREAM_V3_ROADMAP.md](design/STREAM_V3_ROADMAP.md) | Stream V3 实施路线 | 已按实际代码重审为百分比 |
| [design/FFI_INCREMENTAL_ENCRYPTION.md](design/FFI_INCREMENTAL_ENCRYPTION.md) | 增量加密 FFI 设计 | 设计文档，不是实现证明 |

## 历史报告

| 文档 | 用途 | 状态 |
|------|------|------|
| [archive/P0_STREAMING_DECRYPTION_REPORT.md](archive/P0_STREAMING_DECRYPTION_REPORT.md) | P0 流式解密实施报告 | 历史报告，需代码复核 |
| [archive/P0_TEST_REVIEW_REPORT.md](archive/P0_TEST_REVIEW_REPORT.md) | P0 测试与 review 报告 | 历史报告，需代码复核 |
| [archive/performance_report.md](archive/performance_report.md) | 增量加密性能报告 | 历史报告 |
| [archive/secure_image_viewer_report.md](archive/secure_image_viewer_report.md) | 图片浏览器实施报告 | 历史报告，当前 UI 未完成 |
| [archive/_整理报告_2026-04-02.md](archive/_整理报告_2026-04-02.md) | 早期文档整理记录 | 历史报告 |

## 清理原则

- 当前有效文档必须明确区分“已实现”“部分完成”“设计中”“历史记录”。
- 历史报告保留参考价值，但不能作为当前完成度证据。
- 设计文档可以保留，但标题或开头必须说明是否已经落地。
- 后续如要物理移动文件，应先更新所有相对链接。
