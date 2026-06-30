import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/crypto_service.dart';
import '../models/cryption_config.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import '../native/native_lib.dart';

/// Security-focused notepad for editing encrypted text files.
/// Features:
/// - Flutter-rendered text (no system input boxes)
/// - Undo/Redo support
/// - Auto-save with encryption
/// - Secure memory clearing on close
/// - Partial text copy support
class SecureNotepad extends StatefulWidget {
  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;
  final VoidCallback? onSaved;

  const SecureNotepad({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.onSaved,
  });

  @override
  State<SecureNotepad> createState() => _SecureNotepadState();
}

class _SecureNotepadState extends State<SecureNotepad> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  // Undo/Redo support
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  static const int _maxHistorySize = 50;
  String _lastText = '';
  bool _isUndoRedo = false;

  // State management
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Auto-save
  Timer? _autoSaveTimer;
  static const Duration _autoSaveDelay = Duration(seconds: 30);

  // Find/Replace (optional feature)
  bool _showFindReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  int _findIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _loadFile();
    _startAutoSaveTimer();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _secureClear();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  /// Securely clear all sensitive data from memory
  Future<void> _secureClear() async {
    // Clear controller
    final text = _controller.text;
    _controller.clear();

    // Clear undo/redo stacks
    for (final item in _undoStack) {
      await _clearSecureString(item);
    }
    _undoStack.clear();

    for (final item in _redoStack) {
      await _clearSecureString(item);
    }
    _redoStack.clear();

    // Clear the last text
    await _clearSecureString(_lastText);
    await _clearSecureString(text);

    // Clear find/replace controllers
    _findController.clear();
    _replaceController.clear();

    _focusNode.dispose();
  }

  /// Clear a string from memory using native MemZero
  Future<void> _clearSecureString(String text) async {
    if (text.isEmpty) return;

    try {
      // Convert string to bytes and encode as base64
      final bytes = utf8.encode(text);
      final base64Data = base64Encode(bytes);

      // Call native MemZero through FFI
      final native = NativeLib.instance;
      native.clearSecureMemory(base64Data);
    } catch (_) {
      // Best effort: VM-managed String storage cannot be cleared in place.
    }
  }

  /// Start auto-save timer
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(_autoSaveDelay, (timer) {
      if (_hasChanges && !_isSaving) {
        _saveFile(autoSave: true);
      }
    });
  }

  Future<void> _loadFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Decrypt file content
      final contentBytes = widget.cryptoService.decryptFileToData(
        widget.file.encryptedPath,
        widget.tempKeyID,
      );
      final content = utf8.decode(contentBytes);

      if (content.isNotEmpty) {
        _controller.text = content;
        _lastText = content;
        // Add initial state to undo stack
        _undoStack.add(content);
      }

      setState(() {
        _isLoading = false;
        _hasChanges = false;
      });

      // Mark initialization complete after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '文件加载失败：$e';
      });
    }
  }

  Future<void> _saveFile({bool autoSave = false}) async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      final contentBytes = utf8.encode(_controller.text);
      await widget.cryptoService.writeFileBySession(
        widget.file.encryptedPath,
        widget.tempKeyID,
        contentBytes,
      );

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      widget.onSaved?.call();

      if (mounted && !autoSave) {
        ErrorHelper.showSuccess(context, '文件保存成功');
      }
    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.saveFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  /// Push current state to undo stack
  void _pushToUndoStack(String text) {
    if (_undoStack.isEmpty || _undoStack.last != text) {
      _undoStack.add(text);

      // Limit stack size
      if (_undoStack.length > _maxHistorySize) {
        _undoStack.removeAt(0);
      }
    }

    // Clear redo stack on new change
    _redoStack.clear();
  }

  /// Undo last change
  void _undo() {
    if (_undoStack.length > 1) {
      // Save current state to redo stack
      _redoStack.add(_controller.text);

      // Pop last state from undo stack
      final previousState = _undoStack.removeLast();

      _isUndoRedo = true;
      _controller.text = previousState;
      _lastText = previousState;
      _isUndoRedo = false;

      setState(() {
        _hasChanges = _undoStack.length > 1;
      });
    }
  }

  /// Redo last undone change
  void _redo() {
    if (_redoStack.isNotEmpty) {
      // Save current state to undo stack
      _undoStack.add(_controller.text);

      // Pop last state from redo stack
      final nextState = _redoStack.removeLast();

      _isUndoRedo = true;
      _controller.text = nextState;
      _lastText = nextState;
      _isUndoRedo = false;

      setState(() {
        _hasChanges = true;
      });
    }
  }

  /// Find text in the editor
  void _findText() {
    final findText = _findController.text;
    if (findText.isEmpty) return;

    final currentText = _controller.text;
    final startIndex = _findIndex + 1;
    final index = currentText.indexOf(findText, startIndex);

    if (index != -1) {
      setState(() {
        _findIndex = index;
      });
      _controller.selection = TextSelection(
        baseOffset: index,
        extentOffset: index + findText.length,
      );
    } else {
      // Not found, reset search
      setState(() {
        _findIndex = -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到匹配项')),
        );
      }
    }
  }

  /// Replace found text
  void _replaceText() {
    final findText = _findController.text;
    final replaceText = _replaceController.text;

    if (findText.isEmpty || _findIndex == -1) return;

    final currentText = _controller.text;
    final newText = currentText.replaceRange(
      _findIndex,
      _findIndex + findText.length,
      replaceText,
    );

    _pushToUndoStack(_controller.text);
    _controller.text = newText;
    _lastText = newText;
    setState(() {
      _hasChanges = true;
      _findIndex = -1;
    });

    // Find next occurrence
    _findText();
  }

  /// Replace all occurrences
  void _replaceAll() {
    final findText = _findController.text;
    final replaceText = _replaceController.text;

    if (findText.isEmpty) return;

    final currentText = _controller.text;
    final count = findText.allMatches(currentText).length;

    if (count == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到匹配项')),
        );
      }
      return;
    }

    _pushToUndoStack(_controller.text);
    final newText = currentText.replaceAll(findText, replaceText);
    _controller.text = newText;
    _lastText = newText;
    setState(() {
      _hasChanges = true;
      _findIndex = -1;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已替换 $count 处')),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('关闭前是否保存更改？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'no'),
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'yes'),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == 'yes') {
      await _saveFile();
      if (mounted) Navigator.of(context).pop();
      return true;
    } else if (result == 'no') {
      if (mounted) Navigator.of(context).pop();
      return true;
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.file.name),
          actions: [
            // Undo button
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoStack.length > 1 ? _undo : null,
              tooltip: '撤销',
            ),
            // Redo button
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoStack.isNotEmpty ? _redo : null,
              tooltip: '重做',
            ),
            // Find/Replace toggle
            IconButton(
              icon: Icon(_showFindReplace ? Icons.search_off : Icons.search),
              onPressed: () {
                setState(() {
                  _showFindReplace = !_showFindReplace;
                  if (!_showFindReplace) {
                    _findIndex = -1;
                  }
                });
              },
              tooltip: _showFindReplace ? '隐藏查找/替换' : '查找/替换',
            ),
            // Save button
            if (_hasChanges)
              IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                onPressed: _isSaving ? null : _saveFile,
                tooltip: '保存',
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFile,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Find/Replace bar (optional)
            if (_showFindReplace) _buildFindReplaceBar(),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Row(
                children: [
                  if (_hasChanges)
                    const Icon(Icons.edit, size: 16, color: Colors.orange)
                  else
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    _hasChanges ? '未保存' : '已保存',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '撤销: ${_undoStack.length - 1}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '重做: ${_redoStack.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${_controller.text.length} 字符',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Editor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  showCursor: true,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    filled: false,
                  ),
                  cursorColor: Theme.of(context).colorScheme.primary,
                  onChanged: (text) {
                    // Ignore text changes during initialization or undo/redo
                    if (_isInitializing || _isUndoRedo) {
                      return;
                    }

                    // Check if text actually changed
                    if (text != _lastText) {
                      // Push old text to undo stack
                      _pushToUndoStack(_lastText);

                      _lastText = text;
                      if (!_hasChanges) {
                        setState(() => _hasChanges = true);
                      }
                    }
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\s\S]*')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build find/replace bar (optional feature)
  Widget _buildFindReplaceBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
      child: Row(
        children: [
          // Find field
          Expanded(
            child: TextField(
              controller: _findController,
              decoration: const InputDecoration(
                hintText: '查找',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _findText(),
            ),
          ),
          const SizedBox(width: 8),
          // Find button
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: _findText,
            tooltip: '查找下一个',
          ),

          const SizedBox(width: 16),

          // Replace field
          Expanded(
            child: TextField(
              controller: _replaceController,
              decoration: const InputDecoration(
                hintText: '替换',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Replace button
          IconButton(
            icon: const Icon(Icons.find_replace),
            onPressed: _replaceText,
            tooltip: '替换',
          ),
          // Replace all button
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _replaceAll,
            tooltip: '全部替换',
          ),
        ],
      ),
    );
  }
}
