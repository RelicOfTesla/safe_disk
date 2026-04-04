import 'package:flutter/material.dart';
import '../models/cryption_config.dart';
import '../pages/settings_page.dart';

/// Sidebar widget for displaying opened directories
class SidebarWidget extends StatelessWidget {
  final List<EncryptedDirectory> openedDirs;
  final EncryptedDirectory? currentDir;
  final bool drawerPinned;
  final VoidCallback onOpenDirectory;
  final void Function(EncryptedDirectory) onCloseDirectory;
  final void Function(EncryptedDirectory) onSwitchDirectory;
  final Future<void> Function(bool) onTogglePin;

  const SidebarWidget({
    super.key,
    required this.openedDirs,
    required this.currentDir,
    required this.drawerPinned,
    required this.onOpenDirectory,
    required this.onCloseDirectory,
    required this.onSwitchDirectory,
    required this.onTogglePin,
  });

  void _openSettings(BuildContext context) {
    // Close drawer if not pinned
    if (!drawerPinned && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Use post-frame callback to avoid async gap warning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    });
  }

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
                  // Check if we can pop before async gap
                  final canPop = Navigator.canPop(context);
                  await onTogglePin(!drawerPinned);
                  if (!drawerPinned && canPop) {
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
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

                    return ListTile(
                      leading: Icon(
                        Icons.folder,
                        color: dir.isVerified ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        dir.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        dir.isVerified ? 'Verified' : 'Not verified',
                        style: TextStyle(
                          color: dir.isVerified ? Colors.green : Colors.orange,
                        ),
                      ),
                      selected: isSelected,
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => onCloseDirectory(dir),
                      ),
                      onTap: () {
                        if (!drawerPinned && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                        onSwitchDirectory(dir);
                      },
                    );
                  },
                ),
        ),

        // Settings button at bottom
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('设置'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openSettings(context),
          ),
        ),
      ],
    );
  }
}
