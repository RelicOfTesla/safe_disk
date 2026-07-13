import 'package:flutter/material.dart';

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
  final detail = !allowReplace
      ? '源和目标类型不兼容，或源与目标是同一条目。请选择“保留两者”生成新名称。'
      : isDirectory
          ? '选择“合并并替换”会保留目标目录独有的内容，并替换其中的同名文件。'
          : '选择“替换”会用新内容替换现有文件。';
  final result = await showDialog<EntryConflictResolution>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('目标已存在'),
      content: Text('“$name”已存在，无法直接$operation。\n\n$detail'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            EntryConflictResolution.cancel,
          ),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            EntryConflictResolution.keepBoth,
          ),
          child: const Text('保留两者'),
        ),
        if (allowApplyToAll)
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.keepBothForAll,
            ),
            child: const Text('全部保留两者'),
          ),
        if (allowReplace)
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.replace,
            ),
            child: Text(isDirectory ? '合并并替换' : '替换'),
          ),
        if (allowReplace && allowApplyToAll)
          FilledButton.tonal(
            onPressed: () => Navigator.pop(
              dialogContext,
              EntryConflictResolution.replaceForAll,
            ),
            child: const Text('全部替换'),
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
}) {
  final existing = existingNames.map((name) => name.toLowerCase()).toSet();
  final dot = isDirectory ? -1 : originalName.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < originalName.length - 1;
  final base = hasExtension ? originalName.substring(0, dot) : originalName;
  final extension = hasExtension ? originalName.substring(dot) : '';

  for (var index = 1; index < 10000; index++) {
    final suffix = index == 1 ? ' - 副本' : ' - 副本 ($index)';
    final candidate = '$base$suffix$extension';
    if (!existing.contains(candidate.toLowerCase())) return candidate;
  }
  throw StateError('无法为“$originalName”生成不冲突的名称');
}
