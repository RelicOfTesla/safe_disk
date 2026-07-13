import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/secure_clipboard_service.dart';

void main() {
  test('copy and cut record an explicit clipboard operation', () {
    final clipboard = SecureClipboardService();
    const entry = SecureClipboardEntry(
      sourcePath: '/note.txt',
      sourceSessionID: '7',
      name: 'note.txt',
      isDirectory: false,
      operation: SecureClipboardOperation.move,
    );

    clipboard.copy(entry);
    expect(clipboard.entry?.operation, SecureClipboardOperation.copy);
    expect(clipboard.entry?.isMove, isFalse);

    clipboard.cut(entry);
    expect(clipboard.entry?.operation, SecureClipboardOperation.move);
    expect(clipboard.entry?.isMove, isTrue);

    clipboard.copyAll([entry, entry]);
    expect(clipboard.entryCount, 2);
    expect(clipboard.entries.every((item) => !item.isMove), isTrue);
    clipboard.remove(clipboard.entries.first);
    expect(clipboard.entryCount, 1);

    clipboard.cutAll([entry, entry]);
    expect(clipboard.entryCount, 2);
    expect(clipboard.entries.every((item) => item.isMove), isTrue);

    clipboard.clear();
    expect(clipboard.hasEntry, isFalse);
  });
}
