import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

import '../controllers/secure_notepad_controller.dart';
import '../models/cryption_config.dart';
import '../services/crypto_service.dart';
import '../services/document_session_broker.dart';
import '../services/system_text_clipboard.dart';
import '../utils/error_messages.dart';
import 'copyable_snackbar.dart';
import 'secure_notepad_sections.dart';

/// Edits a text file through an open encrypted-root session.
///
/// Sensitive document state and editor behavior live in
/// [SecureNotepadController]; this widget only coordinates navigation and
/// presentation.
class SecureNotepad extends StatefulWidget {
  const SecureNotepad({
    super.key,
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.onSaved,
    this.autoSaveInterval = const Duration(seconds: 30),
    this.initiallyReadOnly = false,
    this.initiallyMonitorClipboard = false,
    this.systemClipboard = const FlutterSystemTextClipboard(),
    this.clipboardMonitorInterval = const Duration(seconds: 1),
    this.documentBroker,
    this.documentLease,
    this.onDirtyChanged,
    this.onClosed,
  });

  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;
  final VoidCallback? onSaved;
  final Duration autoSaveInterval;
  final bool initiallyReadOnly;
  final bool initiallyMonitorClipboard;
  final SystemTextClipboard systemClipboard;
  final Duration clipboardMonitorInterval;
  final DocumentSessionBroker? documentBroker;
  final DocumentLease? documentLease;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onClosed;

  @override
  State<SecureNotepad> createState() => _SecureNotepadState();
}

class _SecureNotepadState extends State<SecureNotepad>
    with WidgetsBindingObserver {
  late final SecureNotepadController _controller;
  bool _showFindReplace = false;
  bool _monitorClipboard = false;
  String? _clipboardPreview;
  String? _clipboardError;
  Timer? _clipboardTimer;
  bool _clipboardReadActive = false;
  int _clipboardGeneration = 0;
  final FocusNode _findFocusNode = FocusNode();
  final SecureTextEditorViewport _editorViewport = SecureTextEditorViewport();

  @override
  void initState() {
    super.initState();
    _controller = SecureNotepadController(
      file: widget.file,
      cryptoService: widget.cryptoService,
      tempKeyID: widget.tempKeyID,
      autoSaveInterval: widget.autoSaveInterval,
      initiallyReadOnly: widget.initiallyReadOnly,
      onSaved: widget.onSaved,
      documentBroker: widget.documentBroker,
      documentLease: widget.documentLease,
      onDirtyChanged: widget.onDirtyChanged,
    )..addListener(_onControllerChanged);
    WidgetsBinding.instance.addObserver(this);
    _monitorClipboard = widget.initiallyMonitorClipboard;
    if (_monitorClipboard) _startClipboardTimer();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    await _controller.load();
    if (!mounted) return;
    if (_controller.loadError != null) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.loadFileFailed,
        originalError: _controller.loadTechnicalError,
        operation: 'secure-notepad-load',
      );
      return;
    }
    if (!_controller.hasRecoveryDraft) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDraftRecoveryDialog();
    });
  }

  Future<void> _showDraftRecoveryDialog() async {
    final strings = AppLocalizations.of(context)!;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.notepadRecoveryDraftFound),
        content: Text(strings.notepadRecoveryDraftDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(strings.notepadDiscardDraft),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'restore'),
            child: Text(strings.notepadRestoreDraft),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'restore') {
      _controller.restoreRecoveryDraft();
      _controller.focusNode.requestFocus();
    } else {
      final discarded = await _controller.discardDraft();
      if (!discarded && mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: _controller.draftTechnicalError,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clipboardTimer?.cancel();
    _findFocusNode.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    widget.onClosed?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_monitorClipboard) return;
    if (state == AppLifecycleState.resumed) {
      _startClipboardTimer();
    } else {
      _clipboardTimer?.cancel();
    }
  }

  void _toggleClipboardMonitor() {
    _clipboardGeneration++;
    setState(() {
      _monitorClipboard = !_monitorClipboard;
      if (!_monitorClipboard) {
        _clipboardPreview = null;
        _clipboardError = null;
      }
    });
    if (_monitorClipboard) {
      _startClipboardTimer();
    } else {
      _clipboardTimer?.cancel();
    }
  }

  void _startClipboardTimer() {
    _clipboardTimer?.cancel();
    unawaited(_refreshClipboardPreview());
    if (widget.clipboardMonitorInterval <= Duration.zero) return;
    _clipboardTimer = Timer.periodic(
      widget.clipboardMonitorInterval,
      (_) => unawaited(_refreshClipboardPreview()),
    );
  }

  Future<void> _refreshClipboardPreview() async {
    if (!_monitorClipboard || _clipboardReadActive) return;
    final generation = _clipboardGeneration;
    _clipboardReadActive = true;
    try {
      final text = await widget.systemClipboard.readText();
      if (!mounted ||
          !_monitorClipboard ||
          generation != _clipboardGeneration) {
        return;
      }
      setState(() {
        _clipboardPreview = _shortClipboardText(text);
        _clipboardError = null;
      });
    } catch (_) {
      if (!mounted ||
          !_monitorClipboard ||
          generation != _clipboardGeneration) {
        return;
      }
      final strings = AppLocalizations.of(context)!;
      setState(() => _clipboardError = strings.notepadClipboardReadFailed);
    } finally {
      _clipboardReadActive = false;
    }
  }

  Future<void> _clearSystemClipboard() async {
    _clipboardGeneration++;
    try {
      await widget.systemClipboard.clear();
      if (!mounted) return;
      setState(() {
        _clipboardPreview = null;
        _clipboardError = null;
      });
    } catch (_) {
      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        setState(() => _clipboardError = strings.notepadClipboardClearFailed);
      }
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!mounted) return;
    if (saved) {
      ErrorHelper.showSuccess(
        context,
        AppLocalizations.of(context)!.notepadFileSaved,
      );
      return;
    }
    ErrorHelper.showError(
      context,
      errorType: ErrorType.saveFileFailed,
      originalError: _controller.saveError,
    );
  }

  void _showFind() {
    if (!_showFindReplace) setState(() => _showFindReplace = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocusNode.requestFocus();
    });
  }

  void _hideFind() {
    if (_showFindReplace) setState(() => _showFindReplace = false);
    _editorViewport.clearSelectionHighlight();
    _controller.focusNode.requestFocus();
  }

  FindResult? _find(String query, {bool backwards = false}) {
    final result = _controller.find(query, backwards: backwards);
    if (result != null) {
      _editorViewport.centerSelection();
    } else {
      _editorViewport.clearSelectionHighlight();
    }
    return result;
  }

  Future<bool> _confirmClose() async {
    if (!_controller.hasChanges) return true;
    final strings = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.notepadUnsavedChanges),
        content: Text(strings.notepadSaveBeforeClosing),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(strings.notepadDontSave),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: Text(strings.notepadSave),
          ),
        ],
      ),
    );
    if (result == 'discard') return _controller.discardDraft();
    if (result != 'save') return false;

    final saved = await _controller.save();
    if (!saved && mounted) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.saveFileFailed,
        originalError: _controller.saveError,
      );
    }
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _showFind,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          unawaited(_save());
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            _controller.undo,
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: true,
          shift: true,
        ): _controller.redo,
        const SingleActivator(LogicalKeyboardKey.escape): _hideFind,
      },
      child: PopScope(
        canPop: !_controller.hasChanges,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldClose = await _confirmClose();
          if (!context.mounted || !shouldClose) return;
          Navigator.of(context).pop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.file.name),
            actions: [
              IconButton(
                icon: Icon(
                  _controller.isReadOnly ? Icons.edit : Icons.visibility,
                ),
                onPressed: _controller.toggleReadOnly,
                tooltip: _controller.isReadOnly
                    ? strings.notepadStartEditing
                    : strings.notepadSwitchReadOnly,
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _controller.canUndo ? _controller.undo : null,
                tooltip: strings.notepadUndoShortcut,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _controller.canRedo ? _controller.redo : null,
                tooltip: strings.notepadRedoShortcut,
              ),
              IconButton(
                icon: Icon(_showFindReplace ? Icons.search_off : Icons.search),
                onPressed: _showFindReplace ? _hideFind : _showFind,
                tooltip: _showFindReplace
                    ? strings.notepadCloseFind
                    : strings.notepadFindReplace,
              ),
              IconButton(
                icon: Icon(
                  _monitorClipboard
                      ? Icons.content_paste_search
                      : Icons.content_paste_outlined,
                ),
                onPressed: _toggleClipboardMonitor,
                tooltip: _monitorClipboard
                    ? strings.notepadStopClipboardMonitoring
                    : strings.notepadMonitorClipboardAction,
              ),
              if (_controller.hasChanges)
                IconButton(
                  icon: _controller.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  onPressed: _controller.isSaving ? null : _save,
                  tooltip: strings.notepadSave,
                ),
            ],
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_loadErrorMessage(AppLocalizations.of(context)!)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadDocument,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          if (_showFindReplace)
            SecureFindReplaceBar(
              readOnly: _controller.isReadOnly,
              onFind: _find,
              onReplace: _controller.replaceSelection,
              onReplaceAll: _controller.replaceAll,
              focusNode: _findFocusNode,
              onQueryChanged: _editorViewport.clearSelectionHighlight,
              onClose: _hideFind,
            ),
          if (_monitorClipboard)
            SecureClipboardMonitorBar(
              preview: _clipboardPreview,
              error: _clipboardError,
              onRefresh: _refreshClipboardPreview,
              onClear: _clearSystemClipboard,
              onClose: _toggleClipboardMonitor,
            ),
          SecureNotepadStatusBar(
            hasChanges: _controller.hasChanges,
            isSaving: _controller.isSaving,
            isReadOnly: _controller.isReadOnly,
            characterCount: _controller.characterCount,
            encoding: _controller.detectedEncoding,
            saveError: _controller.saveError,
            isSavingDraft: _controller.isSavingDraft,
            hasDraftBackup: _controller.hasDraftBackup,
            draftError: _controller.draftError,
          ),
          Expanded(
            child: SecureTextEditor(
              controller: _controller.textController,
              focusNode: _controller.focusNode,
              readOnly: _controller.isReadOnly,
              viewport: _editorViewport,
            ),
          ),
        ],
      ),
    );
  }

  String _loadErrorMessage(AppLocalizations strings) {
    return switch (_controller.loadError!) {
      SecureNotepadLoadError.binaryContent => strings.notepadBinaryContent,
      SecureNotepadLoadError.readFailed => strings.notepadLoadFailed,
    };
  }
}

String? _shortClipboardText(String? value) {
  if (value == null || value.isEmpty) return null;
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return null;
  const maxRunes = 160;
  final runes = compact.runes.toList();
  if (runes.length <= maxRunes) return compact;
  return '${String.fromCharCodes(runes.take(maxRunes))}…';
}
