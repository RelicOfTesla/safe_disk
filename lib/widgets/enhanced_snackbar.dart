import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/error_localizations.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/error_messages.dart';

/// 增强的 SnackBar 组件
///
/// 支持：
/// 1. 显示错误类型
/// 2. 显示建议操作
/// 3. 可复制错误信息
/// 4. 友好的视觉样式
class EnhancedSnackBar extends SnackBar {
  EnhancedSnackBar({
    super.key,
    required ErrorType errorType,
    String? originalError,
    super.duration = const Duration(seconds: 5),
    VoidCallback? onAction,
    String? actionLabel,
  }) : super(
          content: Builder(
            builder: (context) => _buildContent(
              context,
              errorType,
              originalError,
              onAction,
              actionLabel,
            ),
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
    VoidCallback? onAction,
    String? actionLabel,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final error = localizations.errorMessage(errorType);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 错误标题
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

        // 错误描述
        Text(
          error.description,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),

        // 建议操作（如果有）
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
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
        if (onAction != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(actionLabel ?? localizations.viewDetails),
            ),
          ),
        ],
      ],
    );
  }

  /// 显示错误 SnackBar
  static void show(
    BuildContext context, {
    required ErrorType errorType,
    String? originalError,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      EnhancedSnackBar(
        errorType: errorType,
        originalError: originalError,
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

/// 可复制的错误 SnackBar
///
/// 在原有 CopyableSnackBar 基础上，支持错误类型
class CopyableErrorSnackBar extends SnackBar {
  CopyableErrorSnackBar({
    super.key,
    required ErrorType errorType,
    String? originalError,
    super.duration = const Duration(seconds: 6),
  }) : super(
          content: Builder(
            builder: (context) =>
                _buildContent(context, errorType, originalError),
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
  ) {
    final localizations = AppLocalizations.of(context)!;
    final error = localizations.errorMessage(errorType);
    final fullMessage = localizations.errorFullMessage(errorType);

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
