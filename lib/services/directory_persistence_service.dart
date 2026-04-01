import 'package:shared_preferences/shared_preferences.dart';

class DirectoryPersistenceService {
  static const String _keyOpenedDirs = 'opened_directories';
  static const String _keyDrawerPinned = 'drawer_pinned';
  
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
}
