import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/error_reporting_service.dart';
import '../l10n/app_locale.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';

enum _LeaveAction { cancel, discard, save }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.settingsService,
    this.onThemeModeChanged,
    this.onLocaleChanged,
    this.onWebDavEnabledChanged,
  });

  final SettingsService? settingsService;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<Locale?>? onLocaleChanged;
  final Future<void> Function(bool enabled)? onWebDavEnabledChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settingsService;
  String _themeMode = SettingsService.defaultThemeMode;
  String _locale = SettingsService.defaultLocale;
  bool _confirmBeforeDelete = SettingsService.defaultConfirmBeforeDelete;
  bool _autoLockOnBackground = SettingsService.defaultAutoCloseSession;
  int _sessionTTL = SettingsService.defaultSessionTTL;
  int _keyStrengthMs = SettingsService.defaultKeyStrengthMs;
  int _notepadAutoSaveSeconds = SettingsService.defaultNotepadAutoSaveSeconds;
  bool _notepadDefaultReadOnly = SettingsService.defaultNotepadReadOnly;
  bool _notepadDefaultMonitorClipboard =
      SettingsService.defaultNotepadMonitorClipboard;
  bool _detailedErrorReports = SettingsService.defaultDetailedErrorReports;
  bool _openOnDoubleClick = SettingsService.defaultOpenOnDoubleClick;
  bool _webDavEnabled = SettingsService.defaultWebDavEnabled;
  bool _antiScreenshot = SettingsService.defaultAntiScreenshot;
  bool _antiScreenshotOnLinux = SettingsService.defaultAntiScreenshotOnLinux;
  _SettingsSnapshot? _saved;
  bool _isLoading = true;
  bool _allowPop = false;

  bool get _isDirty => _saved != null && _current != _saved;

  _SettingsSnapshot get _current => _SettingsSnapshot(
        themeMode: _themeMode,
        locale: _locale,
        confirmBeforeDelete: _confirmBeforeDelete,
        autoLockOnBackground: _autoLockOnBackground,
        sessionTTL: _sessionTTL,
        keyStrengthMs: _keyStrengthMs,
        notepadAutoSaveSeconds: _notepadAutoSaveSeconds,
        notepadDefaultReadOnly: _notepadDefaultReadOnly,
        notepadDefaultMonitorClipboard: _notepadDefaultMonitorClipboard,
        detailedErrorReports: _detailedErrorReports,
        openOnDoubleClick: _openOnDoubleClick,
        webDavEnabled: _webDavEnabled,
        antiScreenshot: _antiScreenshot,
        antiScreenshotOnLinux: _antiScreenshotOnLinux,
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
        locale: await _settingsService.getLocale(),
        confirmBeforeDelete: await _settingsService.getConfirmBeforeDelete(),
        autoLockOnBackground: await _settingsService.getAutoCloseSession(),
        sessionTTL: await _settingsService.getSessionTTL(),
        keyStrengthMs: await _settingsService.getKeyStrengthMs(),
        notepadAutoSaveSeconds:
            await _settingsService.getNotepadAutoSaveSeconds(),
        notepadDefaultReadOnly:
            await _settingsService.getNotepadDefaultReadOnly(),
        notepadDefaultMonitorClipboard:
            await _settingsService.getNotepadDefaultMonitorClipboard(),
        detailedErrorReports: await _settingsService.getDetailedErrorReports(),
        openOnDoubleClick: await _settingsService.getOpenOnDoubleClick(),
        webDavEnabled: await _settingsService.getWebDavEnabled(),
        antiScreenshot: await _settingsService.getAntiScreenshot(),
        antiScreenshotOnLinux:
            await _settingsService.getAntiScreenshotOnLinux(),
      );
      if (!mounted) return;
      setState(() {
        _themeMode = snapshot.themeMode;
        _locale = snapshot.locale;
        _confirmBeforeDelete = snapshot.confirmBeforeDelete;
        _autoLockOnBackground = snapshot.autoLockOnBackground;
        _sessionTTL = snapshot.sessionTTL;
        _keyStrengthMs = snapshot.keyStrengthMs;
        _notepadAutoSaveSeconds = snapshot.notepadAutoSaveSeconds;
        _notepadDefaultReadOnly = snapshot.notepadDefaultReadOnly;
        _notepadDefaultMonitorClipboard =
            snapshot.notepadDefaultMonitorClipboard;
        _detailedErrorReports = snapshot.detailedErrorReports;
        _openOnDoubleClick = snapshot.openOnDoubleClick;
        _webDavEnabled = snapshot.webDavEnabled;
        _antiScreenshot = snapshot.antiScreenshot;
        _antiScreenshotOnLinux = snapshot.antiScreenshotOnLinux;
        _saved = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ErrorHelper.showError(
        context,
        errorType: ErrorType.loadSettingsFailed,
        originalError: error.toString(),
        operation: 'settings-load',
      );
    }
  }

  Future<bool> _saveSettings() async {
    try {
      await _settingsService.setThemeMode(_themeMode);
      await _settingsService.setLocale(_locale);
      await _settingsService.setConfirmBeforeDelete(_confirmBeforeDelete);
      await _settingsService.setAutoCloseSession(_autoLockOnBackground);
      await _settingsService.setSessionTTL(_sessionTTL);
      await _settingsService.setKeyStrengthMs(_keyStrengthMs);
      await _settingsService.setNotepadAutoSaveSeconds(_notepadAutoSaveSeconds);
      await _settingsService.setNotepadDefaultReadOnly(
        _notepadDefaultReadOnly,
      );
      await _settingsService.setNotepadDefaultMonitorClipboard(
        _notepadDefaultMonitorClipboard,
      );
      await _settingsService.setDetailedErrorReports(_detailedErrorReports);
      await _settingsService.setOpenOnDoubleClick(_openOnDoubleClick);
      await _settingsService.setWebDavEnabled(_webDavEnabled);
      await _settingsService.setAntiScreenshot(_antiScreenshot);
      await _settingsService.setAntiScreenshotOnLinux(_antiScreenshotOnLinux);
      await _settingsService.applyAntiScreenshot();
      await widget.onWebDavEnabledChanged?.call(_webDavEnabled);
      ErrorReportingService.configure(
        detailedErrorsEnabled: _detailedErrorReports,
      );
      if (!mounted) return false;
      setState(() => _saved = _current);
      final strings = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.settingsSaved)),
      );
      return true;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.saveSettingsFailed,
          originalError: error.toString(),
          operation: 'settings-save',
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
      builder: (dialogContext) {
        final strings = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(strings.saveChanges),
          content: Text(strings.unsavedSettings),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _LeaveAction.cancel),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _LeaveAction.discard),
              child: Text(strings.discardChanges),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, _LeaveAction.save),
              child: Text(strings.saveAndReturn),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null || action == _LeaveAction.cancel) return;
    if (action == _LeaveAction.save && !await _saveSettings()) return;
    if (action == _LeaveAction.discard) {
      widget.onThemeModeChanged?.call(_themeModeValue(_saved!.themeMode));
      widget.onLocaleChanged?.call(appLocaleFromPreference(_saved!.locale));
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

  void _setLocale(String locale) {
    setState(() => _locale = locale);
    widget.onLocaleChanged?.call(appLocaleFromPreference(locale));
  }

  void _resetToDefaults() {
    setState(() {
      _themeMode = SettingsService.defaultThemeMode;
      _locale = SettingsService.defaultLocale;
      _confirmBeforeDelete = SettingsService.defaultConfirmBeforeDelete;
      _autoLockOnBackground = SettingsService.defaultAutoCloseSession;
      _sessionTTL = SettingsService.defaultSessionTTL;
      _keyStrengthMs = SettingsService.defaultKeyStrengthMs;
      _notepadAutoSaveSeconds = SettingsService.defaultNotepadAutoSaveSeconds;
      _notepadDefaultReadOnly = SettingsService.defaultNotepadReadOnly;
      _notepadDefaultMonitorClipboard =
          SettingsService.defaultNotepadMonitorClipboard;
      _detailedErrorReports = SettingsService.defaultDetailedErrorReports;
      _openOnDoubleClick = SettingsService.defaultOpenOnDoubleClick;
      _webDavEnabled = SettingsService.defaultWebDavEnabled;
      _antiScreenshot = SettingsService.defaultAntiScreenshot;
      _antiScreenshotOnLinux = SettingsService.defaultAntiScreenshotOnLinux;
    });
    widget.onThemeModeChanged?.call(ThemeMode.system);
    widget.onLocaleChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
            tooltip: strings.back,
          ),
          title: Text(strings.settings),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _resetToDefaults,
              icon: const Icon(Icons.restart_alt),
              tooltip: strings.restoreDefaults,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final sections = [
                    _appearanceCard(strings),
                    _behaviorCard(strings),
                    _securityCard(strings),
                    _notepadCard(strings),
                  ];
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        key: const Key('settings-content'),
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: LayoutBuilder(
                          builder: (context, contentConstraints) {
                            final wide = contentConstraints.maxWidth >= 900;
                            final gap = wide ? 20.0 : 16.0;
                            final cardWidth = wide
                                ? (contentConstraints.maxWidth - gap) / 2
                                : contentConstraints.maxWidth;
                            return Column(
                              children: [
                                Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (final section in sections)
                                      SizedBox(
                                        width: cardWidth,
                                        child: section,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _aboutCard(strings),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _isDirty ? _saveSettings : null,
                                    icon: const Icon(Icons.save_outlined),
                                    label: Text(
                                      _isDirty
                                          ? strings.saveSettings
                                          : strings.settingsSaved,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _appearanceCard(AppLocalizations strings) => _sectionCard(
        key: const Key('settings-appearance'),
        title: strings.appearance,
        icon: Icons.palette_outlined,
        children: [
          SegmentedButton<String>(
            segments: SettingsService.themeModeOptions
                .map(
                  (mode) => ButtonSegment<String>(
                    value: mode,
                    label: Text(_themeLabel(strings, mode)),
                  ),
                )
                .toList(),
            selected: {_themeMode},
            onSelectionChanged: (selection) => _setTheme(selection.single),
          ),
          const SizedBox(height: 10),
          Text(strings.themePreviewHint),
          const Divider(),
          ListTile(
            key: const Key('app-locale'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.language),
            subtitle: Text(strings.languagePreviewHint),
            trailing: DropdownButton<String>(
              value: _locale,
              items: [
                DropdownMenuItem(
                  value: appLocaleSystem,
                  child: Text(strings.languageSystem),
                ),
                DropdownMenuItem(
                  value: appLocaleChinese,
                  child: Text(strings.languageChinese),
                ),
                DropdownMenuItem(
                  value: appLocaleEnglish,
                  child: Text(strings.languageEnglish),
                ),
              ],
              onChanged: (value) {
                if (value != null) _setLocale(value);
              },
            ),
          ),
        ],
      );

  String _themeLabel(AppLocalizations strings, String mode) => switch (mode) {
        'light' => strings.themeLight,
        'dark' => strings.themeDark,
        _ => strings.themeSystem,
      };

  Widget _behaviorCard(AppLocalizations strings) => _sectionCard(
        key: const Key('settings-behavior'),
        title: strings.behavior,
        icon: Icons.tune,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.confirmBeforeDelete),
            subtitle: Text(strings.confirmBeforeDeleteHint),
            value: _confirmBeforeDelete,
            onChanged: (value) => setState(() => _confirmBeforeDelete = value),
          ),
          const Divider(),
          ListTile(
            key: const Key('open-mode'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.openMode),
            subtitle: Text(strings.openModeHint),
            trailing: DropdownButton<bool>(
              value: _openOnDoubleClick,
              items: [
                DropdownMenuItem(
                  value: false,
                  child: Text(strings.openModeSingleClick),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text(strings.openModeDoubleClick),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _openOnDoubleClick = value);
              },
            ),
          ),
        ],
      );

  Widget _securityCard(AppLocalizations strings) => _sectionCard(
        key: const Key('settings-security'),
        title: strings.security,
        icon: Icons.security_outlined,
        children: [
          ListTile(
            key: const Key('session-ttl'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.lockAfterIdle),
            subtitle: Text(strings.lockAfterIdleHint),
            trailing: DropdownButton<int>(
              value: _sessionTTL,
              items: SettingsService.sessionTTLOptions.values
                  .map((seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text(
                          _sessionTtlLabel(strings, seconds),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _sessionTTL = value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            key: const Key('default-key-strength'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.defaultNewDirectoryKdfProfile),
            subtitle: Text(strings.defaultNewDirectoryKdfProfileHint),
            trailing: DropdownButton<int>(
              value: _keyStrengthMs,
              items: SettingsService.keyStrengthOptions.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.value,
                      child: Text(_keyStrengthLabel(strings, entry.key)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _keyStrengthMs = value);
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('auto-lock-on-background'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.lockWhenHidden),
            subtitle: Text(strings.lockWhenHiddenHint),
            value: _autoLockOnBackground,
            onChanged: (value) => setState(() => _autoLockOnBackground = value),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('detailed-error-reports'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.detailedErrors),
            subtitle: Text(strings.detailedErrorsHint),
            value: _detailedErrorReports,
            onChanged: (value) => setState(() => _detailedErrorReports = value),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('webdav-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.webDavGlobalSwitch),
            subtitle: Text(strings.webDavGlobalSwitchHint),
            value: _webDavEnabled,
            onChanged: (value) => setState(() => _webDavEnabled = value),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('anti-screenshot'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.antiScreenshot),
            subtitle: Text(strings.antiScreenshotHint),
            value: _antiScreenshot,
            onChanged: (value) => setState(() => _antiScreenshot = value),
          ),
          if (_antiScreenshot)
            SwitchListTile(
              key: const Key('anti-screenshot-linux'),
              contentPadding: EdgeInsets.zero,
              title: Text(strings.antiScreenshotOnLinux),
              subtitle: Text(strings.antiScreenshotOnLinuxHint),
              value: _antiScreenshotOnLinux,
              onChanged: (value) =>
                  setState(() => _antiScreenshotOnLinux = value),
            ),
        ],
      );

  Widget _notepadCard(AppLocalizations strings) => _sectionCard(
        key: const Key('settings-notepad'),
        title: strings.secureNotepad,
        icon: Icons.note_alt_outlined,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.notepadDraftInterval),
            subtitle: Text(strings.notepadDraftIntervalHint),
            trailing: DropdownButton<int>(
              value: _notepadAutoSaveSeconds,
              items: SettingsService.notepadAutoSaveOptions
                  .map(
                    (seconds) => DropdownMenuItem(
                      value: seconds,
                      child: Text(
                        _notepadAutoSaveLabel(strings, seconds),
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
            title: Text(strings.notepadDefaultReadOnly),
            subtitle: Text(strings.notepadDefaultReadOnlyHint),
            value: _notepadDefaultReadOnly,
            onChanged: (value) =>
                setState(() => _notepadDefaultReadOnly = value),
          ),
          SwitchListTile(
            key: const Key('notepad-default-monitor-clipboard'),
            contentPadding: EdgeInsets.zero,
            title: Text(strings.notepadMonitorClipboard),
            subtitle: Text(strings.notepadMonitorClipboardHint),
            value: _notepadDefaultMonitorClipboard,
            onChanged: (value) =>
                setState(() => _notepadDefaultMonitorClipboard = value),
          ),
        ],
      );

  Widget _aboutCard(AppLocalizations strings) => _sectionCard(
        key: const Key('settings-about'),
        title: strings.about,
        icon: Icons.shield_outlined,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.appTitle),
            subtitle: Text(strings.appVersionDescription),
            isThreeLine: true,
          ),
        ],
      );

  String _sessionTtlLabel(AppLocalizations strings, int seconds) {
    if (seconds == 0) return strings.durationNever;
    if (seconds < 3600) return strings.durationMinutes(seconds ~/ 60);
    if (seconds < 86400) return strings.durationHours(seconds ~/ 3600);
    return strings.durationDays(seconds ~/ 86400);
  }

  String _notepadAutoSaveLabel(AppLocalizations strings, int seconds) {
    if (seconds == 0) return strings.disabled;
    if (seconds < 60) return strings.durationSeconds(seconds);
    return strings.durationMinutes(seconds ~/ 60);
  }

  String _keyStrengthLabel(AppLocalizations strings, String profile) =>
      switch (profile) {
        'fast' => strings.kdfProfileFast,
        'strong' => strings.kdfProfileStrong,
        'maximum' => strings.kdfProfileMaximum,
        _ => strings.kdfProfileBalanced,
      };

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
    required this.locale,
    required this.confirmBeforeDelete,
    required this.autoLockOnBackground,
    required this.sessionTTL,
    required this.keyStrengthMs,
    required this.notepadAutoSaveSeconds,
    required this.notepadDefaultReadOnly,
    required this.notepadDefaultMonitorClipboard,
    required this.detailedErrorReports,
    required this.openOnDoubleClick,
    required this.webDavEnabled,
    required this.antiScreenshot,
    required this.antiScreenshotOnLinux,
  });

  final String themeMode;
  final String locale;
  final bool confirmBeforeDelete;
  final bool autoLockOnBackground;
  final int sessionTTL;
  final int keyStrengthMs;
  final int notepadAutoSaveSeconds;
  final bool notepadDefaultReadOnly;
  final bool notepadDefaultMonitorClipboard;
  final bool detailedErrorReports;
  final bool openOnDoubleClick;
  final bool webDavEnabled;
  final bool antiScreenshot;
  final bool antiScreenshotOnLinux;

  @override
  bool operator ==(Object other) =>
      other is _SettingsSnapshot &&
      themeMode == other.themeMode &&
      locale == other.locale &&
      confirmBeforeDelete == other.confirmBeforeDelete &&
      autoLockOnBackground == other.autoLockOnBackground &&
      sessionTTL == other.sessionTTL &&
      keyStrengthMs == other.keyStrengthMs &&
      notepadAutoSaveSeconds == other.notepadAutoSaveSeconds &&
      notepadDefaultReadOnly == other.notepadDefaultReadOnly &&
      notepadDefaultMonitorClipboard == other.notepadDefaultMonitorClipboard &&
      detailedErrorReports == other.detailedErrorReports &&
      openOnDoubleClick == other.openOnDoubleClick &&
      webDavEnabled == other.webDavEnabled &&
      antiScreenshot == other.antiScreenshot &&
      antiScreenshotOnLinux == other.antiScreenshotOnLinux;

  @override
  int get hashCode => Object.hash(
        themeMode,
        locale,
        confirmBeforeDelete,
        autoLockOnBackground,
        sessionTTL,
        keyStrengthMs,
        notepadAutoSaveSeconds,
        notepadDefaultReadOnly,
        notepadDefaultMonitorClipboard,
        detailedErrorReports,
        openOnDoubleClick,
        webDavEnabled,
        antiScreenshot,
        antiScreenshotOnLinux,
      );
}
