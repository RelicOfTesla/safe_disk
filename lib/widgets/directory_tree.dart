import 'package:flutter/material.dart';
import '../services/file_service.dart';

/// Default page size for directory listing
const int kDefaultPageSize = 100;

class DirectoryTreeWidget extends StatefulWidget {
  final String rootPath;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  final int pageSize;

  const DirectoryTreeWidget({
    super.key,
    required this.rootPath,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
    this.pageSize = kDefaultPageSize,
  });

  @override
  State<DirectoryTreeWidget> createState() => _DirectoryTreeWidgetState();
}

class _DirectoryTreeWidgetState extends State<DirectoryTreeWidget> {
  List<FileSystemNode> _rootItems = [];
  bool _isLoading = false;
  bool _hasMore = false;
  int _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadRootItems();
  }

  Future<void> _loadRootItems({bool loadMore = false}) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final offset = loadMore ? _currentOffset + widget.pageSize : 0;
      final items = await widget.fileService.listCurrentDirectory(
        widget.rootPath,
        offset: offset,
        limit: widget.pageSize,
      );

      // Check if there are more items to load
      // We can't know for sure without counting, so we check if we got a full page
      final hasMore = items.length >= widget.pageSize;

      setState(() {
        if (loadMore) {
          _rootItems.addAll(items);
          _currentOffset = offset;
        } else {
          _rootItems = items;
          _currentOffset = 0;
        }
        _hasMore = hasMore;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadRootItems(loadMore: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _rootItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: _rootItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _rootItems.length) {
            final item = _rootItems[index];
            return _DirectoryTreeItem(
              item: item,
              depth: 0,
              currentPath: widget.currentPath,
              fileService: widget.fileService,
              onPathSelected: widget.onPathSelected,
              pageSize: widget.pageSize,
            );
          } else {
            // "Load more" button
            return _LoadMoreButton(
              isLoading: _isLoading,
              onPressed: () => _loadRootItems(loadMore: true),
            );
          }
        },
      ),
    );
  }
}

class _DirectoryTreeItem extends StatefulWidget {
  final FileSystemNode item;
  final int depth;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  final int pageSize;

  const _DirectoryTreeItem({
    required this.item,
    required this.depth,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
    this.pageSize = kDefaultPageSize,
  });

  @override
  State<_DirectoryTreeItem> createState() => _DirectoryTreeItemState();
}

class _DirectoryTreeItemState extends State<_DirectoryTreeItem> {
  List<FileSystemNode> _children = [];
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _hasLoadedChildren = false;
  bool _hasMore = false;
  int _currentOffset = 0;

  Future<void> _loadChildren({bool loadMore = false}) async {
    if (!widget.item.isDirectory) return;

    if (_isLoading) return;

    if (_hasLoadedChildren && !loadMore) {
      setState(() => _isExpanded = !_isExpanded);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final offset = loadMore ? _currentOffset + widget.pageSize : 0;
      final items = await widget.fileService.listCurrentDirectory(
        widget.item.path,
        offset: offset,
        limit: widget.pageSize,
      );

      // Check if there are more items to load
      final hasMore = items.length >= widget.pageSize;

      setState(() {
        if (loadMore) {
          _children.addAll(items);
          _currentOffset = offset;
        } else {
          _children = items;
          _currentOffset = 0;
          _isExpanded = true;
          _hasLoadedChildren = true;
        }
        _hasMore = hasMore;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.currentPath == widget.item.path;
    final isDirectory = widget.item.isDirectory;
    final hasChildren =
        isDirectory && (_hasLoadedChildren ? _children.isNotEmpty : true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onPathSelected(widget.item.path),
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.depth * 16.0 + 8.0,
              right: 8.0,
              top: 4.0,
              bottom: 4.0,
            ),
            child: Row(
              children: [
                if (isDirectory && hasChildren)
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _loadChildren(loadMore: false),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  )
                else
                  const SizedBox(width: 24),
                Icon(
                  isDirectory
                      ? (isSelected ? Icons.folder_open : Icons.folder)
                      : Icons.insert_drive_file,
                  color: isDirectory
                      ? (isSelected ? Colors.blue : Colors.orange)
                      : null,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        if (_isExpanded && _children.isNotEmpty)
          ...(_children.map((child) => _DirectoryTreeItem(
                item: child,
                depth: widget.depth + 1,
                currentPath: widget.currentPath,
                fileService: widget.fileService,
                onPathSelected: widget.onPathSelected,
                pageSize: widget.pageSize,
              ))),
        if (_isExpanded && _hasMore)
          _LoadMoreButton(
            depth: widget.depth + 1,
            isLoading: _isLoading,
            onPressed: () => _loadChildren(loadMore: true),
          ),
      ],
    );
  }
}

/// "Load more" button widget
class _LoadMoreButton extends StatelessWidget {
  final int depth;
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoadMoreButton({
    this.depth = 0,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onPressed,
      child: Padding(
        padding: EdgeInsets.only(
          left: depth * 16.0 + 32.0,
          right: 8.0,
          top: 8.0,
          bottom: 8.0,
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: Colors.grey,
              ),
            const SizedBox(width: 8),
            Text(
              isLoading ? 'Loading...' : 'Load more',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
