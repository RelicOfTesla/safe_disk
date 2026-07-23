# 本地化生成文件审计

更新时间：2026-07-23

本记录只说明 `lib/l10n/generated/*.dart` 的来源和可重现性，不把生成器版本造成的格式差异误报为业务代码手工修改。

## 当前结论

| 文件 | ARB 重生成结果 | 当前结论 |
|---|---|---|
| `app_localizations_en.dart` | 内容、顺序和格式一致 | 未发现手工业务修改 |
| `app_localizations_zh.dart` | 内容、顺序和格式一致 | 未发现手工业务修改 |
| `app_localizations.dart` | 业务内容一致；少量格式来自不同 Flutter 生成器版本 | 未发现手工业务修改 |

复核使用 `/tmp/flutter-copy` 的可写 Flutter 工具链，在临时项目中从当前 `lib/l10n/arb/*.arb` 生成，再使用同一 Dart formatter 比较。此前工作区曾因 Flutter SDK 缓存不可写而手工同步 WebDAV generated 内容；本轮已用可写工具链重新生成并复核。后续仍应由 `flutter gen-l10n` 生成，不应直接编辑 generated 文件。

## 历史中的直接编辑

通过提交历史逐提交比较 `lib/l10n/arb/` 和 `lib/l10n/generated/`：

- `e95bcea` 只修改了三个 generated 文件，没有同步修改 ARB。它把“剪贴板中没有短文本”改成了“剪贴板中没有文本”，属于直接编辑生成文件，现已被后续 ARB 修改覆盖。
- 其余历史提交中，generated 修改均与 ARB 修改出现在同一提交，未发现只有 generated 文件变化的提交。

## 规则

1. 翻译源只允许修改 `lib/l10n/arb/*.arb`。
2. `lib/l10n/generated/*.dart` 视为构建产物，不接受业务手工修改。
3. Flutter 工具链不可写时，不应把手工同步当作最终状态；应在可写工具链下运行 `flutter gen-l10n`，并将生成结果与 ARB 一起复核。
4. 生成文件审计必须同时检查内容差异和历史来源；生成器/formatter 升级造成的纯格式差异单独记录。

## 复核命令

```bash
PATH=/tmp/flutter-copy/bin:$PATH flutter gen-l10n --no-version-check
dart format lib/l10n/generated
git diff -- lib/l10n/generated
```

如果仓库的 `l10n.yaml` 指向当前项目，验证时应在临时可写项目中生成，避免把审计过程直接覆盖工作区文件。
