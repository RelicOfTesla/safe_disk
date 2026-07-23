import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
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
    this.openOnDoubleClick = false,
    required this.isSelectMode,
    required this.selectedFiles,
    required this.fileService,
    required this.onNavigateToDirectory,
    required this.onNavigateUp,
    required this.onOpenItem,
    this.onItemFocused,
    required this.onItemLongPress,
    required this.onItemSecondaryTap,
    required this.onBackgroundSecondaryTap,
    required this.onViewModeChanged,
    required this.onToggleSelectMode,
    required this.onSelectionToggle,
    this.onSelectionChanged,
    this.onGridColumnCountChanged,
    this.focusedPath,
    required this.onSelectAll,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onLoadMore,
    this.onRetryLoadMore,
  });

  final List<FileSystemNode> items;
  final String? currentPath;
  final String rootPath;
  final ViewMode viewMode;
  final bool openOnDoubleClick;
  final bool isSelectMode;
  final Set<FileSystemNode> selectedFiles;
  final FileService fileService;

  /// Navigate into a subdirectory.
  final void Function(String path) onNavigateToDirectory;

  /// Navigate up to parent directory.
  final VoidCallback onNavigateUp;

  /// Open a file (notepad, image viewer, etc.) or navigate into a directory.
  final void Function(FileSystemNode item) onOpenItem;

  /// Notify the parent about the primary-click keyboard focus target.
  final ValueChanged<FileSystemNode>? onItemFocused;

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

  /// Replace the current selection after a range or drag operation.
  final ValueChanged<Set<FileSystemNode>>? onSelectionChanged;
  final ValueChanged<int>? onGridColumnCountChanged;

  /// Path currently targeted by keyboard navigation in the parent page.
  final String? focusedPath;

  /// Select all non-directory items.
  final VoidCallback onSelectAll;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  bool _isFiltering = false;
  bool _showTreeNavigator = false;
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();
  String? _contextSelectedPath;
  String? _selectionAnchorPath;
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _selectionSurfaceKey = GlobalKey();
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDraggingSelection = false;
  double _lastContentWidth = 0;
  FileSortOrder _sortOrder = FileSortOrder.nameAscending;
  final ScrollController _contentScrollController = ScrollController();
  int? _reportedGridColumnCount;

  bool get _directoryIsIncomplete => widget.hasMore || widget.isLoadingMore;

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
      _selectionAnchorPath = null;
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
    final strings = AppLocalizations.of(context)!;
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
          hintText: strings.filterCurrentDirectoryHint,
          helperText:
              _directoryIsIncomplete ? strings.filterLoadedItemsHint : null,
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
    final strings = AppLocalizations.of(context)!;
    final canNavigateUp = widget.currentPath != null &&
        normalizeLogicalPath(widget.currentPath!) !=
            normalizeLogicalPath(widget.rootPath);
    final treePaneVisible = _showTreeNavigator && _lastContentWidth >= 760;
    final directoryIsIncomplete = _directoryIsIncomplete;

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
                tooltip: strings.navigateUp,
                constraints: buttonConstraints,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    directoryIsIncomplete
                        ? strings.directoryIncompleteSummary(
                            widget.items.length,
                            widget.items.where((i) => i.isDirectory).length,
                            widget.items.where((i) => !i.isDirectory).length,
                          )
                        : strings.directorySummary(
                            widget.items.where((i) => i.isDirectory).length,
                            widget.items.where((i) => !i.isDirectory).length,
                          ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ] else
                const Spacer(),
              PopupMenuButton<FileSortOrder>(
                key: const Key('file-sort-menu'),
                initialValue: _sortOrder,
                tooltip: directoryIsIncomplete
                    ? strings.sortUnavailableUntilFullyLoaded
                    : strings.sortTooltip(_sortOrderLabel(strings, _sortOrder)),
                icon: const Icon(Icons.sort),
                constraints: buttonConstraints,
                onSelected: directoryIsIncomplete
                    ? null
                    : (order) => setState(() => _sortOrder = order),
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
                              Flexible(
                                child: Text(
                                  _sortOrderLabel(strings, order),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              IconButton(
                icon: Icon(
                    _isFiltering ? Icons.filter_alt_off : Icons.filter_alt),
                onPressed: _toggleFilter,
                tooltip: _isFiltering
                    ? strings.closeCurrentDirectoryFilter
                    : strings.filterCurrentDirectory,
                constraints: buttonConstraints,
              ),
              IconButton(
                icon: Icon(
                  treePaneVisible
                      ? Icons.account_tree
                      : Icons.account_tree_outlined,
                ),
                onPressed: _toggleTreeNavigator,
                tooltip: treePaneVisible
                    ? strings.hideDirectoryNavigator
                    : strings.showDirectoryNavigator,
                constraints: buttonConstraints,
              ),
              if (!compact) const SizedBox(width: 8),
              SegmentedButton<ViewMode>(
                key: const Key('content-view-mode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ViewMode.list,
                    icon: Tooltip(
                      message: strings.listView,
                      child: const Icon(Icons.view_list),
                    ),
                  ),
                  ButtonSegment(
                    value: ViewMode.grid,
                    icon: Tooltip(
                      message: strings.gridView,
                      child: const Icon(Icons.grid_view),
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
    // Sorting a partial cursor result would present a local ordering as if it
    // covered the entire directory. Preserve the walker order until EOF.
    final items = _directoryIsIncomplete
        ? filteredItems
        : sortFileSystemNodes(filteredItems, _sortOrder);

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
    final strings = AppLocalizations.of(context)!;
    if (widget.loadMoreError != null && items.isEmpty) {
      return _withBackgroundActions(
        Center(
          child: TextButton.icon(
            onPressed: widget.onRetryLoadMore,
            icon: const Icon(Icons.refresh),
            label: Text(strings.directoryReadFailedRetry),
          ),
        ),
      );
    }

    if (query.isNotEmpty && items.isEmpty) {
      return _withBackgroundActions(Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _directoryIsIncomplete
                  ? strings.noMatchInLoadedEntries(_filterController.text)
                  : strings.noMatchInCurrentDirectory(_filterController.text),
            ),
            if (_directoryIsIncomplete) ...[
              const SizedBox(height: 8),
              Text(strings.unloadedEntriesMayMatch),
              const SizedBox(height: 12),
              _buildFilteredLoadMoreAction(),
            ],
          ],
        ),
      ));
    }

    if (items.isEmpty) {
      return _withBackgroundActions(
        Center(child: Text(strings.currentDirectoryEmpty)),
      );
    }

    if (widget.viewMode == ViewMode.grid) {
      return _buildGridView(items);
    }
    return _buildListView(items);
  }

  Widget _buildFilteredLoadMoreAction() {
    final strings = AppLocalizations.of(context)!;
    if (widget.isLoadingMore) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return FilledButton.icon(
      onPressed: widget.onLoadMore,
      icon: const Icon(Icons.expand_more),
      label: Text(strings.loadMoreEntries),
    );
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
    return _withSelectionPointerHandlers(
      items,
      CustomScrollView(
        controller: _contentScrollController,
        slivers: [
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = widget.selectedFiles.contains(item);
              final isHighlighted =
                  isSelected || _contextSelectedPath == item.path;
              return _FileListTile(
                key: _itemKey(item),
                item: item,
                isSelectMode: widget.isSelectMode,
                isSelected: isSelected,
                isContextHighlighted: isHighlighted,
                isFocused: widget.focusedPath == item.path,
                onTap: () => _handleItemTap(item, isSelected, items),
                onDoubleTap: widget.openOnDoubleClick && !widget.isSelectMode
                    ? () => _handleItemDoubleTap(item)
                    : null,
                onLongPress: () => _handleItemLongPress(item, isSelected),
                onSecondaryTapDown: (position) =>
                    _handleItemSecondaryTap(item, position),
                onToggleSelection: (selected) =>
                    widget.onSelectionToggle(item, selected),
              );
            },
          ),
          _buildLoadMoreStatus(),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _withBackgroundActions(const SizedBox.expand()),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<FileSystemNode> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _reportGridColumnCount(constraints.maxWidth);
        return _withSelectionPointerHandlers(
          items,
          CustomScrollView(
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
                    final isSelected = widget.selectedFiles.contains(item);
                    final isHighlighted =
                        isSelected || _contextSelectedPath == item.path;
                    return _FileGridCard(
                      key: _itemKey(item),
                      item: item,
                      isSelectMode: widget.isSelectMode,
                      isSelected: isSelected,
                      isContextHighlighted: isHighlighted,
                      isFocused: widget.focusedPath == item.path,
                      onTap: () => _handleItemTap(item, isSelected, items),
                      onDoubleTap:
                          widget.openOnDoubleClick && !widget.isSelectMode
                              ? () => _handleItemDoubleTap(item)
                              : null,
                      onLongPress: () => _handleItemLongPress(item, isSelected),
                      onSecondaryTapDown: (position) =>
                          _handleItemSecondaryTap(item, position),
                      onToggleSelection: (selected) =>
                          widget.onSelectionToggle(item, selected),
                    );
                  },
                ),
              ),
              _buildLoadMoreStatus(),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _withBackgroundActions(const SizedBox.expand()),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reportGridColumnCount(double width) {
    if (!width.isFinite || width <= 0) return;
    final usableWidth = width - 16;
    final columns = ((usableWidth + 8) / (150 + 8)).floor().clamp(1, 100);
    if (_reportedGridColumnCount == columns) return;
    _reportedGridColumnCount = columns;
    final callback = widget.onGridColumnCountChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback(columns);
    });
  }

  Widget _buildLoadMoreStatus() {
    final strings = AppLocalizations.of(context)!;
    if (widget.loadMoreError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: TextButton.icon(
              onPressed: widget.onRetryLoadMore,
              icon: const Icon(Icons.refresh),
              label: Text(strings.loadMoreFailedRetry),
            ),
          ),
        ),
      );
    }
    if (widget.hasMore || widget.isLoadingMore) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: widget.isLoadingMore
                ? const CircularProgressIndicator()
                : Text(strings.scrollToLoadMore),
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  GlobalKey _itemKey(FileSystemNode item) {
    return _itemKeys.putIfAbsent(item.path, GlobalKey.new);
  }

  Widget _withSelectionPointerHandlers(
    List<FileSystemNode> items,
    Widget child,
  ) {
    final marqueeRect = _selectionMarqueeRect();
    final colors = Theme.of(context).colorScheme;
    return Stack(
      key: _selectionSurfaceKey,
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse &&
                event.buttons & kPrimaryMouseButton != 0) {
              _dragStart = event.position;
              _dragCurrent = event.position;
              _isDraggingSelection = false;
            }
          },
          onPointerMove: (event) {
            final start = _dragStart;
            if (start == null || event.kind != PointerDeviceKind.mouse) return;
            if (!_isDraggingSelection &&
                (event.position - start).distance > kTouchSlop) {
              _isDraggingSelection = true;
              _dragCurrent = event.position;
            }
            if (_isDraggingSelection) {
              setState(() => _dragCurrent = event.position);
            }
          },
          onPointerUp: (event) {
            final start = _dragStart;
            final end = _dragCurrent;
            final dragging = _isDraggingSelection;
            _dragStart = null;
            _dragCurrent = null;
            _isDraggingSelection = false;
            if (dragging && start != null && end != null) {
              _selectItemsInRect(items, Rect.fromPoints(start, end));
            }
          },
          onPointerCancel: (_) {
            _dragStart = null;
            _dragCurrent = null;
            _isDraggingSelection = false;
          },
          child: child,
        ),
        if (marqueeRect != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const Key('file-selection-marquee'),
                painter: _SelectionMarqueePainter(
                  marqueeRect,
                  colors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Rect? _selectionMarqueeRect() {
    if (!_isDraggingSelection || _dragStart == null || _dragCurrent == null) {
      return null;
    }
    final renderObject =
        _selectionSurfaceKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return Rect.fromPoints(
      renderObject.globalToLocal(_dragStart!),
      renderObject.globalToLocal(_dragCurrent!),
    );
  }

  void _selectItemsInRect(
    List<FileSystemNode> items,
    Rect selectionRect,
  ) {
    final selected = <FileSystemNode>{};
    for (final item in items) {
      final renderObject =
          _itemKeys[item.path]?.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;
      final itemTopLeft = renderObject.localToGlobal(Offset.zero);
      final itemRect = itemTopLeft & renderObject.size;
      if (selectionRect.overlaps(itemRect)) selected.add(item);
    }
    _selectionAnchorPath = selected.isEmpty ? null : selected.last.path;
    _replaceSelection(selected);
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

  void _handleItemTap(
    FileSystemNode item,
    bool isSelected,
    List<FileSystemNode> visibleItems,
  ) {
    if (!widget.openOnDoubleClick) widget.onItemFocused?.call(item);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final hasControl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final hasShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    if (widget.isSelectMode || hasControl || hasShift) {
      final selectable = visibleItems;
      final next = Set<FileSystemNode>.from(widget.selectedFiles);
      if (hasShift) {
        final ordered = selectable.toList();
        final anchorIndex = ordered.indexWhere(
          (entry) => entry.path == _selectionAnchorPath,
        );
        final targetIndex = ordered.indexOf(item);
        if (targetIndex >= 0) {
          final start = anchorIndex < 0
              ? targetIndex
              : (anchorIndex < targetIndex ? anchorIndex : targetIndex);
          final end = anchorIndex < 0
              ? targetIndex
              : (anchorIndex < targetIndex ? targetIndex : anchorIndex);
          if (!hasControl) next.clear();
          next.addAll(ordered.sublist(start, end + 1));
        }
      } else if (hasControl) {
        if (isSelected) {
          next.remove(item);
        } else {
          next.add(item);
        }
      } else if (isSelected) {
        next.remove(item);
      } else {
        next.add(item);
      }
      _selectionAnchorPath = item.path;
      _replaceSelection(next);
    } else if (widget.openOnDoubleClick) {
      // Do not rebuild after the first click; rebuilding would reset the
      // double-tap recognizer before it can receive the second click.
      _contextSelectedPath = item.path;
    } else {
      if (item.isDirectory) _clearFilter(close: false);
      widget.onOpenItem(item);
    }
  }

  void _replaceSelection(Set<FileSystemNode> selected) {
    if (selected.isNotEmpty && !widget.isSelectMode) {
      widget.onToggleSelectMode(true);
    }
    if (widget.onSelectionChanged != null) {
      widget.onSelectionChanged!(selected);
      return;
    }
    final current = widget.selectedFiles;
    for (final item in current.difference(selected)) {
      widget.onSelectionToggle(item, false);
    }
    for (final item in selected.difference(current)) {
      widget.onSelectionToggle(item, true);
    }
  }

  void _handleItemDoubleTap(FileSystemNode item) {
    if (widget.isSelectMode) return;
    if (item.isDirectory) _clearFilter(close: false);
    widget.onOpenItem(item);
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
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.isContextHighlighted,
    required this.isFocused,
    required this.onTap,
    this.onDoubleTap,
    required this.onLongPress,
    required this.onSecondaryTapDown,
    required this.onToggleSelection,
  });

  final FileSystemNode item;
  final bool isSelectMode;
  final bool isSelected;
  final bool isContextHighlighted;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onSecondaryTapDown;
  final void Function(bool selected) onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isHighlighted = isSelected || isContextHighlighted;
    return Semantics(
      container: true,
      label: _entrySemanticsLabel(AppLocalizations.of(context)!, item),
      selected: isHighlighted,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isSelectMode ? null : onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        onSecondaryTapDown: (details) =>
            onSecondaryTapDown(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isHighlighted ? colors.primary : Colors.transparent,
                width: 4,
              ),
              right: BorderSide(
                color: isFocused ? colors.secondary : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
          ),
          child: Material(
            key: ValueKey('file-list-material-${item.path}'),
            color: isHighlighted ? colors.primaryContainer : Colors.transparent,
            child: ListTile(
              key: ValueKey('file-list-${item.path}'),
              leading: isSelectMode
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
                  ? AppLocalizations.of(context)!
                      .directoryItemCount(item.children?.length ?? 0)
                  : item.formattedSize),
              trailing:
                  item.isDirectory ? const Icon(Icons.chevron_right) : null,
              selected: isHighlighted,
              onTap: isSelectMode ? onTap : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single file/directory entry in grid view.
class _FileGridCard extends StatelessWidget {
  const _FileGridCard({
    super.key,
    required this.item,
    required this.isSelectMode,
    required this.isSelected,
    required this.isContextHighlighted,
    required this.isFocused,
    required this.onTap,
    this.onDoubleTap,
    required this.onLongPress,
    required this.onSecondaryTapDown,
    required this.onToggleSelection,
  });

  final FileSystemNode item;
  final bool isSelectMode;
  final bool isSelected;
  final bool isContextHighlighted;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onSecondaryTapDown;
  final ValueChanged<bool> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _entrySemanticsLabel(AppLocalizations.of(context)!, item),
      selected: isSelected || isContextHighlighted,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) =>
            onSecondaryTapDown(details.globalPosition),
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              Card(
                key: ValueKey('file-grid-${item.path}'),
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : isContextHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                elevation: isSelected || isContextHighlighted ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected || isContextHighlighted
                        ? Theme.of(context).colorScheme.primary
                        : isFocused
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected || isContextHighlighted || isFocused
                        ? 2.5
                        : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.isDirectory
                          ? Icons.folder
                          : _getFileIcon(item.extension),
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
              if (isSelectMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Checkbox(
                    key: ValueKey('file-grid-select-${item.path}'),
                    value: isSelected,
                    onChanged: (value) => onToggleSelection(value ?? false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionMarqueePainter extends CustomPainter {
  const _SelectionMarqueePainter(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.12);
    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _SelectionMarqueePainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.color != color;
  }
}

String _entrySemanticsLabel(AppLocalizations strings, FileSystemNode item) {
  return strings.fileSystemEntrySemantics(
    item.name,
    item.isDirectory ? strings.directory : strings.file,
  );
}

String _sortOrderLabel(AppLocalizations strings, FileSortOrder order) {
  return switch (order) {
    FileSortOrder.nameAscending => strings.sortNameAscending,
    FileSortOrder.nameDescending => strings.sortNameDescending,
    FileSortOrder.modifiedNewest => strings.sortModifiedNewest,
    FileSortOrder.modifiedOldest => strings.sortModifiedOldest,
    FileSortOrder.sizeLargest => strings.sortSizeLargest,
    FileSortOrder.sizeSmallest => strings.sortSizeSmallest,
  };
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
