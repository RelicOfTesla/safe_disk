import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../controllers/secure_notepad_controller.dart';
import '../l10n/generated/app_localizations.dart';

class SecureNotepadStatusBar extends StatelessWidget {
  const SecureNotepadStatusBar({
    super.key,
    required this.hasChanges,
    required this.isSaving,
    required this.isReadOnly,
    required this.characterCount,
    this.encoding,
    this.saveError,
    this.isSavingDraft = false,
    this.hasDraftBackup = false,
    this.draftError,
  });

  final bool hasChanges;
  final bool isSaving;
  final bool isReadOnly;
  final int characterCount;
  final String? encoding;
  final String? saveError;
  final bool isSavingDraft;
  final bool hasDraftBackup;
  final SecureNotepadDraftError? draftError;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final statusText = saveError != null
        ? strings.notepadSaveFailed
        : isSaving
            ? strings.notepadSaving
            : hasChanges
                ? strings.notepadUnsaved
                : strings.notepadSaved;
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
            isReadOnly ? strings.notepadReadOnly : strings.notepadEditing,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (encoding != null) ...[
            Text(
              encoding!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            strings.notepadCharacterCount(characterCount),
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
                  ? _draftErrorMessage(strings, draftError!)
                  : isSavingDraft
                      ? strings.notepadSavingDraft
                      : strings.notepadDraftSaved,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _draftErrorMessage(
    AppLocalizations strings,
    SecureNotepadDraftError error,
  ) {
    return switch (error) {
      SecureNotepadDraftError.cleanupAfterSave =>
        strings.notepadDraftCleanupFailed,
      SecureNotepadDraftError.readRecoveryDraft =>
        strings.notepadDraftReadFailed,
      SecureNotepadDraftError.discardRecoveryDraft =>
        strings.notepadDraftDiscardFailed,
      SecureNotepadDraftError.saveRecoveryDraft =>
        strings.notepadDraftSaveFailed,
    };
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
    final strings = AppLocalizations.of(context)!;
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
              strings.notepadClipboardMonitor,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error ?? preview ?? strings.notepadClipboardEmpty,
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
              tooltip: strings.notepadRefreshClipboard,
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              tooltip: strings.notepadClearClipboard,
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
              tooltip: strings.notepadStopClipboardMonitoring,
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
    required this.onQueryChanged,
    required this.onClose,
  });

  final bool readOnly;
  final FindResult? Function(String query, {bool backwards}) onFind;
  final bool Function(String query, String replacement) onReplace;
  final int Function(String query, String replacement) onReplaceAll;
  final FocusNode focusNode;
  final VoidCallback onQueryChanged;
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
      _findQuery,
      backwards: backwards,
    );
    setState(() => _findResult = result);
    if (result == null) {
      _showMessage(AppLocalizations.of(context)!.notepadNoMatches);
    }
  }

  void _replace() {
    if (!widget.onReplace(
      _findQuery,
      _replaceController.text,
    )) {
      _showMessage(AppLocalizations.of(context)!.notepadSelectMatchFirst);
    }
  }

  void _replaceAll() {
    final count = widget.onReplaceAll(
      _findQuery,
      _replaceController.text,
    );
    final strings = AppLocalizations.of(context)!;
    _showMessage(
      count == 0
          ? strings.notepadNoMatches
          : strings.notepadReplacedCount(count),
    );
  }

  String get _findQuery => _findController.text.replaceAll(r'\n', '\n');

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
                const SingleActivator(LogicalKeyboardKey.numpadEnter): _find,
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): () => _find(backwards: true),
                const SingleActivator(
                  LogicalKeyboardKey.numpadEnter,
                  shift: true,
                ): () => _find(backwards: true),
              },
              child: TextField(
                key: const Key('secure-notepad-find-field'),
                controller: _findController,
                focusNode: widget.focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.notepadFindHint,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _find(),
                onChanged: (_) {
                  setState(() => _findResult = null);
                  widget.onQueryChanged();
                },
              ),
            ),
          ),
          if (_findResult != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                strings.notepadFindPosition(
                  _findResult!.current,
                  _findResult!.total,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () => _find(backwards: true),
            tooltip: strings.notepadFindPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () => _find(),
            tooltip: strings.notepadFindNext,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _replaceController,
              enabled: !widget.readOnly,
              decoration: InputDecoration(
                hintText: strings.notepadReplace,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.find_replace),
            onPressed: widget.readOnly ? null : _replace,
            tooltip: strings.notepadReplace,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
            tooltip: strings.notepadCloseFind,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: widget.readOnly ? null : _replaceAll,
            tooltip: strings.notepadReplaceAll,
          ),
        ],
      ),
    );
  }
}

class SecureTextEditorViewport {
  VoidCallback? _centerSelectionCallback;
  VoidCallback? _clearSelectionHighlightCallback;

  void centerSelection() => _centerSelectionCallback?.call();

  void clearSelectionHighlight() => _clearSelectionHighlightCallback?.call();
}

class SecureTextEditor extends StatefulWidget {
  const SecureTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.viewport,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final SecureTextEditorViewport viewport;

  @override
  State<SecureTextEditor> createState() => _SecureTextEditorState();
}

class _SecureTextEditorState extends State<SecureTextEditor> {
  final GlobalKey _editorKey = GlobalKey();
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  List<Rect> _selectionHighlightRects = const [];

  @override
  void initState() {
    super.initState();
    widget.viewport._centerSelectionCallback = _centerSelection;
    widget.viewport._clearSelectionHighlightCallback = _clearSelectionHighlight;
    _scrollController.addListener(_refreshSelectionHighlight);
  }

  @override
  void didUpdateWidget(covariant SecureTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewport != widget.viewport) {
      oldWidget.viewport._centerSelectionCallback = null;
      oldWidget.viewport._clearSelectionHighlightCallback = null;
      widget.viewport._centerSelectionCallback = _centerSelection;
      widget.viewport._clearSelectionHighlightCallback =
          _clearSelectionHighlight;
    }
  }

  @override
  void dispose() {
    widget.viewport._centerSelectionCallback = null;
    widget.viewport._clearSelectionHighlightCallback = null;
    _scrollController.removeListener(_refreshSelectionHighlight);
    _scrollController.dispose();
    super.dispose();
  }

  void _centerSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final selection = widget.controller.selection;
      if (!selection.isValid || selection.isCollapsed) {
        _clearSelectionHighlight();
        return;
      }
      final renderEditable = _findRenderEditable(
        _editorKey.currentContext?.findRenderObject(),
      );
      if (renderEditable == null || !renderEditable.hasSize) return;

      final caret = renderEditable.getLocalRectForCaret(
        TextPosition(offset: selection.extentOffset),
      );
      final position = _scrollController.position;
      final target =
          (position.pixels + caret.center.dy - renderEditable.size.height / 2)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
      _updateSelectionHighlight(renderEditable, selection);
    });
  }

  void _refreshSelectionHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selection = widget.controller.selection;
      if (!selection.isValid || selection.isCollapsed) {
        _clearSelectionHighlight();
        return;
      }
      final renderEditable = _findRenderEditable(
        _editorKey.currentContext?.findRenderObject(),
      );
      if (renderEditable != null) {
        _updateSelectionHighlight(renderEditable, selection);
      }
    });
  }

  void _updateSelectionHighlight(
    RenderEditable renderEditable,
    TextSelection selection,
  ) {
    final highlightBox = _highlightKey.currentContext?.findRenderObject();
    if (highlightBox is! RenderBox || !highlightBox.hasSize) return;
    final rects = renderEditable
        .getBoxesForSelection(selection)
        .map((box) {
          final topLeft = highlightBox.globalToLocal(
            renderEditable.localToGlobal(box.toRect().topLeft),
          );
          final bottomRight = highlightBox.globalToLocal(
            renderEditable.localToGlobal(box.toRect().bottomRight),
          );
          return Rect.fromPoints(topLeft, bottomRight);
        })
        .where((rect) => rect.width > 0 && rect.height > 0)
        .toList(growable: false);
    if (_sameRects(_selectionHighlightRects, rects)) return;
    setState(() => _selectionHighlightRects = rects);
  }

  void _clearSelectionHighlight() {
    if (_selectionHighlightRects.isEmpty || !mounted) return;
    setState(() => _selectionHighlightRects = const []);
  }

  RenderEditable? _findRenderEditable(RenderObject? renderObject) {
    if (renderObject == null) return null;
    if (renderObject is RenderEditable) return renderObject;
    RenderEditable? result;
    renderObject.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Keep the native focused selection legible across desktop themes. When
    // the find bar owns focus, the overlay below supplies the visible match.
    final findSelectionColor = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.42),
      colors.surface,
    );
    final findSelectionOverlayColor = colors.primary.withValues(alpha: 0.32);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: KeyedSubtree(
        key: _editorKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionColor: findSelectionColor,
                ),
              ),
              child: TextField(
                key: const Key('secure-notepad-editor'),
                controller: widget.controller,
                focusNode: widget.focusNode,
                readOnly: widget.readOnly,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: null,
                expands: true,
                autofocus: !widget.readOnly,
                showCursor: !widget.readOnly,
                enableInteractiveSelection: true,
                scrollController: _scrollController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                ),
                cursorColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (_selectionHighlightRects.isNotEmpty)
              Positioned.fill(
                child: KeyedSubtree(
                  key: _highlightKey,
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const Key('secure-notepad-find-highlight'),
                      painter: _FindSelectionHighlightPainter(
                        _selectionHighlightRects,
                        findSelectionOverlayColor,
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: KeyedSubtree(
                  key: _highlightKey,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _sameRects(List<Rect> left, List<Rect> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class _FindSelectionHighlightPainter extends CustomPainter {
  const _FindSelectionHighlightPainter(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FindSelectionHighlightPainter oldDelegate) {
    return color != oldDelegate.color || !_sameRects(rects, oldDelegate.rects);
  }
}
