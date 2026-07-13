import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../utils/error_messages.dart';
import '../models/create_root_options.dart';
import '../widgets/copyable_snackbar.dart';

/// Welcome guide dialog for first-time users
class WelcomeGuideDialog extends StatefulWidget {
  final Function(bool neverShowAgain)? onComplete;

  const WelcomeGuideDialog({super.key, this.onComplete});

  @override
  State<WelcomeGuideDialog> createState() => _WelcomeGuideDialogState();
}

class _WelcomeGuideDialogState extends State<WelcomeGuideDialog> {
  int _currentPage = 0;
  bool _neverShowAgain = false;

  final List<_GuidePage> _pages = const [
    _GuidePage(
      icon: Icons.lock_outline,
      iconColor: Colors.blue,
      title: '欢迎使用 Safe Disk',
      content: '''Safe Disk 是一款安全的加密文件管理器，帮助您保护私密数据。

所有文件都使用 AES-256-GCM 加密算法保护，确保只有您能访问。''',
    ),
    _GuidePage(
      icon: Icons.folder_special,
      iconColor: Colors.orange,
      title: '加密目录',
      content: '''创建加密目录来保护您的文件：

• 打开目录：打开已有的加密目录
• 创建目录：创建新的加密目录

加密目录中的所有文件都会自动加密保护。''',
    ),
    _GuidePage(
      icon: Icons.insert_drive_file,
      iconColor: Colors.green,
      title: '核心功能',
      content: '''• 文件浏览：浏览和管理加密目录中的文件
• 安全记事本：编辑文本文件（.txt, .md）
• 图片浏览器：查看加密的图片文件
• 批量导出：选择多个文件一次性导出''',
    ),
    _GuidePage(
      icon: Icons.security,
      iconColor: Colors.red,
      title: '安全提示',
      content: '''• 请牢记密码！密码丢失后无法恢复文件
• 建议使用强密码（12位以上，混合字符）
• 密钥仅在内存中缓存，关闭应用后自动清除
• 定期备份重要加密目录''',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      setState(() => _currentPage++);
    } else {
      _complete();
    }
  }

  void _skip() {
    _complete();
  }

  void _complete() {
    widget.onComplete?.call(_neverShowAgain);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return AlertDialog(
      title: Row(
        children: [
          Icon(page.icon, color: page.iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              page.title,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.content,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          // Page indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentPage
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // "Don't show again" checkbox (only on last page)
          if (_currentPage == _pages.length - 1)
            Row(
              children: [
                Checkbox(
                  value: _neverShowAgain,
                  onChanged: (value) {
                    setState(() => _neverShowAgain = value ?? false);
                  },
                ),
                const Expanded(
                  child: Text(
                    '不再显示此引导',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _skip,
          child: const Text('跳过'),
        ),
        ElevatedButton(
          onPressed: _nextPage,
          child: Text(_currentPage < _pages.length - 1 ? '下一步' : '开始使用'),
        ),
      ],
    );
  }
}

class _GuidePage {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _GuidePage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });
}

/// Dialog for creating encrypted directory

/// Dialog for creating encrypted directory
class CreateEncryptedDirectoryDialog extends StatefulWidget {
  const CreateEncryptedDirectoryDialog({super.key});

  @override
  State<CreateEncryptedDirectoryDialog> createState() =>
      _CreateEncryptedDirectoryDialogState();
}

class _CreateEncryptedDirectoryDialogState
    extends State<CreateEncryptedDirectoryDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showAdvanced = false;
  String _dataFactory = 'aes-ctr';
  String _nameFactory = 'aes-gcm-name';
  String _deriverFactory = 'argon2id';
  int _keyStrengthMs = 1000;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建加密目录'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: '密码',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: '确认密码',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('高级加密参数'),
                subtitle: const Text('默认配置适合大多数用户'),
                value: _showAdvanced,
                onChanged: (value) => setState(() => _showAdvanced = value),
              ),
              if (_showAdvanced) ...[
                _algorithmDropdown(
                  label: '数据加密',
                  value: _dataFactory,
                  values: CreateRootRequest.dataFactories,
                  onChanged: (value) => setState(() => _dataFactory = value),
                ),
                _algorithmDropdown(
                  label: '文件名加密',
                  value: _nameFactory,
                  values: CreateRootRequest.nameFactories,
                  onChanged: (value) => setState(() => _nameFactory = value),
                ),
                _algorithmDropdown(
                  label: '密码派生',
                  value: _deriverFactory,
                  values: CreateRootRequest.deriverFactories,
                  onChanged: (value) => setState(() => _deriverFactory = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _keyStrengthMs,
                  decoration: const InputDecoration(labelText: '派生强度'),
                  items: CreateRootRequest.keyStrengthOptions
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value 毫秒'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _keyStrengthMs = value);
                  },
                ),
                if (_nameFactory == 'none')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('注意：选择 none 后，文件名和目录名不会加密。'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            final password = _passwordController.text;
            final confirm = _confirmController.text;

            if (password.isEmpty) {
              ErrorHelper.showError(
                context,
                errorType: ErrorType.passwordEmpty,
              );
              return;
            }

            if (password != confirm) {
              ErrorHelper.showError(
                context,
                errorType: ErrorType.passwordMismatch,
              );
              return;
            }

            Navigator.pop(
              context,
              CreateRootRequest(
                password: password,
                dataFactory: _dataFactory,
                nameFactory: _nameFactory,
                deriverFactory: _deriverFactory,
                keyStrengthMs: _keyStrengthMs,
              ),
            );
          },
          child: const Text('创建'),
        ),
      ],
    );
  }

  Widget _algorithmDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}

/// Dialog for selecting directory path with manual input support
class PathSelectionDialog extends StatefulWidget {
  final String? initialPath;

  const PathSelectionDialog({super.key, this.initialPath});

  @override
  State<PathSelectionDialog> createState() => _PathSelectionDialogState();
}

class _PathSelectionDialogState extends State<PathSelectionDialog> {
  final _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.initialPath ?? '';
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browseDirectory() async {
    final String? selectedPath = await getDirectoryPath();
    if (selectedPath != null && selectedPath.isNotEmpty) {
      setState(() {
        _pathController.text = selectedPath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Directory'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pathController,
            decoration: InputDecoration(
              labelText: 'Directory Path',
              hintText: 'Enter or browse for directory',
              suffixIcon: IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _browseDirectory,
                tooltip: 'Browse',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final path = _pathController.text.trim();
            if (path.isEmpty) {
              ErrorHelper.showError(
                context,
                errorType: ErrorType.pathEmpty,
              );
              return;
            }

            Navigator.pop(context, path);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Dialog for confirming directory deletion
enum DeleteDirectoryAction {
  removeFromSidebar,
  deleteFromDisk,
  cancel,
}

class DeleteDirectoryDialog extends StatelessWidget {
  final String directoryPath;
  final String directoryName;

  const DeleteDirectoryDialog({
    super.key,
    required this.directoryPath,
    required this.directoryName,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('确认删除'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '您即将从侧边栏移除加密目录：',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    directoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '请选择操作：',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• 仅从侧边栏移除：保留磁盘目录和加密文件',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            '• 同时删除磁盘目录：永久删除目录及所有文件',
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
        ],
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.pop(context, DeleteDirectoryAction.cancel),
          child: const Text('取消'),
        ),
        // Remove from sidebar only
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(context, DeleteDirectoryAction.removeFromSidebar),
          child: const Text('仅移除'),
        ),
        // Delete from disk (dangerous)
        TextButton(
          onPressed: () =>
              Navigator.pop(context, DeleteDirectoryAction.deleteFromDisk),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('删除磁盘目录'),
        ),
      ],
    );
  }
}
