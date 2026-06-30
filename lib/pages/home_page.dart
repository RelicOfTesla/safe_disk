import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import '../models/cryption_config.dart';
import '../models/view_mode.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../services/directory_service.dart';
import '../services/directory_persistence_service.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/sidebar.dart';
import '../widgets/secure_notepad.dart';
import '../widgets/secure_image_viewer.dart';
import '../widgets/progress_dialog.dart';
import '../widgets/welcome_screen.dart';
import '../widgets/password_prompt.dart';
import '../widgets/file_browser.dart';
import 'dialogs.dart';

export '../models/view_mode.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CryptoService _cryptoService = CryptoService();
  final DirectoryService _directoryService = DirectoryService();
  late final FileService _fileService;
  final DirectoryPersistenceService _persistenceService =
      DirectoryPersistenceService();

  final List<EncryptedDirectory> _openedDirs = [];
  EncryptedDirectory? _currentDir;
  String? _currentPath;
  List<FileSystemNode> _items = [];
  bool _isLoading = false;
  bool _drawerPinned = false;
  ViewMode _viewMode = ViewMode.list;

  // File selection for batch operations
  bool _isSelectMode = false;
  final Set<FileSystemNode> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _fileService = FileService(cryptoService: _cryptoService);
    _loadQuickList();
    _loadPersistedDirectories();
    _loadDrawerPinnedState();
    _checkFirstTimeUser();
  }

  @override
  void dispose() {
    _saveOpenedDirectories();
    super.dispose();
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
    final paths = await _persistenceService.loadOpenedDirectories();
    for (final path in paths) {
      try {
        final config = _cryptoService.loadConfig(path);
        setState(() {
          _openedDirs.add(EncryptedDirectory(
            path: path,
            config: config,
            isVerified: false,
          ));
        });
      } catch (e) {
        // Directory no longer exists or config is invalid, skip it.
      }
    }
  }

  Future<void> _saveOpenedDirectories() async {
    final paths = _openedDirs.map((d) => d.path).toList();
    await _persistenceService.saveOpenedDirectories(paths);
  }

  Future<void> _loadQuickList() async {
    // TODO: Load from config file.
  }

  // ── Directory open / create ───────────────────────────────────────

  Future<void> _openOrCreateEncryptedDirectory() async {
    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => const PathSelectionDialog(),
    );
    if (selectedPath == null || selectedPath.isEmpty) return;

    final configFile = File('$selectedPath/_cryption.json');
    final configExists = await configFile.exists();

    if (configExists) {
      await _loadDirectory(selectedPath);
    } else {
      await _createEncryptedDirectoryWithPath(selectedPath);
    }
  }

  Future<void> _createEncryptedDirectoryWithPath(String selectedPath) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateEncryptedDirectoryDialog(),
    );
    if (result == null) return;

    final password = result['password'] as String;
    final mutable = result['mutable'] as bool;

    setState(() => _isLoading = true);

    try {
      final options = jsonEncode({
        'dataFactory': 'aes-ctr',
        'nameFactory': 'none',
        'mutable': mutable,
      });
      _cryptoService.createRootConfig(selectedPath, password, options);
      final rootID = _cryptoService.openRoot(selectedPath, password, '');
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
      await _loadCurrentPath();

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

  Future<void> _loadCurrentPath() async {
    if (_currentPath == null) return;
    setState(() => _isLoading = true);

    try {
      final items = await _fileService.listCurrentDirectory(_currentPath!);
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.loadDirectoryFailed,
          originalError: e.toString(),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Password verification ─────────────────────────────────────────

  Future<bool> _verifyPassword(String password) async {
    if (_currentDir == null) return false;

    try {
      final rootID = _cryptoService.openRoot(_currentDir!.path, password, '');
      await _handleUnfinishedOperations(rootID);

      setState(() {
        _currentDir = EncryptedDirectory(
          path: _currentDir!.path,
          config: _currentDir!.config,
          isVerified: true,
          tempKeyID: rootID.toString(),
        );

        final index =
            _openedDirs.indexWhere((d) => d.path == _currentDir!.path);
        if (index >= 0) _openedDirs[index] = _currentDir!;
      });

      if (mounted) {
        ErrorHelper.showSuccess(context, '密码验证成功');
      }
      return true;
    } catch (_) {
      if (mounted) {
        ErrorHelper.showError(context, errorType: ErrorType.invalidPassword);
      }
      return false;
    }
  }

  Future<void> _handleUnfinishedOperations(int rootID) async {
    List<Map<String, dynamic>> markers;
    try {
      markers = await _directoryService.listUnfinishedOperations(rootID);
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: e.toString(),
        );
      }
      return;
    }
    if (!mounted || markers.isEmpty) return;

    final clean = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂时跳过'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理状态'),
          ),
        ],
      ),
    );

    if (clean != true) {
      return;
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
  }

  // ── Directory management ──────────────────────────────────────────

  void _switchToDirectory(EncryptedDirectory dir) {
    setState(() {
      _currentDir = dir;
      _currentPath = dir.path;
      _items = [];
    });
    _loadCurrentPath();
  }

  Future<void> _closeDirectory(EncryptedDirectory dir) async {
    final action = await showDialog<DeleteDirectoryAction>(
      context: context,
      builder: (context) => DeleteDirectoryDialog(
        directoryPath: dir.path,
        directoryName: dir.path.split('/').last,
      ),
    );
    if (action == null || action == DeleteDirectoryAction.cancel) return;

    if (action == DeleteDirectoryAction.deleteFromDisk) {
      try {
        final directory = Directory(dir.path);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.deleteFileFailed,
            originalError: 'Failed to delete directory: $e',
          );
        }
        return;
      }
    }

    setState(() {
      _openedDirs.remove(dir);
      if (_currentDir?.path == dir.path) {
        _currentDir = null;
        _currentPath = null;
        _items = [];
      }
    });
    _saveOpenedDirectories();
  }

  // ── Navigation ────────────────────────────────────────────────────

  void _navigateToDirectory(String path) {
    setState(() => _currentPath = path);
    _loadCurrentPath();
  }

  void _navigateUp() {
    if (_currentPath == null || _currentDir == null) return;
    final parent = _fileService.getParentDirectory(_currentPath!);
    if (parent == null || !parent.startsWith(_currentDir!.path)) return;
    _navigateToDirectory(parent);
  }

  // ── File operations ───────────────────────────────────────────────

  void _openItem(FileSystemNode item) {
    if (item.isDirectory) {
      _navigateToDirectory(item.path);
      return;
    }

    final ext = item.extension?.toLowerCase();
    if (ext == 'txt' || ext == 'md') {
      _openNotepad(item);
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      _openImageViewer(item);
    }
    // Other file types: no default action yet.
  }

  void _openNotepad(FileSystemNode item) {
    if (item.isDirectory) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureNotepad(
          tempKeyID: _currentDir!.tempKeyID!,
          file: EncryptedFile(
            name: item.name,
            encryptedPath: item.path,
            modifiedTime: DateTime.now(),
          ),
          cryptoService: _cryptoService,
          onSaved: () => _loadCurrentPath(),
        ),
      ),
    );
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
            modifiedTime: DateTime.now(),
          ),
          cryptoService: _cryptoService,
          directoryPath: _currentPath,
          fileService: _fileService,
        ),
      ),
    );
  }

  void _showFileOptions(FileSystemNode item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!item.isDirectory)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit with Notepad'),
                onTap: () {
                  Navigator.pop(context);
                  _openNotepad(item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(
                  item.isDirectory ? 'Export Directory' : 'Export Decrypted'),
              onTap: () {
                Navigator.pop(context);
                item.isDirectory ? _exportDirectory(item) : _exportFile(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Import / Export ───────────────────────────────────────────────

  Future<void> _importFile() async {
    if (!_validateSession()) return;

    const typeGroup = XTypeGroup(label: 'All Files');
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      setState(() => _isLoading = true);

      final inputFile = File(file.path);
      final plaintext = await inputFile.readAsBytes();
      await _cryptoService.writeFileBySession(
        '$_currentPath/${file.name}',
        _currentDir!.tempKeyID!,
        plaintext,
      );
      await _loadCurrentPath();

      if (mounted) {
        ErrorHelper.showSuccess(context, '文件导入成功：${file.name}');
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

  Future<void> _exportFile(FileSystemNode item) async {
    if (!_validateSession()) return;

    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: item.name,
    );
    if (saveLocation == null) return;

    try {
      await _fileService.exportFile(
          item, saveLocation.path, _currentDir!.tempKeyID!);
      if (mounted) {
        ErrorHelper.showSuccess(context, '文件导出成功：${saveLocation.path}');
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

    final String? exportDir = await getDirectoryPath();
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

    final String? exportDir = await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final totalFiles = _selectedFiles.length;
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
      for (final item in _selectedFiles) {
        if (progressController.isCancelled) break;

        progressController.update(
          current: successCount + failCount + 1,
          currentFileName: item.name,
          status: '正在导出...',
        );
        progressController.estimateTimeRemaining(
          startTime: startTime,
          processedCount: successCount + failCount + 1,
        );

        try {
          await _fileService.exportFile(
            item,
            '$exportDir/${item.name}',
            _currentDir!.tempKeyID!,
          );
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted) progressController.close(context);

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
      if (mounted) progressController.close(context);
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  // ── Delete ────────────────────────────────────────────────────────

  Future<void> _deleteFile(FileSystemNode item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

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

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: _drawerPinned ? null : _buildDrawer(),
      body: Row(
        children: [
          if (_drawerPinned)
            SizedBox(
              width: 280,
              child: SidebarWidget(
                openedDirs: _openedDirs,
                currentDir: _currentDir,
                drawerPinned: _drawerPinned,
                onOpenDirectory: _openOrCreateEncryptedDirectory,
                onCloseDirectory: _closeDirectory,
                onSwitchDirectory: _switchToDirectory,
                onTogglePin: (pinned) async {
                  setState(() => _drawerPinned = pinned);
                  await _persistenceService.saveDrawerPinned(pinned);
                },
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _isSelectMode
          ? Text('${_selectedFiles.length} selected')
          : const Text('Safe Disk'),
      leading: _isSelectMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectMode = false;
                  _selectedFiles.clear();
                });
              },
              tooltip: 'Cancel selection',
            )
          : _drawerPinned
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
      actions: _isSelectMode ? _buildSelectActions() : _buildNormalActions(),
    );
  }

  List<Widget> _buildSelectActions() {
    return [
      IconButton(
        icon: const Icon(Icons.select_all),
        onPressed: () {
          setState(() {
            _selectedFiles.addAll(_items.where((item) => !item.isDirectory));
          });
        },
        tooltip: 'Select all',
      ),
      if (_selectedFiles.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.save_alt),
          onPressed: _batchExport,
          tooltip: 'Export selected',
        ),
    ];
  }

  List<Widget> _buildNormalActions() {
    return [
      IconButton(
        icon: const Icon(Icons.upload_file),
        onPressed: _importFile,
        tooltip: 'Import File',
      ),
      IconButton(
        icon: Icon(
          _viewMode == ViewMode.list ? Icons.grid_view : Icons.view_list,
        ),
        onPressed: () {
          setState(() {
            _viewMode =
                _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
          });
        },
        tooltip: _viewMode == ViewMode.list
            ? 'Switch to Grid View'
            : 'Switch to List View',
      ),
    ];
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SidebarWidget(
        openedDirs: _openedDirs,
        currentDir: _currentDir,
        drawerPinned: _drawerPinned,
        onOpenDirectory: _openOrCreateEncryptedDirectory,
        onCloseDirectory: _closeDirectory,
        onSwitchDirectory: _switchToDirectory,
        onTogglePin: (pinned) async {
          setState(() => _drawerPinned = pinned);
          await _persistenceService.saveDrawerPinned(pinned);
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentDir == null) {
      return const WelcomeScreen();
    }

    if (!_currentDir!.isVerified) {
      return PasswordPrompt(
        directoryPath: _currentDir!.path,
        onUnlock: _verifyPassword,
      );
    }

    return FileBrowser(
      items: _items,
      currentPath: _currentPath,
      rootPath: _currentDir!.path,
      viewMode: _viewMode,
      isSelectMode: _isSelectMode,
      selectedFiles: _selectedFiles,
      fileService: _fileService,
      onNavigateToDirectory: _navigateToDirectory,
      onNavigateUp: _navigateUp,
      onOpenItem: _openItem,
      onItemLongPress: _showFileOptions,
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
      onSelectAll: () {
        setState(() {
          _selectedFiles.addAll(_items.where((item) => !item.isDirectory));
        });
      },
    );
  }
}
