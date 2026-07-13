import 'package:flutter/material.dart';

enum RootDirectoryAction { endSession, removeHistory, deleteDirectory }

Future<RootDirectoryAction?> showRootDirectoryActionDialog({
  required BuildContext context,
  required String directoryName,
  required bool hasActiveSession,
}) {
  return showDialog<RootDirectoryAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('目录操作'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('root-action-end-session'),
              enabled: hasActiveSession,
              leading: const Icon(Icons.lock_outline),
              title: const Text('仅结束会话'),
              subtitle: Text(
                hasActiveSession
                    ? '锁定“$directoryName”，保留侧边栏历史和磁盘目录'
                    : '当前目录已经锁定',
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
              title: const Text('结束会话并移除历史'),
              subtitle: const Text('只从侧边栏移除，本地磁盘目录保持不变'),
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
              title: const Text('结束会话、移除历史并删除目录'),
              subtitle: const Text('永久删除本地加密目录及全部内容，无法撤销'),
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
          child: const Text('取消'),
        ),
      ],
    ),
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
    return AlertDialog(
      title: const Text('永久删除本地目录'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('将永久删除：\n${widget.directoryPath}'),
          const SizedBox(height: 12),
          Text('请输入目录名“$_name”确认：'),
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _controller.text == _name
              ? () => Navigator.pop(context, true)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('永久删除目录'),
        ),
      ],
    );
  }
}
