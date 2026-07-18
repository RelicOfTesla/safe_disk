import 'crypto_service.dart';
import 'secure_notepad_draft_store.dart';

abstract interface class DirectoryCursorGateway {
  Future<int> open(int rootID, String relativePath);
  Future<DirectoryCursorPageData> readPage(int cursorID, int limit);
  Future<void> close(int cursorID);
}

class DirectoryCursorPageData {
  const DirectoryCursorPageData({required this.entries, required this.done});

  final List<DirEntry> entries;
  final bool done;
}

class DirectoryPageSession {
  DirectoryPageSession({
    required this.gateway,
    required this.rootID,
    required this.relativePath,
    this.retainEntries = true,
  });

  final DirectoryCursorGateway gateway;
  final int rootID;
  final String relativePath;
  final bool retainEntries;
  int? _cursorID;
  bool _disposed = false;
  bool _loading = false;
  bool done = false;
  Object? error;
  final List<DirEntry> entries = [];
  List<DirEntry> latestPageEntries = const [];

  bool get hasError => error != null;

  Future<void> loadNext({int limit = 200}) async {
    // A failed cursor is closed. Continuing it would reopen at the first page
    // and append duplicate entries, so callers must create a fresh session.
    if (_disposed || _loading || done || hasError) return;
    _loading = true;
    try {
      var cursorID = _cursorID;
      if (cursorID == null) {
        cursorID = await gateway.open(rootID, relativePath);
        if (_disposed) {
          await gateway.close(cursorID);
          return;
        }
        _cursorID = cursorID;
      }
      final page = await gateway.readPage(cursorID, limit);
      if (_disposed) return;
      final visibleEntries = page.entries
          .where(
            (entry) => !SecureNotepadDraftStore.isDraftName(entry.name),
          )
          .toList(growable: false);
      latestPageEntries = visibleEntries;
      if (retainEntries) entries.addAll(visibleEntries);
      done = page.done;
      error = null;
      if (done) await _closeCursor();
    } catch (caught) {
      error = caught;
      await _closeCursor();
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _closeCursor();
  }

  Future<void> _closeCursor() async {
    final cursorID = _cursorID;
    _cursorID = null;
    if (cursorID != null) await gateway.close(cursorID);
  }
}
