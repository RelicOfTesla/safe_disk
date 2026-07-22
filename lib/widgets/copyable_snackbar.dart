import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/error_localizations.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/error_messages.dart';
import '../services/error_reporting_service.dart';
import '../utils/error_diagnostics.dart';

/// A SnackBar with a copy button for error messages
class CopyableSnackBar extends SnackBar {
  CopyableSnackBar({
    super.key,
    required String message,
    bool isError = false,
    super.duration = const Duration(seconds: 4),
  }) : super(
          content: Builder(
            builder: (context) => Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(50, 30),
                  ),
                  child: Text(AppLocalizations.of(context)!.copy),
                ),
              ],
            ),
          ),
          backgroundColor: isError ? Colors.red[700] : null,
          behavior: SnackBarBehavior.floating,
        );
}

/// 错误提示 SnackBar（支持错误类型）
class ErrorSnackBar extends SnackBar {
  ErrorSnackBar({
    super.key,
    required ErrorType errorType,
    String? originalError,
    String? operation,
    super.duration = const Duration(seconds: 6),
  }) : super(
          content: Builder(
            builder: (context) =>
                _buildContent(context, errorType, originalError, operation),
          ),
          backgroundColor: ErrorMessages.isCritical(errorType)
              ? Colors.red[700]
              : Colors.orange[700],
          behavior: SnackBarBehavior.floating,
        );

  static Widget _buildContent(
    BuildContext context,
    ErrorType errorType,
    String? originalError,
    String? operation,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final error = localizations.errorMessage(errorType);
    final details = ErrorReportingService.detailedErrorsEnabled &&
            originalError != null &&
            originalError.isNotEmpty
        ? ErrorDiagnostics.build(
            type: errorType,
            originalError: originalError,
            labels: localizations.errorDiagnosticsLabels(),
            operation: operation,
          )
        : null;
    final fullMessage = [
      localizations.errorFullMessage(errorType),
      if (details != null) details,
    ].join('\n\n');

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    error.isCritical ? Icons.error : Icons.warning_amber,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                error.description,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              if (error.suggestion != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${localizations.errorSuggestionPrefix}${error.suggestion}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(
                  details,
                  key: const Key('error-technical-details'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: fullMessage));
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(50, 30),
          ),
          child: Text(localizations.copy),
        ),
      ],
    );
  }
}

/// 错误提示辅助工具
class ErrorHelper {
  /// 显示错误 SnackBar
  static void showError(
    BuildContext context, {
    required ErrorType errorType,
    String? originalError,
    String? operation,
    Duration duration = const Duration(seconds: 6),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      ErrorSnackBar(
        errorType: errorType,
        originalError: originalError,
        operation: operation,
        duration: duration,
      ),
    );
  }

  /// 显示成功 SnackBar
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// 显示信息 SnackBar
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }
}
