import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DirectoryPersistenceService {
  static const String _keyOpenedDirs = 'opened_directories';
  static const String _keyDrawerPinned = 'drawer_pinned';
  static const String _keyWelcomeShown = 'welcome_shown';
  static const String _keyNeverShowWelcome = 'never_show_welcome';
  static const String _keyDirectoryAliases = 'directory_aliases';

  /// Save opened directory paths
  Future<void> saveOpenedDirectories(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyOpenedDirs, paths);
  }

  /// Load opened directory paths
  Future<List<String>> loadOpenedDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyOpenedDirs) ?? [];
  }

  Future<Map<String, String>> loadDirectoryAliases() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_keyDirectoryAliases);
    if (encoded == null) return {};
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return {};
      return value.map((key, alias) => MapEntry(key, alias as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDirectoryAlias(String path, String? alias) async {
    final aliases = await loadDirectoryAliases();
    final normalizedAlias = alias?.trim();
    if (normalizedAlias == null || normalizedAlias.isEmpty) {
      aliases.remove(path);
    } else {
      aliases[path] = normalizedAlias;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDirectoryAliases, jsonEncode(aliases));
  }

  /// Clear all saved directories
  Future<void> clearOpenedDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOpenedDirs);
  }

  /// Save drawer pinned state
  Future<void> saveDrawerPinned(bool pinned) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDrawerPinned, pinned);
  }

  /// Load drawer pinned state
  Future<bool> loadDrawerPinned() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDrawerPinned) ?? false;
  }

  /// Check if welcome guide has been shown
  Future<bool> hasShownWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWelcomeShown) ?? false;
  }

  /// Mark welcome guide as shown
  Future<void> markWelcomeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWelcomeShown, true);
  }

  /// Check if user selected "never show welcome again"
  Future<bool> shouldNeverShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNeverShowWelcome) ?? false;
  }

  /// Set "never show welcome again" preference
  Future<void> setNeverShowWelcome(bool neverShow) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNeverShowWelcome, neverShow);
    if (neverShow) {
      // Also mark as shown when user selects "never show"
      await markWelcomeShown();
    }
  }

  /// Check if this is first time user (no directories opened and welcome not shown)
  Future<bool> isFirstTimeUser() async {
    final dirs = await loadOpenedDirectories();
    final welcomeShown = await hasShownWelcome();
    final neverShow = await shouldNeverShowWelcome();
    return dirs.isEmpty && !welcomeShown && !neverShow;
  }
}
