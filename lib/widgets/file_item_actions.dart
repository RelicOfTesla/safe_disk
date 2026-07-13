import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/secure_image_policy.dart';
import '../services/file_service.dart';

enum FileItemAction {
  open,
  edit,
  openInNewWindow,
  select,
  rename,
  copy,
  cut,
  pasteInto,
  export,
  copyName,
  copyPath,
  properties,
  refresh,
  delete,
}

List<FileItemAction> fileItemActionsFor(
  FileSystemNode item, {
  bool canPasteInto = false,
}) {
  if (item.isDirectory) {
    return [
      FileItemAction.open,
      FileItemAction.rename,
      FileItemAction.copy,
      FileItemAction.cut,
      if (canPasteInto) FileItemAction.pasteInto,
      FileItemAction.export,
      FileItemAction.copyName,
      FileItemAction.copyPath,
      FileItemAction.properties,
      FileItemAction.refresh,
    ];
  }

  return [
    if (isViewableImageFile(item)) FileItemAction.open,
    if (isViewableImageFile(item)) FileItemAction.openInNewWindow,
    if (isEditableTextFile(item)) FileItemAction.edit,
    if (isEditableTextFile(item)) FileItemAction.openInNewWindow,
    FileItemAction.select,
    FileItemAction.rename,
    FileItemAction.copy,
    FileItemAction.cut,
    FileItemAction.export,
    FileItemAction.copyName,
    FileItemAction.copyPath,
    FileItemAction.properties,
    FileItemAction.refresh,
    FileItemAction.delete,
  ];
}

bool isViewableImageFile(FileSystemNode item) {
  if (item.isDirectory) return false;
  return isSupportedImageFormat(item.extension);
}

bool isEditableTextFile(FileSystemNode item) {
  return !item.isDirectory && !isViewableImageFile(item);
}

String fileItemActionLabel(FileItemAction action, FileSystemNode item) {
  return switch (action) {
    FileItemAction.open => item.isDirectory ? '打开目录' : '查看图片',
    FileItemAction.edit => '使用安全记事本编辑',
    FileItemAction.openInNewWindow =>
      isViewableImageFile(item) ? '在新窗口中查看' : '在新窗口中编辑',
    FileItemAction.select => '选择',
    FileItemAction.rename => '重命名',
    FileItemAction.copy => '复制',
    FileItemAction.cut => '剪切',
    FileItemAction.pasteInto => '粘贴到此目录',
    FileItemAction.export => item.isDirectory ? '导出目录' : '导出解密文件',
    FileItemAction.copyName => '复制名称（明文）',
    FileItemAction.copyPath => '复制逻辑路径（明文）',
    FileItemAction.properties => '属性',
    FileItemAction.refresh => '刷新',
    FileItemAction.delete => '删除文件',
  };
}

IconData _fileItemActionIcon(FileItemAction action) {
  return switch (action) {
    FileItemAction.open => Icons.open_in_new,
    FileItemAction.edit => Icons.edit_note,
    FileItemAction.openInNewWindow => Icons.open_in_new,
    FileItemAction.select => Icons.check_circle_outline,
    FileItemAction.rename => Icons.drive_file_rename_outline,
    FileItemAction.copy => Icons.copy_outlined,
    FileItemAction.cut => Icons.content_cut,
    FileItemAction.pasteInto => Icons.content_paste_go_outlined,
    FileItemAction.export => Icons.download,
    FileItemAction.copyName => Icons.content_copy,
    FileItemAction.copyPath => Icons.link,
    FileItemAction.properties => Icons.info_outline,
    FileItemAction.refresh => Icons.refresh,
    FileItemAction.delete => Icons.delete_outline,
  };
}

String? validateFileItemName(String value) {
  if (value.isEmpty) return '名称不能为空';
  if (value != value.trim()) return '名称不能以空格开头或结尾';
  if (value == '.' || value == '..') return '不能使用保留名称';
  if (value.endsWith('.')) return '名称不能以点结尾';
  if (value.contains('/') || value.contains('\\') || value.contains('\u0000')) {
    return '名称不能包含路径分隔符或空字符';
  }
  if (RegExp(r'[<>:"|?*]').hasMatch(value)) {
    return '名称包含跨平台不支持的字符';
  }
  final baseName = value.split('.').first.toUpperCase();
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(baseName)) {
    return '该名称是系统保留名称';
  }
  if (utf8.encode(value).length > 255) return '名称不能超过 255 个 UTF-8 字节';
  return null;
}

Future<String?> showRenameFileItemDialog({
  required BuildContext context,
  required FileSystemNode item,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _RenameFileItemDialog(item: item),
  );
}

class _RenameFileItemDialog extends StatefulWidget {
  const _RenameFileItemDialog({required this.item});

  final FileSystemNode item;

  @override
  State<_RenameFileItemDialog> createState() => _RenameFileItemDialogState();
}

class _RenameFileItemDialogState extends State<_RenameFileItemDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _controller = TextEditingController(text: item.name);
    final extensionIndex = item.isDirectory ? -1 : item.name.lastIndexOf('.');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: extensionIndex > 0 ? extensionIndex : item.name.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    final error = validateFileItemName(value);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.isDirectory ? '重命名目录' : '重命名文件'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(
          labelText: '新名称',
          errorText: _validationError,
        ),
        onChanged: (_) {
          if (_validationError != null) {
            setState(() => _validationError = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('重命名'),
        ),
      ],
    );
  }
}

Future<void> showFileItemProperties({
  required BuildContext context,
  required FileSystemNode item,
}) {
  final modifiedTime = item.modifiedTime?.toLocal().toString() ?? '未知';
  final type = item.isDirectory
      ? '目录'
      : (item.extension?.isNotEmpty == true
          ? '${item.extension!.toUpperCase()} 文件'
          : '文件');

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭属性',
    barrierColor: Colors.black54,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, __) => Center(
      child: Material(
        color: Theme.of(dialogContext).colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(dialogContext).colorScheme.outlineVariant,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('属性', style: Theme.of(dialogContext).textTheme.titleLarge),
                const SizedBox(height: 20),
                _PropertyRow(label: '名称', value: item.name),
                _PropertyRow(label: '类型', value: type),
                if (!item.isDirectory)
                  _PropertyRow(label: '大小', value: item.formattedSize),
                _PropertyRow(label: '修改时间', value: modifiedTime),
                _PropertyRow(label: '逻辑路径', value: item.path),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '未知' : value,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

Future<FileItemAction?> showFileItemContextMenu({
  required BuildContext context,
  required FileSystemNode item,
  required Offset globalPosition,
  bool canPasteInto = false,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final position = RelativeRect.fromLTRB(
    globalPosition.dx,
    globalPosition.dy,
    overlay.size.width - globalPosition.dx,
    overlay.size.height - globalPosition.dy,
  );

  return showMenu<FileItemAction>(
    context: context,
    position: position,
    items: fileItemActionsFor(item, canPasteInto: canPasteInto)
        .map(
          (action) => PopupMenuItem<FileItemAction>(
            value: action,
            child: _FileItemActionRow(action: action, item: item),
          ),
        )
        .toList(),
    popUpAnimationStyle: AnimationStyle.noAnimation,
  );
}

Future<FileItemAction?> showFileItemActionSheet({
  required BuildContext context,
  required FileSystemNode item,
  bool canPasteInto = false,
}) {
  return showModalBottomSheet<FileItemAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: fileItemActionsFor(item, canPasteInto: canPasteInto)
            .map(
              (action) => ListTile(
                leading: Icon(
                  _fileItemActionIcon(action),
                  color: action == FileItemAction.delete ? Colors.red : null,
                ),
                title: Text(
                  fileItemActionLabel(action, item),
                  style: action == FileItemAction.delete
                      ? const TextStyle(color: Colors.red)
                      : null,
                ),
                onTap: () => Navigator.pop(sheetContext, action),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _FileItemActionRow extends StatelessWidget {
  const _FileItemActionRow({required this.action, required this.item});

  final FileItemAction action;
  final FileSystemNode item;

  @override
  Widget build(BuildContext context) {
    final isDestructive = action == FileItemAction.delete;
    return Row(
      children: [
        Icon(
          _fileItemActionIcon(action),
          size: 20,
          color: isDestructive ? Colors.red : null,
        ),
        const SizedBox(width: 12),
        Text(
          fileItemActionLabel(action, item),
          style: isDestructive ? const TextStyle(color: Colors.red) : null,
        ),
      ],
    );
  }
}
