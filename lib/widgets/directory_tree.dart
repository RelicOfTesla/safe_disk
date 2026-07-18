import 'dart:async';

import 'package:flutter/material.dart';

import '../services/directory_page_session.dart';
import '../services/file_service.dart';

/// Default number of secure entries read for each tree cursor request.
const int kDefaultPageSize = 100;

class DirectoryTreeWidget extends StatefulWidget {
  const DirectoryTreeWidget({
    super.key,
    required this.rootPath,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
    this.pageSize = kDefaultPageSize,
  });

  final String rootPath;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  final int pageSize;

  @override
  State<DirectoryTreeWidget> createState() => _DirectoryTreeWidgetState();
}

class _DirectoryTreeWidgetState extends State<DirectoryTreeWidget> {
  late _TreeDirectoryPager _pager;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pager = _createPager();
    unawaited(_loadNext());
  }

  @override
  void didUpdateWidget(covariant DirectoryTreeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rootPath == widget.rootPath &&
        oldWidget.fileService == widget.fileService &&
        oldWidget.pageSize == widget.pageSize) {
      return;
    }
    final previous = _pager;
    _pager = _createPager();
    unawaited(previous.dispose());
    unawaited(_loadNext());
  }

  @override
  void dispose() {
    unawaited(_pager.dispose());
    super.dispose();
  }

  _TreeDirectoryPager _createPager() => _TreeDirectoryPager(
        fileService: widget.fileService,
        path: widget.rootPath,
        pageSize: widget.pageSize,
      );

  Future<void> _loadNext({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (refresh) await _pager.reset();
      await _pager.loadNext();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _pager.directories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pager.error != null && _pager.directories.isEmpty) {
      return _TreeRetry(
        message: '无法读取目录树',
        onRetry: () => _loadNext(refresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadNext(refresh: true),
      child: ListView.builder(
        itemCount: _pager.directories.length + _tailItemCount,
        itemBuilder: (context, index) {
          if (index < _pager.directories.length) {
            final item = _pager.directories[index];
            return _DirectoryTreeItem(
              key: ValueKey(item.path),
              item: item,
              depth: 0,
              currentPath: widget.currentPath,
              fileService: widget.fileService,
              onPathSelected: widget.onPathSelected,
              pageSize: widget.pageSize,
            );
          }
          if (_pager.error != null) {
            return _TreeRetry(
              message: '继续读取失败',
              onRetry: () => _loadNext(refresh: true),
            );
          }
          return _LoadMoreButton(
            isLoading: _isLoading,
            onPressed: _loadNext,
          );
        },
      ),
    );
  }

  int get _tailItemCount => _pager.hasMore || _pager.error != null ? 1 : 0;
}

class _DirectoryTreeItem extends StatefulWidget {
  const _DirectoryTreeItem({
    super.key,
    required this.item,
    required this.depth,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
    required this.pageSize,
  });

  final FileSystemNode item;
  final int depth;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  final int pageSize;

  @override
  State<_DirectoryTreeItem> createState() => _DirectoryTreeItemState();
}

class _DirectoryTreeItemState extends State<_DirectoryTreeItem> {
  _TreeDirectoryPager? _pager;
  bool _isExpanded = false;
  bool _isLoading = false;

  @override
  void didUpdateWidget(covariant _DirectoryTreeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path == widget.item.path &&
        oldWidget.fileService == widget.fileService &&
        oldWidget.pageSize == widget.pageSize) {
      return;
    }
    final previous = _pager;
    _pager = null;
    _isExpanded = false;
    if (previous != null) unawaited(previous.dispose());
  }

  @override
  void dispose() {
    unawaited(_pager?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _toggleOrLoad() async {
    final pager = _pager;
    if (pager != null && pager.isLoaded) {
      setState(() => _isExpanded = !_isExpanded);
      return;
    }
    await _loadNext();
  }

  Future<void> _loadNext({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final pager = _pager ??= _TreeDirectoryPager(
      fileService: widget.fileService,
      path: widget.item.path,
      pageSize: widget.pageSize,
    );
    try {
      if (refresh) await pager.reset();
      await pager.loadNext();
      if (mounted) setState(() => _isExpanded = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pager = _pager;
    final isSelected = widget.currentPath == widget.item.path;
    final children = pager?.directories ?? const <FileSystemNode>[];
    final hasChildren = pager == null || children.isNotEmpty || pager.hasMore;

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
                if (hasChildren)
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                    ),
                    onPressed: _isLoading ? null : _toggleOrLoad,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                  )
                else
                  const SizedBox(width: 24),
                Icon(
                  isSelected ? Icons.folder_open : Icons.folder,
                  color: isSelected ? Colors.blue : Colors.orange,
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
        if (_isExpanded)
          for (final child in children)
            _DirectoryTreeItem(
              key: ValueKey(child.path),
              item: child,
              depth: widget.depth + 1,
              currentPath: widget.currentPath,
              fileService: widget.fileService,
              onPathSelected: widget.onPathSelected,
              pageSize: widget.pageSize,
            ),
        if (_isExpanded && pager?.error != null)
          _TreeRetry(
            depth: widget.depth + 1,
            message: '继续读取失败',
            onRetry: () => _loadNext(refresh: true),
          ),
        if (_isExpanded && pager?.hasMore == true)
          _LoadMoreButton(
            depth: widget.depth + 1,
            isLoading: _isLoading,
            onPressed: _loadNext,
          ),
      ],
    );
  }
}

class _TreeDirectoryPager {
  _TreeDirectoryPager({
    required this.fileService,
    required this.path,
    required this.pageSize,
  });

  final FileService fileService;
  final String path;
  final int pageSize;
  DirectoryPageSession? _session;
  bool _usingFallback = false;
  int _fallbackOffset = 0;
  bool done = false;
  Object? error;
  final List<FileSystemNode> directories = [];

  bool get hasMore => !done && error == null;
  bool get isLoaded => _session != null || _usingFallback;

  Future<void> reset() async {
    final previous = _session;
    _session = null;
    _usingFallback = false;
    _fallbackOffset = 0;
    done = false;
    error = null;
    directories.clear();
    await previous?.dispose();
  }

  Future<void> dispose() async {
    final previous = _session;
    _session = null;
    await previous?.dispose();
  }

  Future<void> loadNext() async {
    if (done || error != null) return;
    final session = _session ??= fileService.openCurrentDirectorySession(
      path,
      retainEntries: false,
    );
    if (session == null) {
      _usingFallback = true;
      await _loadFallbackPage();
      return;
    }

    try {
      var previousDirectoryCount = directories.length;
      do {
        await session.loadNext(limit: pageSize);
        directories.addAll(
          fileService
              .nodesForDirectoryPage(session, session.latestPageEntries)
              .where((item) => item.isDirectory),
        );
        if (session.done) done = true;
        if (directories.length != previousDirectoryCount || done) break;
        previousDirectoryCount = directories.length;
      } while (true);
    } catch (caught) {
      error = caught;
    }
  }

  Future<void> _loadFallbackPage() async {
    try {
      var previousDirectoryCount = directories.length;
      do {
        final page = await fileService.listCurrentDirectory(
          path,
          offset: _fallbackOffset,
          limit: pageSize,
        );
        _fallbackOffset += page.length;
        directories.addAll(page.where((item) => item.isDirectory));
        done = page.length < pageSize;
        if (directories.length != previousDirectoryCount || done) break;
        previousDirectoryCount = directories.length;
      } while (true);
    } catch (caught) {
      error = caught;
    }
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    this.depth = 0,
    required this.isLoading,
    required this.onPressed,
  });

  final int depth;
  final bool isLoading;
  final VoidCallback onPressed;

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
              isLoading ? '正在读取…' : '读取更多目录',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeRetry extends StatelessWidget {
  const _TreeRetry({
    required this.message,
    required this.onRetry,
    this.depth = 0,
  });

  final String message;
  final VoidCallback onRetry;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0 + 24.0),
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text('$message，刷新重试'),
      ),
    );
  }
}
