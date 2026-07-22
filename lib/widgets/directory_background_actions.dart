import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'file_item_actions.dart';

enum DirectoryBackgroundAction {
  newFile,
  newDirectory,
  paste,
  refresh,
}

Future<DirectoryBackgroundAction?> showDirectoryBackgroundContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required bool canPaste,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final actions = [
    DirectoryBackgroundAction.newFile,
    DirectoryBackgroundAction.newDirectory,
    if (canPaste) DirectoryBackgroundAction.paste,
    DirectoryBackgroundAction.refresh,
  ];
  return showMenu<DirectoryBackgroundAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    ),
    items: actions
        .map(
          (action) => PopupMenuItem<DirectoryBackgroundAction>(
            value: action,
            child: Row(
              children: [
                Icon(_actionIcon(action), size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child:
                      Text(_actionLabel(AppLocalizations.of(context)!, action)),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

Future<String?> showCreateEntryDialog({
  required BuildContext context,
  required bool isDirectory,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) {
      final strings = AppLocalizations.of(context)!;
      return _CreateEntryDialog(
        isDirectory: isDirectory,
        initialName: isDirectory
            ? strings.newDirectoryDefaultName
            : strings.newFileDefaultName,
      );
    },
  );
}

String _actionLabel(
        AppLocalizations strings, DirectoryBackgroundAction action) =>
    switch (action) {
      DirectoryBackgroundAction.newFile => strings.newFile,
      DirectoryBackgroundAction.newDirectory => strings.newDirectory,
      DirectoryBackgroundAction.paste => strings.pasteToCurrentDirectory,
      DirectoryBackgroundAction.refresh => strings.refresh,
    };

IconData _actionIcon(DirectoryBackgroundAction action) => switch (action) {
      DirectoryBackgroundAction.newFile => Icons.note_add_outlined,
      DirectoryBackgroundAction.newDirectory =>
        Icons.create_new_folder_outlined,
      DirectoryBackgroundAction.paste => Icons.content_paste_go_outlined,
      DirectoryBackgroundAction.refresh => Icons.refresh,
    };

class _CreateEntryDialog extends StatefulWidget {
  const _CreateEntryDialog({
    required this.isDirectory,
    required this.initialName,
  });

  final bool isDirectory;
  final String initialName;

  @override
  State<_CreateEntryDialog> createState() => _CreateEntryDialogState();
}

class _CreateEntryDialogState extends State<_CreateEntryDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.isDirectory
            ? widget.initialName.length
            : widget.initialName
                .lastIndexOf('.')
                .clamp(0, widget.initialName.length),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validateFileItemName(_controller.text);
    if (error != null) {
      setState(() {
        _error =
            fileItemNameValidationMessage(AppLocalizations.of(context)!, error);
      });
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.isDirectory ? strings.newDirectory : strings.newFile),
      content: TextField(
        key: const Key('create-entry-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(labelText: strings.name, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(strings.create),
        ),
      ],
    );
  }
}
