import 'package:flutter/material.dart';
import '../models/cryption_config.dart';
import '../models/logical_path.dart';

enum SidebarDirectoryAction { setAlias, clearAlias, directoryActions }

/// Sidebar widget for displaying opened directories
class SidebarWidget extends StatelessWidget {
  final List<EncryptedDirectory> openedDirs;
  final EncryptedDirectory? currentDir;
  final bool drawerPinned;
  final VoidCallback onOpenDirectory;
  final void Function(EncryptedDirectory) onCloseDirectory;
  final void Function(EncryptedDirectory) onSwitchDirectory;
  final void Function(EncryptedDirectory) onRenameDirectory;
  final Future<void> Function(bool) onTogglePin;

  const SidebarWidget({
    super.key,
    required this.openedDirs,
    required this.currentDir,
    required this.drawerPinned,
    required this.onOpenDirectory,
    required this.onCloseDirectory,
    required this.onSwitchDirectory,
    required this.onRenameDirectory,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: Row(
            children: [
              const Icon(Icons.lock, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safe Disk',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${openedDirs.length} directories',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Pin/Unpin button
              IconButton(
                icon: Icon(drawerPinned ? Icons.lock : Icons.lock_open),
                onPressed: () async {
                  await onTogglePin(!drawerPinned);
                  if (!context.mounted) return;
                  if (!drawerPinned && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                tooltip: drawerPinned ? 'Unpin sidebar' : 'Pin sidebar',
              ),
            ],
          ),
        ),

        // Open or create encrypted directory button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (!drawerPinned && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              onOpenDirectory();
            },
            icon: const Icon(Icons.create_new_folder),
            label: const Text('打开/创建加密目录'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),

        const Divider(),

        // List of opened directories
        Expanded(
          child: openedDirs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No directories opened\n\nClick "打开/创建加密目录" to start',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: openedDirs.length,
                  itemBuilder: (context, index) {
                    final dir = openedDirs[index];
                    final isSelected = currentDir?.path == dir.path;

                    final displayName =
                        dir.displayAlias?.trim().isNotEmpty == true
                            ? dir.displayAlias!
                            : logicalPathBasename(dir.path);
                    return GestureDetector(
                      onSecondaryTapDown: (details) async {
                        final action = await showMenu<SidebarDirectoryAction>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: [
                            const PopupMenuItem(
                              value: SidebarDirectoryAction.setAlias,
                              child: Text('设置显示别名'),
                            ),
                            if (dir.displayAlias != null)
                              const PopupMenuItem(
                                value: SidebarDirectoryAction.clearAlias,
                                child: Text('清除显示别名'),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: SidebarDirectoryAction.directoryActions,
                              child: Text('会话与目录操作'),
                            ),
                          ],
                        );
                        if (!context.mounted || action == null) return;
                        switch (action) {
                          case SidebarDirectoryAction.setAlias:
                            onRenameDirectory(dir);
                          case SidebarDirectoryAction.clearAlias:
                            onRenameDirectory(
                              dir.copyWith(clearDisplayAlias: true),
                            );
                          case SidebarDirectoryAction.directoryActions:
                            onCloseDirectory(dir);
                        }
                      },
                      child: Tooltip(
                        message: dir.path,
                        child: ListTile(
                          leading: Icon(
                            Icons.folder,
                            color:
                                dir.isVerified ? Colors.green : Colors.orange,
                          ),
                          title: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            dir.isVerified ? 'Verified' : 'Not verified',
                            style: TextStyle(
                              color:
                                  dir.isVerified ? Colors.green : Colors.orange,
                            ),
                          ),
                          selected: isSelected,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => onCloseDirectory(dir),
                            tooltip: '目录操作',
                          ),
                          onTap: () {
                            if (!drawerPinned && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            onSwitchDirectory(dir);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
