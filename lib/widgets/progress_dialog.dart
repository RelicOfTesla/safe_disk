import 'package:flutter/material.dart';

/// Progress info for long-running operations
class ProgressInfo {
  final int current;
  final int total;
  final String? currentFileName;
  final String? status;
  final double? estimatedSecondsRemaining;

  const ProgressInfo({
    required this.current,
    required this.total,
    this.currentFileName,
    this.status,
    this.estimatedSecondsRemaining,
  });

  double get progress => total > 0 ? current / total : 0;
  double get progressPercent => progress * 100;
  bool get isComplete => current >= total && total > 0;

  String get formattedTimeRemaining {
    if (estimatedSecondsRemaining == null || estimatedSecondsRemaining! < 0) {
      return '';
    }
    final seconds = estimatedSecondsRemaining!.round();
    if (seconds < 60) {
      return '$seconds 秒';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) {
      return '$minutes 分钟';
    }
    return '$minutes 分 $remainingSeconds 秒';
  }

  ProgressInfo copyWith({
    int? current,
    int? total,
    String? currentFileName,
    String? status,
    double? estimatedSecondsRemaining,
  }) {
    return ProgressInfo(
      current: current ?? this.current,
      total: total ?? this.total,
      currentFileName: currentFileName ?? this.currentFileName,
      status: status ?? this.status,
      estimatedSecondsRemaining:
          estimatedSecondsRemaining ?? this.estimatedSecondsRemaining,
    );
  }
}

/// Progress dialog for long-running operations
///
/// Features:
/// - Progress bar with percentage
/// - Current file name
/// - Processed count / total count
/// - Estimated time remaining (optional)
/// - Cancel button
class ProgressDialog extends StatefulWidget {
  final String title;
  final ProgressInfo progress;
  final bool canCancel;
  final VoidCallback? onCancel;

  const ProgressDialog({
    super.key,
    required this.title,
    required this.progress,
    this.canCancel = true,
    this.onCancel,
  });

  @override
  State<ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<ProgressDialog> {
  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final timeRemaining = progress.formattedTimeRemaining;

    return AlertDialog(
      title: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status text
          if (progress.status != null) ...[
            Text(
              progress.status!,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
          ],

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 8),

          // Progress percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.progressPercent.toStringAsFixed(1)}%',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (timeRemaining.isNotEmpty)
                Text(
                  '预计剩余: $timeRemaining',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // File count
          Text(
            '已处理: ${progress.current} / ${progress.total}',
            style: const TextStyle(fontSize: 13),
          ),

          // Current file name
          if (progress.currentFileName != null) ...[
            const SizedBox(height: 8),
            Text(
              '当前: ${progress.currentFileName}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: [
        if (widget.canCancel && widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('取消'),
          ),
      ],
    );
  }
}

/// Controller for progress dialog
///
/// Usage:
/// ```dart
/// final controller = ProgressController(total: 100);
/// showDialog(
///   context: context,
///   barrierDismissible: false,
///   builder: (context) => ProgressDialog(
///     title: '导出文件',
///     progress: controller.progress,
///     onCancel: () => controller.cancel(),
///   ),
/// );
///
/// // Update progress
/// controller.update(current: 1, currentFileName: 'file1.txt');
///
/// // Check if cancelled
/// if (controller.isCancelled) {
///   return;
/// }
///
/// // Close dialog
/// controller.close(context);
/// ```
class ProgressController extends ChangeNotifier {
  ProgressInfo _progress;
  bool _isCancelled = false;

  ProgressController({
    required int total,
    int current = 0,
    String? currentFileName,
    String? status,
  }) : _progress = ProgressInfo(
          current: current,
          total: total,
          currentFileName: currentFileName,
          status: status,
        );

  ProgressInfo get progress => _progress;
  bool get isCancelled => _isCancelled;
  int get current => _progress.current;
  int get total => _progress.total;

  void update({
    int? current,
    int? total,
    String? currentFileName,
    String? status,
    double? estimatedSecondsRemaining,
  }) {
    _progress = _progress.copyWith(
      current: current,
      total: total,
      currentFileName: currentFileName,
      status: status,
      estimatedSecondsRemaining: estimatedSecondsRemaining,
    );
    notifyListeners();
  }

  void cancel() {
    _isCancelled = true;
    notifyListeners();
  }

  void close(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Calculate estimated time remaining based on processing rate
  void estimateTimeRemaining({
    required DateTime startTime,
    required int processedCount,
  }) {
    if (processedCount <= 0) {
      update(estimatedSecondsRemaining: null);
      return;
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed <= 0) {
      update(estimatedSecondsRemaining: null);
      return;
    }

    final rate = processedCount / elapsed; // items per millisecond
    final remaining = _progress.total - processedCount;
    final estimatedMs = remaining / rate;

    update(estimatedSecondsRemaining: estimatedMs / 1000);
  }
}

/// Helper functions for showing progress dialogs
class ProgressHelper {
  /// Show a progress dialog and return its controller
  static ProgressController showProgressDialog(
    BuildContext context, {
    required String title,
    required int total,
    String? status,
    bool canCancel = true,
    VoidCallback? onCancel,
  }) {
    final controller = ProgressController(
      total: total,
      status: status,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          return ProgressDialog(
            title: title,
            progress: controller.progress,
            canCancel: canCancel,
            onCancel: () {
              controller.cancel();
              if (onCancel != null) {
                onCancel();
              }
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );

    return controller;
  }

  /// Show an indeterminate progress dialog (no progress bar)
  static void showIndeterminateDialog(
    BuildContext context, {
    required String title,
    String? status,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: status != null
            ? Text(status, style: const TextStyle(fontSize: 14))
            : null,
      ),
    );
  }

  /// Hide progress dialog
  static void hideProgressDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}
