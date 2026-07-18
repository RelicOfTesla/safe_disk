import 'package:flutter/material.dart';
import '../models/view_mode.dart';
import '../models/logical_path.dart';
import '../services/file_service.dart';
import '../services/file_sort.dart';
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
    required this.onItemSecondaryTap,
    required this.onBackgroundSecondaryTap,
    required this.onViewModeChanged,
    required this.onToggleSelectMode,
    required this.onSelectionToggle,
    required this.onSelectAll,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
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

  /// Desktop secondary click on an item at the global pointer position.
  final void Function(FileSystemNode item, Offset globalPosition)
      onItemSecondaryTap;

  final ValueChanged<Offset> onBackgroundSecondaryTap;
  final ValueChanged<ViewMode> onViewModeChanged;

  /// Toggle selection mode on/off.
  final void Function(bool selectMode) onToggleSelectMode;

  /// Toggle selection of a single file.
  final void Function(FileSystemNode item, bool selected) onSelectionToggle;

  /// Select all non-directory items.
  final VoidCallback onSelectAll;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  bool _isFiltering = false;
  bool _showTreeNavigator = false;
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();
  String? _contextSelectedPath;
  double _lastContentWidth = 0;
  FileSortOrder _sortOrder = FileSortOrder.nameAscending;
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _filterController.dispose();
    _filterFocusNode.dispose();
    _contentScrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (widget.hasMore &&
        !widget.isLoadingMore &&
        _contentScrollController.position.extentAfter < 480) {
      widget.onLoadMore?.call();
    }
  }

  @override
  void didUpdateWidget(FileBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) {
      _filterController.clear();
      _contextSelectedPath = null;
    }
  }

  // ── Search ────────────────────────────────────────────────────────

  void _applyFilter(String _) {
    setState(() {});
  }

  void _toggleFilter() {
    setState(() {
      _isFiltering = !_isFiltering;
      if (!_isFiltering) _filterController.clear();
    });
    if (_isFiltering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filterFocusNode.requestFocus();
      });
    }
  }

  void _clearFilter({required bool close}) {
    if (!_isFiltering && _filterController.text.isEmpty) return;
    setState(() {
      _filterController.clear();
      if (close) _isFiltering = false;
    });
  }

  void _navigateTo(String path) {
    _clearFilter(close: false);
    setState(() => _contextSelectedPath = null);
    widget.onNavigateToDirectory(path);
  }

  void _navigateUp() {
    _clearFilter(close: false);
    setState(() => _contextSelectedPath = null);
    widget.onNavigateUp();
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastContentWidth = constraints.maxWidth;
        return Column(
          children: [
            if (widget.currentPath != null) _buildBreadcrumb(),
            if (_isFiltering) _buildFilterBar(),
            _buildToolbar(),
            Expanded(child: _buildFileList()),
          ],
        );
      },
    );
  }

  // ── Breadcrumb ────────────────────────────────────────────────────

  Widget _buildBreadcrumb() {
    final breadcrumbs = <Widget>[];
    final rootPath = normalizeLogicalPath(widget.rootPath);
    final currentPath = normalizeLogicalPath(widget.currentPath!);
    final rootName = logicalPathBasename(rootPath);

    breadcrumbs.add(_breadcrumbChip(
      label: rootName,
      isRoot: true,
      onTap: () => _navigateTo(rootPath),
    ));

    String accumulatedPath = rootPath;
    final relativePath =
        currentPath == rootPath ? '' : currentPath.substring(rootPath.length);

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
          onTap: () => _navigateTo(accumulatedPath),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        key: const Key('current-directory-filter'),
        controller: _filterController,
        focusNode: _filterFocusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '筛选当前目录的文件和文件夹…',
          prefixIcon: const Icon(Icons.filter_alt_outlined),
          suffixIcon: _filterController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _filterController.clear();
                    setState(() {});
                    _filterFocusNode.requestFocus();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: _applyFilter,
        onSubmitted: (_) {
          _applyFilter(_filterController.text);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _filterFocusNode.requestFocus();
          });
        },
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────

  Widget _buildToolbar() {
    final canNavigateUp = widget.currentPath != null &&
        normalizeLogicalPath(widget.currentPath!) !=
            normalizeLogicalPath(widget.rootPath);
    final treePaneVisible = _showTreeNavigator && _lastContentWidth >= 760;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final buttonConstraints = compact
            ? const BoxConstraints.tightFor(width: 40, height: 40)
            : null;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: canNavigateUp ? _navigateUp : null,
                tooltip: '返回上级目录',
                constraints: buttonConstraints,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.items.where((i) => i.isDirectory).length} 个文件夹，'
                    '${widget.items.where((i) => !i.isDirectory).length} 个文件',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ] else
                const Spacer(),
              PopupMenuButton<FileSortOrder>(
                key: const Key('file-sort-menu'),
                initialValue: _sortOrder,
                tooltip: '排序：${fileSortOrderLabel(_sortOrder)}',
                icon: const Icon(Icons.sort),
                constraints: buttonConstraints,
                onSelected: (order) => setState(() => _sortOrder = order),
                itemBuilder: (context) => FileSortOrder.values
                    .map((order) => PopupMenuItem(
                          value: order,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: order == _sortOrder
                                    ? const Icon(Icons.check, size: 18)
                                    : null,
                              ),
                              Text(fileSortOrderLabel(order)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              IconButton(
                icon: Icon(
                    _isFiltering ? Icons.filter_alt_off : Icons.filter_alt),
                onPressed: _toggleFilter,
                tooltip: _isFiltering ? '关闭当前目录筛选' : '筛选当前目录',
                constraints: buttonConstraints,
              ),
              IconButton(
                icon: Icon(
                  treePaneVisible
                      ? Icons.account_tree
                      : Icons.account_tree_outlined,
                ),
                onPressed: _toggleTreeNavigator,
                tooltip: treePaneVisible ? '隐藏目录导航' : '显示目录导航',
                constraints: buttonConstraints,
              ),
              if (!compact) const SizedBox(width: 8),
              SegmentedButton<ViewMode>(
                key: const Key('content-view-mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ViewMode.list,
                    icon: Tooltip(
                      message: '列表视图',
                      child: Icon(Icons.view_list),
                    ),
                  ),
                  ButtonSegment(
                    value: ViewMode.grid,
                    icon: Tooltip(
                      message: '网格视图',
                      child: Icon(Icons.grid_view),
                    ),
                  ),
                ],
                selected: {widget.viewMode},
                style: compact
                    ? const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        minimumSize: WidgetStatePropertyAll(Size(36, 36)),
                        padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
                      )
                    : null,
                onSelectionChanged: (selection) {
                  widget.onViewModeChanged(selection.single);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── File list / grid ──────────────────────────────────────────────

  Widget _buildFileList() {
    final query = _filterController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? widget.items
        : widget.items
            .where((item) => item.name.toLowerCase().contains(query))
            .toList();
    final items = sortFileSystemNodes(filteredItems, _sortOrder);

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastContentWidth = constraints.maxWidth;
        final content = _buildContentView(items, query);
        if (!_showTreeNavigator || constraints.maxWidth < 760) return content;
        return Row(
          children: [
            SizedBox(
              key: const Key('directory-tree-pane'),
              width: 240,
              child: _buildTreeNavigator(),
            ),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _buildContentView(List<FileSystemNode> items, String query) {
    if (query.isNotEmpty && items.isEmpty) {
      return _withBackgroundActions(Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('当前目录没有匹配“${_filterController.text}”的条目'),
          ],
        ),
      ));
    }

    if (items.isEmpty) {
      return _withBackgroundActions(
        const Center(child: Text('当前目录为空')),
      );
    }

    if (widget.viewMode == ViewMode.grid) {
      return _buildGridView(items);
    }
    return _buildListView(items);
  }

  Widget _buildTreeNavigator() {
    return DirectoryTreeWidget(
      rootPath: widget.rootPath,
      currentPath: widget.currentPath,
      fileService: widget.fileService,
      onPathSelected: _navigateTo,
    );
  }

  void _toggleTreeNavigator() {
    if (_lastContentWidth >= 760) {
      setState(() => _showTreeNavigator = !_showTreeNavigator);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: DirectoryTreeWidget(
            rootPath: widget.rootPath,
            currentPath: widget.currentPath,
            fileService: widget.fileService,
            onPathSelected: (path) {
              Navigator.pop(sheetContext);
              _navigateTo(path);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<FileSystemNode> items) {
    return CustomScrollView(
      controller: _contentScrollController,
      slivers: [
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = widget.selectedFiles.contains(item) ||
                _contextSelectedPath == item.path;
            return _FileListTile(
              item: item,
              isSelectMode: widget.isSelectMode,
              isSelected: isSelected,
              onTap: () => _handleItemTap(item, isSelected),
              onLongPress: () => _handleItemLongPress(item, isSelected),
              onSecondaryTapDown: (position) =>
                  _handleItemSecondaryTap(item, position),
              onToggleSelection: (selected) =>
                  widget.onSelectionToggle(item, selected),
            );
          },
        ),
        if (widget.hasMore || widget.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: widget.isLoadingMore
                    ? const CircularProgressIndicator()
                    : const Text('继续滚动以加载更多条目'),
              ),
            ),
          ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _withBackgroundActions(const SizedBox.expand()),
        ),
      ],
    );
  }

  Widget _buildGridView(List<FileSystemNode> items) {
    return CustomScrollView(
      controller: _contentScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = widget.selectedFiles.contains(item) ||
                  _contextSelectedPath == item.path;
              return _FileGridCard(
                item: item,
                isSelected: isSelected,
                onTap: () => _handleItemTap(item, isSelected),
                onLongPress: () => _handleItemLongPress(item, isSelected),
                onSecondaryTapDown: (position) =>
                    _handleItemSecondaryTap(item, position),
              );
            },
          ),
        ),
        if (widget.hasMore || widget.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: widget.isLoadingMore
                    ? const CircularProgressIndicator()
                    : const Text('继续滚动以加载更多条目'),
              ),
            ),
          ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _withBackgroundActions(const SizedBox.expand()),
        ),
      ],
    );
  }

  Widget _withBackgroundActions(Widget child) {
    return GestureDetector(
      key: const Key('directory-browser-background'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _contextSelectedPath = null),
      onSecondaryTapUp: (details) {
        setState(() => _contextSelectedPath = null);
        widget.onBackgroundSecondaryTap(details.globalPosition);
      },
      child: child,
    );
  }

  void _handleItemSecondaryTap(FileSystemNode item, Offset position) {
    setState(() => _contextSelectedPath = item.path);
    widget.onItemSecondaryTap(item, position);
  }

  void _handleItemTap(FileSystemNode item, bool isSelected) {
    if (widget.isSelectMode && !item.isDirectory) {
      widget.onSelectionToggle(item, !isSelected);
    } else {
      if (item.isDirectory) _clearFilter(close: false);
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
    required this.onSecondaryTapDown,
    required this.onToggleSelection,
  });

  final FileSystemNode item;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onSecondaryTapDown;
  final void Function(bool selected) onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          onSecondaryTapDown(details.globalPosition),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? colors.primary : Colors.transparent,
              width: 4,
            ),
            bottom: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Material(
          key: ValueKey('file-list-material-${item.path}'),
          color: isSelected ? colors.primaryContainer : Colors.transparent,
          child: ListTile(
            key: ValueKey('file-list-${item.path}'),
            leading: isSelectMode && !item.isDirectory
                ? Checkbox(
                    value: isSelected,
                    onChanged: (v) => onToggleSelection(v ?? false),
                  )
                : Icon(
                    item.isDirectory
                        ? Icons.folder
                        : _getFileIcon(item.extension),
                    color: item.isDirectory ? Colors.orange : null,
                  ),
            title: Text(item.name),
            subtitle: Text(item.isDirectory
                ? '${item.children?.length ?? 0} 个项目'
                : item.formattedSize),
            trailing: item.isDirectory ? const Icon(Icons.chevron_right) : null,
            selected: isSelected,
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
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
    required this.onSecondaryTapDown,
  });

  final FileSystemNode item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) =>
          onSecondaryTapDown(details.globalPosition),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Card(
          key: ValueKey('file-grid-${item.path}'),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2.5 : 1,
            ),
          ),
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
