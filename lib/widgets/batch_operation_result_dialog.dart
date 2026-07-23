import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/batch_operation_result.dart';

Future<void> showBatchOperationResultDialog({
  required BuildContext context,
  required String operation,
  required BatchOperationResult result,
}) {
  final strings = AppLocalizations.of(context)!;
  final title = result.cancelled
      ? strings.batchOperationCancelled(operation)
      : result.failed > 0
          ? strings.batchOperationPartiallyCompleted(operation)
          : strings.batchOperationCompleted(operation);
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
              Text(strings.batchTotal(result.total)),
              Text(strings.batchSucceeded(result.succeeded)),
              Text(strings.batchSkipped(result.skipped)),
              Text(strings.batchFailed(result.failed)),
              Text(strings.batchUnprocessed(result.unprocessed)),
              Text(strings.batchClipboardRemaining(result.remaining)),
              if (result.failures.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  strings.failureDetails,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                for (final failure in result.failures.take(10))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(strings.batchFailureItem(
                      failure.name,
                      failure.reason,
                    )),
                  ),
                if (result.failures.length > 10)
                  Text(strings.additionalFailures(result.failures.length - 10)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(strings.close),
        ),
      ],
    ),
  );
}
