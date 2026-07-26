import 'home_page_auto_lock_mixin.dart';
import 'home_page_file_opening_mixin.dart';
import 'home_page_clipboard_mixin.dart';
import 'home_page_sidebar_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page_import_export_mixin.dart';
import 'home_page_webdav_mixin.dart';
import 'home_page_create_root_workflow.dart';
import 'home_page_shortcuts.dart';
import 'home_page_startup_coordinator.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/error_localizations.dart';
import '../models/cryption_config.dart';
import '../models/batch_operation_result.dart';
import '../models/secure_image_policy.dart';
import '../models/view_mode.dart';
import '../models/text_file_policy.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../services/directory_page_session.dart';
import '../services/directory_service.dart';
import '../services/directory_persistence_service.dart';
import '../services/settings_service.dart';
import '../services/secure_clipboard_service.dart';
import '../native/native_lib.dart';
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
import '../widgets/entry_conflict_dialog.dart';
import '../widgets/directory_background_actions.dart';
import '../widgets/root_directory_action_dialog.dart';
import '../widgets/root_directory_properties.dart';
import '../widgets/root_password_change_dialog.dart';
import '../widgets/root_password_hint_dialog.dart';
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

class _HomePageState extends State<HomePage>
    with
        WidgetsBindingObserver,
        HomePageSidebarMixin,
        HomePageImportExportMixin,
        HomePageWebDavMixin,
        HomePageAutoLockMixin,
        HomePageFileOpeningMixin,
        HomePageClipboardMixin {
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
  late final HomePageStartupCoordinator _startupCoordinator;
  late final HomePageCreateRootWorkflow _createRootWorkflow;
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
  GlobalKey<FileBrowserState> get fileBrowserKey => _fileBrowserKey;

  // -- HomePageSidebarMixin abstract getters --
  @override
  List<EncryptedDirectory> get openedDirs => _openedDirs;
  @override
  EncryptedDirectory? get currentDir => _currentDir;
  @override
  set currentDir(EncryptedDirectory? value) => _currentDir = value;
  @override
  bool get drawerPinned => _drawerPinned;
  @override
  set drawerPinned(bool value) => _drawerPinned = value;
  @override
  DirectoryPersistenceService get persistenceService => _persistenceService;
  @override
  CryptoService get cryptoService => _cryptoService;
  @override
  DocumentSessionBroker get documentBroker => _documentBroker;

  // -- HomePageImportExportMixin abstract getters --
  @override
  DirectoryService get directoryService => _directoryService;
  @override
  FileService get fileService => _fileService;
  @override
  DragDropController get dragDropController => _dragDropController;

  // -- HomePageWebDavMixin abstract getters --
  @override
  Map<int, int> get webDavSessionCounts => _webDavSessionCounts;
  @override
  Map<String, String> get webDavMountOperations => _webDavMountOperations;
  @override
  int get webDavOperationSequence => _webDavOperationSequence;
  @override
  set webDavOperationSequence(int value) => _webDavOperationSequence = value;
  @override
  bool get webDavEnabled => _webDavEnabled;
  @override
  set webDavEnabled(bool value) => _webDavEnabled = value;
  @override
  WebDavService get webDavService => _webDavService;
  @override
  SettingsService get settingsService => _settingsService;
  @override
  Future<String?> Function()? get selectDirectoryFn => widget.selectDirectory;
  @override
  Future<XFile?> Function(List<XTypeGroup>)? get selectFileFn =>
      widget.selectFile;
  @override
  Future<FileSaveLocation?> Function(String)? get selectSaveLocationFn =>
      widget.selectSaveLocation;
  @override
  Future<bool> Function(String)? get exportTargetExistsFn =>
      widget.exportTargetExists;

  // -- HomePageAutoLockMixin abstract getters --
  @override
  String? get currentPath => _currentPath;
  @override
  set currentPath(String? value) => _currentPath = value;
  @override
  RootCloseCoordinator get rootCloseCoordinator => _rootCloseCoordinator;
  @override
  ContentWindowHostBridge get contentWindowBridge => _contentWindowBridge;
  @override
  SecureClipboardService get secureClipboard => _secureClipboard;
  @override
  SecureEntryMoveService get secureEntryMover => _secureEntryMover;
  @override
  RootIdleTracker get idleTracker => _idleTracker;
  @override
  DirectoryPageSession? get pageSession => _pageSession;
  @override
  set pageSession(DirectoryPageSession? value) => _pageSession = value;
  @override
  int get pageGeneration => _pageGeneration;
  @override
  set pageGeneration(int value) => _pageGeneration = value;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  set isLoadingMore(bool value) => _isLoadingMore = value;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) => _isLoading = value;
  @override
  List<FileSystemNode> get items => _items;
  @override
  set items(List<FileSystemNode> value) => _items = value;
  @override
  Set<FileSystemNode> get selectedFiles => _selectedFiles;
  @override
  FileSystemNode? get keyboardTarget => _keyboardTarget;
  @override
  set keyboardTarget(FileSystemNode? value) => _keyboardTarget = value;
  @override
  String? get keyboardSelectionAnchorPath => _keyboardSelectionAnchorPath;
  @override
  set keyboardSelectionAnchorPath(String? value) =>
      _keyboardSelectionAnchorPath = value;
  @override
  bool get isSelectMode => _isSelectMode;
  @override
  set isSelectMode(bool value) => _isSelectMode = value;
  @override
  Duration? get idleCheckInterval => widget.idleCheckInterval;
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
    _contentWindowBridge.onActivity = (token) {
      final sessionID = _documentBroker.rootSessionForToken(token);
      if (sessionID != null) _idleTracker.touch(sessionID);
    };
    _webDavService =
        widget.webDavService ?? WebDavService(cryptoService: _cryptoService);
    _startupCoordinator = HomePageStartupCoordinator(
      settingsService: _settingsService,
      persistenceService: _persistenceService,
    );
    _createRootWorkflow = HomePageCreateRootWorkflow(
      cryptoService: _cryptoService,
      settingsService: _settingsService,
    );
    WidgetsBinding.instance.addObserver(this);
    loadPersistedDirectories();
    loadDrawerPinnedState();
    loadAutoLockPreference();
    loadSessionTTL();
    _loadOpenMode();
    loadWebDavEnabled();
    _startupCoordinator.checkFirstTimeUser(
      context,
      isMounted: () => mounted,
    );
    _startupCoordinator.checkFirstLaunchAntiScreenshot(
      context,
      isMounted: () => mounted,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cancelIdleTimer();
    _idleTracker.clear();
    unawaited(_pageSession?.dispose() ?? Future.value());
    _shortcutFocusNode.dispose();
    _contentWindowBridge.dispose();
    saveOpenedDirectories();
    final sessionIDs = _openedDirs
        .map((directory) => directory.tempKeyID)
        .whereType<String>()
        .toSet();
    for (final sessionID in sessionIDs) {
      closeSession(sessionID);
    }
    super.dispose();
  }

  Future<void> _loadOpenMode() async {
    final openOnDoubleClick = await _settingsService.getOpenOnDoubleClick();
    if (mounted) setState(() => _openOnDoubleClick = openOnDoubleClick);
  }

  void _refreshCurrentDirectory() {
    touchCurrentRoot();
    unawaited(loadCurrentPath());
  }

  /// Pops the current in-process notepad route if one exists.
  /// Used by auto-lock before closing a root session.

  /// Used by auto-lock before closing a root session.

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
    final result = await _createRootWorkflow.run(
      context,
      selectedPath,
      isMounted: () => mounted,
      revokeWebDavSessions: (rootID) => _webDavEnabled
          ? Future.value()
          : revokeWebDavSessionsForRoot(rootID),
      onLoadingChanged: (loading) {
        if (mounted) setState(() => _isLoading = loading);
      },
    );
    if (result == null || !mounted) return;

    setState(() {
      _currentDir = result.directory;
      _currentPath = selectedPath;
      final existingIndex =
          _openedDirs.indexWhere((d) => d.path == selectedPath);
      if (existingIndex >= 0) _openedDirs.removeAt(existingIndex);
      _openedDirs.insert(0, _currentDir!);
    });
    await saveOpenedDirectories();
    await loadCurrentPath();
    if (!mounted) return;
    ErrorHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.encryptedDirectoryCreated,
    );
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

      await saveOpenedDirectories();

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

  @override
  Future<bool> loadCurrentPath() async {
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
        final errorType = (e is NativeOperationException &&
                e.code == NativeErrorCode.corruptedEntry)
            ? ErrorType.dataCorrupted
            : ErrorType.loadDirectoryFailed;
        ErrorHelper.showError(
          context,
          errorType: errorType,
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

    // Guard: wait for any in-flight auto-lock to complete before allowing
    // unlock, otherwise the auto-lock may close the session we are about
    // to open, or the state update races with the PasswordPrompt rebuild.
    const maxGuardMs = 30000;
    final guardStart = DateTime.now();
    if (isAutoLocking) {}
    while (isAutoLocking && mounted) {
      if (DateTime.now().difference(guardStart).inMilliseconds > maxGuardMs) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

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

    if (!_webDavEnabled) await revokeWebDavSessionsForRoot(rootID);
    final transferStateAvailable = await _handleUnfinishedOperations(rootID);
    // The unfinished-state prompt is asynchronous and the sidebar stays
    // usable. Never attach this root to a directory selected after unlock
    // started; close the unowned native session instead.
    if (!transferStateAvailable ||
        !mounted ||
        !identical(_currentDir, openingDirectory)) {
      closeSession(rootID.toString());
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

    final loaded = await loadCurrentPath();
    if (!mounted ||
        _currentDir?.path != openingPath ||
        _currentDir?.tempKeyID != rootID.toString()) {
      // Directory loading can yield to a session switch or a second unlock.
      // Do not leave the root opened by this stale unlock attempt behind.
      closeSession(rootID.toString());
      return false;
    }

    if (loaded) {
      _idleTracker.touch(rootID.toString());
      unawaited(refreshWebDavSessionCount(rootID));
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
      loadCurrentPath();
      final rootID = int.tryParse(dir.tempKeyID ?? '');
      if (rootID != null) unawaited(refreshWebDavSessionCount(rootID));
    }
  }

  Future<void> _closeDirectory(EncryptedDirectory dir) async {
    final strings = AppLocalizations.of(context)!;
    final action = await showRootDirectoryActionDialog(
      context: context,
      directoryName: baseName(dir.path),
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
      await runRootCloseOperation(
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
    if (sessionID != null && !isCurrentDirectorySession(dir.path, sessionID)) {
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
      if (!isCurrentDirectorySession(dir.path, sessionID)) return;
    }

    if (sessionID != null) {
      await disposeCurrentDirectoryPageSession(dir.path, sessionID);
      if (!isCurrentDirectorySession(dir.path, sessionID)) return;
    }
    if (!closeSession(sessionID)) {
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
          replaceWithLockedDirectory(
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
      replaceWithLockedDirectory(
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
    await saveOpenedDirectories();
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
    return runRootCloseOperation(
      sessionID,
      () => _lockRootForPasswordChangeAfterGate(directory, sessionID),
    );
  }

  Future<bool> _lockRootForPasswordChangeAfterGate(
    EncryptedDirectory directory,
    String sessionID,
  ) async {
    if (!isCurrentDirectorySession(directory.path, sessionID)) return false;
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
      if (!isCurrentDirectorySession(directory.path, sessionID)) return false;
    }
    await disposeCurrentDirectoryPageSession(directory.path, sessionID);
    if (!isCurrentDirectorySession(directory.path, sessionID)) return false;
    if (!closeSession(sessionID)) {
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
      replaceWithLockedDirectory(
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
      directoryName: directory.displayAlias ?? baseName(directory.path),
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
        replaceWithLockedDirectory(
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
      directoryName: directory.displayAlias ?? baseName(directory.path),
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

  @override
  void replaceWithLockedDirectory(
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

  @override
  void navigateToDirectory(String path) => _navigateToDirectory(path);

  void _navigateToDirectory(String path) {
    touchCurrentRoot();
    setState(() => _currentPath = path);
    loadCurrentPath();
  }

  void _navigateUp() {
    if (_currentPath == null || _currentDir == null) return;
    final parent = _fileService.getParentDirectory(_currentPath!);
    if (parent == null) return;
    _navigateToDirectory(parent);
  }

  // ── File operations ───────────────────────────────────────────────

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
        await createEntry(isDirectory: false);
        return;
      case DirectoryBackgroundAction.newDirectory:
        await createEntry(isDirectory: true);
        return;
      case DirectoryBackgroundAction.paste:
        await pasteClipboard();
        return;
      case DirectoryBackgroundAction.refresh:
        await loadCurrentPath();
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
        openItem(item);
        return;
      case FileItemAction.edit:
        await openNotepad(item);
        return;
      case FileItemAction.openInNewWindow:
        if (isViewableImageFile(item)) {
          await openImageViewerInNewWindow(item);
        } else {
          await openNotepadInNewWindow(item);
        }
        return;
      case FileItemAction.select:
        setState(() {
          _isSelectMode = true;
          _selectedFiles.add(item);
        });
        return;
      case FileItemAction.rename:
        await renameItem(item);
        return;
      case FileItemAction.copy:
        copyItem(item);
        return;
      case FileItemAction.cut:
        cutItem(item);
        return;
      case FileItemAction.pasteInto:
        await pasteClipboard(targetDirectory: item.path);
        return;
      case FileItemAction.export:
        if (item.isDirectory) {
          await exportDirectory(item);
        } else {
          await exportFile(item);
        }
        return;
      case FileItemAction.exposeToThirdParty:
        await exposeToThirdParty(item);
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
        await loadCurrentPath();
        return;
      case FileItemAction.delete:
        await deleteFile(item);
        return;
    }
  }


  /// Validate that a verified directory with active session is open.
  @override
  bool validateSession() {
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

  @override
  bool closeSession(String? sessionID) {
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
          onWebDavEnabledChanged: setWebDavEnabled,
        ),
      ),
    );
    if (!mounted) return;
    await loadAutoLockPreference();
    await loadSessionTTL();
    await _loadOpenMode();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shortcutActions = HomePageShortcutActions(
      refresh: _refreshCurrentDirectory,
      focusFilter: () {
        touchCurrentRoot();
        _fileBrowserKey.currentState?.focusFilter();
      },
      paste: () {
        if (_secureClipboard.hasEntry) {
          touchCurrentRoot();
          unawaited(pasteClipboard());
        }
      },
      copy: () {
        touchCurrentRoot();
        copyKeyboardTarget(move: false);
      },
      cut: () {
        touchCurrentRoot();
        copyKeyboardTarget(move: true);
      },
      selectAll: selectAllItems,
      cancelSelection: cancelSelection,
      rename: () {
        final target = _selectedFiles.length == 1
            ? _selectedFiles.single
            : _keyboardTarget;
        if (target != null &&
            _items.any((item) => item.path == target.path)) {
          touchCurrentRoot();
          unawaited(renameItem(target));
        }
      },
      showContextMenu: _showKeyboardContextMenu,
      moveUp: () =>
          moveKeyboardTarget(-1, extendSelection: false, vertical: true),
      moveDown: () =>
          moveKeyboardTarget(1, extendSelection: false, vertical: true),
      moveLeft: () => moveKeyboardTarget(-1, extendSelection: false),
      moveRight: () => moveKeyboardTarget(1, extendSelection: false),
      extendUp: () =>
          moveKeyboardTarget(-1, extendSelection: true, vertical: true),
      extendDown: () =>
          moveKeyboardTarget(1, extendSelection: true, vertical: true),
      extendLeft: () => moveKeyboardTarget(-1, extendSelection: true),
      extendRight: () => moveKeyboardTarget(1, extendSelection: true),
      goHome: () =>
          moveKeyboardTargetToEdge(end: false, extendSelection: false),
      goEnd: () => moveKeyboardTargetToEdge(end: true, extendSelection: false),
      extendHome: () =>
          moveKeyboardTargetToEdge(end: false, extendSelection: true),
      extendEnd: () =>
          moveKeyboardTargetToEdge(end: true, extendSelection: true),
      toggleSelection: toggleKeyboardTargetSelection,
    );
    return CallbackShortcuts(
      bindings: shortcutActions.bindings,
      child: Listener(
        onPointerDown: (_) => touchCurrentRoot(),
        child: Focus(
          focusNode: _shortcutFocusNode,
          autofocus: false, // TEMP: test focus conflict
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
            onRetryLoadMore: loadCurrentPath,
            onOpenDirectory: _openOrCreateEncryptedDirectory,
            onCloseDirectory: _closeDirectory,
            onSwitchDirectory: _switchToDirectory,
            onRenameDirectory: renameDirectoryAlias,
            onShowRootProperties: (directory) =>
                unawaited(_showRootDirectoryPropertiesAfterMenu(directory)),
            onChangeRootPassword: (directory) {
              unawaited(_changeRootPassword(directory));
            },
            onMoveDirectoryUp: (directory) => moveDirectory(directory, -1),
            onMoveDirectoryDown: (directory) => moveDirectory(directory, 1),
            onToggleDrawerPin: (pinned) async {
              setState(() => _drawerPinned = pinned);
              await _persistenceService.saveDrawerPinned(pinned);
            },
            onUnlock: _verifyPassword,
            onImportFile: importFile,
            onImportDirectory: importDirectory,
            webDavSessionCount: _webDavSessionCounts[
                    int.tryParse(_currentDir?.tempKeyID ?? '')] ??
                0,
            onShowWebDavSessions:
                _webDavEnabled ? () => unawaited(showWebDavSessions()) : null,
            onExternalDrop: (candidates) {
              unawaited(importDroppedCandidates(candidates));
            },
            fileBrowserKey: _fileBrowserKey,
            onPaste: () => pasteClipboard(),
            onClearClipboard: () {
              _secureClipboard.clear();
              setState(() {});
            },
            onOpenSettings: _openSettings,
            onViewModeChanged: (mode) => setState(() => _viewMode = mode),
            onCancelSelection: () {
              cancelSelection();
            },
            onSelectAll: () {
              selectAllItems();
            },
            onBatchCopy: () => copySelected(move: false),
            onBatchCut: () => copySelected(move: true),
            onBatchExport: batchExport,
            onBatchDelete: batchDelete,
            onNavigateToDirectory: _navigateToDirectory,
            onNavigateUp: _navigateUp,
            onOpenItem: openItem,
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
