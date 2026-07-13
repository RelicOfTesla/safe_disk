enum SecureClipboardOperation { copy, move }

class SecureClipboardEntry {
  const SecureClipboardEntry({
    required this.sourcePath,
    required this.sourceSessionID,
    required this.name,
    required this.isDirectory,
    this.operation = SecureClipboardOperation.copy,
  });

  final String sourcePath;
  final String sourceSessionID;
  final String name;
  final bool isDirectory;
  final SecureClipboardOperation operation;

  bool get isMove => operation == SecureClipboardOperation.move;
}

/// In-memory clipboard for logical entries in currently open secure roots.
/// It deliberately does not expose plaintext or backing-store paths to the OS.
class SecureClipboardService {
  final List<SecureClipboardEntry> _entries = [];

  SecureClipboardEntry? get entry => _entries.isEmpty ? null : _entries.first;
  List<SecureClipboardEntry> get entries => List.unmodifiable(_entries);
  int get entryCount => _entries.length;
  bool get hasEntry => _entries.isNotEmpty;

  void copy(SecureClipboardEntry entry) {
    copyAll([entry]);
  }

  void cut(SecureClipboardEntry entry) {
    cutAll([entry]);
  }

  void copyAll(Iterable<SecureClipboardEntry> entries) {
    _replace(entries, SecureClipboardOperation.copy);
  }

  void cutAll(Iterable<SecureClipboardEntry> entries) {
    _replace(entries, SecureClipboardOperation.move);
  }

  void remove(SecureClipboardEntry entry) {
    _entries.remove(entry);
  }

  void removeSession(String sessionID) {
    _entries.removeWhere((entry) => entry.sourceSessionID == sessionID);
  }

  void _replace(
    Iterable<SecureClipboardEntry> entries,
    SecureClipboardOperation operation,
  ) {
    _entries
      ..clear()
      ..addAll(entries.map(
        (entry) => SecureClipboardEntry(
          sourcePath: entry.sourcePath,
          sourceSessionID: entry.sourceSessionID,
          name: entry.name,
          isDirectory: entry.isDirectory,
          operation: operation,
        ),
      ));
  }

  void clear() {
    _entries.clear();
  }
}
