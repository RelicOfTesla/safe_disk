import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';

void main() {
  test('uses a bounded sibling path and round-trips through root interfaces',
      () async {
    final crypto = _DraftCryptoService();
    final store = SecureNotepadDraftStore(cryptoService: crypto);
    const source = '/vault/notes/private.txt';

    final draftPath = SecureNotepadDraftStore.draftPathFor(source);
    expect(draftPath, startsWith('/vault/notes/'));
    expect(
      draftPath.split('/').last,
      startsWith(SecureNotepadDraftStore.internalNamePrefix),
    );
    expect(draftPath.length, lessThan(100));

    await store.write(source, '7', 'outage recovery');
    expect(await store.exists(source, '7'), isTrue);
    expect(await store.read(source, '7'), 'outage recovery');

    await store.delete(source, '7');
    expect(await store.exists(source, '7'), isFalse);
  });

  test('file listings hide internal notepad drafts', () async {
    final crypto = _DraftCryptoService();
    final entries = await FileService(cryptoService: crypto)
        .listCurrentDirectory('/vault/notes');

    expect(entries.map((entry) => entry.name), ['visible.txt']);
  });
}

class _DraftCryptoService extends CryptoService {
  final files = <String, List<int>>{};

  @override
  int? rootIDForPath(String path) => 7;

  @override
  String? rootPathForID(int rootID) => '/vault';

  @override
  String relativePathForRoot(int rootID, String path) {
    return path.startsWith('/vault/') ? path.substring('/vault/'.length) : '';
  }

  @override
  String absolutePathForRoot(int rootID, String relativePath) {
    return '/vault/$relativePath';
  }

  @override
  Future<List<DirEntry>> listDir(int rootID, String path) async {
    return [
      DirEntry(
        name: 'visible.txt',
        isDir: false,
        size: 1,
        modTime: 1,
        mode: 0,
        path: 'notes/visible.txt',
      ),
      DirEntry(
        name: '${SecureNotepadDraftStore.internalNamePrefix}abcd.bin',
        isDir: false,
        size: 8,
        modTime: 1,
        mode: 0,
        path: 'notes/draft',
      ),
    ];
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    files[path] = List<int>.from(data);
  }

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    final data = files[path];
    if (data == null) throw StateError('missing $path');
    return Uint8List.fromList(data);
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    return files.containsKey(path);
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    files.remove(path);
  }
}
