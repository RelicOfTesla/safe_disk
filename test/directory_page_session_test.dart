import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_page_session.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';

void main() {
  test('accumulates pages, filters drafts, and closes at EOF', () async {
    final gateway = _Gateway([
      DirectoryCursorPageData(
          entries: [_entry('a'), _entry(_draft)], done: false),
      DirectoryCursorPageData(entries: [_entry('b')], done: true),
    ]);
    final session = DirectoryPageSession(
        gateway: gateway, rootID: 7, relativePath: 'notes');

    await session.loadNext(limit: 2);
    await session.loadNext(limit: 2);

    expect(session.entries.map((entry) => entry.name), ['a', 'b']);
    expect(session.done, isTrue);
    expect(gateway.opens, 1);
    expect(gateway.closes, [9]);
  });

  test('closes cursor when a page read fails', () async {
    final gateway = _Gateway([], readError: StateError('corrupt'));
    final session =
        DirectoryPageSession(gateway: gateway, rootID: 7, relativePath: '');

    await expectLater(session.loadNext(), throwsStateError);
    expect(session.error, isA<StateError>());
    expect(gateway.closes, [9]);

    await session.loadNext();
    expect(gateway.opens, 1);
    expect(gateway.closes, [9]);
  });

  test('tree mode keeps only the latest visible page', () async {
    final gateway = _Gateway([
      DirectoryCursorPageData(
          entries: [_entry('a'), _entry(_draft)], done: false),
      DirectoryCursorPageData(entries: [_entry('b')], done: true),
    ]);
    final session = DirectoryPageSession(
      gateway: gateway,
      rootID: 7,
      relativePath: '',
      retainEntries: false,
    );

    await session.loadNext();
    expect(session.entries, isEmpty);
    expect(session.latestPageEntries.map((entry) => entry.name), ['a']);

    await session.loadNext();
    expect(session.entries, isEmpty);
    expect(session.latestPageEntries.map((entry) => entry.name), ['b']);
  });
}

const _draft = '${SecureNotepadDraftStore.internalNamePrefix}draft';

DirEntry _entry(String name) => DirEntry(
    name: name, isDir: false, size: 1, modTime: 1, mode: 0, path: name);

class _Gateway implements DirectoryCursorGateway {
  _Gateway(this.pages, {this.readError});

  final List<DirectoryCursorPageData> pages;
  final Object? readError;
  int opens = 0;
  final List<int> closes = [];

  @override
  Future<void> close(int cursorID) async => closes.add(cursorID);

  @override
  Future<int> open(int rootID, String relativePath) async {
    opens++;
    return 9;
  }

  @override
  Future<DirectoryCursorPageData> readPage(int cursorID, int limit) async {
    if (readError != null) throw readError!;
    return pages.removeAt(0);
  }
}
