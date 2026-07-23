import 'package:shared_preferences/shared_preferences.dart';

/// Settings service for Safe Disk application
///
/// Manages user preferences and application settings:
/// - Default password iteration strength (key derivation time)
/// - Session TTL (key cache time)
/// - UI theme (light/dark/system)
/// - Other application preferences
class SettingsService {
  // Keys for SharedPreferences
  static const String _keyKeyStrengthMs = 'key_strength_ms';
  static const String _keySessionTTL = 'session_ttl';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLocale = 'locale';
  static const String _keyListViewMode = 'list_view_mode';
  static const String _keyShowFileExtensions = 'show_file_extensions';
  static const String _keyConfirmBeforeDelete = 'confirm_before_delete';
  static const String _keyAutoCloseSession = 'auto_close_session';
  static const String _keyNotepadAutoSaveSeconds = 'notepad_auto_save_seconds';
  static const String _keyNotepadDefaultReadOnly = 'notepad_default_read_only';
  static const String _keyNotepadDefaultMonitorClipboard =
      'notepad_default_monitor_clipboard';
  static const String _keyDetailedErrorReports = 'detailed_error_reports';
  static const String _keyOpenOnDoubleClick = 'open_on_double_click';

  // Default values
  static const int defaultKeyStrengthMs = 1000; // 1 second
  static const int defaultSessionTTL = 3600; // 1 hour
  static const String defaultThemeMode = 'system'; // system, light, dark
  static const String defaultLocale = 'zh'; // system, zh, en
  static const bool defaultShowFileExtensions = true;
  static const bool defaultConfirmBeforeDelete = true;
  static const bool defaultAutoCloseSession = false;
  static const int defaultNotepadAutoSaveSeconds = 30;
  static const bool defaultNotepadReadOnly = false;
  static const bool defaultNotepadMonitorClipboard = false;
  static const bool defaultDetailedErrorReports = false;
  static const bool defaultOpenOnDoubleClick = false;

  static const List<int> notepadAutoSaveOptions = [0, 15, 30, 60, 300];

  // Preset options for key strength
  static const Map<String, int> keyStrengthOptions = {
    'fast': 500, // 0.5 seconds - faster but less secure
    'balanced': 1000, // 1 second - balanced (default)
    'strong': 2000, // 2 seconds - stronger but slower
    'maximum': 5000, // 5 seconds - maximum security
  };

  // Preset options for session TTL
  static const Map<String, int> sessionTTLOptions = {
    '15min': 900, // 15 minutes
    '30min': 1800, // 30 minutes
    '1hour': 3600, // 1 hour (default)
    '4hours': 14400, // 4 hours
    'never': 0, // Never expire (until app closes)
  };

  // Theme mode options
  static const List<String> themeModeOptions = ['system', 'light', 'dark'];
  static const List<String> localeOptions = ['system', 'zh', 'en'];

  // ==================== Key Strength Settings ====================

  /// Get default key strength in milliseconds
  Future<int> getKeyStrengthMs() async {
    final prefs = await SharedPreferences.getInstance();
    final milliseconds = prefs.getInt(_keyKeyStrengthMs);
    if (milliseconds == null ||
        keyStrengthOptions.containsValue(milliseconds)) {
      return milliseconds ?? defaultKeyStrengthMs;
    }
    return defaultKeyStrengthMs;
  }

  /// Set default key strength in milliseconds
  Future<void> setKeyStrengthMs(int ms) async {
    if (!keyStrengthOptions.containsValue(ms)) {
      throw ArgumentError.value(
        ms,
        'ms',
        'unsupported-default-key-strength',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyKeyStrengthMs, ms);
  }

  /// Get key strength label for display
  String getKeyStrengthLabel(int ms) {
    for (final entry in keyStrengthOptions.entries) {
      if (entry.value == ms) {
        return entry.key;
      }
    }
    return 'custom';
  }

  // ==================== Session TTL Settings ====================

  /// Get session TTL in seconds
  Future<int> getSessionTTL() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_keySessionTTL);
    if (seconds == null || sessionTTLOptions.containsValue(seconds)) {
      return seconds ?? defaultSessionTTL;
    }
    return defaultSessionTTL;
  }

  /// Set session TTL in seconds
  Future<void> setSessionTTL(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySessionTTL, seconds);
  }

  /// Get session TTL label for display
  String getSessionTTLLabel(int seconds) {
    for (final entry in sessionTTLOptions.entries) {
      if (entry.value == seconds) {
        return entry.key;
      }
    }
    return 'custom';
  }

  // ==================== Theme Settings ====================

  /// Get theme mode
  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? defaultThemeMode;
  }

  /// Set theme mode
  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  // ==================== Language Settings ====================

  Future<String> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(_keyLocale) ?? defaultLocale;
    return localeOptions.contains(locale) ? locale : defaultLocale;
  }

  Future<void> setLocale(String locale) async {
    if (!localeOptions.contains(locale)) {
      throw ArgumentError.value(
          locale, 'locale', 'unsupported-application-locale');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale);
  }

  // ==================== UI Preferences ====================

  /// Get list view mode (list or grid)
  Future<String> getListViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyListViewMode) ?? 'list';
  }

  /// Set list view mode
  Future<void> setListViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyListViewMode, mode);
  }

  /// Get show file extensions preference
  Future<bool> getShowFileExtensions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowFileExtensions) ?? defaultShowFileExtensions;
  }

  /// Set show file extensions preference
  Future<void> setShowFileExtensions(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowFileExtensions, show);
  }

  /// Get confirm before delete preference
  Future<bool> getConfirmBeforeDelete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConfirmBeforeDelete) ?? defaultConfirmBeforeDelete;
  }

  /// Set confirm before delete preference
  Future<void> setConfirmBeforeDelete(bool confirm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfirmBeforeDelete, confirm);
  }

  /// Get auto close session preference
  Future<bool> getAutoCloseSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoCloseSession) ?? defaultAutoCloseSession;
  }

  /// Set auto close session preference
  Future<void> setAutoCloseSession(bool autoClose) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoCloseSession, autoClose);
  }

  Future<int> getNotepadAutoSaveSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyNotepadAutoSaveSeconds) ??
        defaultNotepadAutoSaveSeconds;
  }

  Future<void> setNotepadAutoSaveSeconds(int seconds) async {
    if (!notepadAutoSaveOptions.contains(seconds)) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'unsupported-notepad-autosave-interval',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotepadAutoSaveSeconds, seconds);
  }

  Future<bool> getNotepadDefaultReadOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotepadDefaultReadOnly) ?? defaultNotepadReadOnly;
  }

  Future<void> setNotepadDefaultReadOnly(bool readOnly) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotepadDefaultReadOnly, readOnly);
  }

  Future<bool> getNotepadDefaultMonitorClipboard() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotepadDefaultMonitorClipboard) ??
        defaultNotepadMonitorClipboard;
  }

  Future<void> setNotepadDefaultMonitorClipboard(bool monitor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotepadDefaultMonitorClipboard, monitor);
  }

  Future<bool> getDetailedErrorReports() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDetailedErrorReports) ??
        defaultDetailedErrorReports;
  }

  Future<void> setDetailedErrorReports(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDetailedErrorReports, enabled);
  }

  Future<bool> getOpenOnDoubleClick() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOpenOnDoubleClick) ?? defaultOpenOnDoubleClick;
  }

  Future<void> setOpenOnDoubleClick(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOpenOnDoubleClick, enabled);
  }

  // ==================== Reset to Defaults ====================

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setKeyStrengthMs(defaultKeyStrengthMs);
    await setSessionTTL(defaultSessionTTL);
    await setThemeMode(defaultThemeMode);
    await setLocale(defaultLocale);
    await setShowFileExtensions(defaultShowFileExtensions);
    await setConfirmBeforeDelete(defaultConfirmBeforeDelete);
    await setAutoCloseSession(defaultAutoCloseSession);
    await setNotepadAutoSaveSeconds(defaultNotepadAutoSaveSeconds);
    await setNotepadDefaultReadOnly(defaultNotepadReadOnly);
    await setNotepadDefaultMonitorClipboard(defaultNotepadMonitorClipboard);
    await setDetailedErrorReports(defaultDetailedErrorReports);
    await setOpenOnDoubleClick(defaultOpenOnDoubleClick);
  }
}
