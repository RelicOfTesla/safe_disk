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
  static const String _keyListViewMode = 'list_view_mode';
  static const String _keyShowFileExtensions = 'show_file_extensions';
  static const String _keyConfirmBeforeDelete = 'confirm_before_delete';
  static const String _keyAutoCloseSession = 'auto_close_session';

  // Default values
  static const int defaultKeyStrengthMs = 1000; // 1 second
  static const int defaultSessionTTL = 3600; // 1 hour
  static const String defaultThemeMode = 'system'; // system, light, dark
  static const bool defaultShowFileExtensions = true;
  static const bool defaultConfirmBeforeDelete = true;
  static const bool defaultAutoCloseSession = false;

  // Preset options for key strength
  static const Map<String, int> keyStrengthOptions = {
    'fast': 500,      // 0.5 seconds - faster but less secure
    'balanced': 1000, // 1 second - balanced (default)
    'strong': 2000,   // 2 seconds - stronger but slower
    'maximum': 5000,  // 5 seconds - maximum security
  };

  // Preset options for session TTL
  static const Map<String, int> sessionTTLOptions = {
    '15min': 900,    // 15 minutes
    '30min': 1800,   // 30 minutes
    '1hour': 3600,   // 1 hour (default)
    '4hours': 14400, // 4 hours
    'never': 0,      // Never expire (until app closes)
  };

  // Theme mode options
  static const List<String> themeModeOptions = ['system', 'light', 'dark'];

  // ==================== Key Strength Settings ====================

  /// Get default key strength in milliseconds
  Future<int> getKeyStrengthMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyKeyStrengthMs) ?? defaultKeyStrengthMs;
  }

  /// Set default key strength in milliseconds
  Future<void> setKeyStrengthMs(int ms) async {
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

  /// Get key strength display name (localized)
  String getKeyStrengthDisplayName(int ms) {
    if (ms <= 500) return '快速 (0.5秒)';
    if (ms <= 1000) return '平衡 (1秒)';
    if (ms <= 2000) return '强密钥 (2秒)';
    return '最强 (5秒)';
  }

  // ==================== Session TTL Settings ====================

  /// Get session TTL in seconds
  Future<int> getSessionTTL() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySessionTTL) ?? defaultSessionTTL;
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

  /// Get session TTL display name (localized)
  String getSessionTTLDisplayName(int seconds) {
    if (seconds == 0) return '永不过期';
    if (seconds < 3600) return '${seconds ~/ 60} 分钟';
    if (seconds < 86400) return '${seconds ~/ 3600} 小时';
    return '${seconds ~/ 86400} 天';
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

  /// Get theme mode display name (localized)
  String getThemeModeDisplayName(String mode) {
    switch (mode) {
      case 'system':
        return '跟随系统';
      case 'light':
        return '亮色主题';
      case 'dark':
        return '暗色主题';
      default:
        return '跟随系统';
    }
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

  // ==================== Reset to Defaults ====================

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setKeyStrengthMs(defaultKeyStrengthMs);
    await setSessionTTL(defaultSessionTTL);
    await setThemeMode(defaultThemeMode);
    await setShowFileExtensions(defaultShowFileExtensions);
    await setConfirmBeforeDelete(defaultConfirmBeforeDelete);
    await setAutoCloseSession(defaultAutoCloseSession);
  }
}
