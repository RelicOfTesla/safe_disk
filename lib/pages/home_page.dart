import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/error_localizations.dart';
import '../models/cryption_config.dart';
import '../models/batch_operation_result.dart';
import '../models/secure_image_policy.dart';
import '../models/view_mode.dart';
import '../models/create_root_options.dart';
import '../models/text_file_policy.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../services/directory_page_session.dart';
import '../services/directory_service.dart';
import '../services/directory_persistence_service.dart';
import '../services/settings_service.dart';
import '../services/secure_clipboard_service.dart';
import '../services/secure_entry_move_service.dart';
import '../services/document_session_broker.dart';
import '../services/root_close_coordinator.dart';
import '../services/root_idle_tracker.dart';
import '../services/secure_notepad_policy.dart';
import '../services/content_window_host_bridge.dart';
import '../services/drag_drop_controller.dart';
import '../services/webdav_service.dart';
import '../utils/error_messages.dart';
import '../utils/error_diagnostics.dart';
import '../utils/unlock_error_classifier.dart';
import '../utils/unfinished_transfer_error_classifier.dart';
import '../widgets/batch_operation_result_dialog.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/secure_notepad.dart';
import '../widgets/secure_image_viewer.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/home_shell.dart';
import '../widgets/file_browser.dart';
import '../widgets/file_item_actions.dart';
import '../widgets/anti_screenshot_dialog.dart';
import '../widgets/entry_conflict_dialog.dart';
import '../widgets/directory_background_actions.dart';
import '../widgets/root_directory_action_dialog.dart';
import '../widgets/root_directory_properties.dart';
import '../widgets/root_password_change_dialog.dart';
import '../widgets/root_password_hint_dialog.dart';
import '../widgets/webdav_sessions_dialog.dart';
import 'dialogs.dart';
import 'settings_page.dart';

export '../models/view_mode.dart';

enum _UnfinishedAction { skip, clean, rerun }

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.cryptoService,
    this.directoryService,
    this.fileService,
    this.persistenceService,
    this.settingsService,
    this.onThemeModeChanged,
    this.onLocaleChanged,
    this.selectDirectory,
    this.selectFile,
    this.selectSaveLocation,
    this.contentWindowPlatform,
    this.exportTargetExists,
    this.deleteRootDirectory,
    this.idleCheckInterval,
    this.idleNow,
    this.webDavService,
  });

  final CryptoService? cryptoService;
  final DirectoryService? directoryService;
  final FileService? fileService;
  final DirectoryPersistenceService? persistenceService;
  final SettingsService? settingsService;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ValueChanged<Locale?>? onLocaleChanged;
  final Future<String?> Function()? selectDirectory;
  final Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups)?
      selectFile;
  final Future<FileSaveLocation?> Function(String suggestedName)?
      selectSaveLocation;
  final ContentWindowPlatform? contentWindowPlatform;
  final Future<bool> Function(String path)? exportTargetExists;
  final Future<void> Function(String path)? deleteRootDirectory;
  final Duration? idleCheckInterval;
  final DateTime Function()? idleNow;
  final WebDavService? webDavService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CryptoService _cryptoService;
  late final DirectoryService _directoryService;
  late final FileService _fileService;
  late final DirectoryPersistenceService _persistenceService;
  late final SettingsService _settingsService;
  late final SecureClipboardService _secureClipboard;
  late final SecureEntryMoveService _secureEntryMover;
  late final DocumentSessionBroker _documentBroker;
  late final RootCloseCoordinator _rootCloseCoordinator;
  late final RootIdleTracker _idleTracker;
  late final ContentWindowHostBridge _contentWindowBridge;
  late final WebDavService _webDavService;
  final DragDropController _dragDropController = const DragDropController();
  // This is only a badge cache. Go remains authoritative for session state.
  final Map<int, int> _webDavSessionCounts = {};
  final Map<String, String> _webDavMountOperations = {};
  int _webDavOperationSequence = 0;

  final List<EncryptedDirectory> _openedDirs = [];
  EncryptedDirectory? _currentDir;
  String? _currentPath;
  List<FileSystemNode> _items = [];
  DirectoryPageSession? _pageSession;
  int _pageGeneration = 0;
  bool _isLoadingMore = false;
  bool _isLoading = false;
  bool _autoLockOnBackground = SettingsService.defaultAutoCloseSession;
  bool _isAutoLocking = false;
  final Map<String, Future<void>> _rootCloseTails = {};
  Timer? _idleTimer;
  String? _pendingAutoLockSummary;
  String? _lastIdleAutoLockSummary;
  bool _drawerPinned = false;
  ViewMode _viewMode = ViewMode.list;
  bool _openOnDoubleClick = SettingsService.defaultOpenOnDoubleClick;
  bool _webDavEnabled = SettingsService.defaultWebDavEnabled;

  // File selection for batch operations
  bool _isSelectMode = false;
  final Set<FileSystemNode> _selectedFiles = {};
  FileSystemNode? _keyboardTarget;
  String? _keyboardSelectionAnchorPath;
  int _gridColumnCount = 1;
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home-shortcuts');
  final GlobalKey<FileBrowserState> _fileBrowserKey =
      GlobalKey<FileBrowserState>();

  @override
  void initState() {
    super.initState();
    _cryptoService = widget.cryptoService ?? CryptoService();
    _directoryService = widget.directoryService ?? DirectoryService();
    _fileService =
        widget.fileService ?? FileService(cryptoService: _cryptoService);
    _persistenceService =
        widget.persistenceService ?? DirectoryPersistenceService();
    _settingsService = widget.settingsService ?? SettingsService();
    _secureClipboard = SecureClipboardService();
    _secureEntryMover = SecureEntryMoveService(_cryptoService);
    _documentBroker = DocumentSessionBroker(cryptoService: _cryptoService);
    _rootCloseCoordinator = RootCloseCoordinator(_documentBroker);
    _idleTracker = RootIdleTracker(
      timeout: const Duration(seconds: SettingsService.defaultSessionTTL),
      now: widget.idleNow,
    );
    _contentWindowBridge = ContentWindowHostBridge(
      broker: _documentBroker,
      platform: widget.contentWindowPlatform,
    );
    _webDavService =
        widget.webDavService ?? WebDavService(cryptoService: _cryptoService);
    WidgetsBinding.instance.addObserver(this);
    _loadPersistedDirectories();
    _loadDrawerPinnedState();
    _loadAutoLockPreference();
    _loadSessionTTL();
    _loadOpenMode();
    _loadWebDavEnabled();
    _checkFirstTimeUser();
    _checkFirstLaunchAntiScreenshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _idleTracker.clear();
    unawaited(_pageSession?.dispose() ?? Future.value());
    _shortcutFocusNode.dispose();
    _contentWindowBridge.dispose();
    _saveOpenedDirectories();
    final sessionIDs = _openedDirs
        .map((directory) => directory.tempKeyID)
        .whereType<String>()
        .toSet();
    for (final sessionID in sessionIDs) {
      _closeSession(sessionID);
    }
    super.dispose();
  }

  Future<void> _loadAutoLockPreference() async {
    final enabled = await _settingsService.getAutoCloseSession();
    if (mounted) setState(() => _autoLockOnBackground = enabled);
  }

  Future<void> _loadSessionTTL() async {
    final seconds = await _settingsService.getSessionTTL();
    if (!mounted) return;
    _idleTracker.updateTimeout(Duration(seconds: seconds));
    _idleTimer?.cancel();
    if (_idleTracker.isEnabled) {
      // A TTL enabled after a root was opened starts from this setting change,
      // rather than leaving that session without a deadline or locking it on
      // an activity timestamp the user did not choose this TTL for.
      for (final directory in _openedDirs) {
        final sessionID = directory.tempKeyID;
        if (sessionID != null) _idleTracker.touch(sessionID);
      }
      _idleTimer = Timer.periodic(
        widget.idleCheckInterval ?? const Duration(seconds: 1),
        (_) => unawaited(_lockExpiredRoots()),
      );
    }
  }

  Future<void> _loadOpenMode() async {
    final openOnDoubleClick = await _settingsService.getOpenOnDoubleClick();
    if (mounted) setState(() => _openOnDoubleClick = openOnDoubleClick);
  }

  Future<void> _loadWebDavEnabled() async {
    final enabled = await _settingsService.getWebDavEnabled();
    if (mounted) setState(() => _webDavEnabled = enabled);
  }

  void _touchCurrentRoot() {
    final sessionID = _currentDir?.tempKeyID;
    if (sessionID != null) {
      _idleTracker.touch(sessionID);
      _lastIdleAutoLockSummary = null;
    }
  }

  void _refreshCurrentDirectory() {
    _touchCurrentRoot();
    unawaited(_loadCurrentPath());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_lockEligibleRoots(requireBackgroundPreference: true));
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _showPendingAutoLockSummary();
    }
  }

  void _showPendingAutoLockSummary() {
    final summary = _pendingAutoLockSummary;
    if (summary == null || !mounted) return;
    _pendingAutoLockSummary = null;
    ErrorHelper.showInfo(context, summary);
  }

  Future<void> _lockExpiredRoots() async {
    final expired = _idleTracker.expiredSessionIDs();
    if (expired.isEmpty) {
      _lastIdleAutoLockSummary = null;
      return;
    }
    await _lockEligibleRoots(sessionIDs: expired);
    final summary = _pendingAutoLockSummary;
    if (summary == null || summary == _lastIdleAutoLockSummary) return;
    _lastIdleAutoLockSummary = summary;
    _showPendingAutoLockSummary();
  }

  Future<void> _lockEligibleRoots({
    Set<String>? sessionIDs,
    bool requireBackgroundPreference = false,
  }) async {
    if ((requireBackgroundPreference && !_autoLockOnBackground) ||
        _isAutoLocking) {
      return;
    }
    _isAutoLocking = true;
    var lockedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    try {
      for (final directory in List<EncryptedDirectory>.from(_openedDirs)) {
        final sessionID = directory.tempKeyID;
        if (sessionID == null) continue;
        if (sessionIDs != null && !sessionIDs.contains(sessionID)) continue;
        try {
          await _runRootCloseOperation(sessionID, () async {
            if (!_isCurrentDirectorySession(directory.path, sessionID)) return;
            final decision = _rootCloseCoordinator.inspect(sessionID);
            final nativeWindowCount =
                _contentWindowBridge.nativeWindowCountForRoot(sessionID);
            // Only child windows can participate in the prepare-lock protocol.
            // An in-process editor remains visible and must keep the root open.
            if (decision.windowCount != nativeWindowCount) {
              skippedCount++;
              return;
            }
            if (nativeWindowCount != 0 &&
                !await _contentWindowBridge.prepareAndCloseRootWindows(
                  sessionID,
                )) {
              failedCount++;
              return;
            }
            if (nativeWindowCount == 0 &&
                decision.disposition != RootCloseDisposition.closeImmediately) {
              skippedCount++;
              return;
            }
            await _disposeCurrentDirectoryPageSession(
                directory.path, sessionID);
            if (!_isCurrentDirectorySession(directory.path, sessionID)) return;
            if (!_closeSession(sessionID)) {
              failedCount++;
              return;
            }
            _secureClipboard.removeSession(sessionID);
            _rootCloseCoordinator.releaseRoot(sessionID);
            _idleTracker.remove(sessionID);
            if (mounted) {
              _replaceWithLockedDirectory(
                directory,
                EncryptedDirectory(
                  path: directory.path,
                  config: directory.config,
                  isVerified: false,
                  displayAlias: directory.displayAlias,
                ),
                expectedSessionID: sessionID,
              );
            }
            lockedCount++;
          });
        } catch (_) {
          failedCount++;
        }
      }
    } finally {
      _isAutoLocking = false;
    }
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    final messages = <String>[];
    if (lockedCount > 0) {
      messages.add(strings.autoLockSummaryLocked(lockedCount));
    }
    if (skippedCount > 0) {
      messages.add(strings.autoLockSummarySkipped(skippedCount));
    }
    if (failedCount > 0) {
      messages.add(strings.autoLockSummaryFailed(failedCount));
    }
    if (messages.isNotEmpty) {
      _pendingAutoLockSummary = messages.join(strings.messageListSeparator);
    }
  }

  bool _isCurrentDirectorySession(String path, String sessionID) {
    final current = _currentDir;
    return (current?.path == path && current?.tempKeyID == sessionID) ||
        _openedDirs.any(
          (directory) =>
              directory.path == path && directory.tempKeyID == sessionID,
        );
  }

  Future<T> _runRootCloseOperation<T>(
    String sessionID,
    Future<T> Function() operation,
  ) async {
    final previous = _rootCloseTails[sessionID];
    final completion = Completer<void>();
    _rootCloseTails[sessionID] = completion.future;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_rootCloseTails[sessionID], completion.future)) {
        _rootCloseTails.remove(sessionID);
      }
    }
  }

  Future<void> _disposeCurrentDirectoryPageSession(
    String path,
    String sessionID,
  ) async {
    final current = _currentDir;
    if (current?.path != path || current?.tempKeyID != sessionID) return;
    final pageSession = _pageSession;
    _pageSession = null;
    _pageGeneration++;
    _isLoadingMore = false;
    _isLoading = false;
    await pageSession?.dispose();
  }

  // ── Persistence ───────────────────────────────────────────────────

  Future<void> _checkFirstLaunchAntiScreenshot() async {
    try {
      final enabled = await _settingsService.getAntiScreenshot();
      if (!enabled) return;
      final confirmed =
          await _settingsService.getAntiScreenshotFirstConfirmed();
      if (confirmed) return;

      // First launch with anti-screenshot enabled — two-step flow
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final strings = AppLocalizations.of(context)!;

        // Step 1: informational dialog
        final enable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AntiScreenshotInfoDialog(strings: strings),
        );
        if (!mounted || enable != true) {
          await _settingsService.setAntiScreenshot(false);
          await _settingsService.applyAntiScreenshot();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.antiScreenshotHint)),
            );
          }
          return;
        }

        // Step 2: countdown to confirm
        final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AntiScreenshotCountdownDialog(strings: strings),
        );
        if (saved == true) {
          await _settingsService.setAntiScreenshotFirstConfirmed(true);
        } else {
          // User cancelled or timeout — disable anti-screenshot
          await _settingsService.setAntiScreenshot(false);
          await _settingsService.applyAntiScreenshot();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.antiScreenshotHint)),
            );
          }
        }
      });
    } catch (_) {
      // Best-effort; non-critical.
    }
  }

  Future<void> _checkFirstTimeUser() async {
    final isFirstTime = await _persistenceService.isFirstTimeUser();
    if (isFirstTime && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeGuide());
    }
  }

  Future<void> _showWelcomeGuide() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeGuideDialog(
        onComplete: (neverShowAgain) async {
          if (neverShowAgain) {
            await _persistenceService.setNeverShowWelcome(true);
          } else {
            await _persistenceService.markWelcomeShown();
          }
        },
      ),
    );
  }

  Future<void> _loadDrawerPinnedState() async {
    final pinned = await _persistenceService.loadDrawerPinned();
    setState(() => _drawerPinned = pinned);
  }

  Future<void> _loadPersistedDirectories() async {
    final values = await Future.wait<Object>([
      _persistenceService.loadOpenedDirectories(),
      _persistenceService.loadDirectoryAliases(),
    ]);
    final paths = values[0] as List<String>;
    final aliases = values[1] as Map<String, String>;
    for (final path in paths) {
      try {
        final config = _cryptoService.loadConfig(path);
        setState(() {
          _openedDirs.add(EncryptedDirectory(
            path: path,
            config: config,
            isVerified: false,
            displayAlias: aliases[path],
          ));
        });
      } catch (e) {
        // Directory no longer exists or config is invalid, skip it.
      }
    }
  }

  Future<void> _renameDirectoryAlias(EncryptedDirectory directory) async {
    if (directory.displayAlias == null &&
        _openedDirs.any((item) =>
            item.path == directory.path && item.displayAlias != null)) {
      await _applyDirectoryAlias(directory.path, null);
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
    await _applyDirectoryAlias(directory.path, alias.trim());
  }

  Future<void> _applyDirectoryAlias(String path, String? alias) async {
    setState(() {
      final index = _openedDirs.indexWhere((item) => item.path == path);
      if (index < 0) return;
      final updated = _openedDirs[index].copyWith(
        displayAlias: alias,
        clearDisplayAlias: alias == null || alias.isEmpty,
      );
      _openedDirs[index] = updated;
      if (_currentDir?.path == path) _currentDir = updated;
    });
    await _persistenceService.saveDirectoryAlias(path, alias);
  }

  Future<void> _saveOpenedDirectories() async {
    final paths = _openedDirs.map((d) => d.path).toList();
    await _persistenceService.saveOpenedDirectories(paths);
  }

  Future<void> _moveDirectory(EncryptedDirectory directory, int delta) async {
    final index = _openedDirs.indexWhere((item) => item.path == directory.path);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= _openedDirs.length) return;
    setState(() {
      final moved = _openedDirs.removeAt(index);
      _openedDirs.insert(target, moved);
    });
    await _saveOpenedDirectories();
  }

  // ── Directory open / create ───────────────────────────────────────

  Future<void> _openOrCreateEncryptedDirectory() async {
    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => const PathSelectionDialog(),
    );
    if (selectedPath == null || selectedPath.isEmpty) return;

    final configFile = File.fromUri(
      Directory(selectedPath).uri.resolve('_cryption.json'),
    );
    final configExists = await configFile.exists();

    if (configExists) {
      await _loadDirectory(selectedPath);
    } else {
      await _createEncryptedDirectoryWithPath(selectedPath);
    }
  }

  Future<void> _createEncryptedDirectoryWithPath(String selectedPath) async {
    final directory = Directory(selectedPath);
    bool isNonEmpty;
    try {
      isNonEmpty = await directory.exists() &&
          !await directory.list(followLinks: false).isEmpty;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.createEncryptedDirectoryFailed,
          originalError: error.toString(),
          operation: 'validate-create-root-path',
        );
      }
      return;
    }
    if (isNonEmpty) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.createEncryptedDirectoryRequiresEmpty,
          originalError: 'The selected directory is not empty: $selectedPath',
          operation: 'validate-create-root-path',
        );
      }
      return;
    }
    final initialKeyStrengthMs = await _settingsService.getKeyStrengthMs();
    if (!mounted) return;
    final result = await showDialog<CreateRootRequest>(
      context: context,
      builder: (context) => CreateEncryptedDirectoryDialog(
        initialKeyStrengthMs: initialKeyStrengthMs,
      ),
    );
    if (result == null) return;

    final password = result.password;

    setState(() => _isLoading = true);

    var operation = 'create-root-config';
    try {
      _cryptoService.createRootConfig(
        selectedPath,
        password,
        result.optionsJSON,
      );
      operation = 'open-created-root';
      final rootID = _cryptoService.openRoot(selectedPath, password, '');
      if (!_webDavEnabled) await _revokeWebDavSessionsForRoot(rootID);
      operation = 'load-created-root-config';
      final config = _cryptoService.loadConfig(selectedPath);

      if (mounted) {
        setState(() {
          _currentDir = EncryptedDirectory(
            path: selectedPath,
            config: config,
            isVerified: true,
            tempKeyID: rootID.toString(),
          );
          _currentPath = selectedPath;
          final existingIndex =
              _openedDirs.indexWhere((d) => d.path == selectedPath);
          if (existingIndex >= 0) _openedDirs.removeAt(existingIndex);
          _openedDirs.insert(0, _currentDir!);
        });
        await _saveOpenedDirectories();
        await _loadCurrentPath();
        if (!mounted) return;
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.encryptedDirectoryCreated,
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.createEncryptedDirectoryFailed,
          originalError: e.toString(),
          operation: operation,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);

    try {
      final root = _cryptoService.findCryptionRoot(path);
      if (root.isEmpty) {
        if (mounted) {
          ErrorHelper.showError(context,
              errorType: ErrorType.notEncryptedDirectory);
        }
        return;
      }

      final config = _cryptoService.loadConfig(root);

      setState(() {
        _currentDir = EncryptedDirectory(path: root, config: config);
        _currentPath = root;

        final existingIndex = _openedDirs.indexWhere((d) => d.path == root);
        if (existingIndex >= 0) _openedDirs.removeAt(existingIndex);
        _openedDirs.insert(0, _currentDir!);
      });

      await _saveOpenedDirectories();

      if (root != path && mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.encryptedRootFound(root),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.loadConfigFailed,
          originalError: e.toString(),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _loadCurrentPath() async {
    if (_currentPath == null || !mounted) return false;
    setState(() => _isLoading = true);

    final path = _currentPath!;
    final generation = ++_pageGeneration;
    await _pageSession?.dispose();
    final session = _fileService.openCurrentDirectorySession(path);
    _pageSession = session;
    try {
      if (session == null) {
        final items = await _fileService.listCurrentDirectory(path);
        if (mounted && generation == _pageGeneration) {
          setState(() => _items = items);
        }
        return true;
      }
      await session.loadNext();
      if (mounted && generation == _pageGeneration) {
        setState(() => _items = _nodesForSession(session));
      }
      return true;
    } catch (e) {
      if (mounted && generation == _pageGeneration) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.loadDirectoryFailed,
          originalError: e.toString(),
        );
      }
      return false;
    } finally {
      if (mounted && generation == _pageGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<FileSystemNode> _nodesForSession(DirectoryPageSession session) {
    return _fileService.nodesForDirectoryPage(session, session.entries);
  }

  Future<void> _loadMoreCurrentPath() async {
    final session = _pageSession;
    if (session == null || session.done || session.hasError || _isLoadingMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      await session.loadNext();
      if (mounted && identical(session, _pageSession)) {
        setState(() => _items = _nodesForSession(session));
      }
    } catch (e) {
      if (mounted && identical(session, _pageSession)) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.loadDirectoryFailed,
          originalError: e.toString(),
        );
      }
    } finally {
      if (mounted && identical(session, _pageSession)) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // ── Password verification ─────────────────────────────────────────

  Future<bool> _verifyPassword(String password) async {
    final openingDirectory = _currentDir;
    if (openingDirectory == null) return false;
    final openingPath = openingDirectory.path;

    late final int rootID;
    try {
      rootID = _cryptoService.openRoot(openingPath, password, '');
    } catch (error) {
      if (mounted) {
        final presentation = classifyRootOpenError(error);
        ErrorHelper.showError(
          context,
          errorType: presentation.type,
          originalError: error.toString(),
          operation: presentation.operation,
        );
      }
      return false;
    }

    if (!_webDavEnabled) await _revokeWebDavSessionsForRoot(rootID);
    final transferStateAvailable = await _handleUnfinishedOperations(rootID);
    // The unfinished-state prompt is asynchronous and the sidebar stays
    // usable. Never attach this root to a directory selected after unlock
    // started; close the unowned native session instead.
    if (!transferStateAvailable ||
        !mounted ||
        !identical(_currentDir, openingDirectory)) {
      _closeSession(rootID.toString());
      return false;
    }

    setState(() {
      _currentDir = EncryptedDirectory(
        path: _currentDir!.path,
        config: _currentDir!.config,
        isVerified: true,
        tempKeyID: rootID.toString(),
      );

      final index = _openedDirs.indexWhere((d) => d.path == _currentDir!.path);
      if (index >= 0) _openedDirs[index] = _currentDir!;
    });

    final loaded = await _loadCurrentPath();
    if (!mounted ||
        _currentDir?.path != openingPath ||
        _currentDir?.tempKeyID != rootID.toString()) {
      // Directory loading can yield to a session switch or a second unlock.
      // Do not leave the root opened by this stale unlock attempt behind.
      _closeSession(rootID.toString());
      return false;
    }

    if (loaded) {
      _idleTracker.touch(rootID.toString());
      unawaited(_refreshWebDavSessionCount(rootID));
      ErrorHelper.showSuccess(
        context,
        AppLocalizations.of(context)!.passwordVerified,
      );
    }
    return true;
  }

  Future<bool> _handleUnfinishedOperations(int rootID) async {
    List<Map<String, dynamic>> markers;
    try {
      markers = await _directoryService.listUnfinishedOperations(rootID);
    } catch (e) {
      if (mounted) {
        final presentation = classifyUnfinishedTransferError(e);
        ErrorHelper.showError(
          context,
          errorType: presentation.type,
          originalError: e.toString(),
          operation: presentation.operation,
        );
      }
      return false;
    }
    if (!mounted || markers.isEmpty) return true;
    final strings = AppLocalizations.of(context)!;

    final action = await showDialog<_UnfinishedAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.unfinishedTransfersDetected),
        content: Text(
            strings.unfinishedTransfersDetectedDescription(markers.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.skip),
            child: Text(strings.skipForNow),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.clean),
            child: Text(strings.cleanState),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.rerun),
            child: Text(strings.rerunAll),
          ),
        ],
      ),
    );

    if (action == _UnfinishedAction.rerun) {
      await _rerunUnfinishedOperations(rootID, markers);
      return true;
    }
    if (action != _UnfinishedAction.clean) {
      return true;
    }

    try {
      var cleaned = 0;
      for (final marker in markers) {
        final opID = marker['op_id'] as String?;
        if (opID == null || opID.isEmpty) {
          continue;
        }
        await _directoryService.cleanUnfinishedOperation(rootID, opID);
        cleaned++;
      }

      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.unfinishedStatesCleaned(cleaned),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: e.toString(),
        );
      }
    }
    return true;
  }

  Future<void> _rerunUnfinishedOperations(
    int rootID,
    List<Map<String, dynamic>> markers,
  ) async {
    final strings = AppLocalizations.of(context)!;
    DirectoryTransferCancellationToken? currentToken;
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.rerunUnfinishedTransfers,
      total: 100,
      status: strings.preparing,
      onCancel: () {
        final accepted = currentToken?.cancel() ?? false;
        if (!accepted) {
          progressController.update(status: strings.operationNotCancellableYet);
        }
        return accepted;
      },
    );

    try {
      for (var index = 0; index < markers.length; index++) {
        currentToken = DirectoryTransferCancellationToken();
        progressController.update(
          current: 0,
          status:
              strings.rerunningUnfinishedProgress(index + 1, markers.length),
        );
        await _directoryService.rerunUnfinishedOperation(
          rootID,
          markers[index],
          cancellationToken: currentToken,
          onProgress: (progress) {
            progressController.update(
              current: progress.percent,
              currentFileName: progress.currentFile,
              status: strings.rerunningUnfinishedProgress(
                index + 1,
                markers.length,
              ),
            );
          },
        );
      }
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
        ErrorHelper.showSuccess(
            context, strings.unfinishedTransfersRerunCompleted);
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && currentToken?.isCancelled == true) {
        ErrorHelper.showInfo(
            context, strings.unfinishedTransfersRerunCancelled);
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  // ── Directory management ──────────────────────────────────────────

  void _switchToDirectory(EncryptedDirectory dir) {
    setState(() {
      _currentDir = dir;
      _currentPath = dir.path;
      _items = [];
    });
    if (dir.isVerified) {
      _loadCurrentPath();
      final rootID = int.tryParse(dir.tempKeyID ?? '');
      if (rootID != null) unawaited(_refreshWebDavSessionCount(rootID));
    }
  }

  Future<void> _closeDirectory(EncryptedDirectory dir) async {
    final strings = AppLocalizations.of(context)!;
    final action = await showRootDirectoryActionDialog(
      context: context,
      directoryName: _baseName(dir.path),
      hasActiveSession: dir.tempKeyID != null,
    );
    if (action == null || !mounted) return;
    if (action == RootDirectoryAction.deleteDirectory) {
      final confirmed = await confirmRootDirectoryDeletion(
        context: context,
        directoryPath: dir.path,
      );
      if (!confirmed || !mounted) return;
    }

    final sessionID = dir.tempKeyID;
    if (sessionID != null) {
      await _runRootCloseOperation(
        sessionID,
        () => _closeDirectoryAfterDecision(dir, action, sessionID, strings),
      );
      return;
    }
    await _closeDirectoryAfterDecision(dir, action, null, strings);
  }

  Future<void> _closeDirectoryAfterDecision(
    EncryptedDirectory dir,
    RootDirectoryAction action,
    String? sessionID,
    AppLocalizations strings,
  ) async {
    if (sessionID != null && !_isCurrentDirectorySession(dir.path, sessionID)) {
      return;
    }
    final closeDecision =
        sessionID == null ? null : _rootCloseCoordinator.inspect(sessionID);
    if (closeDecision?.disposition ==
        RootCloseDisposition.blockedByActiveWrites) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.rootActiveWritesTitle),
          content: Text(
            strings.rootActiveWritesDescription(
              closeDecision!.activeWriteCount,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.acknowledge),
            ),
          ],
        ),
      );
      return;
    }
    if (closeDecision?.disposition ==
        RootCloseDisposition.blockedByUnsavedDocuments) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.rootUnsavedContentTitle),
          content: Text(
            strings.rootUnsavedContentDescription(
              closeDecision!.dirtyDocumentNames.join('\n'),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.acknowledge),
            ),
          ],
        ),
      );
      return;
    }
    if (sessionID != null && closeDecision?.windowCount != 0) {
      try {
        await _contentWindowBridge.closeRootWindows(sessionID);
      } catch (error) {
        if (mounted) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: error.toString(),
            operation: 'close-root-content-windows',
          );
        }
        return;
      }
      if (!_isCurrentDirectorySession(dir.path, sessionID)) return;
    }

    if (sessionID != null) {
      await _disposeCurrentDirectoryPageSession(dir.path, sessionID);
      if (!_isCurrentDirectorySession(dir.path, sessionID)) return;
    }
    if (!_closeSession(sessionID)) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: 'close-root-session-failed',
          operation: 'close-root-session',
        );
      }
      return;
    }
    if (sessionID != null) _secureClipboard.removeSession(sessionID);
    if (sessionID != null) _rootCloseCoordinator.releaseRoot(sessionID);
    if (sessionID != null) _idleTracker.remove(sessionID);

    final lockedDirectory = EncryptedDirectory(
      path: dir.path,
      config: dir.config,
      isVerified: false,
      displayAlias: dir.displayAlias,
    );
    if (action == RootDirectoryAction.deleteDirectory) {
      try {
        final delete = widget.deleteRootDirectory ??
            (path) => Directory(path).delete(recursive: true);
        await delete(dir.path);
      } catch (error) {
        if (mounted) {
          _replaceWithLockedDirectory(
            dir,
            lockedDirectory,
            expectedSessionID: sessionID,
          );
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: error.toString(),
            operation: 'delete-root-directory',
          );
        }
        return;
      }
    }

    if (action == RootDirectoryAction.endSession) {
      _replaceWithLockedDirectory(
        dir,
        lockedDirectory,
        expectedSessionID: sessionID,
      );
      return;
    }

    setState(() {
      _openedDirs.removeWhere((item) => item.path == dir.path);
      if (_currentDir?.path == dir.path) {
        _currentDir = _openedDirs.isEmpty ? null : _openedDirs.first;
        _currentPath = _currentDir?.path;
        _items = [];
      }
    });
    await _saveOpenedDirectories();
    if (mounted) {
      ErrorHelper.showSuccess(
        context,
        action == RootDirectoryAction.deleteDirectory
            ? strings.rootDirectoryDeleted
            : strings.rootHistoryRemoved,
      );
    }
  }

  Future<bool> _lockRootForPasswordChange(EncryptedDirectory directory) async {
    final sessionID = directory.tempKeyID;
    if (sessionID == null) return true;
    return _runRootCloseOperation(
      sessionID,
      () => _lockRootForPasswordChangeAfterGate(directory, sessionID),
    );
  }

  Future<bool> _lockRootForPasswordChangeAfterGate(
    EncryptedDirectory directory,
    String sessionID,
  ) async {
    if (!_isCurrentDirectorySession(directory.path, sessionID)) return false;
    final decision = _rootCloseCoordinator.inspect(sessionID);
    if (decision.disposition != RootCloseDisposition.closeImmediately) {
      final strings = AppLocalizations.of(context)!;
      final message =
          decision.disposition == RootCloseDisposition.blockedByActiveWrites
              ? strings.passwordChangeBlockedBySaving
              : strings.passwordChangeBlockedByDocuments;
      if (mounted) ErrorHelper.showInfo(context, message);
      return false;
    }
    if (decision.windowCount != 0) {
      try {
        await _contentWindowBridge.closeRootWindows(sessionID);
      } catch (error) {
        if (mounted) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: error.toString(),
            operation: 'change-root-password/close-windows',
          );
        }
        return false;
      }
      if (!_isCurrentDirectorySession(directory.path, sessionID)) return false;
    }
    await _disposeCurrentDirectoryPageSession(directory.path, sessionID);
    if (!_isCurrentDirectorySession(directory.path, sessionID)) return false;
    if (!_closeSession(sessionID)) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: 'change-root-password-close-session-failed',
          operation: 'change-root-password/close-session',
        );
      }
      return false;
    }
    _secureClipboard.removeSession(sessionID);
    _rootCloseCoordinator.releaseRoot(sessionID);
    _idleTracker.remove(sessionID);
    if (mounted) {
      _replaceWithLockedDirectory(
        directory,
        EncryptedDirectory(
          path: directory.path,
          config: directory.config,
          displayAlias: directory.displayAlias,
        ),
        expectedSessionID: sessionID,
      );
    }
    return true;
  }

  Future<void> _changeRootPassword(EncryptedDirectory directory) async {
    final strings = AppLocalizations.of(context)!;
    if (!rootSupportsPasswordChange(directory)) {
      await showUnsupportedRootPasswordChange(
        context: context,
        directory: directory,
      );
      return;
    }
    final request = await showRootPasswordChangeDialog(
      context: context,
      directoryName: directory.displayAlias ?? _baseName(directory.path),
    );
    if (request == null || !mounted) return;
    if (!await _lockRootForPasswordChange(directory) || !mounted) return;

    setState(() => _isLoading = true);
    try {
      _cryptoService.changeRootPassword(
        directory.path,
        request.oldPassword,
        request.newPassword,
      );
      final updatedConfig = _cryptoService.loadConfig(directory.path);
      if (mounted) {
        _replaceWithLockedDirectory(
          directory,
          EncryptedDirectory(
            path: directory.path,
            config: updatedConfig,
            displayAlias: directory.displayAlias,
          ),
        );
        ErrorHelper.showSuccess(context, strings.passwordChangedUnlockAgain);
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'change-root-password',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manageRootPasswordHint(EncryptedDirectory directory) async {
    final strings = AppLocalizations.of(context)!;
    if (!directory.isVerified ||
        _cryptoService.rootIDForPath(directory.path) == null) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.directoryNotVerified,
        originalError: 'password-hint-root-session-not-open',
        operation: 'password-hint/update',
      );
      return;
    }
    final request = await showRootPasswordHintDialog(
      context: context,
      directoryName: directory.displayAlias ?? _baseName(directory.path),
      currentHint: directory.config.passwordHint,
    );
    if (request == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      _cryptoService.updateRootPasswordHint(
        directory.path,
        request.password,
        request.hint,
      );
      final updatedConfig = _cryptoService.loadConfig(directory.path);
      if (mounted) {
        setState(() {
          final index =
              _openedDirs.indexWhere((item) => item.path == directory.path);
          final latestDirectory = index >= 0 ? _openedDirs[index] : _currentDir;
          final updatedDirectory = latestDirectory?.copyWith(
            config: updatedConfig,
          );
          if (index >= 0 && updatedDirectory != null) {
            _openedDirs[index] = updatedDirectory;
          }
          if (_currentDir?.path == directory.path) {
            _currentDir = updatedDirectory ??
                _currentDir!.copyWith(config: updatedConfig);
          }
        });
        ErrorHelper.showSuccess(context, strings.passwordHintUpdated);
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'password-hint/update',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _replaceWithLockedDirectory(
    EncryptedDirectory directory,
    EncryptedDirectory lockedDirectory, {
    String? expectedSessionID,
  }) {
    setState(() {
      final index =
          _openedDirs.indexWhere((item) => item.path == directory.path);
      final openedDirectory = index >= 0 ? _openedDirs[index] : null;
      final openedMatches = expectedSessionID == null ||
          openedDirectory?.tempKeyID == expectedSessionID;
      if (index >= 0 && openedMatches) {
        _openedDirs[index] = lockedDirectory;
      }
      final currentMatches = expectedSessionID == null ||
          _currentDir?.tempKeyID == expectedSessionID;
      if (_currentDir?.path == directory.path && currentMatches) {
        _currentDir = lockedDirectory;
        _currentPath = lockedDirectory.path;
        _items = [];
        _selectedFiles.clear();
        _keyboardTarget = null;
        _keyboardSelectionAnchorPath = null;
        _isSelectMode = false;
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────

  void _navigateToDirectory(String path) {
    _touchCurrentRoot();
    setState(() => _currentPath = path);
    _loadCurrentPath();
  }

  void _navigateUp() {
    if (_currentPath == null || _currentDir == null) return;
    final parent = _fileService.getParentDirectory(_currentPath!);
    if (parent == null) return;
    _navigateToDirectory(parent);
  }

  // ── File operations ───────────────────────────────────────────────

  void _openItem(FileSystemNode item) {
    if (item.isDirectory) {
      _navigateToDirectory(item.path);
      return;
    }

    if (isSupportedImageFormat(item.extension)) {
      _openImageViewer(item);
    } else {
      _openNotepad(item);
    }
  }

  Future<void> _openNotepad(FileSystemNode item) async {
    final directory = _currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    final settings = await Future.wait<Object>([
      _settingsService.getNotepadAutoSaveSeconds(),
      _settingsService.getNotepadDefaultReadOnly(),
      _settingsService.getNotepadDefaultMonitorClipboard(),
    ]);
    final autoSaveSeconds = settings[0] as int;
    final isZeroByte = item.size != null && item.size == 0;
    final initiallyReadOnly = isZeroByte
        ? false
        : settings[1] as bool || shouldOpenFallbackTextReadOnly(item.name);
    final initiallyMonitorClipboard = settings[2] as bool;
    if (!mounted || _currentDir?.tempKeyID != directory!.tempKeyID) return;
    try {
      final lease = _documentBroker.open(
        rootSessionID: directory.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureNotepadContentBytes,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureNotepad(
            tempKeyID: directory.tempKeyID!,
            file: EncryptedFile(
              name: item.name,
              encryptedPath: item.path,
              modifiedTime: DateTime.now(),
            ),
            cryptoService: _cryptoService,
            autoSaveInterval: Duration(seconds: autoSaveSeconds),
            initiallyReadOnly: initiallyReadOnly,
            initiallyMonitorClipboard: initiallyMonitorClipboard,
            onSaved: () => _loadCurrentPath(),
            documentBroker: _documentBroker,
            documentLease: lease,
          ),
        ),
      );
    } on DocumentContentSizeUnknown catch (_) {
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } on DocumentContentLimitExceeded catch (_) {
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!
              .notepadFileTooLarge(kSecureNotepadContentLimitLabel),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  Future<void> _openNotepadInNewWindow(FileSystemNode item) async {
    final directory = _currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    DocumentLease? lease;
    try {
      final localePreference = await _settingsService.getLocale();
      if (!mounted) return;
      lease = _documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureNotepadContentBytes,
      );
      if (await _contentWindowBridge.openNotepad(
        lease,
        localePreference: localePreference,
      )) {
        return;
      }
      _documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.nativeContentWindowUnavailable,
      );
      await _openNotepad(item);
    } on DocumentContentSizeUnknown catch (_) {
      if (lease != null) _documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } on DocumentContentLimitExceeded catch (_) {
      if (lease != null) _documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!
              .notepadFileTooLarge(kSecureNotepadContentLimitLabel),
        );
      }
    } catch (error) {
      if (lease != null) _documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  void _openImageViewer(FileSystemNode item) {
    if (item.isDirectory) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewer(
          tempKeyID: _currentDir!.tempKeyID!,
          file: EncryptedFile(
            name: item.name,
            encryptedPath: item.path,
            originalSize: item.size,
            modifiedTime: DateTime.now(),
          ),
          cryptoService: _cryptoService,
          directoryPath: _currentPath,
          fileService: _fileService,
        ),
      ),
    );
  }

  Future<void> _openImageViewerInNewWindow(FileSystemNode item) async {
    final directory = _currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    DocumentLease? lease;
    try {
      final localePreference = await _settingsService.getLocale();
      if (!mounted) return;
      lease = _documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureImageEncodedBytes,
        readOnly: true,
      );
      if (await _contentWindowBridge.openImage(
        lease,
        localePreference: localePreference,
      )) {
        return;
      }
      _documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.nativeContentWindowUnavailable,
      );
      _openImageViewer(item);
    } on DocumentContentSizeUnknown catch (_) {
      if (lease != null) _documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } catch (error) {
      if (lease != null) _documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  Future<void> _showFileOptions(FileSystemNode item) async {
    final action = await showFileItemActionSheet(
      context: context,
      item: item,
      canPasteInto: item.isDirectory && _secureClipboard.hasEntry,
    );
    if (action != null && mounted) await _executeFileItemAction(item, action);
  }

  Future<void> _showFileContextMenu(
    FileSystemNode item,
    Offset globalPosition,
  ) async {
    _keyboardTarget = item;
    final action = await showFileItemContextMenu(
      context: context,
      item: item,
      globalPosition: globalPosition,
      canPasteInto: item.isDirectory && _secureClipboard.hasEntry,
    );
    if (action != null && mounted) await _executeFileItemAction(item, action);
    if (mounted) _shortcutFocusNode.requestFocus();
  }

  Future<void> _showRootDirectoryPropertiesAfterMenu(
    EncryptedDirectory directory,
  ) async {
    // Let the popup-menu route finish before inserting another overlay.
    // Linux otherwise pays the first-frame cost for both layers at once.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showRootDirectoryProperties(
      context: context,
      directory: directory,
      onManagePasswordHint: directory.isVerified
          ? () => _manageRootPasswordHint(directory)
          : null,
    );
  }

  Future<void> _showBackgroundContextMenu(Offset globalPosition) async {
    _keyboardTarget = null;
    _keyboardSelectionAnchorPath = null;
    final action = await showDirectoryBackgroundContextMenu(
      context: context,
      globalPosition: globalPosition,
      canPaste: _secureClipboard.hasEntry,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case DirectoryBackgroundAction.newFile:
        await _createEntry(isDirectory: false);
        return;
      case DirectoryBackgroundAction.newDirectory:
        await _createEntry(isDirectory: true);
        return;
      case DirectoryBackgroundAction.paste:
        await _pasteClipboard();
        return;
      case DirectoryBackgroundAction.refresh:
        await _loadCurrentPath();
        return;
    }
  }

  Offset _keyboardContextMenuPosition() {
    final renderObject = Overlay.of(context).context.findRenderObject();
    if (renderObject is! RenderBox) return Offset.zero;
    return renderObject.size.center(Offset.zero);
  }

  void _showKeyboardContextMenu() {
    final target =
        _selectedFiles.length == 1 ? _selectedFiles.single : _keyboardTarget;
    final position = _keyboardContextMenuPosition();
    if (target != null && _items.any((item) => item.path == target.path)) {
      unawaited(_showFileContextMenu(target, position));
    } else {
      unawaited(_showBackgroundContextMenu(position));
    }
  }

  Future<void> _executeFileItemAction(
    FileSystemNode item,
    FileItemAction action,
  ) async {
    switch (action) {
      case FileItemAction.open:
        _openItem(item);
        return;
      case FileItemAction.edit:
        await _openNotepad(item);
        return;
      case FileItemAction.openInNewWindow:
        if (isViewableImageFile(item)) {
          await _openImageViewerInNewWindow(item);
        } else {
          await _openNotepadInNewWindow(item);
        }
        return;
      case FileItemAction.select:
        setState(() {
          _isSelectMode = true;
          _selectedFiles.add(item);
        });
        return;
      case FileItemAction.rename:
        await _renameItem(item);
        return;
      case FileItemAction.copy:
        _copyItem(item);
        return;
      case FileItemAction.cut:
        _cutItem(item);
        return;
      case FileItemAction.pasteInto:
        await _pasteClipboard(targetDirectory: item.path);
        return;
      case FileItemAction.export:
        if (item.isDirectory) {
          await _exportDirectory(item);
        } else {
          await _exportFile(item);
        }
        return;
      case FileItemAction.exposeToThirdParty:
        await _exposeToThirdParty(item);
        return;
      case FileItemAction.copyName:
        await Clipboard.setData(ClipboardData(text: item.name));
        if (mounted) {
          ErrorHelper.showInfo(
            context,
            AppLocalizations.of(context)!.copiedNameToSystemClipboard,
          );
        }
        return;
      case FileItemAction.copyPath:
        await Clipboard.setData(ClipboardData(text: item.path));
        if (mounted) {
          ErrorHelper.showInfo(
            context,
            AppLocalizations.of(context)!.copiedPathToSystemClipboard,
          );
        }
        return;
      case FileItemAction.properties:
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await showFileItemProperties(context: context, item: item);
        return;
      case FileItemAction.refresh:
        await _loadCurrentPath();
        return;
      case FileItemAction.delete:
        await _deleteFile(item);
        return;
    }
  }

  Future<void> _exposeToThirdParty(FileSystemNode item) async {
    if (!_webDavEnabled) {
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.webDavDisabledMessage,
      );
      return;
    }
    if (!_validateSession()) return;
    final directory = _currentDir;
    final activeSessionID = directory?.tempKeyID;
    if (directory == null || activeSessionID == null) return;
    final rootID = int.tryParse(activeSessionID);
    if (rootID == null) return;

    final confirmed = await confirmWebDavReadOnlyExposure(
      context: context,
      displayName: item.name,
    );
    if (!confirmed || !mounted) return;
    final options = await chooseWebDavOpenOptions(context: context);
    if (options == null || !mounted) return;
    if (!_isCurrentDirectorySession(directory.path, activeSessionID)) return;

    try {
      final session = _webDavService.open(
        rootID: rootID,
        logicalPath: item.path,
        displayName: item.name,
        authMode: options.authMode,
        credentialVisibility: options.credentialVisibility,
        sessionLifetime: options.sessionLifetime,
        tls: options.tls,
      );
      if (!mounted ||
          !_isCurrentDirectorySession(directory.path, activeSessionID)) {
        _webDavService.close(session.id);
        return;
      }
      await showWebDavCredentialsDialog(context: context, session: session);
      await _refreshWebDavSessionCount(rootID);
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/open',
        );
      }
    }
  }

  Future<void> _showWebDavSessions() async {
    if (!_webDavEnabled) return;
    final directory = _currentDir;
    final activeSessionID = directory?.tempKeyID;
    if (directory == null || activeSessionID == null) return;
    final rootID = int.tryParse(activeSessionID);
    if (rootID == null) return;
    final sessions = await _listWebDavSessions(rootID, reportErrors: true);
    if (sessions == null ||
        !mounted ||
        !_isCurrentDirectorySession(directory.path, activeSessionID)) {
      return;
    }
    await _setWebDavSessionCount(rootID, sessions.length);
    if (!mounted) return;
    await showWebDavSessionsDialog(
      context: context,
      sessions: sessions,
      onRevoke: _revokeWebDavSession,
      onMount: _mountWebDavSession,
      onUnmount: _unmountWebDavSession,
      onCancelMount: _cancelWebDavMount,
      onReveal: _revealWebDavSession,
      onRefresh: () => _refreshWebDavSessionsForDialog(rootID),
    );
  }

  Future<bool> _revokeWebDavSession(WebDavSessionStatus session) async {
    try {
      _webDavService.close(session.id);
      await _refreshWebDavSessionCount(session.rootID);
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.webDavSessionRevoked,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/close',
        );
      }
      return false;
    }
  }

  Future<bool> _runWebDavMountOperation(
    WebDavSessionStatus session, {
    required bool mount,
  }) async {
    final operationID =
        'webdav-${++_webDavOperationSequence}-${DateTime.now().microsecondsSinceEpoch}';
    _webDavMountOperations[session.id] = operationID;
    try {
      if (mount) {
        _webDavService.startMount(
          operationID: operationID,
          sessionID: session.id,
        );
      } else {
        _webDavService.startUnmount(
          operationID: operationID,
          sessionID: session.id,
        );
      }
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final result = _webDavService.pollOperation(operationID);
        final state = result['state'];
        if (state == 'running') continue;
        if (state == 'cancelled') return true;
        final response = result['response'];
        if (response is! Map || response['success'] != true) {
          throw StateError(
            response is Map
                ? response['error']?.toString() ?? 'webdav-operation-failed'
                : 'webdav-operation-response-missing',
          );
        }
        if (mounted && mount) {
          final data = response['data'];
          final path = data is Map ? data['mount_path']?.toString() : null;
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.webDavMountedAt(path ?? ''),
          );
        } else if (mounted) {
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.webDavUnmounted,
          );
        }
        return true;
      }
      return false;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: mount ? 'webdav/mount' : 'webdav/unmount',
        );
      }
      return false;
    } finally {
      try {
        // If the widget disappears before the final poll, stop the native
        // command instead of leaving a background mount operation alive.
        _webDavService.cancelOperation(operationID);
      } catch (_) {}
      _webDavMountOperations.remove(session.id);
    }
  }

  Future<bool> _mountWebDavSession(WebDavSessionStatus session) {
    return _runWebDavMountOperation(session, mount: true);
  }

  Future<bool> _unmountWebDavSession(WebDavSessionStatus session) {
    return _runWebDavMountOperation(session, mount: false);
  }

  Future<bool> _cancelWebDavMount(WebDavSessionStatus session) async {
    final operationID = _webDavMountOperations[session.id];
    if (operationID == null) return false;
    try {
      return _webDavService.cancelOperation(operationID);
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/cancel-mount',
        );
      }
      return false;
    }
  }

  Future<bool> _revealWebDavSession(WebDavSessionStatus session) async {
    try {
      final opened = _webDavService.reveal(session.id, rootID: session.rootID);
      if (mounted) {
        await showWebDavCredentialsDialog(context: context, session: opened);
      }
      return true;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/reveal',
        );
      }
      return false;
    }
  }

  Future<void> _refreshWebDavSessionCount(int rootID) async {
    final sessions = await _listWebDavSessions(rootID, reportErrors: false);
    if (sessions != null) await _setWebDavSessionCount(rootID, sessions.length);
  }

  Future<List<WebDavSessionStatus>?> _refreshWebDavSessionsForDialog(
    int rootID,
  ) async {
    final sessions = await _listWebDavSessions(rootID, reportErrors: true);
    if (sessions != null) await _setWebDavSessionCount(rootID, sessions.length);
    return sessions;
  }

  Future<void> _setWebDavSessionCount(int rootID, int count) async {
    if (!mounted || _webDavSessionCounts[rootID] == count) return;
    setState(() => _webDavSessionCounts[rootID] = count);
  }

  Future<void> _setWebDavEnabled(bool enabled) async {
    if (mounted) setState(() => _webDavEnabled = enabled);
    if (enabled) return;

    for (final operationID in _webDavMountOperations.values.toList()) {
      try {
        _webDavService.cancelOperation(operationID);
      } catch (_) {
        // Best-effort cleanup: cancel may fail if the operation has already
        // completed or the underlying connection has been torn down.
      }
    }

    for (final directory in List<EncryptedDirectory>.from(_openedDirs)) {
      final sessionID = directory.tempKeyID;
      final rootID = sessionID == null ? null : int.tryParse(sessionID);
      if (rootID == null) continue;
      final sessions = await _listWebDavSessions(rootID, reportErrors: false);
      if (sessions == null) continue;
      await _revokeWebDavSessionsForRoot(rootID, sessions: sessions);
      final remaining = await _listWebDavSessions(rootID, reportErrors: false);
      if (mounted) {
        setState(() => _webDavSessionCounts[rootID] =
            remaining?.length ?? sessions.length);
      }
    }
  }

  Future<void> _revokeWebDavSessionsForRoot(
    int rootID, {
    List<WebDavSessionStatus>? sessions,
  }) async {
    final active = sessions ??
        await _listWebDavSessions(
          rootID,
          reportErrors: false,
        );
    if (active == null) return;
    for (final session in active) {
      try {
        _webDavService.close(session.id);
      } catch (_) {
        // The switch remains disabled; Go remains authoritative for status.
      }
    }
  }

  Future<List<WebDavSessionStatus>?> _listWebDavSessions(
    int rootID, {
    required bool reportErrors,
  }) async {
    try {
      return _webDavService.list(rootID: rootID);
    } catch (error) {
      if (reportErrors && mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/list',
        );
      }
      return null;
    }
  }

  // ── Import / Export ───────────────────────────────────────────────

  Future<void> _importFile() async {
    if (!_validateSession()) return;

    final typeGroup = XTypeGroup(label: AppLocalizations.of(context)!.allFiles);
    final XFile? file = widget.selectFile != null
        ? await widget.selectFile!([typeGroup])
        : await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;

    await _importFilePath(file.path, file.name);
  }

  Future<void> _importFilePath(String sourcePath, String sourceName) async {
    if (!_validateSession()) return;

    var destinationName = sourceName;
    var overwrite = false;
    if (_items
        .any((item) => item.name.toLowerCase() == sourceName.toLowerCase())) {
      final existing = _items.firstWhere(
        (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
      );
      final resolution = await showEntryConflictDialog(
        context: context,
        name: sourceName,
        isDirectory: false,
        operation: AppLocalizations.of(context)!.importOperation,
        allowReplace: !existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        destinationName = nextAvailableEntryName(
          originalName: sourceName,
          isDirectory: false,
          existingNames: _items.map((item) => item.name),
          copyLabel: AppLocalizations.of(context)!.copySuffix,
        );
      } else {
        overwrite = true;
      }
    }

    try {
      setState(() => _isLoading = true);

      final rootID = int.parse(_currentDir!.tempKeyID!);
      final currentRelative =
          _cryptoService.relativePathForRoot(rootID, _currentPath!);
      final destination = currentRelative.isEmpty
          ? destinationName
          : '$currentRelative/$destinationName';
      await _directoryService.importFile(
        rootID,
        sourcePath,
        destination,
        overwrite: overwrite,
      );
      await _loadCurrentPath();

      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.fileImportCompleted(destinationName),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.importFileFailed,
          originalError: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importDirectory() async {
    if (!_validateSession()) return;

    final sourcePath = widget.selectDirectory != null
        ? await widget.selectDirectory!()
        : await getDirectoryPath();
    if (sourcePath == null || !mounted) return;
    await _importDirectoryPath(sourcePath);
  }

  Future<void> _importDirectoryPath(String sourcePath) async {
    if (!_validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    if (isPathInsideDirectory(sourcePath, _currentDir!.path)) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.importDirectoryInsideCurrentRoot,
      );
      return;
    }

    var destPath = buildDirectoryImportDestination(
      rootPath: _currentDir!.path,
      currentPath: _currentPath!,
      sourcePath: sourcePath,
    );
    final sourceName = destPath.split('/').last;
    var overwrite = false;
    if (_items.any(
      (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
    )) {
      final existing = _items.firstWhere(
        (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
      );
      final resolution = await showEntryConflictDialog(
        context: context,
        name: sourceName,
        isDirectory: true,
        operation: AppLocalizations.of(context)!.importOperation,
        allowReplace: existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        final newName = nextAvailableEntryName(
          originalName: sourceName,
          isDirectory: true,
          existingNames: _items.map((item) => item.name),
          copyLabel: AppLocalizations.of(context)!.copySuffix,
        );
        final separator = destPath.lastIndexOf('/');
        destPath = separator < 0
            ? newName
            : '${destPath.substring(0, separator + 1)}$newName';
      } else {
        overwrite = true;
      }
    }

    final rootID = int.parse(_currentDir!.tempKeyID!);
    final cancellationToken = DirectoryTransferCancellationToken();
    var completedFiles = 0;
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.importDirectory,
      total: 100,
      status: strings.preparingImport,
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: strings.preparingCannotCancel);
        }
        return accepted;
      },
    );

    try {
      await _directoryService.importDirectory(
        rootID,
        sourcePath,
        destPath,
        overwrite: overwrite,
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          completedFiles = progress.completedFiles;
          progressController.update(
            current: progress.percent,
            currentFileName: progress.currentFile,
            status: strings.importing,
          );
        },
      );
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (!mounted) return;
      await _loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          strings.directoryImportCompleted(completedFiles),
        );
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && cancellationToken.isCancelled) {
        ErrorHelper.showInfo(
          context,
          strings.transferCancelledWithUnfinishedState,
        );
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.importDirectoryFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> _importDroppedCandidates(
    List<DragDropCandidate> candidates,
  ) async {
    if (!_validateSession()) return;
    final directory = _currentDir!;
    final requests = _dragDropController.importRequests(
      candidates: candidates,
      rootPath: directory.path,
    );
    for (final request in requests) {
      if (!mounted || !_validateSession()) return;
      switch (request.kind) {
        case DragDropImportKind.file:
          await _importFilePath(
            request.path,
            File(request.path).uri.pathSegments.last,
          );
        case DragDropImportKind.directory:
          await _importDirectoryPath(request.path);
      }
    }
  }

  Future<void> _exportFile(FileSystemNode item) async {
    if (!_validateSession()) return;
    if (!await _confirmPlaintextExport(item)) return;

    final FileSaveLocation? saveLocation = widget.selectSaveLocation != null
        ? await widget.selectSaveLocation!(item.name)
        : await getSaveLocation(suggestedName: item.name);
    if (saveLocation == null || !mounted) return;
    final destination = await _resolveExportDestination(
      saveLocation.path,
      operation: AppLocalizations.of(context)!.exportOperation,
    );
    if (destination == null || !mounted) return;

    try {
      await _fileService.exportFile(
        item,
        destination.path,
        _currentDir!.tempKeyID!,
        overwrite: destination.overwrite,
      );
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.fileExportCompleted(destination.path),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> _exportDirectory(FileSystemNode item) async {
    if (!_validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    if (!await _confirmPlaintextExport(item)) return;

    final String? exportDir = widget.selectDirectory != null
        ? await widget.selectDirectory!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final String? dstDir;
    try {
      dstDir = await _resolveDirectoryExportDestination(
        '$exportDir/${item.name}',
        operation: strings.exportOperation,
      );
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportDirectoryFailed,
          originalError: error.toString(),
          operation: 'resolve-directory-export-destination',
        );
      }
      return;
    }
    if (dstDir == null || !mounted) return;
    final cancellationToken = DirectoryTransferCancellationToken();
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.exportDirectory,
      total: 100,
      status: strings.preparingExport,
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: strings.preparingCannotCancel);
        }
        return accepted;
      },
    );

    try {
      final progress = await _directoryService.decryptDirectory(
        item.path,
        dstDir,
        _currentDir!.tempKeyID!,
        cancellationToken: cancellationToken,
        onProgress: (jobProgress) {
          progressController.update(
            current: jobProgress.percent,
            currentFileName: jobProgress.currentFile,
            status: strings.exporting,
          );
        },
      );

      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }

      if (mounted) {
        if (progress.isCancelled) {
          ErrorHelper.showInfo(
            context,
            strings.transferCancelledWithUnfinishedState,
          );
        } else if (progress.isComplete &&
            !progress.isFailed &&
            !progress.isCancelled) {
          ErrorHelper.showSuccess(context,
              strings.directoryExportCompleted(progress.processedFiles));
        } else if (progress.isFailed) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.exportDirectoryFailed,
            originalError:
                progress.error ?? 'directory-export-failed-without-error',
          );
        }
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(
          context,
          strings.transferCancelledWithUnfinishedState,
        );
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportDirectoryFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> _batchExport() async {
    if (!_validateSession()) return;
    final strings = AppLocalizations.of(context)!;

    final String? exportDir = widget.selectDirectory != null
        ? await widget.selectDirectory!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final jobs = <({FileSystemNode item, String path, bool overwrite})>[];
    for (final item in _selectedFiles) {
      final destination = await _resolveExportDestination(
        '$exportDir/${item.name}',
        operation: AppLocalizations.of(context)!.batchExportOperation,
      );
      if (destination == null || !mounted) return;
      jobs.add((
        item: item,
        path: destination.path,
        overwrite: destination.overwrite,
      ));
    }

    final totalFiles = jobs.length;
    final progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.batchExport,
      total: totalFiles,
      status: strings.preparingExport,
    );

    final startTime = DateTime.now();
    int successCount = 0;
    int failCount = 0;

    try {
      for (final job in jobs) {
        if (progressController.isCancelled) break;

        progressController.update(
          current: successCount + failCount + 1,
          currentFileName: job.item.name,
          status: strings.exporting,
        );
        progressController.estimateTimeRemaining(
          startTime: startTime,
          processedCount: successCount + failCount + 1,
        );

        try {
          await _fileService.exportFile(
            job.item,
            job.path,
            _currentDir!.tempKeyID!,
            overwrite: job.overwrite,
          );
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }

      setState(() {
        _isSelectMode = false;
        _selectedFiles.clear();
      });

      if (mounted && !progressController.isCancelled) {
        final message = failCount > 0
            ? strings.batchExportCompleted(successCount, failCount)
            : strings.batchExportCompletedAll(successCount);
        ErrorHelper.showSuccess(context, message);
      } else if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(
            context, strings.batchExportCancelled(successCount, failCount));
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<({String path, bool overwrite})?> _resolveExportDestination(
    String path, {
    required String operation,
  }) async {
    final destination = File(path);
    final exists = widget.exportTargetExists != null
        ? await widget.exportTargetExists!(path)
        : await destination.exists();
    if (!exists) {
      return (path: path, overwrite: false);
    }
    if (!mounted) return null;

    final name = _baseName(destination.path);
    final resolution = await showEntryConflictDialog(
      context: context,
      name: name,
      isDirectory: false,
      operation: operation,
    );
    if (resolution == EntryConflictResolution.cancel || !mounted) return null;
    if (resolution == EntryConflictResolution.replace) {
      return (path: path, overwrite: true);
    }

    final parent = destination.parent;
    final existingNames = <String>[];
    await for (final entry in parent.list(followLinks: false)) {
      existingNames.add(_baseName(entry.path));
    }
    final availableName = nextAvailableEntryName(
      originalName: name,
      isDirectory: false,
      existingNames: existingNames,
      copyLabel: AppLocalizations.of(context)!.copySuffix,
    );
    return (
      path: '${parent.path}${Platform.pathSeparator}$availableName',
      overwrite: false,
    );
  }

  Future<String?> _resolveDirectoryExportDestination(
    String path, {
    required String operation,
  }) async {
    final destination = Directory(path);
    final exists = widget.exportTargetExists != null
        ? await widget.exportTargetExists!(path)
        : await destination.exists();
    if (!exists) return path;
    if (!mounted) return null;

    final resolution = await showEntryConflictDialog(
      context: context,
      name: _baseName(destination.path),
      isDirectory: true,
      operation: operation,
      allowReplace: false,
    );
    if (resolution == EntryConflictResolution.cancel || !mounted) return null;

    final parent = destination.parent;
    final existingNames = <String>[];
    await for (final entry in parent.list(followLinks: false)) {
      existingNames.add(_baseName(entry.path));
    }
    final availableName = nextAvailableEntryName(
      originalName: _baseName(destination.path),
      isDirectory: true,
      existingNames: existingNames,
      copyLabel: AppLocalizations.of(context)!.copySuffix,
    );
    return '${parent.path}${Platform.pathSeparator}$availableName';
  }

  Future<void> _batchDelete() async {
    if (!_validateSession() || _selectedFiles.isEmpty) return;
    final strings = AppLocalizations.of(context)!;
    final selected = Set<FileSystemNode>.from(_selectedFiles);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmBatchDeletion),
        content: Text(strings.confirmBatchDeletionDescription(selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(strings.deleteSelected),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.batchDelete,
      total: selected.length,
      status: strings.preparingDelete,
    );
    final succeeded = <FileSystemNode>{};
    final failed = <FileSystemNode>{};
    var processed = 0;
    for (final item in selected) {
      if (progressController.isCancelled) break;
      progressController.update(
        current: processed + 1,
        currentFileName: item.name,
        status: strings.deleting,
      );
      try {
        await _cryptoService.deleteFileBySession(
          item.path,
          _currentDir!.tempKeyID!,
        );
        succeeded.add(item);
      } catch (_) {
        failed.add(item);
      }
      processed++;
    }

    if (mounted && !progressController.isCancelled) {
      progressController.close(context);
    }
    if (!mounted) return;
    await _loadCurrentPath();
    if (!mounted) return;
    setState(() {
      _selectedFiles.removeAll(succeeded);
      _isSelectMode = _selectedFiles.isNotEmpty;
    });

    if (progressController.isCancelled) {
      ErrorHelper.showInfo(
        context,
        strings.batchDeleteCancelled(succeeded.length, _selectedFiles.length),
      );
    } else if (failed.isNotEmpty) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.deleteFileFailed,
        originalError: 'batch-delete-failed',
        operation: 'batch-delete',
      );
    } else {
      ErrorHelper.showSuccess(
          context, strings.batchDeleteCompleted(succeeded.length));
    }
  }

  String _baseName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  Future<bool> _confirmPlaintextExport(FileSystemNode item) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmPlaintextExport),
        content: Text(strings.confirmPlaintextExportDescription(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.continueExport),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _copyItem(FileSystemNode item) {
    if (!_validateSession()) return;
    _secureClipboard.copy(SecureClipboardEntry(
      sourcePath: item.path,
      sourceSessionID: _currentDir!.tempKeyID!,
      name: item.name,
      isDirectory: item.isDirectory,
    ));
    setState(() {});
    ErrorHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.copiedForPaste(item.name),
    );
  }

  void _cutItem(FileSystemNode item) {
    if (!_validateSession()) return;
    _secureClipboard.cut(SecureClipboardEntry(
      sourcePath: item.path,
      sourceSessionID: _currentDir!.tempKeyID!,
      name: item.name,
      isDirectory: item.isDirectory,
    ));
    setState(() {});
    ErrorHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.cutForMove(item.name),
    );
  }

  void _copySelected({required bool move}) {
    if (!_validateSession() || _selectedFiles.isEmpty) return;
    final entries = _items
        .where(_selectedFiles.contains)
        .map(
          (item) => SecureClipboardEntry(
            sourcePath: item.path,
            sourceSessionID: _currentDir!.tempKeyID!,
            name: item.name,
            isDirectory: item.isDirectory,
          ),
        )
        .toList();
    if (move) {
      _secureClipboard.cutAll(entries);
    } else {
      _secureClipboard.copyAll(entries);
    }
    setState(() {
      _isSelectMode = false;
      _selectedFiles.clear();
    });
    ErrorHelper.showSuccess(
      context,
      move
          ? AppLocalizations.of(context)!.cutManyForMove(entries.length)
          : AppLocalizations.of(context)!.copiedManyForPaste(entries.length),
    );
  }

  void _copyKeyboardTarget({required bool move}) {
    if (_selectedFiles.isNotEmpty) {
      _copySelected(move: move);
      return;
    }
    final target = _keyboardTarget;
    if (target == null || !_items.any((item) => item.path == target.path)) {
      return;
    }
    if (move) {
      _cutItem(target);
    } else {
      _copyItem(target);
    }
  }

  void _moveKeyboardTarget(
    int delta, {
    required bool extendSelection,
    bool vertical = false,
  }) {
    if (_items.isEmpty) return;
    final movement = vertical && _viewMode == ViewMode.grid
        ? delta * _gridColumnCount
        : delta;
    final currentIndex = _keyboardTarget == null
        ? -1
        : _items.indexWhere((item) => item.path == _keyboardTarget!.path);
    final nextIndex = (currentIndex + movement).clamp(0, _items.length - 1);
    final target = _items[nextIndex];
    setState(() {
      _keyboardTarget = target;
      if (!extendSelection) {
        _keyboardSelectionAnchorPath = target.path;
        return;
      }
      final anchorPath = _keyboardSelectionAnchorPath ?? target.path;
      final anchorIndex = _items.indexWhere((item) => item.path == anchorPath);
      final start = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? anchorIndex : nextIndex);
      final end = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? nextIndex : anchorIndex);
      _selectedFiles
        ..clear()
        ..addAll(_items.sublist(start, end + 1));
      _isSelectMode = _selectedFiles.isNotEmpty;
    });
  }

  void _moveKeyboardTargetToEdge({
    required bool end,
    required bool extendSelection,
  }) {
    if (_items.isEmpty) return;
    final nextIndex = end ? _items.length - 1 : 0;
    final target = _items[nextIndex];
    setState(() {
      _keyboardTarget = target;
      if (!extendSelection) {
        _keyboardSelectionAnchorPath = target.path;
        return;
      }
      final anchorPath = _keyboardSelectionAnchorPath ?? target.path;
      final anchorIndex = _items.indexWhere((item) => item.path == anchorPath);
      final start = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? anchorIndex : nextIndex);
      final finish = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? nextIndex : anchorIndex);
      _selectedFiles
        ..clear()
        ..addAll(_items.sublist(start, finish + 1));
      _isSelectMode = _selectedFiles.isNotEmpty;
    });
  }

  void _toggleKeyboardTargetSelection() {
    final target = _keyboardTarget;
    if (target == null) return;
    setState(() {
      _isSelectMode = true;
      if (_selectedFiles.contains(target)) {
        _selectedFiles.remove(target);
      } else {
        _selectedFiles.add(target);
      }
    });
  }

  void _selectAllItems() {
    if (_items.isEmpty) return;
    setState(() {
      _selectedFiles.addAll(_items);
      _isSelectMode = true;
    });
  }

  void _cancelSelection() {
    if (!_isSelectMode && _selectedFiles.isEmpty) return;
    setState(() {
      _isSelectMode = false;
      _selectedFiles.clear();
      _keyboardSelectionAnchorPath = null;
    });
  }

  Future<void> _createEntry({required bool isDirectory}) async {
    if (!_validateSession()) return;
    final name = await showCreateEntryDialog(
      context: context,
      isDirectory: isDirectory,
    );
    if (name == null || !mounted) return;
    if (_items.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.operationFailed,
        originalError: 'entry-already-exists:$name',
        operation: 'create-entry',
      );
      return;
    }

    final path = _joinLogicalPath(_currentPath!, name);
    try {
      if (isDirectory) {
        await _cryptoService.createDirectoryBySession(
          path,
          _currentDir!.tempKeyID!,
        );
      } else {
        await _cryptoService.createEmptyFileBySession(
          path,
          _currentDir!.tempKeyID!,
        );
      }
      await _loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          isDirectory
              ? AppLocalizations.of(context)!.directoryCreated(name)
              : AppLocalizations.of(context)!.fileCreated(name),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  Future<void> _pasteClipboard({String? targetDirectory}) async {
    if (!_validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    final entries = List<SecureClipboardEntry>.from(_secureClipboard.entries);
    if (entries.isEmpty) {
      ErrorHelper.showInfo(
        context,
        strings.noEncryptedClipboardEntries,
      );
      return;
    }

    final destinationDirectory = targetDirectory ?? _currentPath!;
    final destinationSessionID = _currentDir!.tempKeyID!;
    var successCount = 0;
    var cancelled = false;
    var processedCount = 0;
    final failures = <BatchOperationFailure>[];
    final conflictSession = EntryConflictSession();
    String? lastDestinationName;
    try {
      final destinationItems = List<FileSystemNode>.from(
        destinationDirectory == _currentPath
            ? _items
            : await _fileService.listCurrentDirectory(destinationDirectory),
      );
      if (!mounted) return;
      for (final entry in entries) {
        if (entry.isDirectory &&
            entry.sourceSessionID == destinationSessionID &&
            _isSameOrDescendantPath(destinationDirectory, entry.sourcePath)) {
          processedCount++;
          failures.add(BatchOperationFailure(
            name: entry.name,
            reason: strings.cannotPasteDirectoryIntoItself,
          ));
          continue;
        }
        var destinationName = entry.name;
        var overwrite = false;
        FileSystemNode? matching;
        for (final item in destinationItems) {
          if (item.name.toLowerCase() == destinationName.toLowerCase()) {
            matching = item;
            break;
          }
        }
        if (matching != null) {
          final destinationPath =
              _joinLogicalPath(destinationDirectory, destinationName);
          var sameEntry = false;
          if (entry.sourceSessionID == _currentDir!.tempKeyID) {
            final rootID = int.parse(entry.sourceSessionID);
            sameEntry = _cryptoService.relativePathForRoot(
                  rootID,
                  entry.sourcePath,
                ) ==
                _cryptoService.relativePathForRoot(rootID, destinationPath);
          }
          if (!mounted) return;
          final allowReplace =
              !sameEntry && matching.isDirectory == entry.isDirectory;
          var resolution = conflictSession.automaticResolution(
            allowReplace: allowReplace,
          );
          resolution ??= await showEntryConflictDialog(
            context: context,
            name: destinationName,
            isDirectory: entry.isDirectory,
            operation: entries.length == 1
                ? AppLocalizations.of(context)!.pasteOperation
                : AppLocalizations.of(context)!.batchPasteOperation,
            allowReplace: allowReplace,
            allowApplyToAll: entries.length > 1,
          );
          resolution = conflictSession.apply(resolution);
          if (resolution == EntryConflictResolution.cancel || !mounted) {
            cancelled = true;
            break;
          }
          if (resolution == EntryConflictResolution.keepBoth) {
            destinationName = nextAvailableEntryName(
              originalName: entry.name,
              isDirectory: entry.isDirectory,
              existingNames: destinationItems.map((item) => item.name),
              copyLabel: AppLocalizations.of(context)!.copySuffix,
            );
          } else {
            overwrite = true;
          }
        }

        try {
          if (mounted) setState(() => _isLoading = true);
          final destinationPath =
              _joinLogicalPath(destinationDirectory, destinationName);
          if (entry.isMove) {
            await _secureEntryMover.move(
              entry: entry,
              destinationPath: destinationPath,
              destinationSessionID: destinationSessionID,
              overwrite: overwrite,
            );
          } else {
            await _cryptoService.copyBySession(
              sourcePath: entry.sourcePath,
              sourceSessionID: entry.sourceSessionID,
              destinationPath: destinationPath,
              destinationSessionID: destinationSessionID,
              overwrite: overwrite,
            );
          }
          _secureClipboard.remove(entry);
          if (matching != null && overwrite) destinationItems.remove(matching);
          destinationItems.add(FileSystemNode(
            name: destinationName,
            path: destinationPath,
            isDirectory: entry.isDirectory,
          ));
          successCount++;
          processedCount++;
          lastDestinationName = destinationName;
        } catch (error) {
          processedCount++;
          failures.add(BatchOperationFailure(
            name: entry.name,
            reason: _clipboardMoveFailureReason(strings, error),
          ));
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
      if (destinationDirectory == _currentPath) await _loadCurrentPath();
      if (!mounted) return;
      setState(() {});
      if (entries.length > 1) {
        await showBatchOperationResultDialog(
          context: context,
          operation:
              entries.first.isMove ? strings.batchMove : strings.batchPaste,
          result: BatchOperationResult(
            total: entries.length,
            succeeded: successCount,
            skipped: 0,
            failures: failures,
            unprocessed: entries.length - processedCount,
            remaining: _secureClipboard.entryCount,
            cancelled: cancelled,
          ),
        );
      } else if (successCount == 1) {
        ErrorHelper.showSuccess(
          context,
          entries.first.isMove
              ? strings.movedToDestination(lastDestinationName!)
              : strings.pastedToDestination(lastDestinationName!),
        );
      } else if (cancelled) {
        ErrorHelper.showInfo(
          context,
          strings.batchPasteCancelled(
            successCount,
            _secureClipboard.entryCount,
          ),
        );
      } else if (failures.isNotEmpty) {
        if (entries.first.isMove) {
          await showBatchOperationResultDialog(
            context: context,
            operation:
                entries.first.isMove ? strings.batchMove : strings.batchPaste,
            result: BatchOperationResult(
              total: 1,
              succeeded: 0,
              skipped: 0,
              failures: failures,
              unprocessed: 0,
              remaining: _secureClipboard.entryCount,
              cancelled: false,
            ),
          );
        } else {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: 'batch-paste-failed',
            operation: 'batch-paste',
          );
        }
      } else {
        ErrorHelper.showSuccess(
          context,
          entries.first.isMove
              ? strings.movedFiles(successCount)
              : strings.pastedFiles(successCount),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _clipboardMoveFailureReason(AppLocalizations strings, Object error) {
    return switch (error) {
      SecureEntryMovePartialFailure() => strings.moveSourceDeleteFailed,
      _ => ErrorDiagnostics.sanitize(
          error.toString(),
          labels: strings.errorDiagnosticsLabels(),
        ),
    };
  }

  bool _isSameOrDescendantPath(String candidate, String parent) {
    String normalize(String value) {
      final normalized = value.replaceAll('\\', '/');
      return normalized.endsWith('/') && normalized.length > 1
          ? normalized.substring(0, normalized.length - 1)
          : normalized;
    }

    final normalizedCandidate = normalize(candidate);
    final normalizedParent = normalize(parent);
    return normalizedCandidate == normalizedParent ||
        normalizedCandidate.startsWith('$normalizedParent/');
  }

  String _joinLogicalPath(String directory, String name) {
    return directory.endsWith('/') ? '$directory$name' : '$directory/$name';
  }

  Future<void> _renameItem(FileSystemNode item) async {
    if (!_validateSession()) return;
    final newName =
        await showRenameFileItemDialog(context: context, item: item);
    if (newName == null || newName == item.name || !mounted) return;

    final parentPath = File(item.path).parent.path;
    final newPath = parentPath == '/' ? '/$newName' : '$parentPath/$newName';
    try {
      await _cryptoService.renameBySession(
        item.path,
        newPath,
        _currentDir!.tempKeyID!,
      );
      await _loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.renamedTo(newName),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────

  Future<void> _deleteFile(FileSystemNode item) async {
    if (item.isDirectory) return;
    final requireConfirmation = await _settingsService.getConfirmBeforeDelete();
    if (!mounted) return;
    final confirm = requireConfirmation
        ? await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                AppLocalizations.of(dialogContext)!.confirmDeleteFile,
              ),
              content: Text(
                AppLocalizations.of(dialogContext)!
                    .confirmDeleteFileDescription(item.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(AppLocalizations.of(dialogContext)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(AppLocalizations.of(dialogContext)!.delete),
                ),
              ],
            ),
          )
        : true;

    if (confirm == true) {
      try {
        await _cryptoService.deleteFileBySession(
          item.path,
          _currentDir!.tempKeyID!,
        );
        _loadCurrentPath();
        if (mounted) {
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.fileDeleted,
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.deleteFileFailed,
            originalError: e.toString(),
          );
        }
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Validate that a verified directory with active session is open.
  bool _validateSession() {
    if (!mounted) return false;
    if (_currentDir == null || !_currentDir!.isVerified) {
      ErrorHelper.showError(context, errorType: ErrorType.directoryNotVerified);
      return false;
    }
    if (_currentDir!.tempKeyID == null) {
      ErrorHelper.showError(context, errorType: ErrorType.sessionExpired);
      return false;
    }
    if (_currentPath == null) {
      ErrorHelper.showError(context, errorType: ErrorType.noDirectorySelected);
      return false;
    }
    return true;
  }

  bool _closeSession(String? sessionID) {
    if (sessionID == null) return true;
    final rootID = int.tryParse(sessionID);
    if (rootID == null) return false;
    try {
      _cryptoService.closeRoot(rootID);
      _webDavSessionCounts.remove(rootID);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          settingsService: _settingsService,
          onThemeModeChanged: widget.onThemeModeChanged,
          onLocaleChanged: widget.onLocaleChanged,
          onWebDavEnabledChanged: _setWebDavEnabled,
        ),
      ),
    );
    if (!mounted) return;
    await _loadAutoLockPreference();
    await _loadSessionTTL();
    await _loadOpenMode();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          _refreshCurrentDirectory();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _refreshCurrentDirectory,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            _refreshCurrentDirectory,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _touchCurrentRoot();
          _fileBrowserKey.currentState?.focusFilter();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          _touchCurrentRoot();
          _fileBrowserKey.currentState?.focusFilter();
        },
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
          if (_secureClipboard.hasEntry) {
            _touchCurrentRoot();
            unawaited(_pasteClipboard());
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
          if (_secureClipboard.hasEntry) {
            _touchCurrentRoot();
            unawaited(_pasteClipboard());
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
          _touchCurrentRoot();
          _copyKeyboardTarget(move: false);
        },
        const SingleActivator(LogicalKeyboardKey.keyX, control: true): () {
          _touchCurrentRoot();
          _copyKeyboardTarget(move: true);
        },
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): () {
          _touchCurrentRoot();
          _copyKeyboardTarget(move: false);
        },
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): () {
          _touchCurrentRoot();
          _copyKeyboardTarget(move: true);
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAllItems,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            _selectAllItems,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelSelection,
        const SingleActivator(LogicalKeyboardKey.f2): () {
          final target = _selectedFiles.length == 1
              ? _selectedFiles.single
              : _keyboardTarget;
          if (target != null &&
              _items.any((item) => item.path == target.path)) {
            _touchCurrentRoot();
            unawaited(_renameItem(target));
          }
        },
        const SingleActivator(LogicalKeyboardKey.contextMenu):
            _showKeyboardContextMenu,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true):
            _showKeyboardContextMenu,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveKeyboardTarget(-1, extendSelection: false, vertical: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveKeyboardTarget(1, extendSelection: false, vertical: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveKeyboardTarget(-1, extendSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveKeyboardTarget(1, extendSelection: false),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            _moveKeyboardTarget(-1, extendSelection: true, vertical: true),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            _moveKeyboardTarget(1, extendSelection: true, vertical: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            _moveKeyboardTarget(-1, extendSelection: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            _moveKeyboardTarget(1, extendSelection: true),
        const SingleActivator(LogicalKeyboardKey.home): () =>
            _moveKeyboardTargetToEdge(end: false, extendSelection: false),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _moveKeyboardTargetToEdge(end: true, extendSelection: false),
        const SingleActivator(LogicalKeyboardKey.home, shift: true): () =>
            _moveKeyboardTargetToEdge(end: false, extendSelection: true),
        const SingleActivator(LogicalKeyboardKey.end, shift: true): () =>
            _moveKeyboardTargetToEdge(end: true, extendSelection: true),
        const SingleActivator(LogicalKeyboardKey.space, control: true):
            _toggleKeyboardTargetSelection,
      },
      child: Listener(
        onPointerDown: (_) => _touchCurrentRoot(),
        child: Focus(
          focusNode: _shortcutFocusNode,
          autofocus: true,
          child: HomeShell(
            scaffoldKey: _scaffoldKey,
            openedDirectories: _openedDirs,
            currentDirectory: _currentDir,
            currentPath: _currentPath,
            focusedPath: _keyboardTarget?.path,
            items: _items,
            drawerPinned: _drawerPinned,
            viewMode: _viewMode,
            openOnDoubleClick: _openOnDoubleClick,
            selectMode: _isSelectMode,
            selectedFiles: _selectedFiles,
            fileService: _fileService,
            loading: _isLoading,
            canPaste: _secureClipboard.hasEntry,
            clipboardEntry: _secureClipboard.entry,
            clipboardEntryCount: _secureClipboard.entryCount,
            hasMore: _pageSession != null &&
                !_pageSession!.done &&
                !_pageSession!.hasError,
            isLoadingMore: _isLoadingMore,
            loadMoreError: _pageSession?.error,
            onLoadMore: _loadMoreCurrentPath,
            onRetryLoadMore: _loadCurrentPath,
            onOpenDirectory: _openOrCreateEncryptedDirectory,
            onCloseDirectory: _closeDirectory,
            onSwitchDirectory: _switchToDirectory,
            onRenameDirectory: _renameDirectoryAlias,
            onShowRootProperties: (directory) =>
                unawaited(_showRootDirectoryPropertiesAfterMenu(directory)),
            onChangeRootPassword: (directory) {
              unawaited(_changeRootPassword(directory));
            },
            onMoveDirectoryUp: (directory) => _moveDirectory(directory, -1),
            onMoveDirectoryDown: (directory) => _moveDirectory(directory, 1),
            onToggleDrawerPin: (pinned) async {
              setState(() => _drawerPinned = pinned);
              await _persistenceService.saveDrawerPinned(pinned);
            },
            onUnlock: _verifyPassword,
            onImportFile: _importFile,
            onImportDirectory: _importDirectory,
            webDavSessionCount: _webDavSessionCounts[
                    int.tryParse(_currentDir?.tempKeyID ?? '')] ??
                0,
            onShowWebDavSessions:
                _webDavEnabled ? () => unawaited(_showWebDavSessions()) : null,
            onExternalDrop: (candidates) {
              unawaited(_importDroppedCandidates(candidates));
            },
            fileBrowserKey: _fileBrowserKey,
            onPaste: () => _pasteClipboard(),
            onClearClipboard: () {
              _secureClipboard.clear();
              setState(() {});
            },
            onOpenSettings: _openSettings,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            onCancelSelection: () {
              _cancelSelection();
            },
            onSelectAll: () {
              _selectAllItems();
            },
            onBatchCopy: () => _copySelected(move: false),
            onBatchCut: () => _copySelected(move: true),
            onBatchExport: _batchExport,
            onBatchDelete: _batchDelete,
            onNavigateToDirectory: _navigateToDirectory,
            onNavigateUp: _navigateUp,
            onOpenItem: _openItem,
            onItemFocused: (item) {
              setState(() {
                _keyboardTarget = item;
                _keyboardSelectionAnchorPath = item.path;
              });
            },
            onGridColumnCountChanged: (count) {
              if (count != _gridColumnCount) {
                setState(() => _gridColumnCount = count);
              }
            },
            onShowItemOptions: _showFileOptions,
            onShowItemContextMenu: _showFileContextMenu,
            onShowBackgroundContextMenu: _showBackgroundContextMenu,
            onCloseCurrentRoot: () {
              final directory = _currentDir;
              if (directory != null) _closeDirectory(directory);
            },
            onToggleSelectMode: (selectMode) {
              setState(() => _isSelectMode = selectMode);
            },
            onSelectionToggle: (item, selected) {
              setState(() {
                if (selected) {
                  _selectedFiles.add(item);
                } else {
                  _selectedFiles.remove(item);
                }
              });
            },
            onSelectionChanged: (selected) {
              setState(() {
                _selectedFiles
                  ..clear()
                  ..addAll(selected);
                _isSelectMode = selected.isNotEmpty;
              });
            },
          ),
        ),
      ),
    );
  }
}
