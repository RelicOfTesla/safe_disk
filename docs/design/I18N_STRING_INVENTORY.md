# 用户可见文案清点与迁移规则

## 目的

本清单约束 Safe Disk 的多语言迁移范围和验收方式。它只依据当前代码，不把“已有语言选择器”或“部分页面能显示英文”误写为完整多语言。

截至 2026-07-22，在 `lib/pages`、`lib/widgets`、`lib/windows` 中以 `Text(`、`Tooltip(`、`Semantics(` 为入口的候选构造点共有 **269** 个，分布于 **27** 个产品 UI 文件：

| 区域 | 候选点 | 文件数 | 说明 |
| --- | ---: | ---: | --- |
| `lib/pages` | 88 | 3 | 主页、设置和通用对话框 |
| `lib/widgets` | 177 | 23 | 浏览、菜单、传输、错误、根目录操作、记事本和图片 |
| `lib/windows` | 4 | 1 | 记事本子窗口壳 |

这是筛选入口，不是“269 条均应翻译”的断言。每个候选点必须在迁移时分类为用户文案、动态数据、开发/测试文本或不可翻译的协议/数据；只有用户文案进入 ARB。

## 文件范围

第一轮需要逐文件审核的产品 UI 文件如下。`lib/testing`、纯 controller/service、日志和测试夹具不属于本清单，但若它们创建面向用户的独立窗口，仍必须自行提供 locale。

| 模块 | 文件 | 当前迁移状态 |
| --- | --- | --- |
| 应用壳与入口 | `pages/home_page.dart`、`widgets/home_shell.dart`、`widgets/welcome_screen.dart`、`widgets/native_library_startup_error.dart` | 原生库与内容窗口启动错误、欢迎页、主壳、侧边栏、导入入口和解锁提示已完成；主页中的文件/目录操作仍随下一批迁移 |
| 设置 | `pages/settings_page.dart` | 已完成，全部用户文案和时长格式经 ARB 呈现；英文提示仅说明其他模块仍未完成 |
| 通用对话框与错误 | `pages/dialogs.dart`、`widgets/error_dialog.dart`、`widgets/enhanced_snackbar.dart`、`widgets/copyable_snackbar.dart`、`widgets/progress_dialog.dart`、`widgets/batch_operation_result_dialog.dart` | 错误 descriptor、创建加密目录、路径选择、目录移除确认与批量结果对话框已完成；批量统计、失败详情、创建密码选项、路径输入、删除操作和关闭按钮都有英文 widget 覆盖。进度面板的时间、计数、当前文件，以及重跑、导入、导出和批量删除调用点的标题/状态/结果已迁移；未完成传输确认已迁移并有英文 widget 覆盖，批量删除确认已迁移且保留中文行为覆盖，尚缺英文专门断言 |
| 目录浏览与操作 | `widgets/file_browser.dart`、`widgets/file_item_actions.dart`、`widgets/directory_background_actions.dart`、`widgets/directory_tree.dart`、`widgets/property_overlay.dart`、`widgets/entry_conflict_dialog.dart` | 已完成：筛选、排序、分页、视图模式、空态、条目类型与读屏语义，重命名校验、属性、动作面板、目录树读取/分页/重试，以及冲突确认/批量策略/自动命名后缀均进入 ARB；后续只需随主页的其余确认对话框迁移 |
| Root 与侧边栏 | `widgets/sidebar.dart`、`widgets/root_directory_action_dialog.dart`、`widgets/root_directory_properties.dart`、`widgets/root_password_change_dialog.dart`、`widgets/password_prompt.dart` | 已完成；共享属性浮层也已支持按 locale 显示标签与在长文本下滚动 |
| 安全记事本 | `widgets/secure_notepad.dart`、`widgets/secure_notepad_sections.dart`、`windows/secure_notepad_window.dart` | 未开始；错误组件已可本地化 |
| 图片浏览 | `widgets/secure_image_viewer.dart` | 部分完成，仅状态语义进入 ARB |

## 提取规则

1. 所有用户可见的 `Text`、`TextSpan`、`Tooltip`、`Semantics.label`、按钮标签、菜单标签、对话框标题/说明、空态、SnackBar 和确认提示必须从 `AppLocalizations.of(context)!` 获取。
2. ARB 键使用模块前缀和稳定语义，例如 `browserCreateFolder`、`notepadFindNext`、`rootDeleteHistoryOnly`。禁止以中文或英文整句作为键名。
3. 动态值必须使用 ARB 具名占位符。文件名、计数、路径摘要可传入；密码、密钥、明文、完整加密路径、原始异常和内部标识不能传入。
4. 领域层、FFI、controller 和 service 只返回结构化状态、`ErrorType` 或安全参数，不能返回已翻译句子。
5. 平台文件扩展名、算法标识、快捷键组合、协议字段和日志不翻译；面向用户解释这些值的标签需要翻译。
6. 无法立即迁移的用户文案必须登记在本文件对应模块中，说明原因和预计批次。不得在产品代码中增加中文 fallback。

## 迁移批次与完成定义

| 批次 | 范围 | 完成条件 |
| --- | --- | --- |
| A | 应用壳、加载/启动失败、设置全页、通用按钮 | 中文/英文下无遗留硬编码用户文案；设置英文页不再显示“仍在翻译”提示 |
| B | 主页、欢迎/解锁、文件浏览、目录/文件右键、属性、搜索和创建 | 每个交互路径在 `zh`、`en` 下均有 widget 测试；文件名/路径只作为安全占位符 |
| C | 导入、导出、冲突、进度、未完成状态和所有确认对话框 | 错误、冲突策略和取消路径都有中英文覆盖；不泄露技术细节 |
| D | 安全记事本与图片浏览器，包括子窗口、草稿、剪贴板和无障碍语义 | 新窗口取得创建时的 locale 快照；快捷键说明和读屏标签均翻译 |
| E | 低频 root 操作、剩余设置项、平台细节和发布验收 | 静态检查无未登记的用户文案；Linux、Windows、macOS 验收字体、截断和读屏 |

一个批次只能在以下条件同时满足时标记完成：对应 UI 文件逐项审核，ARB 的 `zh`/`en` 键和占位符一致，`flutter gen-l10n` 无差异，中文和英文 widget 测试通过，且没有把技术诊断、密码或完整敏感路径放入翻译参数。

## 防回退检查

在全部迁移完成前，检查采用基线模式而非直接禁止所有硬编码：

1. 每次新增或修改产品 UI 的可见静态字符串，必须同时新增 ARB 键，或在评审中说明它属于本文件“不可翻译”范围。
2. 每批开始前记录该模块候选点总数、已判定动态/不可翻译数和已提取数；只允许已提取数增加、未审计数减少。
3. 在批次 E 前，不把全局字符串扫描设为阻断 CI，避免历史债务掩盖新增问题；批次 E 完成后将产品 UI 目录的未登记静态文案设为 CI 失败。
4. 测试的 `MaterialApp` 必须显式注入 `AppLocalizations.localizationsDelegates` 和 `supportedLocales`，并显式指定 `zh` 或 `en`，不能依赖测试机器系统语言。

## 与现有设计的关系

本清单落实 [I18N_DESIGN.md](I18N_DESIGN.md) 的迁移批次和“页面只通过 `BuildContext` 获取文本”规则。错误 `ErrorDescriptor` 是框架前置项，不代替各页面文案迁移；设置页的英文预览提示在批次 A 完成前继续保留，防止把局部翻译展示为完整英文产品。
