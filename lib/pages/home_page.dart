import 'package:flutter/material.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../models/cryption_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CryptoService _cryptoService = CryptoService();
  late final FileService _fileService;
  
  List<EncryptedDirectory> _openedDirs = []; // List of opened encrypted directories
  EncryptedDirectory? _currentDir;
  String? _currentPath; // Current browsing path (can be subdirectory)
  List<FileSystemNode> _items = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _fileService = FileService(_cryptoService);
    _loadQuickList();
  }
  
  Future<void> _loadQuickList() async {
    // TODO: Load from config file
    // For now, just initialize empty list
  }
  
  Future<void> _openDirectory() async {
    // Show a dialog to input path
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Encrypted Directory'),
        content: TextField(
          controller: controller,
          autofocus: true,
          enableInteractiveSelection: true,
          decoration: const InputDecoration(
            labelText: 'Directory Path',
            hintText: '/path/to/encrypted/directory',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      await _loadDirectory(result);
    }
  }
  
  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);
    
    try {
      // Find encrypted root (search upward like .git)
      final root = await _cryptoService.findEncryptedRoot(path);
      if (root == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not an encrypted directory (no _cryption.json found in this or parent directories)')),
          );
        }
        return;
      }
      
      // Load config from the root
      final config = await _cryptoService.loadConfig(root);
      if (config == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load encryption config')),
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
          SnackBar(content: Text('Error loading directory: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _verifyPassword(String password) async {
    if (_currentDir == null) return;
    
    final isValid = await _cryptoService.verifyPassword(_currentDir!, password);
    
    if (isValid) {
      setState(() {
        _currentDir = EncryptedDirectory(
          path: _currentDir!.path,
          config: _currentDir!.config,
          isVerified: true,
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
          const SnackBar(content: Text('Invalid password')),
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
      // Open file (decrypt and view)
      await _openFile(item);
    }
  }
  
  Future<void> _openFile(FileSystemNode file) async {
    if (_currentDir == null || !_currentDir!.isVerified) return;
    
    final key = _cryptoService.getCachedKey(_currentDir!.path);
    if (key == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cached key, please verify password again')),
        );
      }
      return;
    }
    
    try {
      final tempPath = await _fileService.decryptFile(file, key);
      if (mounted) {
        // Show file content in a dialog
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(file.name),
            content: SingleChildScrollView(
              child: Text('File decrypted to: $tempPath'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Disk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openDirectory,
            tooltip: 'Open Directory',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }
  
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock, size: 48),
                const SizedBox(height: 8),
                const Text(
                  'Safe Disk',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_openedDirs.length} directories opened',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          
          // Open new directory button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _openDirectory,
              icon: const Icon(Icons.add),
              label: const Text('Open Directory'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ),
          
          const Divider(),
          
          // List of opened directories
          Expanded(
            child: _openedDirs.isEmpty
                ? const Center(
                    child: Text('No directories opened'),
                  )
                : ListView.builder(
                    itemCount: _openedDirs.length,
                    itemBuilder: (context, index) {
                      final dir = _openedDirs[index];
                      final isSelected = _currentDir?.path == dir.path;
                      
                      return ListTile(
                        leading: Icon(
                          Icons.folder,
                          color: dir.isVerified ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          dir.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          dir.isVerified ? 'Verified' : 'Not verified',
                          style: TextStyle(
                            color: dir.isVerified ? Colors.green : Colors.orange,
                          ),
                        ),
                        selected: isSelected,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _closeDirectory(dir),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _switchToDirectory(dir);
                        },
                      );
                    },
                  ),
          ),
        ],
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
    
    return _buildFileBrowser();
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
              autofocus: true,
              obscureText: true,
              enableInteractiveSelection: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => _verifyPassword(value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _verifyPassword(controller.text),
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
  
  Widget _buildBreadcrumb() {
    if (_currentPath == null || _currentDir == null) {
      return const SizedBox.shrink();
    }
    
    // Build path segments
    final segments = <String>[];
    String path = _currentPath!;
    final rootPath = _currentDir!.path;
    
    // Extract relative path segments
    if (path.startsWith(rootPath)) {
      final relative = path.substring(rootPath.length);
      if (relative.isNotEmpty) {
        segments.addAll(relative.split('/').where((s) => s.isNotEmpty));
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Root button
          InkWell(
            onTap: _navigateToRoot,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home, size: 18),
                const SizedBox(width: 4),
                Text(
                  _currentDir!.path.split('/').last,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Path segments
          ...segments.map((segment) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_right, size: 18),
              const SizedBox(width: 4),
              Text(segment),
            ],
          )),
        ],
      ),
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
          
          // View toggle (future: list/grid)
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed: () {},
            tooltip: 'View',
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileList() {
    if (_items.isEmpty) {
      return const Center(
        child: Text('Empty directory'),
      );
    }
    
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          leading: Icon(
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
          onTap: () => _openItem(item),
        );
      },
    );
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
