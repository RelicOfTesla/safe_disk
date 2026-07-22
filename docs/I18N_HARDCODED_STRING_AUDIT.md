# 本地化未迁移文案清单

此文件由 `dart run tool/audit_i18n_strings.dart` 生成，请勿手工编辑。

扫描范围：`lib/**/*.dart`；排除生成的 `lib/l10n/`。
脚本采用 Dart 字符串词法扫描，覆盖单行、多行、raw 字符串，并忽略注释；CJK 字符串全量列出，同时补充 UI 与错误反馈上下文中的可见英文。

分类不等同于完成结论：

- `直接 UI 文案`：应优先迁入 ARB。
- `错误/服务边界文案`：先确认是否由 UI 直接展示；若是，应改为稳定状态/错误码，再在 UI 映射 ARB。
- `CJK 待人工复核`：可能是协议、日志或测试数据，须登记理由后才可排除。
- 英文候选用于发现未本地化 fallback；技术标识、URL、协议字段不应翻译。

候选总数：31

## 按分类统计

| 分类 | 候选数 |
| --- | ---: |
| CJK 待人工复核 | 9 |
| 错误/反馈英文文案 | 22 |

## 按文件统计

| 文件 | 候选数 |
| --- | ---: |
| `lib/services/directory_service.dart` | 9 |
| `lib/utils/error_diagnostics.dart` | 9 |
| `lib/native/native_lib.dart` | 7 |
| `lib/services/crypto_service.dart` | 3 |
| `lib/native/bindings.dart` | 2 |
| `lib/services/settings_service.dart` | 1 |

## 逐项清单

| 分类 | 文件 | 行号 | 字符串 | 源码上下文 |
| --- | --- | ---: | --- | --- |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 17 | 错误类型：${type.name} | '错误类型：${type.name}', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 18 | 操作阶段：$operation | if (operation != null && operation.isNotEmpty) '操作阶段：$operation', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 19 | 底层错误：$sanitized | '底层错误：$sanitized', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 36 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 43 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 47 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 53 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 57 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 60 | ${result.substring(0, _maxDetailLength)}\n[详细信息已截断] | result = '${result.substring(0, _maxDetailLength)}\n[详细信息已截断]'; |
| 错误/反馈英文文案 | `lib/native/bindings.dart` | 328 | Native library is missing from the application bundle:  | 'Native library is missing from the application bundle: ' |
| 错误/反馈英文文案 | `lib/native/bindings.dart` | 335 | Unsupported platform | throw UnsupportedError('Unsupported platform'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 510 | secTransferV3ListUnfinished returned invalid data | throw StateError('secTransferV3ListUnfinished returned invalid data'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 514 | secTransferV3ListUnfinished returned invalid markers | throw StateError('secTransferV3ListUnfinished returned invalid markers'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 518 | secTransferV3ListUnfinished returned invalid marker | throw StateError('secTransferV3ListUnfinished returned invalid marker'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 756 | $operation worker exited without a result | throw StateError('$operation worker exited without a result'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 787 | $operation worker sent an unknown event | throw StateError('$operation worker sent an unknown event'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 975 | unsupported transfer kind | throw ArgumentError.value(kind, 'kind', 'unsupported transfer kind'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 1015 | TransferCancellationToken cannot be reused | throw StateError('TransferCancellationToken cannot be reused'); |
| 错误/反馈英文文案 | `lib/services/crypto_service.dart` | 61 | Encrypted root must be created in an empty directory | 'Encrypted root must be created in an empty directory', |
| 错误/反馈英文文案 | `lib/services/crypto_service.dart` | 120 | Root $rootID is not open | throw StateError('Root $rootID is not open'); |
| 错误/反馈英文文案 | `lib/services/crypto_service.dart` | 135 | Root $rootID is not open | throw StateError('Root $rootID is not open'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 130 | Unfinished operation $opID has invalid entry_kind | throw StateError('Unfinished operation $opID has invalid entry_kind'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 133 | Unfinished operation $opID has unsupported type | throw StateError('Unfinished operation $opID has unsupported type'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 136 | Unfinished import $opID has no source path | throw StateError('Unfinished import $opID has no source path'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 139 | Unfinished export $opID has no destination path | throw StateError('Unfinished export $opID has no destination path'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 142 | Unfinished file operation $opID has no destination | throw StateError('Unfinished file operation $opID has no destination'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 169 | Unfinished operation marker has no $key | throw StateError('Unfinished operation marker has no $key'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 285 | Directory import paths must not be empty | throw ArgumentError('Directory import paths must not be empty'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 288 | Current path is outside the open root | throw StateError('Current path is outside the open root'); |
| 错误/反馈英文文案 | `lib/services/directory_service.dart` | 292 | Source directory must have a name | throw ArgumentError('Source directory must have a name'); |
| 错误/反馈英文文案 | `lib/services/settings_service.dart` | 139 | unsupported application locale | locale, 'locale', 'unsupported application locale'); |
