import 'package:flutter/material.dart';
import '../models/view_mode.dart';
import '../services/file_service.dart';
import '../widgets/directory_tree.dart';

/// A self-contained file browser with toolbar, breadcrumb, search, and
/// list/grid view. Manages its own search and tree-view state.
class FileBrowser extends StatefulWidget {
  const FileBrowser({
    super.key,
    required this.items,
    required this.currentPath,
    required this.rootPath,
    required this.viewMode,
    required this.isSelectMode,
    required this.selectedFiles,
    required this.fileService,
    required this.onNavigateToDirectory,
    required this.onNavigateUp,
    required this.onOpenItem,
    required this.onItemLongPress,
    required this.onToggleSelectMode,
    required this.onSelectionToggle,
    required this.onSelectAll,
  });

  final List<FileSystemNode> items;
  final String? currentPath;
  final String rootPath;
  final ViewMode viewMode;
  final bool isSelectMode;
  final Set<FileSystemNode> selectedFiles;
  final FileService fileService;

  /// Navigate into a subdirectory.
  final void Function(String path) onNavigateToDirectory;

  /// Navigate up to parent directory.
  final VoidCallback onNavigateUp;

  /// Open a file (notepad, image viewer, etc.) or navigate into a directory.
  final void Function(FileSystemNode item) onOpenItem;

  /// Long press on an item (show file options).
  final void Function(FileSystemNode item) onItemLongPress;

  /// Toggle selection mode on/off.
  final void Function(bool selectMode) onToggleSelectMode;

  /// Toggle selection of a single file.
  final void Function(FileSystemNode item, bool selected) onSelectionToggle;

  /// Select all non-directory items.
  final VoidCallback onSelectAll;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  bool _isSearching = false;
  bool _showTreeView = false;
  final TextEditingController _searchController = TextEditingController();
  List<FileSystemNode> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _searchResults = widget.items
          .where((item) => item.name.toLowerCase().contains(lowerQuery))
          .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSearching) _buildSearchBar(),
        if (!_isSearching && widget.currentPath != null) _buildBreadcrumb(),
        _buildToolbar(),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  // ── Breadcrumb ────────────────────────────────────────────────────

  Widget _buildBreadcrumb() {
    final breadcrumbs = <Widget>[];
    final rootName = widget.rootPath.split('/').last;

    breadcrumbs.add(_breadcrumbChip(
      label: rootName,
      isRoot: true,
      onTap: () => widget.onNavigateToDirectory(widget.rootPath),
    ));

    String accumulatedPath = widget.rootPath;
    final relativePath =
        widget.currentPath!.substring(widget.rootPath.length);

    if (relativePath.isNotEmpty) {
      final subdirs =
          relativePath.split('/').where((s) => s.isNotEmpty).toList();
      for (final subdir in subdirs) {
        accumulatedPath = '$accumulatedPath/$subdir';
        breadcrumbs.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.chevron_right, size: 16),
          ),
        );
        breadcrumbs.add(_breadcrumbChip(
          label: subdir,
          onTap: () => widget.onNavigateToDirectory(accumulatedPath),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        child: Row(children: breadcrumbs),
      ),
    );
  }

  Widget _breadcrumbChip({
    required String label,
    bool isRoot = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isRoot ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
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

  // ── Toolbar ───────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final canNavigateUp = widget.currentPath != null &&
        widget.currentPath != widget.rootPath;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: canNavigateUp ? widget.onNavigateUp : null,
            tooltip: 'Go up',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.items.where((i) => i.isDirectory).length} folders, '
              '${widget.items.where((i) => !i.isDirectory).length} files',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _isSearching ? 'Close search' : 'Search',
          ),
          IconButton(
            icon: Icon(_showTreeView ? Icons.view_list : Icons.account_tree),
            onPressed: () => setState(() => _showTreeView = !_showTreeView),
            tooltip: _showTreeView ? 'List view' : 'Tree view',
          ),
        ],
      ),
    );
  }

  // ── File list / grid ──────────────────────────────────────────────

  Widget _buildFileList() {
    final items = _isSearching && _searchResults.isNotEmpty
        ? _searchResults
        : (_isSearching ? _searchResults : widget.items);

    if (_isSearching &&
        _searchController.text.isNotEmpty &&
        items.isEmpty) {
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
      return const Center(child: Text('Empty directory'));
    }

    // Tree view (only when not searching).
    if (!_isSearching && _showTreeView) {
      return DirectoryTreeWidget(
        rootPath: widget.rootPath,
        currentPath: widget.currentPath,
        fileService: widget.fileService,
        onPathSelected: (path) => widget.onNavigateToDirectory(path),
      );
    }

    if (widget.viewMode == ViewMode.grid) {
      return _buildGridView(items);
    }
    return _buildListView(items);
  }

  Widget _buildListView(List<FileSystemNode> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = widget.selectedFiles.contains(item);
        return _FileListTile(
          item: item,
          isSelectMode: widget.isSelectMode,
          isSelected: isSelected,
          onTap: () => _handleItemTap(item, isSelected),
          onLongPress: () => _handleItemLongPress(item, isSelected),
          onToggleSelection: (selected) =>
              widget.onSelectionToggle(item, selected),
        );
      },
    );
  }

  Widget _buildGridView(List<FileSystemNode> items) {
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
        final isSelected = widget.selectedFiles.contains(item);
        return _FileGridCard(
          item: item,
          isSelected: isSelected,
          onTap: () => _handleItemTap(item, isSelected),
          onLongPress: () => _handleItemLongPress(item, isSelected),
        );
      },
    );
  }

  void _handleItemTap(FileSystemNode item, bool isSelected) {
    if (widget.isSelectMode && !item.isDirectory) {
      widget.onSelectionToggle(item, !isSelected);
    } else {
      if (_isSearching) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
          _searchResults = [];
        });
      }
      widget.onOpenItem(item);
    }
  }

  void _handleItemLongPress(FileSystemNode item, bool isSelected) {
    if (!item.isDirectory && !widget.isSelectMode) {
      widget.onToggleSelectMode(true);
      widget.onSelectionToggle(item, true);
    } else {
      widget.onItemLongPress(item);
    }
  }
}

// ── Helper widgets ──────────────────────────────────────────────────

/// A single file/directory entry in list view.
class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelection,
  });

  final FileSystemNode item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(bool selected) onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isSelectMode && !item.isDirectory
          ? Checkbox(
              value: isSelected,
              onChanged: (v) => onToggleSelection(v ?? false),
            )
          : Icon(
              item.isDirectory ? Icons.folder : _getFileIcon(item.extension),
              color: item.isDirectory ? Colors.orange : null,
            ),
      title: Text(item.name),
      subtitle: Text(item.isDirectory
          ? '${item.children?.length ?? 0} items'
          : item.formattedSize),
      trailing: item.isDirectory ? const Icon(Icons.chevron_right) : null,
      selected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// A single file/directory entry in grid view.
class _FileGridCard extends StatelessWidget {
  const _FileGridCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final FileSystemNode item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isDirectory ? Icons.folder : _getFileIcon(item.extension),
              size: 48,
              color: item.isDirectory ? Colors.orange : null,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Map file extension to icon.
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
