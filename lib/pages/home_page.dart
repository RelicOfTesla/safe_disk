import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
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
import '../services/content_window_host_bridge.dart';
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
import '../widgets/file_item_actions.dart';
import '../widgets/entry_conflict_dialog.dart';
import '../widgets/directory_background_actions.dart';
import '../widgets/root_directory_action_dialog.dart';
import '../widgets/root_directory_properties.dart';
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
    this.selectDirectory,
    this.selectFile,
    this.selectSaveLocation,
    this.contentWindowPlatform,
    this.exportTargetExists,
    this.deleteRootDirectory,
  });

  final CryptoService? cryptoService;
  final DirectoryService? directoryService;
  final FileService? fileService;
  final DirectoryPersistenceService? persistenceService;
  final SettingsService? settingsService;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final Future<String?> Function()? selectDirectory;
  final Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups)?
      selectFile;
  final Future<FileSaveLocation?> Function(String suggestedName)?
      selectSaveLocation;
  final ContentWindowPlatform? contentWindowPlatform;
  final Future<bool> Function(String path)? exportTargetExists;
  final Future<void> Function(String path)? deleteRootDirectory;

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
  late final ContentWindowHostBridge _contentWindowBridge;

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
  String? _pendingAutoLockSummary;
  bool _drawerPinned = false;
  ViewMode _viewMode = ViewMode.list;

  // File selection for batch operations
  bool _isSelectMode = false;
  final Set<FileSystemNode> _selectedFiles = {};
  FileSystemNode? _keyboardTarget;
  final FocusNode _shortcutFocusNode = FocusNode(debugLabel: 'home-shortcuts');

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
    _contentWindowBridge = ContentWindowHostBridge(
      broker: _documentBroker,
      platform: widget.contentWindowPlatform,
    );
    WidgetsBinding.instance.addObserver(this);
    _loadPersistedDirectories();
    _loadDrawerPinnedState();
    _loadAutoLockPreference();
    _checkFirstTimeUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_lockEligibleRootsForBackground());
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ErrorHelper.showInfo(context, summary);
    });
  }

  Future<void> _lockEligibleRootsForBackground() async {
    if (!_autoLockOnBackground || _isAutoLocking) return;
    _isAutoLocking = true;
    var lockedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    try {
      for (final directory in List<EncryptedDirectory>.from(_openedDirs)) {
        final sessionID = directory.tempKeyID;
        if (sessionID == null) continue;
        final decision = _rootCloseCoordinator.inspect(sessionID);
        if (decision.disposition != RootCloseDisposition.closeImmediately) {
          skippedCount++;
          continue;
        }
        try {
          if (!_isCurrentDirectorySession(directory.path, sessionID)) continue;
          await _disposeCurrentDirectoryPageSession(directory.path, sessionID);
          if (!_isCurrentDirectorySession(directory.path, sessionID)) continue;
          if (!_closeSession(sessionID)) {
            failedCount++;
            continue;
          }
          _secureClipboard.removeSession(sessionID);
          _rootCloseCoordinator.releaseRoot(sessionID);
          if (mounted) {
            _replaceWithLockedDirectory(
              directory,
              EncryptedDirectory(
                path: directory.path,
                config: directory.config,
                isVerified: false,
                displayAlias: directory.displayAlias,
              ),
            );
          }
          lockedCount++;
        } catch (_) {
          failedCount++;
        }
      }
    } finally {
      _isAutoLocking = false;
    }
    if (!mounted) return;
    final messages = <String>[];
    if (lockedCount > 0) messages.add('已自动锁定 $lockedCount 个目录');
    if (skippedCount > 0) messages.add('$skippedCount 个目录含内容窗口或未完成保存，未强制关闭');
    if (failedCount > 0) messages.add('$failedCount 个目录锁定失败');
    if (messages.isNotEmpty) _pendingAutoLockSummary = messages.join('；');
  }

  bool _isCurrentDirectorySession(String path, String sessionID) {
    final current = _currentDir;
    return (current?.path == path && current?.tempKeyID == sessionID) ||
        _openedDirs.any(
          (directory) =>
              directory.path == path && directory.tempKeyID == sessionID,
        );
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
    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置目录显示别名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: '别名',
            hintText: '留空将恢复目录名',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
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
    if (!mounted) return;
    final result = await showDialog<CreateRootRequest>(
      context: context,
      builder: (context) => const CreateEncryptedDirectoryDialog(),
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
        ErrorHelper.showSuccess(context, '加密目录创建成功');
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
        ErrorHelper.showInfo(context, '已找到加密根目录：$root');
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
    return session.entries.map((entry) {
      final relative = session.relativePath.isEmpty
          ? entry.name
          : '${session.relativePath}/${entry.name}';
      return FileSystemNode(
          name: entry.name,
          path: _cryptoService.absolutePathForRoot(session.rootID, relative),
          isDirectory: entry.isDir,
          modifiedTime:
              DateTime.fromMillisecondsSinceEpoch(entry.modTime * 1000),
          size: entry.size);
    }).toList();
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
    if (_currentDir == null) return false;

    late final int rootID;
    try {
      rootID = _cryptoService.openRoot(_currentDir!.path, password, '');
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

    final transferStateAvailable = await _handleUnfinishedOperations(rootID);
    if (!transferStateAvailable) {
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
    if (!mounted) return false;

    if (loaded) {
      ErrorHelper.showSuccess(context, '密码验证成功');
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

    final action = await showDialog<_UnfinishedAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现未完成的导入/导出'),
        content: Text(
          '检测到 ${markers.length} 个未完成的导入/导出状态。\n\n'
          'Safe Disk V3 不做断点续传。你可以清理状态后重新全量执行导入/导出，'
          '也可以暂时跳过。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.skip),
            child: const Text('暂时跳过'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.clean),
            child: const Text('清理状态'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _UnfinishedAction.rerun),
            child: const Text('全量重跑'),
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
        ErrorHelper.showSuccess(context, '已清理 $cleaned 个未完成状态');
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
    DirectoryTransferCancellationToken? currentToken;
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: '全量重跑导入/导出',
      total: 100,
      status: '正在准备...',
      onCancel: () {
        final accepted = currentToken?.cancel() ?? false;
        if (!accepted) {
          progressController.update(status: '当前操作尚未可取消...');
        }
        return accepted;
      },
    );

    try {
      for (var index = 0; index < markers.length; index++) {
        currentToken = DirectoryTransferCancellationToken();
        progressController.update(
          current: 0,
          status: '正在重跑 ${index + 1}/${markers.length}...',
        );
        await _directoryService.rerunUnfinishedOperation(
          rootID,
          markers[index],
          cancellationToken: currentToken,
          onProgress: (progress) {
            progressController.update(
              current: progress.percent,
              currentFileName: progress.currentFile,
              status: '正在重跑 ${index + 1}/${markers.length}...',
            );
          },
        );
      }
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
        ErrorHelper.showSuccess(context, '未完成导入/导出已全量重跑');
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && currentToken?.isCancelled == true) {
        ErrorHelper.showInfo(context, '重跑已取消，未完成状态已保留');
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
    }
  }

  Future<void> _closeDirectory(EncryptedDirectory dir) async {
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
    final closeDecision =
        sessionID == null ? null : _rootCloseCoordinator.inspect(sessionID);
    if (closeDecision?.disposition ==
        RootCloseDisposition.blockedByActiveWrites) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('正在保存内容'),
          content: Text(
            '当前有 ${closeDecision!.activeWriteCount} 个内容保存操作尚未完成，'
            '请等待保存结束后再关闭会话。',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
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
          title: const Text('存在未保存内容'),
          content: Text(
            '请先处理以下内容窗口，再结束会话：\n\n'
            '${closeDecision!.dirtyDocumentNames.join('\n')}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
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
            originalError: '内容窗口关闭失败：$error',
          );
        }
        return;
      }
    }

    if (sessionID != null) {
      await _disposeCurrentDirectoryPageSession(dir.path, sessionID);
    }
    if (!_closeSession(dir.tempKeyID)) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: '无法结束当前 root 会话',
        );
      }
      return;
    }
    if (sessionID != null) _secureClipboard.removeSession(sessionID);
    if (sessionID != null) _rootCloseCoordinator.releaseRoot(sessionID);

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
          _replaceWithLockedDirectory(dir, lockedDirectory);
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: '本地目录删除失败，历史记录已保留：$error',
          );
        }
        return;
      }
    }

    if (action == RootDirectoryAction.endSession) {
      _replaceWithLockedDirectory(dir, lockedDirectory);
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
            ? '本地加密目录已永久删除'
            : '目录历史已移除，本地磁盘内容保持不变',
      );
    }
  }

  void _replaceWithLockedDirectory(
    EncryptedDirectory directory,
    EncryptedDirectory lockedDirectory,
  ) {
    setState(() {
      final index =
          _openedDirs.indexWhere((item) => item.path == directory.path);
      if (index >= 0) _openedDirs[index] = lockedDirectory;
      if (_currentDir?.path == directory.path) {
        _currentDir = lockedDirectory;
        _currentPath = lockedDirectory.path;
        _items = [];
        _selectedFiles.clear();
        _keyboardTarget = null;
        _isSelectMode = false;
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────

  void _navigateToDirectory(String path) {
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
    final initiallyReadOnly =
        settings[1] as bool || shouldOpenFallbackTextReadOnly(item.name);
    final initiallyMonitorClipboard = settings[2] as bool;
    if (!mounted || _currentDir?.tempKeyID != directory!.tempKeyID) return;
    try {
      final lease = _documentBroker.open(
        rootSessionID: directory.tempKeyID!,
        path: item.path,
        displayName: item.name,
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
      lease = _documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
      );
      if (await _contentWindowBridge.openNotepad(lease)) return;
      _documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(context, '当前平台尚未启用原生内容窗口，已在主窗口打开');
      await _openNotepad(item);
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
      lease = _documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureImageEncodedBytes,
        readOnly: true,
      );
      if (await _contentWindowBridge.openImage(lease)) return;
      _documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(context, '当前平台尚未启用原生内容窗口，已在主窗口打开');
      _openImageViewer(item);
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

  Future<void> _showBackgroundContextMenu(Offset globalPosition) async {
    _keyboardTarget = null;
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
      case FileItemAction.copyName:
        await Clipboard.setData(ClipboardData(text: item.name));
        if (mounted) {
          ErrorHelper.showInfo(context, '已将明文名称复制到系统剪贴板');
        }
        return;
      case FileItemAction.copyPath:
        await Clipboard.setData(ClipboardData(text: item.path));
        if (mounted) {
          ErrorHelper.showInfo(context, '已将明文逻辑路径复制到系统剪贴板');
        }
        return;
      case FileItemAction.properties:
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

  // ── Import / Export ───────────────────────────────────────────────

  Future<void> _importFile() async {
    if (!_validateSession()) return;

    const typeGroup = XTypeGroup(label: 'All Files');
    final XFile? file = widget.selectFile != null
        ? await widget.selectFile!([typeGroup])
        : await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;

    var destinationName = file.name;
    var overwrite = false;
    if (_items
        .any((item) => item.name.toLowerCase() == file.name.toLowerCase())) {
      final existing = _items.firstWhere(
        (item) => item.name.toLowerCase() == file.name.toLowerCase(),
      );
      final resolution = await showEntryConflictDialog(
        context: context,
        name: file.name,
        isDirectory: false,
        operation: '导入',
        allowReplace: !existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        destinationName = nextAvailableEntryName(
          originalName: file.name,
          isDirectory: false,
          existingNames: _items.map((item) => item.name),
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
        file.path,
        destination,
        overwrite: overwrite,
      );
      await _loadCurrentPath();

      if (mounted) {
        ErrorHelper.showSuccess(context, '文件导入成功：$destinationName');
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
    if (isPathInsideDirectory(sourcePath, _currentDir!.path)) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.importDirectoryFailed,
        originalError: 'Source directory is inside the encrypted root',
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
        operation: '导入',
        allowReplace: existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        final newName = nextAvailableEntryName(
          originalName: sourceName,
          isDirectory: true,
          existingNames: _items.map((item) => item.name),
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
      title: '导入目录',
      total: 100,
      status: '正在准备导入...',
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: '正在准备，暂时无法取消...');
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
            status: '正在导入...',
          );
        },
      );
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (!mounted) return;
      await _loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(context, '目录导入完成：$completedFiles 个文件');
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && cancellationToken.isCancelled) {
        ErrorHelper.showInfo(context, '导入已取消，可在下次打开目录时清理未完成状态');
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.importDirectoryFailed,
          originalError: e.toString(),
        );
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
      operation: '导出',
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
        ErrorHelper.showSuccess(context, '文件导出成功：${destination.path}');
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
    if (!await _confirmPlaintextExport(item)) return;

    final String? exportDir = widget.selectDirectory != null
        ? await widget.selectDirectory!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final dstDir = '$exportDir/${item.name}';
    final cancellationToken = DirectoryTransferCancellationToken();
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: '导出目录',
      total: 100,
      status: '正在准备导出...',
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: '正在准备，暂时无法取消...');
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
            status: '正在导出...',
          );
        },
      );

      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }

      if (mounted) {
        if (progress.isCancelled) {
          ErrorHelper.showInfo(context, '导出已取消，可在下次打开目录时清理未完成状态');
        } else if (progress.isComplete &&
            !progress.isFailed &&
            !progress.isCancelled) {
          ErrorHelper.showSuccess(
              context, '导出完成：${progress.processedFiles} 个文件');
        } else if (progress.isFailed) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.exportDirectoryFailed,
            originalError: progress.error ?? 'Unknown error',
          );
        }
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(context, '导出已取消，可在下次打开目录时清理未完成状态');
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

    final String? exportDir = widget.selectDirectory != null
        ? await widget.selectDirectory!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final jobs = <({FileSystemNode item, String path, bool overwrite})>[];
    for (final item in _selectedFiles) {
      final destination = await _resolveExportDestination(
        '$exportDir/${item.name}',
        operation: '批量导出',
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
      title: '批量导出',
      total: totalFiles,
      status: '正在准备导出...',
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
          status: '正在导出...',
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
            ? '导出完成：成功 $successCount 个，失败 $failCount 个'
            : '导出完成：成功 $successCount 个文件';
        ErrorHelper.showSuccess(context, message);
      } else if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(
            context, '导出已取消：成功 $successCount 个，失败 $failCount 个');
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
    );
    return (
      path: '${parent.path}${Platform.pathSeparator}$availableName',
      overwrite: false,
    );
  }

  Future<void> _batchDelete() async {
    if (!_validateSession() || _selectedFiles.isEmpty) return;
    final selected = Set<FileSystemNode>.from(_selectedFiles);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text(
          '确定删除所选 ${selected.length} 个文件吗？此操作无法撤销。'
          '删除会逐项执行，发生失败时已删除的文件不会恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除所选文件'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progressController = ProgressHelper.showProgressDialog(
      context,
      title: '批量删除',
      total: selected.length,
      status: '正在准备删除...',
    );
    final succeeded = <FileSystemNode>{};
    final failed = <FileSystemNode>{};
    var processed = 0;
    for (final item in selected) {
      if (progressController.isCancelled) break;
      progressController.update(
        current: processed + 1,
        currentFileName: item.name,
        status: '正在删除...',
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
        '批量删除已取消：成功 ${succeeded.length} 个，'
        '剩余 ${_selectedFiles.length} 个仍保持选择',
      );
    } else if (failed.isNotEmpty) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.deleteFileFailed,
        originalError: '成功 ${succeeded.length} 个，失败 ${failed.length} 个；'
            '失败项已保留选择，可重试或退出选择模式。',
      );
    } else {
      ErrorHelper.showSuccess(context, '已删除 ${succeeded.length} 个文件');
    }
  }

  String _baseName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  Future<bool> _confirmPlaintextExport(FileSystemNode item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认导出明文'),
        content: Text(
          '“${item.name}”将以未加密形式写入你选择的位置。'
          '导出后的副本不再受 Safe Disk 保护，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('继续导出'),
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
    ErrorHelper.showSuccess(context, '已复制“${item.name}”，请选择目标目录粘贴');
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
    ErrorHelper.showSuccess(context, '已剪切“${item.name}”，请选择目标目录移动');
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
          ? '已剪切 ${entries.length} 个文件，请选择目标目录移动'
          : '已复制 ${entries.length} 个文件，请选择目标目录粘贴',
    );
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
        originalError: '目标已存在：$name',
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
          isDirectory ? '目录已创建：$name' : '文件已创建：$name',
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
    final entries = List<SecureClipboardEntry>.from(_secureClipboard.entries);
    if (entries.isEmpty) {
      ErrorHelper.showInfo(context, '剪贴板中没有可粘贴的加密条目');
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
            reason: '目录不能粘贴到自身或其子目录',
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
            operation: entries.length == 1 ? '粘贴' : '批量粘贴',
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
            reason: ErrorDiagnostics.sanitize(error.toString()),
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
          operation: entries.first.isMove ? '批量移动' : '批量粘贴',
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
              ? '已移动：$lastDestinationName'
              : '已粘贴：$lastDestinationName',
        );
      } else if (cancelled) {
        ErrorHelper.showInfo(
          context,
          '批量粘贴已取消：成功 $successCount 个，'
          '剩余 ${_secureClipboard.entryCount} 个可重试',
        );
      } else if (failures.isNotEmpty) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: '成功 $successCount 个，失败 ${failures.length} 个；'
              '失败项已保留在应用内剪贴板。',
        );
      } else {
        ErrorHelper.showSuccess(
          context,
          entries.first.isMove
              ? '已移动 $successCount 个文件'
              : '已粘贴 $successCount 个文件',
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
      if (mounted) ErrorHelper.showSuccess(context, '已重命名为：$newName');
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
            builder: (context) => AlertDialog(
              title: const Text('确认删除文件'),
              content: Text('确定要删除“${item.name}”吗？此操作无法撤销。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
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
        if (mounted) ErrorHelper.showSuccess(context, '文件已删除');
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
        ),
      ),
    );
    if (mounted) await _loadAutoLockPreference();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () {
          unawaited(_loadCurrentPath());
        },
        const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
          if (_secureClipboard.hasEntry) unawaited(_pasteClipboard());
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          final target = _selectedFiles.length == 1
              ? _selectedFiles.single
              : _keyboardTarget;
          if (target != null &&
              _items.any((item) => item.path == target.path)) {
            unawaited(_renameItem(target));
          }
        },
      },
      child: Focus(
        focusNode: _shortcutFocusNode,
        autofocus: true,
        child: HomeShell(
          scaffoldKey: _scaffoldKey,
          openedDirectories: _openedDirs,
          currentDirectory: _currentDir,
          currentPath: _currentPath,
          items: _items,
          drawerPinned: _drawerPinned,
          viewMode: _viewMode,
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
          onShowRootProperties: (directory) {
            unawaited(showRootDirectoryProperties(
              context: context,
              directory: directory,
            ));
          },
          onChangeRootPassword: (directory) {
            unawaited(showUnsupportedRootPasswordChange(
              context: context,
              directory: directory,
            ));
          },
          onToggleDrawerPin: (pinned) async {
            setState(() => _drawerPinned = pinned);
            await _persistenceService.saveDrawerPinned(pinned);
          },
          onUnlock: _verifyPassword,
          onImportFile: _importFile,
          onImportDirectory: _importDirectory,
          onPaste: () => _pasteClipboard(),
          onClearClipboard: () {
            _secureClipboard.clear();
            setState(() {});
          },
          onOpenSettings: _openSettings,
          onViewModeChanged: (mode) => setState(() => _viewMode = mode),
          onCancelSelection: () {
            setState(() {
              _isSelectMode = false;
              _selectedFiles.clear();
            });
          },
          onSelectAll: () {
            setState(() {
              _selectedFiles.addAll(_items.where((item) => !item.isDirectory));
            });
          },
          onBatchCopy: () => _copySelected(move: false),
          onBatchCut: () => _copySelected(move: true),
          onBatchExport: _batchExport,
          onBatchDelete: _batchDelete,
          onNavigateToDirectory: _navigateToDirectory,
          onNavigateUp: _navigateUp,
          onOpenItem: _openItem,
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
        ),
      ),
    );
  }
}
