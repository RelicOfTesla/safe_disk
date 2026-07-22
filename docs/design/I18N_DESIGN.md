# 多语言架构与迁移框架

状态：设计完成，待按批次实施。本文不代表英文界面已完成。

## 目标与边界

Safe Disk 的界面语言必须可在简体中文和英文之间切换，并在主窗口、记事本子窗口、图片子窗口中保持一致。语言选择只影响界面呈现：不得改变加密格式、文件名、配置字段、FFI ABI、CLI JSON 字段、错误码或磁盘数据。

首发支持 `zh` 和 `en`。中文是产品默认语言；“跟随系统语言”是显式可选项，而不是默认值。系统语言不在支持集合内时回退到中文。

不在本轮范围：CLI 多语言、动态下载语言包、第三方原生插件界面、区域化数字/日期格式重设计、RTL 语言。

## 当前事实与问题

截至 2026-07-22，工程已有 `lib/l10n/arb/app_zh.arb`、`app_en.arb`、`flutter gen-l10n` 生成类、设置持久化字段和三类 `MaterialApp` 的 locale 注入。第一批框架修正已将默认偏好改为中文，增加受支持语言的 resolver，并将内容窗口参数升级为 v2 的语言快照，解析器继续接受 v1。设置页的少量核心文本已经消费 ARB。

但当前不能视为完整架构，原因如下：

- 产品 UI 目录当前有 27 个文件、269 个候选可见文案构造点；按模块的审核范围、迁移顺序和防回退规则见 [I18N_STRING_INVENTORY.md](I18N_STRING_INVENTORY.md)。主页、文件操作、记事本和图片查看器尚未按统一 API 迁移。
- `ErrorMessages` 是 context-free 的静态中文映射，不能安全地直接转换语言。
- 为兼容未注入 delegate 的旧 widget 测试，设置页暂有中文 fallback。这种 fallback 不应扩散到产品页面，否则会制造半英文页面。
- 静态错误映射已改为 `ErrorDescriptor`，所有既有 `ErrorType` 的标题、说明、建议和复制内容均在 UI 层按 context 从 ARB 解析。
- 英文设置页与其余硬编码中文页面共存，尚未达到对普通用户开放完整英文的门槛。

## 架构决策

### 1. ARB 是唯一用户文案源

保留单个 Flutter 标准 ARB 域，目录固定为 `lib/l10n/arb/`，生成文件固定为 `lib/l10n/generated/`。以 `app_zh.arb` 作为模板文件，`app_en.arb` 必须有完全相同的键与占位符集合。

键按领域命名，而不是按可见中文命名：

```text
common.cancel
settings.language.title
home.unlock.prompt
browser.context.rename
notepad.find.next
image.load.failed
error.loadFile.description
```

ARB 中的动态值一律使用具名占位符。文件名、数量、路径摘要等由调用点传入；不得把密码、明文内容、密钥、完整加密路径或底层异常直接插入翻译字符串。

仅以下内容可保留在代码中而不进入 ARB：日志、断言、错误码、协议字段、测试夹具、开发者注释和用户不可见的原生诊断。任何可见 `Text`、`Tooltip`、`Semantics`、确认对话框、SnackBar、空态和按钮标签都必须迁移。

### 2. 页面只通过 BuildContext 获取文本

UI 层统一使用 `AppLocalizations.of(context)!`，或一个仅作该调用简写的 context extension。生产组件不得提供中文字符串 fallback；测试必须为被测 `MaterialApp` 注入 `AppLocalizations.localizationsDelegates` 与 `supportedLocales`。

纯 Dart service、controller、FFI 和 domain model 不依赖 `BuildContext`，也不返回已翻译的文本。它们返回稳定的错误类型、状态枚举或结构化参数；翻译只在 widget/presenter 层发生。

### 3. 错误呈现分离语义与语言

`ErrorType` 保留为稳定语义标识。现有 `ErrorMessage(title, description, suggestion)` 静态中文映射应迁移为 `ErrorDescriptor`，只保存错误类型、严重性、可选操作阶段和参数。`ErrorSnackBar`、错误对话框与页面错误态在持有 context 时从 ARB 取得标题、描述和建议。

技术诊断继续由 `ErrorDiagnostics` 负责脱敏。详细错误关闭时不得构造或显示诊断文本；开启时只追加已脱敏的诊断，不能翻译或改写错误码、路径隐藏标记和安全字段。

### 4. locale 状态与窗口协议

语言偏好值只允许 `zh`、`en`、`system`。默认值改为 `zh`。解析规则：显式 `zh`/`en` 使用对应 locale；`system` 使用系统语言的主 languageCode；系统语言不受支持时使用 `zh`。

主应用持有解析后的 `Locale?` 并传入根 `MaterialApp`。设置页的预览回调只改变内存状态；保存后才更新 `SettingsService`。放弃修改必须恢复保存前语言。

内容子窗口不能在启动时自行读取语言设置作为唯一来源。扩展 `ContentWindowArguments` 的版本化载荷，主窗口创建子窗口时附带语言偏好或解析后的 languageCode 快照；子窗口优先使用该快照。旧载荷缺字段时才读取设置并按安全默认 `zh` 回退。这样同一次打开操作中的主/子窗口语言一致，且向旧版本协议兼容。

`MaterialApp`、记事本子窗口、图片子窗口和内容窗口启动失败页必须共用：

```dart
locale: resolvedLocale
localizationsDelegates: AppLocalizations.localizationsDelegates
supportedLocales: AppLocalizations.supportedLocales
localeResolutionCallback: resolveSafeDiskLocale
```

### 5. 不允许半翻译伪装

“English” 选项只在源代码迁移完成后对普通用户开放。当前以词法审计 `tool/audit_i18n_strings.dart` 为门槛：产品 `lib` 扫描结果必须为零候选，英文 ARB 不得包含中文值；两者只证明源级迁移完成，不能替代真实桌面的视觉、字号、截断、键盘或读屏验收。若任一门槛退化，设置页必须重新明确语言仍在迁移，或暂时禁用该选项。

## 迁移批次

1. **框架修正**：默认值改为 `zh`；ARB 模板改为中文；统一 locale resolver；内容窗口参数快照；错误 descriptor 设计落地。受影响的错误路径测试必须显式注入 locale；全量测试包装器仍待后续统一。
2. **应用壳与设置**：启动错误、加载页、设置全页、语言管理和通用确认/按钮。完成后设置页英文必须无遗留中文。
3. **主页与目录浏览**：欢迎/解锁、路径栏、文件浏览、右键菜单、批量操作、搜索/筛选、属性和创建目录。
4. **传输与错误**：导入/导出/冲突/未完成任务、所有 `ErrorType`、进度与恢复提示。
5. **内容窗口**：安全记事本、图片查看器、草稿/剪贴板状态、子窗口启动失败和无障碍语义。
6. **低频与发布**：设置剩余项、空态、调试/诊断边界、快捷键说明、平台字体和截断。

每个批次必须同时完成中文/英文 ARB、代码迁移、widget 测试和文案审校。不得以“翻译文件有键”替代实际页面渲染验证。

## 测试与发布门槛

- `flutter gen-l10n` 后生成文件必须在工作树中一致；CI 检查 ARB 键和占位符一致性。
- 单元测试：locale 偏好合法性、默认中文、`system` 回退、错误 descriptor 参数和诊断脱敏。
- widget 测试：每个迁移页面在 `zh`、`en` 下验证关键动作、对话框、错误和 Semantics；不得只检查 `MaterialApp.locale`。
- 内容窗口测试：创建时快照传递、旧协议回退、主窗口更改语言后的新旧子窗口行为。
- 静态检查：新增用户可见硬编码字符串需要显式 allowlist 或失败；每批次减少 allowlist。
- 桌面验收：Linux、Windows、macOS 验证中英文 CJK/Latin 字体回退、长文本截断、快捷键提示、读屏标签和新窗口一致性。

## 当前实施约束

默认中文、中文 ARB 模板、locale resolver、子窗口语言快照和错误 descriptor 已完成定向及完整测试；全量测试包装器和主体页面文案仍未完成。按 [I18N_STRING_INVENTORY.md](I18N_STRING_INVENTORY.md) 逐模块审核与迁移前，现有实现不满足完整多语言的发布门槛。
