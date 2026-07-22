import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

enum EntryConflictResolution {
  cancel,
  keepBoth,
  replace,
  keepBothForAll,
  replaceForAll,
}

enum EntryConflictPolicy { ask, keepBoth, replace }

class EntryConflictSession {
  EntryConflictPolicy _policy = EntryConflictPolicy.ask;

  EntryConflictPolicy get policy => _policy;

  EntryConflictResolution? automaticResolution({required bool allowReplace}) {
    return switch (_policy) {
      EntryConflictPolicy.ask => null,
      EntryConflictPolicy.keepBoth => EntryConflictResolution.keepBoth,
      EntryConflictPolicy.replace when allowReplace =>
        EntryConflictResolution.replace,
      EntryConflictPolicy.replace => null,
    };
  }

  EntryConflictResolution apply(EntryConflictResolution resolution) {
    switch (resolution) {
      case EntryConflictResolution.keepBothForAll:
        _policy = EntryConflictPolicy.keepBoth;
        return EntryConflictResolution.keepBoth;
      case EntryConflictResolution.replaceForAll:
        _policy = EntryConflictPolicy.replace;
        return EntryConflictResolution.replace;
      case EntryConflictResolution.cancel:
      case EntryConflictResolution.keepBoth:
      case EntryConflictResolution.replace:
        return resolution;
    }
  }
}

Future<EntryConflictResolution> showEntryConflictDialog({
  required BuildContext context,
  required String name,
  required bool isDirectory,
  required String operation,
  bool allowReplace = true,
  bool allowApplyToAll = false,
}) async {
  final strings = AppLocalizations.of(context)!;
  final detail = !allowReplace
      ? strings.conflictReplacementUnavailable
      : isDirectory
          ? strings.conflictDirectoryReplaceDetail
          : strings.conflictFileReplaceDetail;
  final result = await showDialog<EntryConflictResolution>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.conflictTargetExists),
      content: Text(strings.conflictDescription(name, operation, detail)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            EntryConflictResolution.cancel,
          ),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            EntryConflictResolution.keepBoth,
          ),
          child: Text(strings.keepBoth),
        ),
        if (allowApplyToAll)
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.keepBothForAll,
            ),
            child: Text(strings.keepBothForAll),
          ),
        if (allowReplace)
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.replace,
            ),
            child:
                Text(isDirectory ? strings.mergeAndReplace : strings.replace),
          ),
        if (allowReplace && allowApplyToAll)
          FilledButton.tonal(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.replaceForAll,
            ),
            child: Text(strings.replaceForAll),
          ),
      ],
    ),
  );
  return result ?? EntryConflictResolution.cancel;
}

String nextAvailableEntryName({
  required String originalName,
  required bool isDirectory,
  required Iterable<String> existingNames,
  required String copyLabel,
}) {
  final existing = existingNames.map((name) => name.toLowerCase()).toSet();
  final dot = isDirectory ? -1 : originalName.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < originalName.length - 1;
  final base = hasExtension ? originalName.substring(0, dot) : originalName;
  final extension = hasExtension ? originalName.substring(dot) : '';

  for (var index = 1; index < 10000; index++) {
    final suffix = index == 1 ? ' - $copyLabel' : ' - $copyLabel ($index)';
    final candidate = '$base$suffix$extension';
    if (!existing.contains(candidate.toLowerCase())) return candidate;
  }
  throw StateError('no-conflict-free-entry-name');
}
