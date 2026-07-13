import 'package:flutter/material.dart';

import '../models/batch_operation_result.dart';

Future<void> showBatchOperationResultDialog({
  required BuildContext context,
  required String operation,
  required BatchOperationResult result,
}) {
  final title = result.cancelled
      ? '$operation已取消'
      : result.failed > 0
          ? '$operation部分完成'
          : '$operation完成';
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('总数：${result.total}'),
              Text('成功：${result.succeeded}'),
              Text('跳过：${result.skipped}'),
              Text('失败：${result.failed}'),
              Text('未处理：${result.unprocessed}'),
              Text('剪贴板剩余：${result.remaining}'),
              if (result.failures.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '失败详情',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                for (final failure in result.failures.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('“${failure.name}”：${failure.reason}'),
                  ),
                if (result.failures.length > 10)
                  Text('另有 ${result.failures.length - 10} 项失败'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
