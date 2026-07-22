import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/secure_image_policy.dart';
import '../services/file_service.dart';
import 'property_overlay.dart';

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

String fileItemActionLabel(
  AppLocalizations strings,
  FileItemAction action,
  FileSystemNode item,
) {
  return switch (action) {
    FileItemAction.open =>
      item.isDirectory ? strings.openDirectory : strings.viewImage,
    FileItemAction.edit => strings.editWithSecureNotepad,
    FileItemAction.openInNewWindow => isViewableImageFile(item)
        ? strings.viewInNewWindow
        : strings.editInNewWindow,
    FileItemAction.select => strings.select,
    FileItemAction.rename => strings.rename,
    FileItemAction.copy => strings.copy,
    FileItemAction.cut => strings.cut,
    FileItemAction.pasteInto => strings.pasteIntoDirectory,
    FileItemAction.export =>
      item.isDirectory ? strings.exportDirectory : strings.exportDecryptedFile,
    FileItemAction.copyName => strings.copyPlaintextName,
    FileItemAction.copyPath => strings.copyPlaintextLogicalPath,
    FileItemAction.properties => strings.properties,
    FileItemAction.refresh => strings.refresh,
    FileItemAction.delete => strings.deleteFile,
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

enum FileItemNameValidationIssue {
  empty,
  leadingOrTrailingWhitespace,
  reservedDotName,
  trailingDot,
  pathSeparatorOrNull,
  unsupportedCharacter,
  reservedSystemName,
  tooLong,
}

FileItemNameValidationIssue? validateFileItemName(String value) {
  if (value.isEmpty) return FileItemNameValidationIssue.empty;
  if (value != value.trim()) {
    return FileItemNameValidationIssue.leadingOrTrailingWhitespace;
  }
  if (value == '.' || value == '..') {
    return FileItemNameValidationIssue.reservedDotName;
  }
  if (value.endsWith('.')) return FileItemNameValidationIssue.trailingDot;
  if (value.contains('/') || value.contains('\\') || value.contains('\u0000')) {
    return FileItemNameValidationIssue.pathSeparatorOrNull;
  }
  if (RegExp(r'[<>:"|?*]').hasMatch(value)) {
    return FileItemNameValidationIssue.unsupportedCharacter;
  }
  final baseName = value.split('.').first.toUpperCase();
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$').hasMatch(baseName)) {
    return FileItemNameValidationIssue.reservedSystemName;
  }
  if (utf8.encode(value).length > 255) {
    return FileItemNameValidationIssue.tooLong;
  }
  return null;
}

String fileItemNameValidationMessage(
  AppLocalizations strings,
  FileItemNameValidationIssue issue,
) {
  return switch (issue) {
    FileItemNameValidationIssue.empty => strings.fileNameEmpty,
    FileItemNameValidationIssue.leadingOrTrailingWhitespace =>
      strings.fileNameLeadingOrTrailingWhitespace,
    FileItemNameValidationIssue.reservedDotName => strings.fileNameReserved,
    FileItemNameValidationIssue.trailingDot => strings.fileNameTrailingDot,
    FileItemNameValidationIssue.pathSeparatorOrNull =>
      strings.fileNamePathSeparatorOrNull,
    FileItemNameValidationIssue.unsupportedCharacter =>
      strings.fileNameUnsupportedCharacter,
    FileItemNameValidationIssue.reservedSystemName =>
      strings.fileNameReservedSystemName,
    FileItemNameValidationIssue.tooLong => strings.fileNameTooLong,
  };
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
      setState(() {
        _validationError =
            fileItemNameValidationMessage(AppLocalizations.of(context)!, error);
      });
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.item.isDirectory
          ? strings.renameDirectory
          : strings.renameFile),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 255,
        decoration: InputDecoration(
          labelText: strings.newName,
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
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(strings.rename),
        ),
      ],
    );
  }
}

Future<void> showFileItemProperties({
  required BuildContext context,
  required FileSystemNode item,
}) {
  final strings = AppLocalizations.of(context)!;
  final modifiedTime = item.modifiedTime == null
      ? strings.unknown
      : DateFormat.yMMMd(strings.localeName)
          .add_jm()
          .format(item.modifiedTime!.toLocal());
  final type = item.isDirectory
      ? strings.directory
      : (item.extension?.isNotEmpty == true
          ? strings.fileTypeWithExtension(item.extension!.toUpperCase())
          : strings.file);

  return showPropertyOverlay(
    context: context,
    title: strings.properties,
    values: [
      PropertyValue(strings.name, item.name),
      PropertyValue(strings.type, type),
      if (!item.isDirectory) PropertyValue(strings.size, item.formattedSize),
      PropertyValue(strings.modifiedTime, modifiedTime),
      PropertyValue(strings.logicalPath, item.path),
    ],
  );
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
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: fileItemActionsFor(item, canPasteInto: canPasteInto)
              .map(
                (action) => ListTile(
                  leading: Icon(
                    _fileItemActionIcon(action),
                    color: action == FileItemAction.delete ? Colors.red : null,
                  ),
                  title: Text(
                    fileItemActionLabel(
                      AppLocalizations.of(context)!,
                      action,
                      item,
                    ),
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
          fileItemActionLabel(AppLocalizations.of(context)!, action, item),
          style: isDestructive ? const TextStyle(color: Colors.red) : null,
        ),
      ],
    );
  }
}
