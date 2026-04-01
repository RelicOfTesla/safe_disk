import 'package:flutter/material.dart';
import '../services/file_service.dart';

class DirectoryTreeWidget extends StatefulWidget {
  final String rootPath;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  
  const DirectoryTreeWidget({
    super.key,
    required this.rootPath,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
  });
  
  @override
  State<DirectoryTreeWidget> createState() => _DirectoryTreeWidgetState();
}

class _DirectoryTreeWidgetState extends State<DirectoryTreeWidget> {
  List<FileSystemNode> _rootItems = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadRootItems();
  }
  
  Future<void> _loadRootItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await widget.fileService.listCurrentDirectory(widget.rootPath);
      setState(() => _rootItems = items);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return ListView.builder(
      itemCount: _rootItems.length,
      itemBuilder: (context, index) {
        final item = _rootItems[index];
        return _DirectoryTreeItem(
          item: item,
          depth: 0,
          currentPath: widget.currentPath,
          fileService: widget.fileService,
          onPathSelected: widget.onPathSelected,
        );
      },
    );
  }
}

class _DirectoryTreeItem extends StatefulWidget {
  final FileSystemNode item;
  final int depth;
  final String? currentPath;
  final FileService fileService;
  final void Function(String path) onPathSelected;
  
  const _DirectoryTreeItem({
    required this.item,
    required this.depth,
    this.currentPath,
    required this.fileService,
    required this.onPathSelected,
  });
  
  @override
  State<_DirectoryTreeItem> createState() => _DirectoryTreeItemState();
}

class _DirectoryTreeItemState extends State<_DirectoryTreeItem> {
  List<FileSystemNode> _children = [];
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _hasLoadedChildren = false;
  
  Future<void> _loadChildren() async {
    if (_hasLoadedChildren) {
      setState(() => _isExpanded = !_isExpanded);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final items = await widget.fileService.listCurrentDirectory(widget.item.path);
      setState(() {
        _children = items;
        _isExpanded = true;
        _hasLoadedChildren = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isSelected = widget.currentPath == widget.item.path;
    final isDirectory = widget.item.isDirectory;
    final hasChildren = isDirectory && (_hasLoadedChildren ? _children.isNotEmpty : true);
    
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
                    onPressed: _isLoading ? null : _loadChildren,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          ))),
      ],
    );
  }
}
