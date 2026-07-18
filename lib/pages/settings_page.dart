import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/error_reporting_service.dart';

enum _LeaveAction { cancel, discard, save }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.settingsService,
    this.onThemeModeChanged,
  });

  final SettingsService? settingsService;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settingsService;
  String _themeMode = SettingsService.defaultThemeMode;
  bool _confirmBeforeDelete = SettingsService.defaultConfirmBeforeDelete;
  bool _autoLockOnBackground = SettingsService.defaultAutoCloseSession;
  int _notepadAutoSaveSeconds = SettingsService.defaultNotepadAutoSaveSeconds;
  bool _notepadDefaultReadOnly = SettingsService.defaultNotepadReadOnly;
  bool _notepadDefaultMonitorClipboard =
      SettingsService.defaultNotepadMonitorClipboard;
  bool _detailedErrorReports = SettingsService.defaultDetailedErrorReports;
  _SettingsSnapshot? _saved;
  bool _isLoading = true;
  bool _allowPop = false;

  bool get _isDirty => _saved != null && _current != _saved;

  _SettingsSnapshot get _current => _SettingsSnapshot(
        themeMode: _themeMode,
        confirmBeforeDelete: _confirmBeforeDelete,
        autoLockOnBackground: _autoLockOnBackground,
        notepadAutoSaveSeconds: _notepadAutoSaveSeconds,
        notepadDefaultReadOnly: _notepadDefaultReadOnly,
        notepadDefaultMonitorClipboard: _notepadDefaultMonitorClipboard,
        detailedErrorReports: _detailedErrorReports,
      );

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? SettingsService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final snapshot = _SettingsSnapshot(
        themeMode: await _settingsService.getThemeMode(),
        confirmBeforeDelete: await _settingsService.getConfirmBeforeDelete(),
        autoLockOnBackground: await _settingsService.getAutoCloseSession(),
        notepadAutoSaveSeconds:
            await _settingsService.getNotepadAutoSaveSeconds(),
        notepadDefaultReadOnly:
            await _settingsService.getNotepadDefaultReadOnly(),
        notepadDefaultMonitorClipboard:
            await _settingsService.getNotepadDefaultMonitorClipboard(),
        detailedErrorReports: await _settingsService.getDetailedErrorReports(),
      );
      if (!mounted) return;
      setState(() {
        _themeMode = snapshot.themeMode;
        _confirmBeforeDelete = snapshot.confirmBeforeDelete;
        _autoLockOnBackground = snapshot.autoLockOnBackground;
        _notepadAutoSaveSeconds = snapshot.notepadAutoSaveSeconds;
        _notepadDefaultReadOnly = snapshot.notepadDefaultReadOnly;
        _notepadDefaultMonitorClipboard =
            snapshot.notepadDefaultMonitorClipboard;
        _detailedErrorReports = snapshot.detailedErrorReports;
        _saved = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载设置失败：$error')),
      );
    }
  }

  Future<bool> _saveSettings() async {
    try {
      await _settingsService.setThemeMode(_themeMode);
      await _settingsService.setConfirmBeforeDelete(_confirmBeforeDelete);
      await _settingsService.setAutoCloseSession(_autoLockOnBackground);
      await _settingsService.setNotepadAutoSaveSeconds(_notepadAutoSaveSeconds);
      await _settingsService.setNotepadDefaultReadOnly(
        _notepadDefaultReadOnly,
      );
      await _settingsService.setNotepadDefaultMonitorClipboard(
        _notepadDefaultMonitorClipboard,
      );
      await _settingsService.setDetailedErrorReports(_detailedErrorReports);
      ErrorReportingService.configure(
        detailedErrorsEnabled: _detailedErrorReports,
      );
      if (!mounted) return false;
      setState(() => _saved = _current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存设置失败：$error')),
        );
      }
      return false;
    }
  }

  Future<void> _requestLeave() async {
    if (!_isDirty) {
      _popAfterRebuild();
      return;
    }
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存设置更改？'),
        content: const Text('当前修改尚未保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveAction.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveAction.discard),
            child: const Text('放弃修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, _LeaveAction.save),
            child: const Text('保存并返回'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == _LeaveAction.cancel) return;
    if (action == _LeaveAction.save && !await _saveSettings()) return;
    if (action == _LeaveAction.discard) {
      widget.onThemeModeChanged?.call(_themeModeValue(_saved!.themeMode));
    }
    _popAfterRebuild();
  }

  void _popAfterRebuild() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _setTheme(String mode) {
    setState(() => _themeMode = mode);
    widget.onThemeModeChanged?.call(_themeModeValue(mode));
  }

  void _resetToDefaults() {
    setState(() {
      _themeMode = SettingsService.defaultThemeMode;
      _confirmBeforeDelete = SettingsService.defaultConfirmBeforeDelete;
      _notepadAutoSaveSeconds = SettingsService.defaultNotepadAutoSaveSeconds;
      _notepadDefaultReadOnly = SettingsService.defaultNotepadReadOnly;
      _notepadDefaultMonitorClipboard =
          SettingsService.defaultNotepadMonitorClipboard;
      _detailedErrorReports = SettingsService.defaultDetailedErrorReports;
    });
    widget.onThemeModeChanged?.call(ThemeMode.system);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _requestLeave,
            icon: const Icon(Icons.arrow_back),
            tooltip: '返回',
          ),
          title: const Text('设置'),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
              tooltip: '恢复默认设置（未保存）',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final sections = [
                    _appearanceCard(),
                    _behaviorCard(),
                    _aboutCard(),
                  ];
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        key: const Key('settings-content'),
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          children: [
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: sections[0]),
                                  const SizedBox(width: 20),
                                  Expanded(child: sections[1]),
                                ],
                              )
                            else ...[
                              sections[0],
                              const SizedBox(height: 16),
                              sections[1],
                            ],
                            const SizedBox(height: 16),
                            sections[2],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isDirty ? _saveSettings : null,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(
                                  _isDirty ? '保存设置' : '已保存',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _appearanceCard() => _sectionCard(
        key: const Key('settings-appearance'),
        title: '外观',
        icon: Icons.palette_outlined,
        children: [
          SegmentedButton<String>(
            segments: SettingsService.themeModeOptions
                .map(
                  (mode) => ButtonSegment<String>(
                    value: mode,
                    label: Text(_settingsService.getThemeModeDisplayName(mode)),
                  ),
                )
                .toList(),
            selected: {_themeMode},
            onSelectionChanged: (selection) => _setTheme(selection.single),
          ),
          const SizedBox(height: 10),
          const Text('主题会立即预览；保存后会在下次启动时保留。'),
        ],
      );

  Widget _behaviorCard() => _sectionCard(
        key: const Key('settings-behavior'),
        title: '行为',
        icon: Icons.tune,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('删除前确认'),
            subtitle: const Text('删除文件前显示确认对话框'),
            value: _confirmBeforeDelete,
            onChanged: (value) => setState(() => _confirmBeforeDelete = value),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('auto-lock-on-background'),
            contentPadding: EdgeInsets.zero,
            title: const Text('应用隐藏时自动锁定'),
            subtitle: const Text(
              '仅锁定没有内容窗口、未保存修改或活动写入的目录；其他目录不会被强制关闭',
            ),
            value: _autoLockOnBackground,
            onChanged: (value) => setState(() => _autoLockOnBackground = value),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('安全草稿保存间隔'),
            subtitle: const Text('定时写入同目录加密草稿，不覆盖原文件'),
            trailing: DropdownButton<int>(
              value: _notepadAutoSaveSeconds,
              items: SettingsService.notepadAutoSaveOptions
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text(
                        _settingsService.getNotepadAutoSaveDisplayName(seconds),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _notepadAutoSaveSeconds = value);
                }
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('notepad-default-read-only'),
            contentPadding: EdgeInsets.zero,
            title: const Text('记事本默认只读'),
            subtitle: const Text('新打开的文件先以只读方式显示，可手动开始编辑'),
            value: _notepadDefaultReadOnly,
            onChanged: (value) =>
                setState(() => _notepadDefaultReadOnly = value),
          ),
          SwitchListTile(
            key: const Key('notepad-default-monitor-clipboard'),
            contentPadding: EdgeInsets.zero,
            title: const Text('默认监视剪贴板'),
            subtitle: const Text('仅显示短文本预览，不写入文件或设置'),
            value: _notepadDefaultMonitorClipboard,
            onChanged: (value) =>
                setState(() => _notepadDefaultMonitorClipboard = value),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('detailed-error-reports'),
            contentPadding: EdgeInsets.zero,
            title: const Text('显示详细错误信息'),
            subtitle: const Text('在错误提示中显示经脱敏的操作阶段与底层错误；不会写入磁盘日志'),
            value: _detailedErrorReports,
            onChanged: (value) => setState(() => _detailedErrorReports = value),
          ),
        ],
      );

  Widget _aboutCard() => _sectionCard(
        key: const Key('settings-about'),
        title: '关于',
        icon: Icons.shield_outlined,
        children: const [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Safe Disk'),
            subtitle: Text('版本 1.0.0\n加密文件管理器'),
            isThreeLine: true,
          ),
        ],
      );

  Widget _sectionCard({
    required Key key,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      key: key,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

ThemeMode _themeModeValue(String mode) => switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class _SettingsSnapshot {
  const _SettingsSnapshot({
    required this.themeMode,
    required this.confirmBeforeDelete,
    required this.autoLockOnBackground,
    required this.notepadAutoSaveSeconds,
    required this.notepadDefaultReadOnly,
    required this.notepadDefaultMonitorClipboard,
    required this.detailedErrorReports,
  });

  final String themeMode;
  final bool confirmBeforeDelete;
  final bool autoLockOnBackground;
  final int notepadAutoSaveSeconds;
  final bool notepadDefaultReadOnly;
  final bool notepadDefaultMonitorClipboard;
  final bool detailedErrorReports;

  @override
  bool operator ==(Object other) =>
      other is _SettingsSnapshot &&
      themeMode == other.themeMode &&
      confirmBeforeDelete == other.confirmBeforeDelete &&
      autoLockOnBackground == other.autoLockOnBackground &&
      notepadAutoSaveSeconds == other.notepadAutoSaveSeconds &&
      notepadDefaultReadOnly == other.notepadDefaultReadOnly &&
      notepadDefaultMonitorClipboard == other.notepadDefaultMonitorClipboard &&
      detailedErrorReports == other.detailedErrorReports;

  @override
  int get hashCode => Object.hash(
        themeMode,
        confirmBeforeDelete,
        autoLockOnBackground,
        notepadAutoSaveSeconds,
        notepadDefaultReadOnly,
        notepadDefaultMonitorClipboard,
        detailedErrorReports,
      );
}
