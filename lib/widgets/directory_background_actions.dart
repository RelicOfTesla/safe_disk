import 'package:flutter/material.dart';

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
                Text(_actionLabel(action)),
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
    builder: (_) => _CreateEntryDialog(isDirectory: isDirectory),
  );
}

String _actionLabel(DirectoryBackgroundAction action) => switch (action) {
      DirectoryBackgroundAction.newFile => '新建文件',
      DirectoryBackgroundAction.newDirectory => '新建目录',
      DirectoryBackgroundAction.paste => '粘贴到当前目录',
      DirectoryBackgroundAction.refresh => '刷新',
    };

IconData _actionIcon(DirectoryBackgroundAction action) => switch (action) {
      DirectoryBackgroundAction.newFile => Icons.note_add_outlined,
      DirectoryBackgroundAction.newDirectory =>
        Icons.create_new_folder_outlined,
      DirectoryBackgroundAction.paste => Icons.content_paste_go_outlined,
      DirectoryBackgroundAction.refresh => Icons.refresh,
    };

class _CreateEntryDialog extends StatefulWidget {
  const _CreateEntryDialog({required this.isDirectory});

  final bool isDirectory;

  @override
  State<_CreateEntryDialog> createState() => _CreateEntryDialogState();
}

class _CreateEntryDialogState extends State<_CreateEntryDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.isDirectory ? '新建目录' : '新建文件.txt',
    )..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.isDirectory ? 4 : 4,
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
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isDirectory ? '新建目录' : '新建文件'),
      content: TextField(
        key: const Key('create-entry-name'),
        controller: _controller,
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(labelText: '名称', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }
}
