import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../services/crypto_service.dart';
import '../services/directory_persistence_service.dart';

/// Sidebar data management for HomePage.
///
/// Extracted from home_page.dart for maintainability.
/// The host State must implement the abstract getters/setters below.
mixin HomePageSidebarMixin {
  // -- Abstract interface (implemented by _HomePageState) --

  List<EncryptedDirectory> get openedDirs;
  EncryptedDirectory? get currentDir;
  set currentDir(EncryptedDirectory? value);
  bool get drawerPinned;
  set drawerPinned(bool value);
  DirectoryPersistenceService get persistenceService;
  CryptoService get cryptoService;

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  // -- Implementation --

  Future<void> loadDrawerPinnedState() async {
    final pinned = await persistenceService.loadDrawerPinned();
    if (mounted) {
      setState(() => drawerPinned = pinned);
    }
  }

  Future<void> loadPersistedDirectories() async {
    final values = await Future.wait<Object>([
      persistenceService.loadOpenedDirectories(),
      persistenceService.loadDirectoryAliases(),
    ]);
    final paths = values[0] as List<String>;
    final aliases = values[1] as Map<String, String>;
    for (final path in paths) {
      try {
        final config = cryptoService.loadConfig(path);
        if (mounted) {
          setState(() {
            openedDirs.add(EncryptedDirectory(
              path: path,
              config: config,
              isVerified: false,
              displayAlias: aliases[path],
            ));
          });
        }
      } catch (e) {
        // Directory no longer exists or config is invalid, skip it.
      }
    }
  }

  Future<void> renameDirectoryAlias(EncryptedDirectory directory) async {
    if (directory.displayAlias == null &&
        openedDirs.any((item) =>
            item.path == directory.path && item.displayAlias != null)) {
      await applyDirectoryAlias(directory.path, null);
      return;
    }
    final controller = TextEditingController(text: directory.displayAlias);
    final strings = AppLocalizations.of(context)!;
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.directoryAliasTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(
            labelText: strings.directoryAliasLabel,
            hintText: strings.directoryAliasHint,
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (alias == null || !mounted) return;
    await applyDirectoryAlias(directory.path, alias.trim());
  }

  Future<void> applyDirectoryAlias(String path, String? alias) async {
    if (mounted) {
      setState(() {
        final index = openedDirs.indexWhere((item) => item.path == path);
        if (index < 0) return;
        final updated = openedDirs[index].copyWith(
          displayAlias: alias,
          clearDisplayAlias: alias == null || alias.isEmpty,
        );
        openedDirs[index] = updated;
        if (currentDir?.path == path) currentDir = updated;
      });
    }
    await persistenceService.saveDirectoryAlias(path, alias);
  }

  Future<void> saveOpenedDirectories() async {
    final paths = openedDirs.map((d) => d.path).toList();
    await persistenceService.saveOpenedDirectories(paths);
  }

  Future<void> moveDirectory(EncryptedDirectory directory, int delta) async {
    final index = openedDirs.indexWhere((item) => item.path == directory.path);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= openedDirs.length) return;
    if (mounted) {
      setState(() {
        final moved = openedDirs.removeAt(index);
        openedDirs.insert(target, moved);
      });
    }
    await saveOpenedDirectories();
  }
}
