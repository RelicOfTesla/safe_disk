import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

enum RootDirectoryAction { endSession, removeHistory, deleteDirectory }

Future<RootDirectoryAction?> showRootDirectoryActionDialog({
  required BuildContext context,
  required String directoryName,
  required bool hasActiveSession,
}) {
  return showDialog<RootDirectoryAction>(
    context: context,
    builder: (dialogContext) {
      final strings = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        title: Text(strings.rootDirectoryActions),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('root-action-end-session'),
                enabled: hasActiveSession,
                leading: const Icon(Icons.lock_outline),
                title: Text(strings.endSessionOnly),
                subtitle: Text(
                  hasActiveSession
                      ? strings.endSessionDescription(directoryName)
                      : strings.directoryAlreadyLocked,
                ),
                onTap: hasActiveSession
                    ? () => Navigator.pop(
                          dialogContext,
                          RootDirectoryAction.endSession,
                        )
                    : null,
              ),
              ListTile(
                key: const Key('root-action-remove-history'),
                leading: const Icon(Icons.playlist_remove),
                title: Text(strings.endSessionAndRemoveHistory),
                subtitle: Text(strings.removeHistoryDescription),
                onTap: () => Navigator.pop(
                  dialogContext,
                  RootDirectoryAction.removeHistory,
                ),
              ),
              ListTile(
                key: const Key('root-action-delete-directory'),
                leading: const Icon(Icons.delete_forever_outlined),
                iconColor: Theme.of(context).colorScheme.error,
                textColor: Theme.of(context).colorScheme.error,
                title: Text(strings.endSessionRemoveHistoryAndDelete),
                subtitle: Text(strings.deleteDirectoryDescription),
                onTap: () => Navigator.pop(
                  dialogContext,
                  RootDirectoryAction.deleteDirectory,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
        ],
      );
    },
  );
}

Future<bool> confirmRootDirectoryDeletion({
  required BuildContext context,
  required String directoryPath,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _RootDirectoryDeletionDialog(
      directoryPath: directoryPath,
    ),
  );
  return confirmed == true;
}

class _RootDirectoryDeletionDialog extends StatefulWidget {
  const _RootDirectoryDeletionDialog({required this.directoryPath});

  final String directoryPath;

  @override
  State<_RootDirectoryDeletionDialog> createState() =>
      _RootDirectoryDeletionDialogState();
}

class _RootDirectoryDeletionDialogState
    extends State<_RootDirectoryDeletionDialog> {
  final TextEditingController _controller = TextEditingController();

  String get _name =>
      widget.directoryPath.replaceAll('\\', '/').split('/').last;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.permanentlyDeleteLocalDirectory),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.willPermanentlyDelete),
          const SizedBox(height: 4),
          SelectableText(widget.directoryPath),
          const SizedBox(height: 12),
          Text(strings.enterDirectoryNameToConfirm(_name)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('root-delete-confirmation'),
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _controller.text == _name
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(strings.permanentlyDeleteDirectory),
        ),
      ],
    );
  }
}
