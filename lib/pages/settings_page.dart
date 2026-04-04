import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Settings page for Safe Disk application
/// 
/// Provides UI for managing:
/// - Default password iteration strength
/// - Session TTL (key cache time)
/// - UI theme
/// - Other preferences
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  
  // Current settings values
  int _keyStrengthMs = SettingsService.defaultKeyStrengthMs;
  int _sessionTTL = SettingsService.defaultSessionTTL;
  String _themeMode = SettingsService.defaultThemeMode;
  bool _showFileExtensions = SettingsService.defaultShowFileExtensions;
  bool _confirmBeforeDelete = SettingsService.defaultConfirmBeforeDelete;
  bool _autoCloseSession = SettingsService.defaultAutoCloseSession;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final keyStrength = await _settingsService.getKeyStrengthMs();
      final sessionTTL = await _settingsService.getSessionTTL();
      final themeMode = await _settingsService.getThemeMode();
      final showFileExtensions = await _settingsService.getShowFileExtensions();
      final confirmBeforeDelete = await _settingsService.getConfirmBeforeDelete();
      final autoCloseSession = await _settingsService.getAutoCloseSession();
      
      if (mounted) {
        setState(() {
          _keyStrengthMs = keyStrength;
          _sessionTTL = sessionTTL;
          _themeMode = themeMode;
          _showFileExtensions = showFileExtensions;
          _confirmBeforeDelete = confirmBeforeDelete;
          _autoCloseSession = autoCloseSession;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载设置失败: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _settingsService.setKeyStrengthMs(_keyStrengthMs);
      await _settingsService.setSessionTTL(_sessionTTL);
      await _settingsService.setThemeMode(_themeMode);
      await _settingsService.setShowFileExtensions(_showFileExtensions);
      await _settingsService.setConfirmBeforeDelete(_confirmBeforeDelete);
      await _settingsService.setAutoCloseSession(_autoCloseSession);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败: $e')),
        );
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确定要恢复默认设置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _settingsService.resetToDefaults();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复默认设置')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: '恢复默认',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Security Settings Section
                _buildSectionHeader('安全设置'),
                _buildKeyStrengthTile(),
                _buildSessionTTLTile(),
                
                const Divider(),
                
                // Appearance Settings Section
                _buildSectionHeader('外观设置'),
                _buildThemeTile(),
                _buildShowFileExtensionsTile(),
                
                const Divider(),
                
                // Behavior Settings Section
                _buildSectionHeader('行为设置'),
                _buildConfirmBeforeDeleteTile(),
                _buildAutoCloseSessionTile(),
                
                const Divider(),
                
                // About Section
                _buildSectionHeader('关于'),
                _buildAboutTile(),
                
                const SizedBox(height: 24),
                
                // Save button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('保存设置'),
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildKeyStrengthTile() {
    return ListTile(
      leading: const Icon(Icons.security),
      title: const Text('默认密码强度'),
      subtitle: Text(_settingsService.getKeyStrengthDisplayName(_keyStrengthMs)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showKeyStrengthDialog(),
    );
  }

  Widget _buildSessionTTLTile() {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('会话有效期'),
      subtitle: Text(_settingsService.getSessionTTLDisplayName(_sessionTTL)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSessionTTLDialog(),
    );
  }

  Widget _buildThemeTile() {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('主题模式'),
      subtitle: Text(_settingsService.getThemeModeDisplayName(_themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(),
    );
  }

  Widget _buildShowFileExtensionsTile() {
    return SwitchListTile(
      secondary: const Icon(Icons.extension),
      title: const Text('显示文件扩展名'),
      subtitle: const Text('在文件列表中显示文件扩展名'),
      value: _showFileExtensions,
      onChanged: (value) {
        setState(() {
          _showFileExtensions = value;
        });
      },
    );
  }

  Widget _buildConfirmBeforeDeleteTile() {
    return SwitchListTile(
      secondary: const Icon(Icons.delete_outline),
      title: const Text('删除前确认'),
      subtitle: const Text('删除文件前显示确认对话框'),
      value: _confirmBeforeDelete,
      onChanged: (value) {
        setState(() {
          _confirmBeforeDelete = value;
        });
      },
    );
  }

  Widget _buildAutoCloseSessionTile() {
    return SwitchListTile(
      secondary: const Icon(Icons.lock_clock),
      title: const Text('自动关闭会话'),
      subtitle: const Text('退出目录时自动关闭加密会话'),
      value: _autoCloseSession,
      onChanged: (value) {
        setState(() {
          _autoCloseSession = value;
        });
      },
    );
  }

  Widget _buildAboutTile() {
    return const ListTile(
      leading: Icon(Icons.info_outline),
      title: Text('Safe Disk'),
      subtitle: Text('版本 1.0.0\n加密文件管理器'),
      isThreeLine: true,
    );
  }

  void _showKeyStrengthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('默认密码强度'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.keyStrengthOptions.entries.map((entry) {
            final isSelected = _keyStrengthMs == entry.value;
            return RadioListTile<int>(
              title: Text(_settingsService.getKeyStrengthDisplayName(entry.value)),
              subtitle: Text(_getKeyStrengthDescription(entry.key)),
              value: entry.value,
              groupValue: _keyStrengthMs,
              selected: isSelected,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _keyStrengthMs = value;
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showSessionTTLDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话有效期'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.sessionTTLOptions.entries.map((entry) {
            final isSelected = _sessionTTL == entry.value;
            return RadioListTile<int>(
              title: Text(_settingsService.getSessionTTLDisplayName(entry.value)),
              subtitle: Text(_getSessionTTLDescription(entry.key)),
              value: entry.value,
              groupValue: _sessionTTL,
              selected: isSelected,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _sessionTTL = value;
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsService.themeModeOptions.map((mode) {
            final isSelected = _themeMode == mode;
            return RadioListTile<String>(
              title: Text(_settingsService.getThemeModeDisplayName(mode)),
              subtitle: Text(_getThemeDescription(mode)),
              value: mode,
              groupValue: _themeMode,
              selected: isSelected,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _themeMode = value;
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getKeyStrengthDescription(String key) {
    switch (key) {
      case 'fast':
        return '快速但安全性较低';
      case 'balanced':
        return '安全性与性能平衡';
      case 'strong':
        return '高安全性，创建目录较慢';
      case 'maximum':
        return '最高安全性，创建目录很慢';
      default:
        return '';
    }
  }

  String _getSessionTTLDescription(String key) {
    switch (key) {
      case '15min':
        return '适合高安全需求';
      case '30min':
        return '平衡安全与便利';
      case '1hour':
        return '推荐选项';
      case '4hours':
        return '适合长时间工作';
      case 'never':
        return '会话永不过期（直到应用关闭）';
      default:
        return '';
    }
  }

  String _getThemeDescription(String mode) {
    switch (mode) {
      case 'system':
        return '跟随系统设置自动切换';
      case 'light':
        return '始终使用亮色主题';
      case 'dark':
        return '始终使用暗色主题';
      default:
        return '';
    }
  }
}
