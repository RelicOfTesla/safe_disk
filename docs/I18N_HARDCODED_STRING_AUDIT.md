# 本地化硬编码候选清单

此文件由 `dart run tool/audit_i18n_strings.dart` 生成，请勿手工编辑。

扫描范围为 `lib/**/*.dart`，排除生成的 `lib/l10n/` 和 `lib/testing/`。
它列出所有 CJK 字符串，以及常见 UI 构造位置的 ASCII 字符串。
候选项需要人工分类：领域操作标识、技术诊断和仅供开发者使用的文本不应直接迁入 ARB。

候选总数：68

## 按文件统计

| 文件 | 候选数 |
| --- | ---: |
| `lib/services/document_window_client.dart` | 9 |
| `lib/services/settings_service.dart` | 9 |
| `lib/utils/error_diagnostics.dart` | 9 |
| `lib/controllers/secure_notepad_controller.dart` | 7 |
| `lib/models/secure_image_policy.dart` | 6 |
| `lib/services/content_window_host_bridge.dart` | 6 |
| `lib/services/document_session_broker.dart` | 5 |
| `lib/services/secure_entry_move_service.dart` | 4 |
| `lib/widgets/secure_notepad.dart` | 4 |
| `lib/services/clipboard_helper.dart` | 3 |
| `lib/services/remote_document_crypto_service.dart` | 2 |
| `lib/widgets/secure_image_viewer.dart` | 2 |
| `lib/main.dart` | 1 |
| `lib/widgets/native_library_startup_error.dart` | 1 |

## 逐项候选

| 文件 | 行号 | 类型 | 字符串 | 源码上下文 |
| --- | ---: | --- | --- | --- |
| `lib/controllers/secure_notepad_controller.dart` | 108 | CJK 字符串 | 文件包含 NUL 字节，可能是二进制文件 | throw const FormatException('文件包含 NUL 字节，可能是二进制文件'); |
| `lib/controllers/secure_notepad_controller.dart` | 133 | CJK 字符串 | 文件包含二进制内容，不能用安全记事本打开。 | return '文件包含二进制内容，不能用安全记事本打开。'; |
| `lib/controllers/secure_notepad_controller.dart` | 135 | CJK 字符串 | 无法读取文件内容。请检查文件是否存在且可读，然后重试。 | return '无法读取文件内容。请检查文件是否存在且可读，然后重试。'; |
| `lib/controllers/secure_notepad_controller.dart` | 176 | CJK 字符串 | 原文件已保存，但无法清理旧草稿。 | _draftError = '原文件已保存，但无法清理旧草稿。'; |
| `lib/controllers/secure_notepad_controller.dart` | 204 | CJK 字符串 | 无法检查恢复草稿。 | _draftError = '无法检查恢复草稿。'; |
| `lib/controllers/secure_notepad_controller.dart` | 232 | CJK 字符串 | 无法清理恢复草稿。 | _draftError = '无法清理恢复草稿。'; |
| `lib/controllers/secure_notepad_controller.dart` | 256 | CJK 字符串 | 无法保存恢复草稿。 | _draftError = '无法保存恢复草稿。'; |
| `lib/main.dart` | 197 | UI ASCII 字符串 | Safe Disk | title: 'Safe Disk', |
| `lib/models/secure_image_policy.dart` | 56 | CJK 字符串 | 图片编码数据超过 ${formatImageByteLimit(maxBytes)} 上限 | '图片编码数据超过 ${formatImageByteLimit(maxBytes)} 上限', |
| `lib/models/secure_image_policy.dart` | 67 | CJK 字符串 | 图片内容为空 | throw const SecureImagePolicyException('图片内容为空'); |
| `lib/models/secure_image_policy.dart` | 80 | CJK 字符串 | 图片尺寸无效 | throw const SecureImagePolicyException('图片尺寸无效'); |
| `lib/models/secure_image_policy.dart` | 84 | CJK 字符串 | 图片解码尺寸超过 ${formatImagePixelLimit(maxPixels)} 上限 | '图片解码尺寸超过 ${formatImagePixelLimit(maxPixels)} 上限', |
| `lib/models/secure_image_policy.dart` | 96 | CJK 字符串 | 图片内容损坏或当前平台不支持该格式 | throw const SecureImagePolicyException('图片内容损坏或当前平台不支持该格式'); |
| `lib/models/secure_image_policy.dart` | 114 | CJK 字符串 | $pixels 像素 | return '$pixels 像素'; |
| `lib/services/clipboard_helper.dart` | 32 | CJK 字符串 | 已取消：成功 $filesProcessed 个，失败 $filesFailed 个 | return '已取消：成功 $filesProcessed 个，失败 $filesFailed 个'; |
| `lib/services/clipboard_helper.dart` | 35 | CJK 字符串 | 完成：成功粘贴 $filesProcessed 个文件 | return '完成：成功粘贴 $filesProcessed 个文件'; |
| `lib/services/clipboard_helper.dart` | 37 | CJK 字符串 | 完成：成功 $filesProcessed 个，失败 $filesFailed 个 | return '完成：成功 $filesProcessed 个，失败 $filesFailed 个'; |
| `lib/services/content_window_host_bridge.dart` | 305 | CJK 字符串 | revision 或 content 格式无效 | throw const FormatException('revision 或 content 格式无效'); |
| `lib/services/content_window_host_bridge.dart` | 317 | CJK 字符串 | content 格式无效 | throw const FormatException('content 格式无效'); |
| `lib/services/content_window_host_bridge.dart` | 326 | CJK 字符串 | dirty 格式无效 | if (dirty is! bool) throw const FormatException('dirty 格式无效'); |
| `lib/services/content_window_host_bridge.dart` | 336 | CJK 字符串 | 不支持的内容窗口调用：${call.method} | message: '不支持的内容窗口调用：${call.method}', |
| `lib/services/content_window_host_bridge.dart` | 354 | CJK 字符串 | 请求参数必须是 map | if (arguments is! Map) throw const FormatException('请求参数必须是 map'); |
| `lib/services/content_window_host_bridge.dart` | 361 | CJK 字符串 | $key 格式无效 | throw FormatException('$key 格式无效'); |
| `lib/services/document_session_broker.dart` | 21 | CJK 字符串 | 内容窗口会话不存在或已经关闭 | String toString() => '内容窗口会话不存在或已经关闭'; |
| `lib/services/document_session_broker.dart` | 30 | CJK 字符串 | 内容超过允许的 $maxBytes 字节上限 | String toString() => '内容超过允许的 $maxBytes 字节上限'; |
| `lib/services/document_session_broker.dart` | 37 | CJK 字符串 | 当前内容窗口会话为只读 | String toString() => '当前内容窗口会话为只读'; |
| `lib/services/document_session_broker.dart` | 205 | CJK 字符串 | 窗口内容版本已过期，请重新加载后再保存 | throw const DocumentSessionConflict('窗口内容版本已过期，请重新加载后再保存'); |
| `lib/services/document_session_broker.dart` | 213 | CJK 字符串 | 文件已被另一个窗口修改，已阻止覆盖 | throw const DocumentSessionConflict('文件已被另一个窗口修改，已阻止覆盖'); |
| `lib/services/document_window_client.dart` | 32 | CJK 字符串 | 主窗口未在限定时间内响应：$operation | String toString() => '主窗口未在限定时间内响应：$operation'; |
| `lib/services/document_window_client.dart` | 58 | CJK 字符串 | 读取文档 | '读取文档', |
| `lib/services/document_window_client.dart` | 69 | CJK 字符串 | 保存文档 | '保存文档', |
| `lib/services/document_window_client.dart` | 84 | CJK 字符串 | 读取安全草稿 | '读取安全草稿', |
| `lib/services/document_window_client.dart` | 94 | CJK 字符串 | 写入安全草稿 | '写入安全草稿', |
| `lib/services/document_window_client.dart` | 104 | CJK 字符串 | 删除安全草稿 | '删除安全草稿', |
| `lib/services/document_window_client.dart` | 114 | CJK 字符串 | 同步编辑状态 | '同步编辑状态', |
| `lib/services/document_window_client.dart` | 124 | CJK 字符串 | 关闭文档会话 | '关闭文档会话', |
| `lib/services/document_window_client.dart` | 147 | CJK 字符串 | 主窗口返回了无效的文档快照 | throw StateError('主窗口返回了无效的文档快照'); |
| `lib/services/remote_document_crypto_service.dart` | 26 | CJK 字符串 | 安全草稿不存在 | if (draft == null) throw StateError('安全草稿不存在'); |
| `lib/services/remote_document_crypto_service.dart` | 58 | CJK 字符串 | 内容窗口不能删除原文件 | throw UnsupportedError('内容窗口不能删除原文件'); |
| `lib/services/secure_entry_move_service.dart` | 11 | CJK 字符串 | 目标文件已复制，但删除源文件失败；为避免数据丢失，源文件和目标文件均已保留。 | return '目标文件已复制，但删除源文件失败；为避免数据丢失，源文件和目标文件均已保留。' |
| `lib/services/secure_entry_move_service.dart` | 12 | CJK 字符串 | 请确认后手动删除源文件。原始错误：$cause | '请确认后手动删除源文件。原始错误：$cause'; |
| `lib/services/secure_entry_move_service.dart` | 38 | CJK 字符串 | 跨 root 或替换已有目录的移动尚不安全：当前缺少递归删除源目录接口。 | '跨 root 或替换已有目录的移动尚不安全：当前缺少递归删除源目录接口。' |
| `lib/services/secure_entry_move_service.dart` | 39 | CJK 字符串 | 可改用复制，确认内容后再手动删除源目录。 | '可改用复制，确认内容后再手动删除源目录。', |
| `lib/services/settings_service.dart` | 88 | CJK 字符串 | 快速 (0.5秒) | if (ms <= 500) return '快速 (0.5秒)'; |
| `lib/services/settings_service.dart` | 89 | CJK 字符串 | 平衡 (1秒) | if (ms <= 1000) return '平衡 (1秒)'; |
| `lib/services/settings_service.dart` | 90 | CJK 字符串 | 强密钥 (2秒) | if (ms <= 2000) return '强密钥 (2秒)'; |
| `lib/services/settings_service.dart` | 91 | CJK 字符串 | 最强 (5秒) | return '最强 (5秒)'; |
| `lib/services/settings_service.dart` | 157 | CJK 字符串 | 跟随系统 | return '跟随系统'; |
| `lib/services/settings_service.dart` | 159 | CJK 字符串 | 亮色主题 | return '亮色主题'; |
| `lib/services/settings_service.dart` | 161 | CJK 字符串 | 暗色主题 | return '暗色主题'; |
| `lib/services/settings_service.dart` | 163 | CJK 字符串 | 跟随系统 | return '跟随系统'; |
| `lib/services/settings_service.dart` | 225 | CJK 字符串 | 不支持的自动保存间隔 | throw ArgumentError.value(seconds, 'seconds', '不支持的自动保存间隔'); |
| `lib/utils/error_diagnostics.dart` | 17 | CJK 字符串 | 错误类型：${type.name} | '错误类型：${type.name}', |
| `lib/utils/error_diagnostics.dart` | 18 | CJK 字符串 | 操作阶段：$operation | if (operation != null && operation.isNotEmpty) '操作阶段：$operation', |
| `lib/utils/error_diagnostics.dart` | 19 | CJK 字符串 | 底层错误：$sanitized | '底层错误：$sanitized', |
| `lib/utils/error_diagnostics.dart` | 36 | CJK 字符串 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| `lib/utils/error_diagnostics.dart` | 43 | CJK 字符串 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| `lib/utils/error_diagnostics.dart` | 47 | CJK 字符串 | ${match.group(1)}[已隐藏] | (match) => '${match.group(1)}[已隐藏]', |
| `lib/utils/error_diagnostics.dart` | 53 | CJK 字符串 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| `lib/utils/error_diagnostics.dart` | 57 | CJK 字符串 | [路径已隐藏] | (_) => '[路径已隐藏]', |
| `lib/utils/error_diagnostics.dart` | 60 | CJK 字符串 | ${result.substring(0, _maxDetailLength)}\n[详细信息已截断] | result = '${result.substring(0, _maxDetailLength)}\n[详细信息已截断]'; |
| `lib/widgets/native_library_startup_error.dart` | 60 | UI ASCII 字符串 | ${strings.errorSuggestionPrefix}$suggestion | Text('${strings.errorSuggestionPrefix}$suggestion'), |
| `lib/widgets/secure_image_viewer.dart` | 182 | CJK 字符串 | 无法加载图片：${e.message} | ? '无法加载图片：${e.message}' |
| `lib/widgets/secure_image_viewer.dart` | 183 | CJK 字符串 | 无法加载图片：图片解密失败或内容无效 | : '无法加载图片：图片解密失败或内容无效'; |
| `lib/widgets/secure_notepad.dart` | 99 | CJK 字符串 | 读取安全记事本 | operation: '读取安全记事本', |
| `lib/widgets/secure_notepad.dart` | 214 | CJK 字符串 | 无法读取剪贴板：$error | setState(() => _clipboardError = '无法读取剪贴板：$error'); |
| `lib/widgets/secure_notepad.dart` | 231 | CJK 字符串 | 无法清空剪贴板：$error | setState(() => _clipboardError = '无法清空剪贴板：$error'); |
| `lib/widgets/secure_notepad.dart` | 244 | CJK 字符串 | 文件保存成功 | ErrorHelper.showSuccess(context, '文件保存成功'); |
