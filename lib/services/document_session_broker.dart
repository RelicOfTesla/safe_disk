import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'crypto_service.dart';
import 'secure_notepad_draft_store.dart';

class DocumentSessionConflict implements Exception {
  const DocumentSessionConflict(this.message);

  final String message;

  @override
  String toString() => message;
}

class DocumentSessionNotFound implements Exception {
  const DocumentSessionNotFound();

  @override
  String toString() => '内容窗口会话不存在或已经关闭';
}

class DocumentContentLimitExceeded implements Exception {
  const DocumentContentLimitExceeded(this.maxBytes);

  final int maxBytes;

  @override
  String toString() => '内容超过允许的 $maxBytes 字节上限';
}

class DocumentSessionReadOnly implements Exception {
  const DocumentSessionReadOnly();

  @override
  String toString() => '当前内容窗口会话为只读';
}

class DocumentSnapshot {
  const DocumentSnapshot({
    required this.content,
    required this.revision,
  });

  final Uint8List content;
  final int revision;
}

class DocumentLease {
  const DocumentLease({
    required this.token,
    required this.documentID,
    required this.displayName,
    required this.snapshot,
  });

  final String token;
  final String documentID;
  final String displayName;
  final DocumentSnapshot snapshot;
}

class RootLeaseSummary {
  const RootLeaseSummary({
    required this.windowCount,
    required this.dirtyDocumentNames,
    required this.activeWriteCount,
  });

  final int windowCount;
  final List<String> dirtyDocumentNames;
  final int activeWriteCount;

  bool get hasWindows => windowCount > 0;
  bool get hasDirtyWindows => dirtyDocumentNames.isNotEmpty;
  bool get hasActiveWrites => activeWriteCount > 0;
}

/// Owns document-window capabilities without exposing root IDs to window code.
///
/// Revisions are backed by exact byte snapshots. A save re-reads the encrypted
/// file and rejects stale writers before writing, so timestamp granularity and
/// hash collisions cannot silently overwrite another window's changes.
class DocumentSessionBroker {
  DocumentSessionBroker({
    required CryptoService cryptoService,
    Random? secureRandom,
  })  : _cryptoService = cryptoService,
        _random = secureRandom ?? Random.secure();

  final CryptoService _cryptoService;
  final Random _random;
  final Map<String, _DocumentSession> _sessions = {};
  final Map<String, String> _documentIDs = {};
  final Map<String, Future<void>> _saveQueues = {};
  int _nextRevision = 1;

  DocumentLease open({
    required String rootSessionID,
    required String path,
    required String displayName,
    int? knownContentBytes,
    int? maxContentBytes,
    bool readOnly = false,
  }) {
    if (maxContentBytes != null &&
        knownContentBytes != null &&
        knownContentBytes > maxContentBytes) {
      throw DocumentContentLimitExceeded(maxContentBytes);
    }
    final content = Uint8List.fromList(
      _cryptoService.decryptFileToData(path, rootSessionID),
    );
    if (maxContentBytes != null && content.length > maxContentBytes) {
      content.fillRange(0, content.length, 0);
      throw DocumentContentLimitExceeded(maxContentBytes);
    }
    final token = _newToken();
    final documentKey = '$rootSessionID\u0000$path';
    final documentID = _documentIDs.putIfAbsent(documentKey, _newToken);
    final session = _DocumentSession(
      token: token,
      documentID: documentID,
      rootSessionID: rootSessionID,
      path: path,
      displayName: displayName,
      baseContent: content,
      revision: _nextRevision++,
      maxContentBytes: maxContentBytes,
      readOnly: readOnly,
    );
    _sessions[token] = session;
    return _leaseFor(session);
  }

  DocumentSnapshot read(String token) {
    final session = _requireSession(token);
    final content = Uint8List.fromList(
      _cryptoService.decryptFileToData(session.path, session.rootSessionID),
    );
    if (session.maxContentBytes case final maxBytes?) {
      if (content.length > maxBytes) {
        content.fillRange(0, content.length, 0);
        throw DocumentContentLimitExceeded(maxBytes);
      }
    }
    _replaceBaseContent(session, content);
    session
      ..revision = _nextRevision++
      ..dirty = false;
    return _snapshotFor(session);
  }

  Future<DocumentSnapshot> save({
    required String token,
    required int baseRevision,
    required List<int> content,
    bool force = false,
  }) {
    final session = _requireSession(token);
    _requireEditable(session);
    if (session.maxContentBytes case final maxBytes?) {
      if (content.length > maxBytes) {
        throw DocumentContentLimitExceeded(maxBytes);
      }
    }
    session.pendingWrites++;
    final completer = Completer<DocumentSnapshot>();
    final previous = _saveQueues[session.documentID] ?? Future<void>.value();
    late final Future<void> queued;
    queued = previous.then((_) async {
      try {
        completer.complete(await _saveNow(
          session: session,
          baseRevision: baseRevision,
          content: content,
          force: force,
        ));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        session.pendingWrites--;
        if (session.closeRequested && session.pendingWrites == 0) {
          _removeSession(session.token);
        }
      }
    });
    _saveQueues[session.documentID] = queued;
    unawaited(queued.whenComplete(() {
      if (identical(_saveQueues[session.documentID], queued)) {
        _saveQueues.remove(session.documentID);
      }
    }));
    return completer.future;
  }

  Future<DocumentSnapshot> _saveNow({
    required _DocumentSession session,
    required int baseRevision,
    required List<int> content,
    required bool force,
  }) async {
    if (baseRevision != session.revision) {
      throw const DocumentSessionConflict('窗口内容版本已过期，请重新加载后再保存');
    }

    final current = _cryptoService.decryptFileToData(
      session.path,
      session.rootSessionID,
    );
    if (!force && !_bytesEqual(current, session.baseContent)) {
      throw const DocumentSessionConflict('文件已被另一个窗口修改，已阻止覆盖');
    }

    await _cryptoService.writeFileBySession(
      session.path,
      session.rootSessionID,
      content,
    );
    _replaceBaseContent(session, Uint8List.fromList(content));
    session
      ..revision = _nextRevision++
      ..dirty = false;
    return _snapshotFor(session);
  }

  void setDirty(String token, bool dirty) {
    final session = _requireSession(token);
    _requireEditable(session);
    session.dirty = dirty;
  }

  Future<Uint8List?> readDraft(String token) async {
    final session = _requireSession(token);
    _requireEditable(session);
    final path = SecureNotepadDraftStore.draftPathFor(session.path);
    if (!await _cryptoService.fileExistsBySession(
      path,
      session.rootSessionID,
    )) {
      return null;
    }
    return Uint8List.fromList(
      _cryptoService.decryptFileToData(path, session.rootSessionID),
    );
  }

  Future<void> writeDraft(String token, List<int> content) {
    final session = _requireSession(token);
    _requireEditable(session);
    return _cryptoService.writeFileBySession(
      SecureNotepadDraftStore.draftPathFor(session.path),
      session.rootSessionID,
      content,
    );
  }

  Future<void> deleteDraft(String token) async {
    final session = _requireSession(token);
    _requireEditable(session);
    final path = SecureNotepadDraftStore.draftPathFor(session.path);
    if (await _cryptoService.fileExistsBySession(
      path,
      session.rootSessionID,
    )) {
      await _cryptoService.deleteFileBySession(path, session.rootSessionID);
    }
  }

  void close(String token) {
    final session = _sessions[token];
    if (session == null) return;
    if (session.pendingWrites > 0) {
      session.closeRequested = true;
    } else {
      _removeSession(token);
    }
  }

  void closeRootSessions(String rootSessionID) {
    for (final session in _sessions.values
        .where((session) => session.rootSessionID == rootSessionID)
        .toList()) {
      close(session.token);
    }
    _documentIDs.removeWhere(
      (key, _) => key.startsWith('$rootSessionID\u0000'),
    );
  }

  RootLeaseSummary summarizeRoot(String rootSessionID) {
    final sessions = _sessions.values
        .where((session) => session.rootSessionID == rootSessionID)
        .toList();
    return RootLeaseSummary(
      windowCount: sessions.length,
      dirtyDocumentNames: sessions
          .where((session) => session.dirty)
          .map((session) => session.displayName)
          .toSet()
          .toList(growable: false),
      activeWriteCount: sessions.fold(
        0,
        (total, session) => total + session.pendingWrites,
      ),
    );
  }

  Set<String> tokensForRoot(String rootSessionID) => _sessions.values
      .where((session) => session.rootSessionID == rootSessionID)
      .map((session) => session.token)
      .toSet();

  bool containsToken(String token) => _sessions.containsKey(token);

  void _removeSession(String token) {
    final session = _sessions.remove(token);
    session?.baseContent.fillRange(0, session.baseContent.length, 0);
  }

  void _replaceBaseContent(_DocumentSession session, Uint8List content) {
    session.baseContent.fillRange(0, session.baseContent.length, 0);
    session.baseContent = content;
  }

  _DocumentSession _requireSession(String token) {
    final session = _sessions[token];
    if (session == null) throw const DocumentSessionNotFound();
    return session;
  }

  void _requireEditable(_DocumentSession session) {
    if (session.readOnly) throw const DocumentSessionReadOnly();
  }

  DocumentLease _leaseFor(_DocumentSession session) => DocumentLease(
        token: session.token,
        documentID: session.documentID,
        displayName: session.displayName,
        snapshot: _snapshotFor(session),
      );

  DocumentSnapshot _snapshotFor(_DocumentSession session) => DocumentSnapshot(
        content: Uint8List.fromList(session.baseContent),
        revision: session.revision,
      );

  String _newToken() {
    String token;
    do {
      final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
      token =
          bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    } while (_sessions.containsKey(token) || _documentIDs.containsValue(token));
    return token;
  }
}

class _DocumentSession {
  _DocumentSession({
    required this.token,
    required this.documentID,
    required this.rootSessionID,
    required this.path,
    required this.displayName,
    required this.baseContent,
    required this.revision,
    required this.maxContentBytes,
    required this.readOnly,
  });

  final String token;
  final String documentID;
  final String rootSessionID;
  final String path;
  final String displayName;
  Uint8List baseContent;
  int revision;
  final int? maxContentBytes;
  final bool readOnly;
  bool dirty = false;
  int pendingWrites = 0;
  bool closeRequested = false;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
