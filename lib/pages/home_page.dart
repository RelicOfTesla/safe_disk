import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../services/directory_persistence_service.dart';
import '../models/cryption_config.dart';
import '../widgets/directory_tree.dart';
import '../widgets/secure_notepad.dart';
import '../widgets/secure_image_viewer.dart';
import '../widgets/sidebar.dart';
import '../widgets/copyable_snackbar.dart';
import 'dialogs.dart';

// View mode enum for file browsing
enum ViewMode { list, grid }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CryptoService _cryptoService = CryptoService();
  late final FileService _fileService;
  final DirectoryPersistenceService _persistenceService = DirectoryPersistenceService();
  
  List<EncryptedDirectory> _openedDirs = []; // List of opened encrypted directories
  EncryptedDirectory? _currentDir;
  String? _currentPath; // Current browsing path (can be subdirectory)
  List<FileSystemNode> _items = [];
  bool _isLoading = false;
  bool _drawerPinned = false; // Whether drawer is pinned (stays open)
  bool _showTreeView = false; // Whether to show directory tree view
  bool _isSearching = false; // Whether search mode is active
  final TextEditingController _searchController = TextEditingController();
  List<FileSystemNode> _searchResults = [];
  
  // File selection for batch operations
  bool _isSelectMode = false; // Whether in select mode
  Set<FileSystemNode> _selectedFiles = {}; // Selected files for batch operations
  
  // View mode for file browsing (list or grid)
  ViewMode _viewMode = ViewMode.list; // Current view mode
  
  @override
  void initState() {
    super.initState();
    _fileService = FileService(_cryptoService);
    _loadQuickList();
    _loadPersistedDirectories();
    _loadDrawerPinnedState();
  }
  
  Future<void> _loadDrawerPinnedState() async {
    final pinned = await _persistenceService.loadDrawerPinned();
    setState(() {
      _drawerPinned = pinned;
    });
  }
  
  @override
  void dispose() {
    _saveOpenedDirectories();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPersistedDirectories() async {
    final paths = await _persistenceService.loadOpenedDirectories();
    // We load directory configs but don't restore verification status
    // (user needs to re-enter password for security)
    for (final path in paths) {
      try {
        final config = await _cryptoService.loadConfig(path);
        if (config != null) {
          setState(() {
            _openedDirs.add(EncryptedDirectory(
              path: path,
              config: config,
              isVerified: false,
            ));
          });
        }
      } catch (e) {
        // Directory no longer exists or config is invalid, skip it
        print('Failed to load persisted directory $path: $e');
      }
    }
  }
  
  Future<void> _saveOpenedDirectories() async {
    final paths = _openedDirs.map((d) => d.path).toList();
    await _persistenceService.saveOpenedDirectories(paths);
  }
  
  Future<void> _loadQuickList() async {
    // TODO: Load from config file
    // For now, just initialize empty list
  }
  
  Future<void> _openDirectory() async {
    // Use path selection dialog (supports both input and browse)
    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => PathSelectionDialog(),
    );
    
    if (selectedPath != null && selectedPath.isNotEmpty) {
      await _loadDirectory(selectedPath);
    }
  }
  
  Future<void> _createEncryptedDirectory() async {
    // Step 1: Select directory (with path input support)
    final String? selectedPath = await showDialog<String>(
      context: context,
      builder: (context) => PathSelectionDialog(),
    );
    if (selectedPath == null || selectedPath.isEmpty) {
      return;
    }
    
    // Step 2: Show password dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateEncryptedDirectoryDialog(),
    );
    
    if (result == null) {
      return;
    }
    
    final password = result['password'] as String;
    final mutable = result['mutable'] as bool;
    
    // Step 3: Generate all keys and config
    setState(() => _isLoading = true);
    
    try {
      // Use new FFI function to generate complete encryption config
      // keyStrengthMs: 1000ms (1 second) for good security/performance balance
      // challengeId: empty string to use default "safe_disk"
      final configJson = _cryptoService.generateEncryptionConfig(password, 1000, mutable, '');
      
      // Parse JSON config
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;
      
      // Extract fields from config
      final salt = configMap['salt'] as String;
      final iterN = configMap['iterN'] as int;
      final encryptedChallengeId = configMap['encryptedChallengeId'] as String;
      final encryptedKey = configMap['key'] as String?; // Only present in mutable mode
      
      // Assemble config JSON with additional fields
      final config = {
        'version': '1.2',
        'mode': mutable ? 'mutable' : 'immutable',
        'check': encryptedChallengeId, // Use encryptedChallengeId as check
        'salt': salt,
        'iterN': iterN,
        'algorithm': 'AES-256-GCM',
        'kdf': 'pbkdf2',
        'created': DateTime.now().toUtc().toIso8601String(),
        if (encryptedKey != null) 'key': encryptedKey,
      };
      
      // Step 4: Create config file via FFI
      final resultData = _cryptoService.createEncryptedDirectory(selectedPath, config);
      
      if (resultData['success'] != true) {
        throw Exception(resultData['error'] ?? 'Failed to create config file');
      }
      
      // Step 5: Encrypt all files
      final dir = Directory(selectedPath);
      final files = dir.listSync(recursive: true);
      
      // Create session with password and config
      final tempKeyID = _cryptoService.createSession(password, jsonEncode(config));
      
      int fileCount = 0;
      for (final file in files) {
        if (file is File && file.path.endsWith('_cryption.json') == false) {
          try {
            // Read file
            final plaintext = await file.readAsBytes();
            
            // Encrypt using session key
            final ciphertextBase64 = _cryptoService.encryptDataBytes(plaintext, tempKeyID);
            final ciphertext = base64Decode(ciphertextBase64);
            
            // Write encrypted file
            await file.writeAsBytes(ciphertext);
            fileCount++;
          } catch (e) {
            print('Failed to encrypt file ${file.path}: $e');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encrypted directory created! $fileCount files encrypted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CopyableSnackBar(message: 'Failed to create encrypted directory: $e', isError: true),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);
    
    try {
      // Find encrypted root (search upward like .git)
      final root = _cryptoService.findCryptionRoot(path);
      if (root == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            CopyableSnackBar(message: 'Not an encrypted directory (no _cryption.json found in this or parent directories)'),
          );
        }
        return;
      }
      
      // Load config from the root
      final config = await _cryptoService.loadConfig(root);
      if (config == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            CopyableSnackBar(message: 'Failed to load encryption config', isError: true),
          );
        }
        return;
      }
      
      // Set current directory
      setState(() {
        _currentDir = EncryptedDirectory(path: root, config: config);
        _currentPath = root;
        
        // Add to opened directories list if not already present
        final existingIndex = _openedDirs.indexWhere((d) => d.path == root);
        if (existingIndex >= 0) {
          // Move to front (most recent)
          _openedDirs.removeAt(existingIndex);
        }
        _openedDirs.insert(0, _currentDir!);
      });
      
      // Save to persistence
      await _saveOpenedDirectories();
      
      // Load files
      await _loadCurrentPath();
      
      // Show info if we're in a subdirectory
      if (root != path && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found encrypted root at: $root')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          CopyableSnackBar(message: 'Error loading directory: $e', isError: true),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _verifyPassword(String password) async {
    if (_currentDir == null) return;
    
    // Convert config to JSON string
    final configJSON = jsonEncode(_currentDir!.config.toJson());
    
    final result = _cryptoService.verifyPassword(password, configJSON);
    
    if (result.success) {
      // Create session with password and config
      final tempKeyID = _cryptoService.createSession(password, configJSON);
      
      setState(() {
        _currentDir = EncryptedDirectory(
          path: _currentDir!.path,
          config: _currentDir!.config,
          isVerified: true,
          tempKeyID: tempKeyID,
        );
        
        // Update in opened directories list
        final index = _openedDirs.indexWhere((d) => d.path == _currentDir!.path);
        if (index >= 0) {
          _openedDirs[index] = _currentDir!;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password verified')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CopyableSnackBar(message: 'Invalid password', isError: true),
        );
      }
    }
  }
  
  void _switchToDirectory(EncryptedDirectory dir) {
    setState(() {
      _currentDir = dir;
      _currentPath = dir.path;
      _items = [];
    });
    _loadCurrentPath();
  }
  
  void _closeDirectory(EncryptedDirectory dir) {
    setState(() {
      _openedDirs.remove(dir);
      if (_currentDir?.path == dir.path) {
        _currentDir = null;
        _currentPath = null;
        _items = [];
      }
    });
    // Save to persistence
    _saveOpenedDirectories();
  }
  
  void _navigateToDirectory(String path) {
    setState(() {
      _currentPath = path;
    });
    _loadCurrentPath();
  }
  
  void _navigateUp() {
    if (_currentPath == null || _currentDir == null) return;
    
    final parent = _fileService.getParentDirectory(_currentPath!);
    if (parent == null || !parent.startsWith(_currentDir!.path)) {
      // Already at root or no parent
      return;
    }
    
    _navigateToDirectory(parent);
  }
  
  void _navigateToRoot() {
    if (_currentDir == null) return;
    _navigateToDirectory(_currentDir!.path);
  }
  
  Future<void> _openItem(FileSystemNode item) async {
    if (item.isDirectory) {
      // Navigate into directory
      _navigateToDirectory(item.path);
    } else {
      // Check file extension
      final ext = item.extension?.toLowerCase();
      
      // Text files
      if (ext == 'txt' || ext == 'md') {
        _openNotepad(item);
        return;
      }
      
      // Image files
      if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
        _openImageViewer(item);
        return;
      }
      
      // Other files
      // TODO: alert dialog to export file
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
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
            ? null // Hide menu button when drawer is pinned
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        actions: _isSelectMode
          ? [
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: () {
                  setState(() {
                    // Select all files (not directories)
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
            ]
          : [
              IconButton(
                icon: const Icon(Icons.create_new_folder),
                onPressed: _createEncryptedDirectory,
                tooltip: 'Create Encrypted Directory',
              ),
              IconButton(
                icon: const Icon(Icons.folder_open),
                onPressed: _openDirectory,
                tooltip: 'Open Directory',
              ),
              // Import file button
              IconButton(
                icon: const Icon(Icons.upload_file),
                onPressed: _importFile,
                tooltip: 'Import File',
              ),
              // View mode toggle button
              IconButton(
                icon: Icon(_viewMode == ViewMode.list ? Icons.grid_view : Icons.view_list),
                onPressed: () {
                  setState(() {
                    _viewMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list;
                  });
                },
                tooltip: _viewMode == ViewMode.list ? 'Switch to Grid View' : 'Switch to List View',
              ),
            ],
      ),
      drawer: _drawerPinned ? null : _buildDrawer(),
      body: Row(
        children: [
          // Show drawer as permanent sidebar when pinned
          if (_drawerPinned) 
            SizedBox(
              width: 280,
              child: SidebarWidget(
                openedDirs: _openedDirs,
                currentDir: _currentDir,
                drawerPinned: _drawerPinned,
                onOpenDirectory: _openDirectory,
                onCloseDirectory: _closeDirectory,
                onSwitchDirectory: _switchToDirectory,
                onTogglePin: (pinned) async {
                  setState(() {
                    _drawerPinned = pinned;
                  });
                  await _persistenceService.saveDrawerPinned(pinned);
                },
              ),
            ),
          // Main content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: SidebarWidget(
        openedDirs: _openedDirs,
        currentDir: _currentDir,
        drawerPinned: _drawerPinned,
        onOpenDirectory: _openDirectory,
        onCloseDirectory: _closeDirectory,
        onSwitchDirectory: _switchToDirectory,
        onTogglePin: (pinned) async {
          setState(() {
            _drawerPinned = pinned;
          });
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
      return _buildWelcome();
    }
    
    if (!_currentDir!.isVerified) {
      return _buildPasswordPrompt();
    }
    
    // Show search bar if searching
    return Column(
      children: [
        if (_isSearching) _buildSearchBar(),
        if (!_isSearching && _currentPath != null) _buildBreadcrumb(),
        Expanded(
          child: _buildFileBrowser(),
        ),
      ],
    );
  }
  
  Widget _buildBreadcrumb() {
    // Build breadcrumb path navigation
    final pathParts = _currentPath!.split('/');
    final breadcrumbs = <Widget>[];
    
    // Build encrypted root name
    final rootName = _currentDir!.path.split('/').last;
    
    // Add root directory
    breadcrumbs.add(
      InkWell(
        onTap: () => _navigateToDirectory(_currentDir!.path),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            rootName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
    
    // Add subdirectories
    String accumulatedPath = _currentDir!.path;
    final relativePath = _currentPath!.substring(_currentDir!.path.length);
    
    if (relativePath.isNotEmpty) {
      final subdirs = relativePath.split('/').where((s) => s.isNotEmpty).toList();
      
      for (final subdir in subdirs) {
        accumulatedPath = '$accumulatedPath/$subdir';
        
        breadcrumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Icon(Icons.chevron_right, size: 16),
          ),
        );
        
        breadcrumbs.add(
          InkWell(
            onTap: () => _navigateToDirectory(accumulatedPath),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                subdir,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: breadcrumbs,
        ),
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search files and folders...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: _performSearch,
      ),
    );
  }
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    final lowerQuery = query.toLowerCase();
    final results = <FileSystemNode>[];
    
    // Search in current directory
    for (final item in _items) {
      if (item.name.toLowerCase().contains(lowerQuery)) {
        results.add(item);
      }
    }
    
    setState(() => _searchResults = results);
  }
  
  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Safe Disk',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Encrypted file manager'),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openDirectory,
            icon: const Icon(Icons.folder_open),
            label: const Text('Open Encrypted Directory'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPasswordPrompt() {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    
    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48),
            const SizedBox(height: 16),
            Text(
              'Enter password for:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _currentDir!.path,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              obscureText: true,
              enableInteractiveSelection: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await _verifyPassword(value);
                // Keep focus on password field if verification failed
                if (_currentDir != null && !_currentDir!.isVerified) {
                  focusNode.requestFocus();
                  controller.clear();
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await _verifyPassword(controller.text);
                // Keep focus on password field if verification failed
                if (_currentDir != null && !_currentDir!.isVerified) {
                  focusNode.requestFocus();
                  controller.clear();
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileBrowser() {
    return Column(
      children: [
        // Breadcrumb navigation
        _buildBreadcrumb(),
        
        // Toolbar
        _buildToolbar(),
        
        // File list
        Expanded(
          child: _buildFileList(),
        ),
      ],
    );
  }
  
  Widget _buildToolbar() {
    final canNavigateUp = _currentPath != null && 
                          _currentDir != null && 
                          _currentPath != _currentDir!.path;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: canNavigateUp ? _navigateUp : null,
            tooltip: 'Go up',
          ),
          
          const SizedBox(width: 8),
          
          // Current path info
          Expanded(
            child: Text(
              '${_items.where((i) => i.isDirectory).length} folders, ${_items.where((i) => !i.isDirectory).length} files',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          
          // Search button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
            tooltip: _isSearching ? 'Close search' : 'Search',
          ),
          IconButton(
            icon: Icon(_showTreeView ? Icons.view_list : Icons.account_tree),
            onPressed: () {
              setState(() {
                _showTreeView = !_showTreeView;
              });
            },
            tooltip: _showTreeView ? 'List view' : 'Tree view',
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileList() {
    // Use search results if searching
    final items = _isSearching && _searchResults.isNotEmpty 
        ? _searchResults 
        : (_isSearching ? _searchResults : _items);
    
    if (_isSearching && _searchController.text.isNotEmpty && items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No results for "${_searchController.text}"'),
          ],
        ),
      );
    }
    
    if (items.isEmpty) {
      return const Center(
        child: Text('Empty directory'),
      );
    }
    
    // Show tree view if enabled and directory is verified (not in search mode)
    if (!_isSearching && _showTreeView && _currentDir != null && _currentDir!.isVerified) {
      return DirectoryTreeWidget(
        rootPath: _currentDir!.path,
        currentPath: _currentPath,
        fileService: _fileService,
        onPathSelected: (path) {
          setState(() {
            _currentPath = path;
          });
          _loadCurrentPath();
        },
      );
    }
    
    // Default list view or grid view based on _viewMode
    if (_viewMode == ViewMode.grid) {
      // Grid view
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = _selectedFiles.contains(item);
          
          return InkWell(
            onTap: () {
              if (_isSelectMode && !item.isDirectory) {
                // Toggle selection in select mode
                setState(() {
                  if (isSelected) {
                    _selectedFiles.remove(item);
                  } else {
                    _selectedFiles.add(item);
                  }
                });
              } else {
                if (_isSearching) {
                  // Close search when opening item
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchResults = [];
                  });
                }
                _openItem(item);
              }
            },
            onLongPress: () {
              if (!item.isDirectory) {
                // Enter select mode on long press
                if (!_isSelectMode) {
                  setState(() {
                    _isSelectMode = true;
                    _selectedFiles.add(item);
                  });
                }
              }
            },
            child: Card(
              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.isDirectory ? Icons.folder : _getFileIcon(item.extension),
                    size: 48,
                    color: item.isDirectory ? Colors.orange : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    
    // List view (default)
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedFiles.contains(item);
        
        return ListTile(
          leading: _isSelectMode && !item.isDirectory
              ? Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedFiles.add(item);
                      } else {
                        _selectedFiles.remove(item);
                      }
                    });
                  },
                )
              : Icon(
                  item.isDirectory ? Icons.folder : _getFileIcon(item.extension),
                  color: item.isDirectory ? Colors.orange : null,
                ),
          title: Text(item.name),
          subtitle: Text(
            item.isDirectory 
                ? '${item.children?.length ?? 0} items'
                : item.formattedSize,
          ),
          trailing: item.isDirectory ? const Icon(Icons.chevron_right) : null,
          selected: isSelected,
          onTap: () {
            if (_isSelectMode && !item.isDirectory) {
              // Toggle selection in select mode
              setState(() {
                if (isSelected) {
                  _selectedFiles.remove(item);
                } else {
                  _selectedFiles.add(item);
                }
              });
            } else {
              if (_isSearching) {
                // Close search when opening item
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchResults = [];
                });
              }
              _openItem(item);
            }
          },
          onLongPress: () {
            if (!item.isDirectory) {
              // Enter select mode on long press
              if (!_isSelectMode) {
                setState(() {
                  _isSelectMode = true;
                  _selectedFiles.add(item);
                });
              } else {
                _showFileOptions(item);
              }
            } else {
              _showFileOptions(item);
            }
          },
        );
      },
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
              title: Text(item.isDirectory ? 'Export Directory' : 'Export Decrypted'),
              onTap: () {
                Navigator.pop(context);
                if (item.isDirectory) {
                  _exportDirectory(item);
                } else {
                  _exportFile(item);
                }
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
  
  void _openNotepad(FileSystemNode item) {
    if (item.isDirectory) return;
    
    final encryptedFile = EncryptedFile(
      name: item.name,
      encryptedPath: item.path,
      modifiedTime: DateTime.now(),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureNotepad(
        tempKeyID: _currentDir!.tempKeyID!,
          file: encryptedFile,
          cryptoService: _cryptoService,
          onSaved: () {
            _loadCurrentPath();
          },
        ),
      ),
    );
  }
  
  void _openImageViewer(FileSystemNode item) {
    if (item.isDirectory) return;
    
    final encryptedFile = EncryptedFile(
      name: item.name,
      encryptedPath: item.path,
      modifiedTime: DateTime.now(),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewer(
        tempKeyID: _currentDir!.tempKeyID!,
          file: encryptedFile,
          cryptoService: _cryptoService,
        ),
      ),
    );
  }
  
  /// Import a file from external location, encrypt it, and save to current directory
  Future<void> _importFile() async {
    if (!mounted) return;
    
    // Check if directory is opened and verified
    if (_currentDir == null || !_currentDir!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Please verify the directory first', isError: true),
      );
      return;
    }
    
    // Check if session is active
    if (_currentDir!.tempKeyID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Session expired. Please re-verify the directory', isError: true),
      );
      return;
    }
    
    // Check if current path is set
    if (_currentPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No directory selected')),
      );
      return;
    }
    
    // Use file selector to choose file to import
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'All Files',
    );
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
    
    if (file == null) return; // User cancelled
    
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // Read file content
      final inputFile = File(file.path);
      final plaintext = await inputFile.readAsBytes();
      
      // Encrypt and save to current directory
      final encryptedDataBase64 = _cryptoService.encryptDataBytes(plaintext, _currentDir!.tempKeyID!);
      final encryptedData = base64Decode(encryptedDataBase64);
      
      // Save encrypted file to current directory
      final fileName = file.name;
      final outputFile = File('$_currentPath/$fileName');
      await outputFile.writeAsBytes(encryptedData);
      
      // Refresh file list
      await _loadCurrentPath();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File imported: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _exportFile(FileSystemNode item) async {
    if (!mounted) return;
    
    // Check if directory is opened and verified
    if (_currentDir == null || !_currentDir!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Please verify the directory first', isError: true),
      );
      return;
    }
    
    // Check if session is active
    if (_currentDir!.tempKeyID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Session expired. Please re-verify the directory', isError: true),
      );
      return;
    }
    
    // Use file selector to choose save location
    final FileSaveLocation? saveLocation = await getSaveLocation(
      suggestedName: item.name,
    );
    
    if (saveLocation == null) return; // User cancelled
    
    try {
      // Export file
      await _fileService.exportFile(item, saveLocation.path, _currentDir!.tempKeyID!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File exported to: ${saveLocation.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export file: $e')),
        );
      }
    }
  }
  
  Future<void> _exportDirectory(FileSystemNode item) async {
    if (!mounted) return;
    
    // Check if directory is opened and verified
    if (_currentDir == null || !_currentDir!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Please verify the directory first', isError: true),
      );
      return;
    }
    
    // Check if session is active
    if (_currentDir!.tempKeyID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Session expired. Please re-verify the directory', isError: true),
      );
      return;
    }
    
    // Use file selector to choose export directory
    final String? exportDir = await getDirectoryPath();
    
    if (exportDir == null) return; // User cancelled
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      // Show progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Recursively export directory
      await _exportDirectoryRecursive(item, exportDir, (success, fail) {
        successCount += success;
        failCount += fail;
      });
      
      // Hide progress indicator
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $successCount files${failCount > 0 ? ', $failCount failed' : ''}'),
          ),
        );
      }
    } catch (e) {
      // Hide progress indicator
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export directory: $e')),
        );
      }
    }
  }
  
  Future<void> _exportDirectoryRecursive(
    FileSystemNode node,
    String exportPath,
    void Function(int success, int fail) onProgress,
  ) async {
    if (node.isDirectory) {
      // Create directory in export path
      final newDirPath = '$exportPath/${node.name}';
      await Directory(newDirPath).create(recursive: true);
      
      // Load children
      final children = await _fileService.listCurrentDirectory(node.path);
      
      // Recursively export children
      for (final child in children) {
        await _exportDirectoryRecursive(child, newDirPath, onProgress);
      }
    } else {
      // Export file
      try {
        final outputPath = '$exportPath/${node.name}';
        await _fileService.exportFile(node, outputPath, _currentDir!.tempKeyID!);
        onProgress(1, 0);
      } catch (e) {
        print('Failed to export ${node.name}: $e');
        onProgress(0, 1);
      }
    }
  }
  
  Future<void> _batchExport() async {
    if (!mounted) return;
    
    // Check if directory is opened and verified
    if (_currentDir == null || !_currentDir!.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Please verify the directory first', isError: true),
      );
      return;
    }
    
    // Check if session is active
    if (_currentDir!.tempKeyID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        CopyableSnackBar(message: 'Session expired. Please re-verify the directory', isError: true),
      );
      return;
    }
    
    // Use file selector to choose export directory
    final String? exportDir = await getDirectoryPath();
    
    if (exportDir == null) return; // User cancelled
    
    try {
      int successCount = 0;
      int failCount = 0;
      
      // Show progress indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Export each selected file
      for (final item in _selectedFiles) {
        try {
          final outputPath = '$exportDir/${item.name}';
          await _fileService.exportFile(item, outputPath, _currentDir!.tempKeyID!);
          successCount++;
        } catch (e) {
          print('Failed to export ${item.name}: $e');
          failCount++;
        }
      }
      
      // Hide progress indicator
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Exit select mode
      setState(() {
        _isSelectMode = false;
        _selectedFiles.clear();
      });
      
      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $successCount files${failCount > 0 ? ', $failCount failed' : ''}'),
          ),
        );
      }
    } catch (e) {
      // Hide progress indicator
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export files: $e')),
        );
      }
    }
  }
  
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
        final file = File(item.path);
        await file.delete();
        _loadCurrentPath();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: $e')),
        );
      }
    }
  }
  
  IconData _getFileIcon(String? extension) {
    switch (extension) {
      case 'txt':
      case 'md':
        return Icons.description;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
