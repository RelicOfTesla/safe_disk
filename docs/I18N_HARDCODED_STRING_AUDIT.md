# 本地化未迁移文案清单

此文件由 `dart run tool/audit_i18n_strings.dart` 生成，请勿手工编辑。

扫描范围：`lib/**/*.dart`；排除生成的 `lib/l10n/`。
脚本采用 Dart 字符串词法扫描，覆盖单行、多行、raw 字符串，并忽略注释；CJK 字符串全量列出，同时补充 UI 与错误反馈上下文中的可见英文。

分类不等同于完成结论：

- `直接 UI 文案`：应优先迁入 ARB。
- `错误/服务边界文案`：先确认是否由 UI 直接展示；若是，应改为稳定状态/错误码，再在 UI 映射 ARB。
- `CJK 待人工复核`：可能是协议、日志或测试数据，须登记理由后才可排除。
- 英文候选用于发现未本地化 fallback；技术标识、URL、协议字段不应翻译。

候选总数：117

## 按分类统计

| 分类 | 候选数 |
| --- | ---: |
| CJK 待人工复核 | 27 |
| 直接 UI 文案 | 6 |
| 直接 UI 英文文案 | 4 |
| 错误/反馈英文文案 | 64 |
| 错误/服务边界文案 | 16 |

## 按文件统计

| 文件 | 候选数 |
| --- | ---: |
| `lib/models/ffi_results.dart` | 17 |
| `lib/services/incremental_encrypt_service.dart` | 11 |
| `lib/services/clipboard_service.dart` | 10 |
| `lib/services/directory_service.dart` | 9 |
| `lib/services/document_window_client.dart` | 9 |
| `lib/utils/error_diagnostics.dart` | 9 |
| `lib/native/native_lib.dart` | 8 |
| `lib/models/secure_image_policy.dart` | 6 |
| `lib/services/clipboard_helper.dart` | 6 |
| `lib/services/content_window_host_bridge.dart` | 6 |
| `lib/services/document_session_broker.dart` | 5 |
| `lib/services/secure_entry_move_service.dart` | 4 |
| `lib/services/crypto_service.dart` | 3 |
| `lib/widgets/secure_image_viewer.dart` | 3 |
| `lib/widgets/secure_notepad.dart` | 3 |
| `lib/native/bindings.dart` | 2 |
| `lib/services/remote_document_crypto_service.dart` | 2 |
| `lib/main.dart` | 1 |
| `lib/pages/home_page.dart` | 1 |
| `lib/services/settings_service.dart` | 1 |
| `lib/widgets/entry_conflict_dialog.dart` | 1 |

## 逐项清单

| 分类 | 文件 | 行号 | 字符串 | 源码上下文 |
| --- | --- | ---: | --- | --- |
| CJK 待人工复核 | `lib/models/secure_image_policy.dart` | 114 | $pixels 像素 | return '$pixels 像素'; |
| CJK 待人工复核 | `lib/services/clipboard_helper.dart` | 32 | 已取消：成功 $filesProcessed 个，失败 $filesFailed 个 | return '已取消：成功 $filesProcessed 个，失败 $filesFailed 个'; |
| CJK 待人工复核 | `lib/services/clipboard_helper.dart` | 35 | 完成：成功粘贴 $filesProcessed 个文件 | return '完成：成功粘贴 $filesProcessed 个文件'; |
| CJK 待人工复核 | `lib/services/clipboard_helper.dart` | 37 | 完成：成功 $filesProcessed 个，失败 $filesFailed 个 | return '完成：成功 $filesProcessed 个，失败 $filesFailed 个'; |
| CJK 待人工复核 | `lib/services/document_session_broker.dart` | 21 | 内容窗口会话不存在或已经关闭 | String toString() => '内容窗口会话不存在或已经关闭'; |
| CJK 待人工复核 | `lib/services/document_session_broker.dart` | 30 | 内容超过允许的 $maxBytes 字节上限 | String toString() => '内容超过允许的 $maxBytes 字节上限'; |
| CJK 待人工复核 | `lib/services/document_session_broker.dart` | 37 | 当前内容窗口会话为只读 | String toString() => '当前内容窗口会话为只读'; |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 32 | 主窗口未在限定时间内响应：$operation | String toString() => '主窗口未在限定时间内响应：$operation'; |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 58 | 读取文档 | '读取文档', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 69 | 保存文档 | '保存文档', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 84 | 读取安全草稿 | '读取安全草稿', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 94 | 写入安全草稿 | '写入安全草稿', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 104 | 删除安全草稿 | '删除安全草稿', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 114 | 同步编辑状态 | '同步编辑状态', |
| CJK 待人工复核 | `lib/services/document_window_client.dart` | 124 | 关闭文档会话 | '关闭文档会话', |
| CJK 待人工复核 | `lib/services/secure_entry_move_service.dart` | 11 | 目标文件已复制，但删除源文件失败；为避免数据丢失，源文件和目标文件均已保留。 | return '目标文件已复制，但删除源文件失败；为避免数据丢失，源文件和目标文件均已保留。' |
| CJK 待人工复核 | `lib/services/secure_entry_move_service.dart` | 12 | 请确认后手动删除源文件。原始错误：$cause | '请确认后手动删除源文件。原始错误：$cause'; |
| CJK 待人工复核 | `lib/services/secure_entry_move_service.dart` | 39 | 可改用复制，确认内容后再手动删除源目录。 | '可改用复制，确认内容后再手动删除源目录。', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 17 | 错误类型：${type.name} | '错误类型：${type.name}', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 18 | 操作阶段：$operation | if (operation != null && operation.isNotEmpty) '操作阶段：$operation', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 19 | 底层错误：$sanitized | '底层错误：$sanitized', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 36 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 43 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 47 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 53 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 57 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| CJK 待人工复核 | `lib/utils/error_diagnostics.dart` | 60 | ${result.substring(0, _maxDetailLength)}\n[详细信息已截断] | result = '${result.substring(0, _maxDetailLength)}\n[详细信息已截断]'; |
| 直接 UI 文案 | `lib/services/content_window_host_bridge.dart` | 336 | 不支持的内容窗口调用：${call.method} | message: '不支持的内容窗口调用：${call.method}', |
| 直接 UI 文案 | `lib/widgets/secure_image_viewer.dart` | 182 | 无法加载图片：${e.message} | ? '无法加载图片：${e.message}' |
| 直接 UI 文案 | `lib/widgets/secure_image_viewer.dart` | 183 | 无法加载图片：图片解密失败或内容无效 | : '无法加载图片：图片解密失败或内容无效'; |
| 直接 UI 文案 | `lib/widgets/secure_notepad.dart` | 214 | 无法读取剪贴板：$error | setState(() => _clipboardError = '无法读取剪贴板：$error'); |
| 直接 UI 文案 | `lib/widgets/secure_notepad.dart` | 231 | 无法清空剪贴板：$error | setState(() => _clipboardError = '无法清空剪贴板：$error'); |
| 直接 UI 文案 | `lib/widgets/secure_notepad.dart` | 244 | 文件保存成功 | ErrorHelper.showSuccess(context, '文件保存成功'); |
| 直接 UI 英文文案 | `lib/main.dart` | 197 | Safe Disk | title: 'Safe Disk', |
| 直接 UI 英文文案 | `lib/pages/home_page.dart` | 1776 | Unknown error | originalError: progress.error ?? 'Unknown error', |
| 直接 UI 英文文案 | `lib/widgets/entry_conflict_dialog.dart` | 128 | No conflict-free entry name could be generated | throw StateError('No conflict-free entry name could be generated'); |
| 直接 UI 英文文案 | `lib/widgets/secure_image_viewer.dart` | 129 | Failed to load image list: $e | debugPrint('Failed to load image list: $e'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 45 | Operation failed | throw Exception(error ?? 'Operation failed'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 48 | No data returned | throw Exception('No data returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 72 | Operation failed | throw Exception(error ?? 'Operation failed'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 95 | Session creation failed | throw Exception(error ?? 'Session creation failed'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 98 | No temporary key ID returned | throw Exception('No temporary key ID returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 122 | Config loading failed | throw Exception(error ?? 'Config loading failed'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 125 | No config returned | throw Exception('No config returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 165 | Failed to check file format | throw Exception(error ?? 'Failed to check file format'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 224 | Job creation failed | throw Exception(error ?? 'Job creation failed'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 227 | No job ID returned | throw Exception('No job ID returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 370 | Failed to create incremental encryptor | throw Exception(error ?? 'Failed to create incremental encryptor'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 373 | No handle ID returned | throw Exception('No handle ID returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 407 | Failed to open incremental decryptor | throw Exception(error ?? 'Failed to open incremental decryptor'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 410 | No handle ID returned | throw Exception('No handle ID returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 441 | Failed to decrypt block | throw Exception(error ?? 'Failed to decrypt block'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 444 | No data returned | throw Exception('No data returned'); |
| 错误/反馈英文文案 | `lib/models/ffi_results.dart` | 539 | Failed to check file format | throw Exception(error ?? 'Failed to check file format'); |
| 错误/反馈英文文案 | `lib/native/bindings.dart` | 328 | Native library is missing from the application bundle:  | 'Native library is missing from the application bundle: ' |
| 错误/反馈英文文案 | `lib/native/bindings.dart` | 335 | Unsupported platform | throw UnsupportedError('Unsupported platform'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 510 | secTransferV3ListUnfinished returned invalid data | throw StateError('secTransferV3ListUnfinished returned invalid data'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 514 | secTransferV3ListUnfinished returned invalid markers | throw StateError('secTransferV3ListUnfinished returned invalid markers'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 518 | secTransferV3ListUnfinished returned invalid marker | throw StateError('secTransferV3ListUnfinished returned invalid marker'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 756 | $operation worker exited without a result | throw StateError('$operation worker exited without a result'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 787 | $operation worker sent an unknown event | throw StateError('$operation worker sent an unknown event'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 959 | Incremental encryption FFI is not part of the active Safe Disk API. | 'Incremental encryption FFI is not part of the active Safe Disk API.', |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 1030 | unsupported transfer kind | throw ArgumentError.value(kind, 'kind', 'unsupported transfer kind'); |
| 错误/反馈英文文案 | `lib/native/native_lib.dart` | 1070 | TransferCancellationToken cannot be reused | throw StateError('TransferCancellationToken cannot be reused'); |
| 错误/反馈英文文案 | `lib/services/clipboard_helper.dart` | 103 | Failed to read clipboard | errors: [clipboardResult.error ?? 'Failed to read clipboard'], |
| 错误/反馈英文文案 | `lib/services/clipboard_helper.dart` | 153 | Failed to paste: ${item.path} | errors.add('Failed to paste: ${item.path}'); |
| 错误/反馈英文文案 | `lib/services/clipboard_helper.dart` | 246 | Failed: $relativePath - $e | errors.add('Failed: $relativePath - $e'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 86 | No items to copy | return ClipboardResult.failure('No items to copy'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 93 | Directory not found: ${item.path} | return ClipboardResult.failure('Directory not found: ${item.path}'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 97 | File not found: ${item.path} | return ClipboardResult.failure('File not found: ${item.path}'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 108 | Unsupported platform | return ClipboardResult.failure('Unsupported platform'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 111 | Failed to copy: $e | return ClipboardResult.failure('Failed to copy: $e'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 141 | Unsupported platform | return ClipboardResult.failure('Unsupported platform'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 143 | Failed to paste: $e | return ClipboardResult.failure('Failed to paste: $e'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 216 | Failed to set clipboard data | return ClipboardResult.failure('Failed to set clipboard data'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 363 | No files in clipboard | return ClipboardResult.failure('No files in clipboard'); |
| 错误/反馈英文文案 | `lib/services/clipboard_service.dart` | 528 | No files in clipboard | return ClipboardResult.failure('No files in clipboard'); |
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
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 93 | Failed to create encryptor | onError?.call(result.error ?? 'Failed to create encryptor'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 126 | Failed to add block | onError?.call(result.error ?? 'Failed to add block'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 173 | Failed to finalize encryption | onError?.call(result.error ?? 'Failed to finalize encryption'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 293 | Failed to open decryptor | onError?.call(result.error ?? 'Failed to open decryptor'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 311 | Decryptor is not open. Call open() first. | throw StateError('Decryptor is not open. Call open() first.'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 314 | Decryptor is closed. | throw StateError('Decryptor is closed.'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 330 | Failed to decrypt block $blockIndex | onError?.call(result.error ?? 'Failed to decrypt block $blockIndex'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 356 | Failed to decrypt range $offset-$length | ?.call(result.error ?? 'Failed to decrypt range $offset-$length'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 377 | Failed to decrypt all | onError?.call(result.error ?? 'Failed to decrypt all'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 443 | Failed to get block info | onError?.call(result.error ?? 'Failed to get block info'); |
| 错误/反馈英文文案 | `lib/services/incremental_encrypt_service.dart` | 465 | Failed to get all block info | onError?.call(result.error ?? 'Failed to get all block info'); |
| 错误/反馈英文文案 | `lib/services/settings_service.dart` | 139 | unsupported application locale | locale, 'locale', 'unsupported application locale'); |
| 错误/服务边界文案 | `lib/models/secure_image_policy.dart` | 56 | 图片编码数据超过 ${formatImageByteLimit(maxBytes)} 上限 | '图片编码数据超过 ${formatImageByteLimit(maxBytes)} 上限', |
| 错误/服务边界文案 | `lib/models/secure_image_policy.dart` | 67 | 图片内容为空 | throw const SecureImagePolicyException('图片内容为空'); |
| 错误/服务边界文案 | `lib/models/secure_image_policy.dart` | 80 | 图片尺寸无效 | throw const SecureImagePolicyException('图片尺寸无效'); |
| 错误/服务边界文案 | `lib/models/secure_image_policy.dart` | 84 | 图片解码尺寸超过 ${formatImagePixelLimit(maxPixels)} 上限 | '图片解码尺寸超过 ${formatImagePixelLimit(maxPixels)} 上限', |
| 错误/服务边界文案 | `lib/models/secure_image_policy.dart` | 96 | 图片内容损坏或当前平台不支持该格式 | throw const SecureImagePolicyException('图片内容损坏或当前平台不支持该格式'); |
| 错误/服务边界文案 | `lib/services/content_window_host_bridge.dart` | 305 | revision 或 content 格式无效 | throw const FormatException('revision 或 content 格式无效'); |
| 错误/服务边界文案 | `lib/services/content_window_host_bridge.dart` | 317 | content 格式无效 | throw const FormatException('content 格式无效'); |
| 错误/服务边界文案 | `lib/services/content_window_host_bridge.dart` | 326 | dirty 格式无效 | if (dirty is! bool) throw const FormatException('dirty 格式无效'); |
| 错误/服务边界文案 | `lib/services/content_window_host_bridge.dart` | 354 | 请求参数必须是 map | if (arguments is! Map) throw const FormatException('请求参数必须是 map'); |
| 错误/服务边界文案 | `lib/services/content_window_host_bridge.dart` | 361 | $key 格式无效 | throw FormatException('$key 格式无效'); |
| 错误/服务边界文案 | `lib/services/document_session_broker.dart` | 205 | 窗口内容版本已过期，请重新加载后再保存 | throw const DocumentSessionConflict('窗口内容版本已过期，请重新加载后再保存'); |
| 错误/服务边界文案 | `lib/services/document_session_broker.dart` | 213 | 文件已被另一个窗口修改，已阻止覆盖 | throw const DocumentSessionConflict('文件已被另一个窗口修改，已阻止覆盖'); |
| 错误/服务边界文案 | `lib/services/document_window_client.dart` | 147 | 主窗口返回了无效的文档快照 | throw StateError('主窗口返回了无效的文档快照'); |
| 错误/服务边界文案 | `lib/services/remote_document_crypto_service.dart` | 26 | 安全草稿不存在 | if (draft == null) throw StateError('安全草稿不存在'); |
| 错误/服务边界文案 | `lib/services/remote_document_crypto_service.dart` | 58 | 内容窗口不能删除原文件 | throw UnsupportedError('内容窗口不能删除原文件'); |
| 错误/服务边界文案 | `lib/services/secure_entry_move_service.dart` | 38 | 跨 root 或替换已有目录的移动尚不安全：当前缺少递归删除源目录接口。 | '跨 root 或替换已有目录的移动尚不安全：当前缺少递归删除源目录接口。' |
