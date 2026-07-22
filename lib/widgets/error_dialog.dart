import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/error_localizations.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/error_messages.dart';
import '../services/error_reporting_service.dart';
import '../utils/error_diagnostics.dart';

/// 友好的错误提示对话框
///
/// 显示清晰的错误信息和解决建议
class ErrorDialog extends StatelessWidget {
  final ErrorType errorType;
  final String? originalError;
  final VoidCallback? onRetry;

  const ErrorDialog({
    super.key,
    required this.errorType,
    this.originalError,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final error = localizations.errorMessage(errorType);
    final details = ErrorReportingService.detailedErrorsEnabled &&
            originalError != null &&
            originalError!.isNotEmpty
        ? ErrorDiagnostics.build(
            type: errorType,
            originalError: originalError!,
          )
        : null;

    return AlertDialog(
      icon: Icon(
        error.isCritical ? Icons.error : Icons.warning_amber,
        color: error.isCritical ? Colors.red : Colors.orange,
        size: 48,
      ),
      title: Text(
        error.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 错误描述
          Text(
            error.description,
            style: const TextStyle(fontSize: 14),
          ),

          // 建议操作
          if (error.suggestion != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error.suggestion!,
                      style: const TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 原始错误（仅在调试模式或用户请求时显示）
          if (details != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                localizations.technicalDetails,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              tilePadding: EdgeInsets.zero,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    details,
                    style:
                        const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizations.errorDetailsCopied)),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: Text(localizations.copy),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(localizations.close),
        ),
        if (onRetry != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.retry),
          ),
      ],
    );
  }

  /// 显示错误对话框
  ///
  /// 返回 true 表示用户点击了"重试"，false 表示点击了"关闭"
  static Future<bool> show(
    BuildContext context, {
    required ErrorType errorType,
    String? originalError,
    VoidCallback? onRetry,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ErrorDialog(
        errorType: errorType,
        originalError: originalError,
        onRetry: onRetry,
      ),
    );
    return result ?? false;
  }
}
