import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/secure_notepad_controller.dart';

class SecureNotepadStatusBar extends StatelessWidget {
  const SecureNotepadStatusBar({
    super.key,
    required this.hasChanges,
    required this.isSaving,
    required this.isReadOnly,
    required this.undoCount,
    required this.redoCount,
    required this.characterCount,
    this.saveError,
    this.isSavingDraft = false,
    this.hasDraftBackup = false,
    this.draftError,
  });

  final bool hasChanges;
  final bool isSaving;
  final bool isReadOnly;
  final int undoCount;
  final int redoCount;
  final int characterCount;
  final String? saveError;
  final bool isSavingDraft;
  final bool hasDraftBackup;
  final String? draftError;

  @override
  Widget build(BuildContext context) {
    final statusText = saveError != null
        ? '保存失败'
        : isSaving
            ? '正在保存'
            : hasChanges
                ? '未保存'
                : '已保存';
    final statusColor = saveError != null
        ? Theme.of(context).colorScheme.error
        : hasChanges
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            saveError != null
                ? Icons.error_outline
                : hasChanges
                    ? Icons.edit
                    : Icons.check_circle,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Text(statusText, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          Icon(
            isReadOnly ? Icons.visibility : Icons.edit_note,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isReadOnly ? '只读' : '编辑',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 16),
          Text('撤销: $undoCount', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 8),
          Text('重做: $redoCount', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            '$characterCount 字符',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isSavingDraft || hasDraftBackup || draftError != null) ...[
            const SizedBox(width: 12),
            Icon(
              draftError != null
                  ? Icons.warning_amber
                  : Icons.cloud_done_outlined,
              size: 16,
              color: draftError != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              draftError != null
                  ? '草稿失败'
                  : isSavingDraft
                      ? '正在保存草稿'
                      : '已保存安全草稿',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class SecureClipboardMonitorBar extends StatelessWidget {
  const SecureClipboardMonitorBar({
    super.key,
    required this.preview,
    required this.error,
    required this.onRefresh,
    required this.onClear,
    required this.onClose,
  });

  final String? preview;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onClear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('secure-clipboard-monitor'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.content_paste_search, size: 18),
            const SizedBox(width: 8),
            Text(
              '剪贴板监视',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error ?? preview ?? '剪贴板中没有短文本',
                key: const Key('secure-clipboard-preview'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: error == null
                          ? null
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '立即刷新剪贴板',
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              tooltip: '快速清空系统剪贴板',
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              tooltip: '停止剪贴板监视',
            ),
          ],
        ),
      ),
    );
  }
}

class SecureFindReplaceBar extends StatefulWidget {
  const SecureFindReplaceBar({
    super.key,
    required this.readOnly,
    required this.onFind,
    required this.onReplace,
    required this.onReplaceAll,
    required this.focusNode,
    required this.onClose,
  });

  final bool readOnly;
  final FindResult? Function(String query, {bool backwards}) onFind;
  final bool Function(String query, String replacement) onReplace;
  final int Function(String query, String replacement) onReplaceAll;
  final FocusNode focusNode;
  final VoidCallback onClose;

  @override
  State<SecureFindReplaceBar> createState() => _SecureFindReplaceBarState();
}

class _SecureFindReplaceBarState extends State<SecureFindReplaceBar> {
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  FindResult? _findResult;

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _find({bool backwards = false}) {
    final result = widget.onFind(
      _findController.text,
      backwards: backwards,
    );
    setState(() => _findResult = result);
    if (result == null) {
      _showMessage('未找到匹配项');
    }
  }

  void _replace() {
    if (!widget.onReplace(
      _findController.text,
      _replaceController.text,
    )) {
      _showMessage('请先选择匹配项');
    }
  }

  void _replaceAll() {
    final count = widget.onReplaceAll(
      _findController.text,
      _replaceController.text,
    );
    _showMessage(count == 0 ? '未找到匹配项' : '已替换 $count 处');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _find,
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): () => _find(backwards: true),
              },
              child: TextField(
                key: const Key('secure-notepad-find-field'),
                controller: _findController,
                focusNode: widget.focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '查找',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _findResult = null),
              ),
            ),
          ),
          if (_findResult != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('${_findResult!.current}/${_findResult!.total}'),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => _find(backwards: true),
            tooltip: '查找上一个',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () => _find(),
            tooltip: '查找下一个',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _replaceController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(
                hintText: '替换',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.find_replace),
            onPressed: widget.readOnly ? null : _replace,
            tooltip: '替换',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: '关闭查找',
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: widget.readOnly ? null : _replaceAll,
            tooltip: '全部替换',
          ),
        ],
      ),
    );
  }
}

class SecureTextEditor extends StatelessWidget {
  const SecureTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        key: const Key('secure-notepad-editor'),
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        style: Theme.of(context).textTheme.bodyLarge,
        maxLines: null,
        expands: true,
        autofocus: !readOnly,
        showCursor: !readOnly,
        enableInteractiveSelection: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: false,
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
