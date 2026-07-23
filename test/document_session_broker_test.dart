import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/document_session_broker.dart';
import 'package:safe_disk/services/root_close_coordinator.dart';

void main() {
  test('issues opaque tokens and keeps root session IDs inside the broker', () {
    final crypto = _MemoryCryptoService({'/note.txt': 'initial'});
    final broker = DocumentSessionBroker(
      cryptoService: crypto,
      secureRandom: Random(7),
    );

    final first = broker.open(
      rootSessionID: 'root-secret-17',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final second = broker.open(
      rootSessionID: 'root-secret-17',
      path: '/note.txt',
      displayName: 'note.txt',
    );

    expect(first.token, hasLength(32));
    expect(first.token, isNot(contains('root-secret-17')));
    expect(first.token, isNot(second.token));
    expect(first.documentID, second.documentID);
    expect(utf8.decode(first.snapshot.content), 'initial');
  });

  test('rejects stale same-file writers and allows save after reload',
      () async {
    final crypto = _MemoryCryptoService({'/note.txt': 'initial'});
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final first = broker.open(
      rootSessionID: '1',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final second = broker.open(
      rootSessionID: '1',
      path: '/note.txt',
      displayName: 'note.txt',
    );

    await broker.save(
      token: first.token,
      baseRevision: first.snapshot.revision,
      content: utf8.encode('first write'),
    );
    await expectLater(
      broker.save(
        token: second.token,
        baseRevision: second.snapshot.revision,
        content: utf8.encode('stale write'),
      ),
      throwsA(isA<DocumentSessionConflict>()),
    );
    expect(crypto.files['/note.txt'], 'first write');

    final reloaded = broker.read(second.token);
    await broker.save(
      token: second.token,
      baseRevision: reloaded.revision,
      content: utf8.encode('second write'),
    );
    expect(crypto.files['/note.txt'], 'second write');
  });

  test('content limit rejects before decrypt when size is known or unknown',
      () {
    final crypto = _MemoryCryptoService({'/image.png': '12345'});
    final broker = DocumentSessionBroker(cryptoService: crypto);

    expect(
      () => broker.open(
        rootSessionID: '1',
        path: '/image.png',
        displayName: 'image.png',
        knownContentBytes: 5,
        maxContentBytes: 4,
      ),
      throwsA(isA<DocumentContentLimitExceeded>()),
    );
    expect(crypto.readPaths, isEmpty);

    expect(
      () => broker.open(
        rootSessionID: '1',
        path: '/image.png',
        displayName: 'image.png',
        maxContentBytes: 4,
      ),
      throwsA(isA<DocumentContentSizeUnknown>()),
    );
    expect(crypto.readPaths, isEmpty);
    expect(broker.tokensForRoot('1'), isEmpty);
  });

  test('read-only content limit persists across child-window reads', () {
    final crypto = _MemoryCryptoService({'/image.png': '12345'});
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final lease = broker.open(
      rootSessionID: '1',
      path: '/image.png',
      displayName: 'image.png',
      maxContentBytes: 5,
      readOnly: true,
    );

    crypto.files['/image.png'] = '123456';
    expect(
      () => broker.read(lease.token),
      throwsA(isA<DocumentContentLimitExceeded>()),
    );
    expect(
      () => broker.save(
        token: lease.token,
        baseRevision: lease.snapshot.revision,
        content: utf8.encode('x'),
      ),
      throwsA(isA<DocumentSessionReadOnly>()),
    );
  });

  test('root close decisions distinguish clean and dirty window leases', () {
    final crypto = _MemoryCryptoService({'/a.txt': 'a', '/b.txt': 'b'});
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final coordinator = RootCloseCoordinator(broker);

    expect(
      coordinator.inspect('1').disposition,
      RootCloseDisposition.closeImmediately,
    );
    final first = broker.open(
      rootSessionID: '1',
      path: '/a.txt',
      displayName: 'a.txt',
    );
    broker.open(
      rootSessionID: '1',
      path: '/b.txt',
      displayName: 'b.txt',
    );
    expect(
      coordinator.inspect('1').disposition,
      RootCloseDisposition.confirmClosingWindows,
    );

    broker.setDirty(first.token, true);
    final blocked = coordinator.inspect('1');
    expect(blocked.disposition, RootCloseDisposition.blockedByUnsavedDocuments);
    expect(blocked.dirtyDocumentNames, ['a.txt']);

    coordinator.releaseRoot('1');
    expect(coordinator.inspect('1').windowCount, 0);
    expect(broker.containsToken(first.token), isFalse);
  });

  test('serializes concurrent saves and retains leases during active writes',
      () async {
    final crypto = _DelayedCryptoService({'/note.txt': 'initial'});
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final coordinator = RootCloseCoordinator(broker);
    final first = broker.open(
      rootSessionID: '1',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final second = broker.open(
      rootSessionID: '1',
      path: '/note.txt',
      displayName: 'note.txt',
    );

    final firstSave = broker.save(
      token: first.token,
      baseRevision: first.snapshot.revision,
      content: utf8.encode('first'),
    );
    await crypto.writeStarted.future;
    final secondSave = broker.save(
      token: second.token,
      baseRevision: second.snapshot.revision,
      content: utf8.encode('second'),
    );
    expect(
      coordinator.inspect('1').disposition,
      RootCloseDisposition.blockedByActiveWrites,
    );

    broker.close(first.token);
    expect(broker.containsToken(first.token), isTrue);
    crypto.allowWrite.complete();
    await firstSave;
    await expectLater(secondSave, throwsA(isA<DocumentSessionConflict>()));
    expect(crypto.files['/note.txt'], 'first');
    expect(broker.containsToken(first.token), isFalse);
  });
}

class _MemoryCryptoService extends CryptoService {
  _MemoryCryptoService(Map<String, String> files) : files = {...files};

  final Map<String, String> files;
  final List<String> readPaths = [];

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    readPaths.add(path);
    return Uint8List.fromList(utf8.encode(files[path]!));
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    files[path] = utf8.decode(data);
  }
}

class _DelayedCryptoService extends _MemoryCryptoService {
  _DelayedCryptoService(super.files);

  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> allowWrite = Completer<void>();

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await allowWrite.future;
    await super.writeFileBySession(path, tempKeyID, data);
  }
}
