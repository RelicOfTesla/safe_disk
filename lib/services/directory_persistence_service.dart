import 'package:shared_preferences/shared_preferences.dart';

class DirectoryPersistenceService {
  static const String _keyOpenedDirs = 'opened_directories';
  static const String _keyDrawerPinned = 'drawer_pinned';
  static const String _keyWelcomeShown = 'welcome_shown';
  static const String _keyNeverShowWelcome = 'never_show_welcome';

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
