import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/cryption_config.dart';
import '../native/native_lib.dart';
import '../services/crypto_service.dart';
import '../services/document_session_broker.dart';
import '../services/secure_notepad_draft_store.dart';
import '../utils/encoding_detector.dart';

class SecureNotepadController extends ChangeNotifier {
  SecureNotepadController({
    required this.file,
    required this.cryptoService,
    required this.tempKeyID,
    this.autoSaveInterval = const Duration(seconds: 30),
    this.onSaved,
    SecureNotepadDraftStore? draftStore,
    this.documentBroker,
    this.documentLease,
    this.onDirtyChanged,
    bool initiallyReadOnly = false,
  })  : _isReadOnly = initiallyReadOnly,
        _draftStore = draftStore ??
            SecureNotepadDraftStore(cryptoService: cryptoService) {
    assert(
      (documentBroker == null) == (documentLease == null),
      'documentBroker and documentLease must be provided together',
    );
    textController.addListener(_handleTextChanged);
  }

  static const int maxHistorySize = 50;

  final EncryptedFile file;
  final CryptoService cryptoService;
  final String tempKeyID;
  final Duration autoSaveInterval;
  final VoidCallback? onSaved;
  final DocumentSessionBroker? documentBroker;
  final DocumentLease? documentLease;
  final ValueChanged<bool>? onDirtyChanged;
  final SecureNotepadDraftStore _draftStore;

  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  final List<String> _history = [];
  int _historyIndex = -1;
  String _savedText = '';
  bool _applyingHistory = false;
  bool _disposed = false;
  Timer? _autoSaveTimer;
  Future<void>? _activeDraftWrite;
  String? _lastDraftText;
  String? _recoveryDraftText;
  int? _documentRevision;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingDraft = false;
  bool _hasDraftBackup = false;
  bool _hasChanges = false;
  bool _isReadOnly;
  String? _loadError;
  String? _saveError;
  String? _draftError;
  String? _detectedEncoding;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSavingDraft => _isSavingDraft;
  bool get hasDraftBackup => _hasDraftBackup;
  bool get hasRecoveryDraft => _recoveryDraftText != null;
  bool get hasChanges => _hasChanges;
  bool get isReadOnly => _isReadOnly;
  String? get loadError => _loadError;
  String? get saveError => _saveError;
  String? get draftError => _draftError;
  String? get detectedEncoding => _detectedEncoding;
  String get draftPath =>
      SecureNotepadDraftStore.draftPathFor(file.encryptedPath);
  bool get canUndo => !_isReadOnly && _historyIndex > 0;
  bool get canRedo =>
      !_isReadOnly && _historyIndex >= 0 && _historyIndex < _history.length - 1;
  int get characterCount => textController.text.length;

  Future<void> load() async {
    _setLoading(true);
    _loadError = null;
    _saveError = null;
    try {
      final lease = documentLease;
      final contentBytes = lease?.snapshot.content ??
          cryptoService.decryptFileToData(
            file.encryptedPath,
            tempKeyID,
          );
      _documentRevision = lease?.snapshot.revision;
      if (contentBytes.contains(0)) {
        throw const FormatException('文件包含 NUL 字节，可能是二进制文件');
      }
      final decoded = await EncodingDetector.decode(contentBytes);
      _detectedEncoding = decoded.encoding;
      final content = decoded.text;
      _replaceText(content);
      _savedText = content;
      _history
        ..clear()
        ..add(content);
      _historyIndex = 0;
      _hasChanges = false;
      onDirtyChanged?.call(false);
      await _loadRecoveryDraft(content);
      _startAutoSaveTimer();
    } catch (error) {
      _loadError = '文件加载失败：$error';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> save() async {
    if (_isSaving) return false;
    if (!_hasChanges) return true;

    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final activeDraftWrite = _activeDraftWrite;
      if (activeDraftWrite != null) await activeDraftWrite;
      final content = utf8.encode(textController.text);
      final broker = documentBroker;
      final lease = documentLease;
      if (broker != null && lease != null) {
        final snapshot = await broker.save(
          token: lease.token,
          baseRevision: _documentRevision!,
          content: content,
        );
        _documentRevision = snapshot.revision;
      } else {
        await cryptoService.writeFileBySession(
          file.encryptedPath,
          tempKeyID,
          content,
        );
      }
      _savedText = textController.text;
      _hasChanges = false;
      onDirtyChanged?.call(false);
      try {
        await _draftStore.delete(file.encryptedPath, tempKeyID);
        _hasDraftBackup = false;
        _lastDraftText = null;
        _recoveryDraftText = null;
        _draftError = null;
      } catch (error) {
        _draftError = '原文件已保存，但旧草稿清理失败：$error';
      }
      onSaved?.call();
      return true;
    } catch (error) {
      _saveError = error.toString();
      return false;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _loadRecoveryDraft(String originalContent) async {
    _draftError = null;
    try {
      final draft = await _draftStore.read(file.encryptedPath, tempKeyID);
      if (draft == null) return;
      if (draft == originalContent) {
        await _draftStore.delete(file.encryptedPath, tempKeyID);
        return;
      }
      _recoveryDraftText = draft;
      _lastDraftText = draft;
      _hasDraftBackup = true;
    } catch (error) {
      _draftError = '安全草稿检测失败：$error';
    }
  }

  void restoreRecoveryDraft() {
    final draft = _recoveryDraftText;
    if (draft == null) return;
    _recoveryDraftText = null;
    _replaceText(draft);
    _recordCurrentText();
    _hasDraftBackup = true;
    notifyListeners();
  }

  Future<bool> discardDraft() async {
    try {
      final activeDraftWrite = _activeDraftWrite;
      if (activeDraftWrite != null) await activeDraftWrite;
      await _draftStore.delete(file.encryptedPath, tempKeyID);
      _recoveryDraftText = null;
      _lastDraftText = null;
      _hasDraftBackup = false;
      _draftError = null;
      if (!_disposed) notifyListeners();
      return true;
    } catch (error) {
      _draftError = '安全草稿清理失败：$error';
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> saveDraft() async {
    if (!_hasChanges || _isSaving || _isSavingDraft) return false;
    final content = textController.text;
    if (content == _lastDraftText) return true;

    _isSavingDraft = true;
    _draftError = null;
    notifyListeners();
    final write = _draftStore.write(file.encryptedPath, tempKeyID, content);
    _activeDraftWrite = write;
    try {
      await write;
      _lastDraftText = content;
      _hasDraftBackup = true;
      return true;
    } catch (error) {
      _draftError = '安全草稿保存失败：$error';
      return false;
    } finally {
      if (identical(_activeDraftWrite, write)) _activeDraftWrite = null;
      _isSavingDraft = false;
      if (!_disposed) notifyListeners();
    }
  }

  void toggleReadOnly() {
    _isReadOnly = !_isReadOnly;
    notifyListeners();
    if (!_isReadOnly) {
      focusNode.requestFocus();
    }
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    _replaceText(_history[_historyIndex]);
    _syncDirtyState();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    _replaceText(_history[_historyIndex]);
    _syncDirtyState();
  }

  bool findNext(String query) {
    return find(query) != null;
  }

  FindResult? find(String query, {bool backwards = false}) {
    if (query.isEmpty) return null;
    final text = textController.text;
    final matches = query.allMatches(text).toList();
    if (matches.isEmpty) return null;
    final selection = textController.selection;
    final cursor = selection.isValid
        ? (backwards ? selection.start : selection.end)
        : (backwards ? text.length : 0);
    var matchIndex = backwards
        ? matches.lastIndexWhere((match) => match.end <= cursor)
        : matches.indexWhere((match) => match.start >= cursor);
    if (matchIndex < 0) matchIndex = backwards ? matches.length - 1 : 0;
    final match = matches[matchIndex];
    textController.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
    return FindResult(current: matchIndex + 1, total: matches.length);
  }

  bool replaceSelection(String query, String replacement) {
    final selection = textController.selection;
    if (!selection.isValid || selection.isCollapsed) return false;
    final selected = selection.textInside(textController.text);
    if (selected != query) return false;

    final value = textController.text.replaceRange(
      selection.start,
      selection.end,
      replacement,
    );
    _replaceText(value);
    _recordCurrentText();
    textController.selection = TextSelection.collapsed(
      offset: selection.start + replacement.length,
    );
    return true;
  }

  int replaceAll(String query, String replacement) {
    if (query.isEmpty) return 0;
    final count = query.allMatches(textController.text).length;
    if (count == 0) return 0;
    _replaceText(textController.text.replaceAll(query, replacement));
    _recordCurrentText();
    return count;
  }

  void _handleTextChanged() {
    if (_applyingHistory || _isLoading) return;
    _recordCurrentText();
  }

  void _recordCurrentText() {
    final text = textController.text;
    if (_historyIndex >= 0 && _history[_historyIndex] == text) return;

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(text);
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
    _syncDirtyState();
  }

  void _replaceText(String text) {
    _applyingHistory = true;
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _applyingHistory = false;
  }

  void _syncDirtyState() {
    _hasChanges = textController.text != _savedText;
    onDirtyChanged?.call(_hasChanges);
    final broker = documentBroker;
    final lease = documentLease;
    if (broker != null && lease != null && broker.containsToken(lease.token)) {
      broker.setDirty(lease.token, _hasChanges);
    }
    _saveError = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (!_disposed) notifyListeners();
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    if (autoSaveInterval <= Duration.zero) return;
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) {
      if (_hasChanges && !_isSaving && !_isSavingDraft) {
        unawaited(saveDraft());
      }
    });
  }

  Future<void> _clearSecureString(String text) async {
    if (text.isEmpty) return;
    try {
      NativeLib.instance.clearSecureMemory(base64Encode(utf8.encode(text)));
    } catch (_) {
      // VM-managed String storage cannot be cleared in place.
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _autoSaveTimer?.cancel();
    final broker = documentBroker;
    final lease = documentLease;
    if (broker != null && lease != null) broker.close(lease.token);

    final values = <String>{
      textController.text,
      _savedText,
      if (_lastDraftText != null) _lastDraftText!,
      if (_recoveryDraftText != null) _recoveryDraftText!,
      ..._history,
    };
    textController
      ..removeListener(_handleTextChanged)
      ..clear()
      ..dispose();
    focusNode.dispose();
    _history.clear();
    _savedText = '';
    _lastDraftText = null;
    _recoveryDraftText = null;
    for (final value in values) {
      unawaited(_clearSecureString(value));
    }
    super.dispose();
  }
}

class FindResult {
  const FindResult({required this.current, required this.total});

  final int current;
  final int total;
}
