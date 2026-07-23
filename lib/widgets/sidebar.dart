import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../models/logical_path.dart';

enum SidebarDirectoryAction {
  properties,
  changePassword,
  setAlias,
  clearAlias,
  moveUp,
  moveDown,
  directoryActions,
}

/// Sidebar widget for displaying opened directories
class SidebarWidget extends StatefulWidget {
  final List<EncryptedDirectory> openedDirs;
  final EncryptedDirectory? currentDir;
  final bool drawerPinned;
  final VoidCallback onOpenDirectory;
  final void Function(EncryptedDirectory) onCloseDirectory;
  final void Function(EncryptedDirectory) onSwitchDirectory;
  final void Function(EncryptedDirectory) onRenameDirectory;
  final void Function(EncryptedDirectory) onShowProperties;
  final void Function(EncryptedDirectory) onChangePassword;
  final Future<void> Function(EncryptedDirectory)? onMoveDirectoryUp;
  final Future<void> Function(EncryptedDirectory)? onMoveDirectoryDown;
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
    required this.onShowProperties,
    required this.onChangePassword,
    this.onMoveDirectoryUp,
    this.onMoveDirectoryDown,
    required this.onTogglePin,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  String? _contextMenuPath;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
                    Text(
                      strings.appTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      strings.openedDirectoriesCount(widget.openedDirs.length),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Pin/Unpin button
              IconButton(
                icon: Icon(
                  widget.drawerPinned ? Icons.lock : Icons.lock_open,
                ),
                onPressed: () async {
                  await widget.onTogglePin(!widget.drawerPinned);
                  if (!context.mounted) return;
                  if (!widget.drawerPinned && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                tooltip: widget.drawerPinned
                    ? strings.unpinSidebar
                    : strings.pinSidebar,
              ),
            ],
          ),
        ),

        // Open or create encrypted directory button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              if (!widget.drawerPinned && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
              widget.onOpenDirectory();
            },
            icon: const Icon(Icons.create_new_folder),
            label: Text(strings.openOrCreateEncryptedDirectory),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),

        const Divider(),

        // List of opened directories
        Expanded(
          child: widget.openedDirs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      strings.noOpenedDirectories,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.openedDirs.length,
                  itemBuilder: (context, index) {
                    final dir = widget.openedDirs[index];
                    final isSelected = widget.currentDir?.path == dir.path;

                    final displayName =
                        dir.displayAlias?.trim().isNotEmpty == true
                            ? dir.displayAlias!
                            : logicalPathBasename(dir.path);
                    return GestureDetector(
                      onSecondaryTapDown: (details) async {
                        setState(() => _contextMenuPath = dir.path);
                        final action = await showMenu<SidebarDirectoryAction>(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: [
                            PopupMenuItem(
                              value: SidebarDirectoryAction.properties,
                              child: Text(strings.properties),
                            ),
                            PopupMenuItem(
                              value: SidebarDirectoryAction.changePassword,
                              child: Text(strings.changePassword),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: SidebarDirectoryAction.setAlias,
                              child: Text(strings.setAlias),
                            ),
                            if (dir.displayAlias != null)
                              PopupMenuItem(
                                value: SidebarDirectoryAction.clearAlias,
                                child: Text(strings.clearAlias),
                              ),
                            if (widget.onMoveDirectoryUp != null && index > 0)
                              PopupMenuItem(
                                value: SidebarDirectoryAction.moveUp,
                                child: Text(strings.moveDirectoryUp),
                              ),
                            if (widget.onMoveDirectoryDown != null &&
                                index < widget.openedDirs.length - 1)
                              PopupMenuItem(
                                value: SidebarDirectoryAction.moveDown,
                                child: Text(strings.moveDirectoryDown),
                              ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: SidebarDirectoryAction.directoryActions,
                              child: Text(strings.closeOrRemoveDirectory),
                            ),
                          ],
                        );
                        if (!context.mounted) return;
                        setState(() => _contextMenuPath = null);
                        if (action == null) return;
                        switch (action) {
                          case SidebarDirectoryAction.properties:
                            widget.onShowProperties(dir);
                          case SidebarDirectoryAction.changePassword:
                            widget.onChangePassword(dir);
                          case SidebarDirectoryAction.setAlias:
                            widget.onRenameDirectory(dir);
                          case SidebarDirectoryAction.clearAlias:
                            widget.onRenameDirectory(
                              dir.copyWith(clearDisplayAlias: true),
                            );
                          case SidebarDirectoryAction.moveUp:
                            await widget.onMoveDirectoryUp?.call(dir);
                          case SidebarDirectoryAction.moveDown:
                            await widget.onMoveDirectoryDown?.call(dir);
                          case SidebarDirectoryAction.directoryActions:
                            widget.onCloseDirectory(dir);
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
                            dir.isVerified
                                ? strings.directoryUnlocked
                                : strings.directoryNeedsPassword,
                            style: TextStyle(
                              color:
                                  dir.isVerified ? Colors.green : Colors.orange,
                            ),
                          ),
                          selected: isSelected || _contextMenuPath == dir.path,
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => widget.onCloseDirectory(dir),
                            tooltip: strings.moreDirectoryActions,
                          ),
                          onTap: () {
                            if (!widget.drawerPinned &&
                                Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            widget.onSwitchDirectory(dir);
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
