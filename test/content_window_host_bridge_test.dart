import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/content_window_host_bridge.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/document_session_broker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('opens a native window without exposing root IDs or file paths',
      () async {
    final crypto = _BridgeCryptoService('initial');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final lease = broker.open(
      rootSessionID: 'root-secret',
      path: '/private/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);

    expect(await bridge.openNotepad(lease, localePreference: 'en'), isTrue);
    expect(platform.opened, hasLength(1));
    final request = platform.opened.single;
    expect(request.keys, {'token', 'documentID', 'title', 'localePreference'});
    expect(request['localePreference'], 'en');
    expect(request.values, isNot(contains('root-secret')));
    expect(request.values, isNot(contains('/private/note.txt')));
  });

  test('window requests content, draft, dirty state and close through broker',
      () async {
    final crypto = _BridgeCryptoService('initial');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    final read = await platform.call('document.read', {
      'token': lease.token,
    }) as Map;
    expect(utf8.decode(read['content'] as Uint8List), 'initial');

    await platform.call('document.setDirty', {
      'token': lease.token,
      'dirty': true,
    });
    expect(broker.summarizeRoot('7').hasDirtyWindows, isTrue);

    final draft = Uint8List.fromList(utf8.encode('recovery'));
    await platform.call('document.draftWrite', {
      'token': lease.token,
      'content': draft,
    });
    expect(
      utf8.decode(await platform.call('document.draftRead', {
        'token': lease.token,
      }) as Uint8List),
      'recovery',
    );
    await platform.call('document.draftDelete', {'token': lease.token});
    expect(
      await platform.call('document.draftRead', {'token': lease.token}),
      isNull,
    );

    final saved = await platform.call('document.save', {
      'token': lease.token,
      'revision': read['revision'],
      'content': Uint8List.fromList(utf8.encode('from native window')),
    }) as Map;
    expect(saved['revision'], isNot(read['revision']));
    expect(crypto.content, 'from native window');

    await platform.call('document.closed', {'token': lease.token});
    expect(broker.containsToken(lease.token), isFalse);
  });

  test('returns stable protocol markers for invalid window calls', () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'en');

    await expectLater(
      platform.call('document.save', {'token': lease.token}),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'invalid_request')
            .having(
              (error) => error.message,
              'message',
              'invalid-document-save-payload',
            ),
      ),
    );
    await expectLater(
      platform.call('document.unknown', {'token': lease.token}),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'unsupported_method')
            .having(
              (error) => error.message,
              'message',
              'unsupported-content-window-method',
            ),
      ),
    );
  });

  test('releases a lease when a native window disappears unexpectedly',
      () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    platform.alive.add({lease.token});
    await Future<void>.delayed(Duration.zero);
    platform.alive.add({});
    await Future<void>.delayed(Duration.zero);

    expect(broker.containsToken(lease.token), isFalse);
  });

  test('requests native windows to close before releasing root leases',
      () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    await bridge.closeRootWindows('7');

    expect(platform.closedTokens, {lease.token});
    expect(broker.containsToken(lease.token), isFalse);
  });

  test('blocks a root token while the native window close completes', () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');
    platform.onCloseTokens = (tokens) async {
      expect(tokens, {lease.token});
      await expectLater(
        platform.call('document.read', {'token': lease.token}),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'session_not_found',
          ),
        ),
      );
    };

    await bridge.closeRootWindows('7');

    expect(broker.containsToken(lease.token), isFalse);
  });

  test('keeps a prepared lease when native close fails', () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform()
      ..onCloseTokens = (_) async => throw StateError('close failed');
    final bridge = ContentWindowHostBridge(broker: broker, platform: platform);
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    expect(await bridge.prepareAndCloseRootWindows('7'), isFalse);
    expect(platform.preparedTokens, {lease.token});
    expect(platform.cancelledTokens, {lease.token});
    expect(broker.containsToken(lease.token), isTrue);

    final read = await platform.call('document.read', {
      'token': lease.token,
    }) as Map;
    expect(utf8.decode(read['content'] as Uint8List), 'initial');
  });

  test('keeps a lease when manual native close fails', () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform()
      ..onCloseTokens = (_) async => throw StateError('close failed');
    final bridge = ContentWindowHostBridge(broker: broker, platform: platform);
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    await expectLater(
      bridge.closeRootWindows('7'),
      throwsA(isA<StateError>()),
    );
    expect(broker.containsToken(lease.token), isTrue);
    final read = await platform.call('document.read', {
      'token': lease.token,
    }) as Map;
    expect(utf8.decode(read['content'] as Uint8List), 'initial');
  });

  test('prepares every content window before revoking its root capability',
      () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(broker: broker, platform: platform);
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');
    platform.onPrepareToken = (token, requestID) async {
      expect(token, lease.token);
      expect(requestID, isNotEmpty);
      expect(broker.containsToken(token), isTrue);
      return ContentWindowLockResponse(
        token: token,
        lockRequestID: requestID,
        prepared: true,
      );
    };

    expect(await bridge.prepareAndCloseRootWindows('7'), isTrue);
    expect(platform.preparedTokens, {lease.token});
    expect(platform.closedTokens, {lease.token});
    expect(broker.containsToken(lease.token), isFalse);
  });

  test('keeps every token open when any content window rejects lock prepare',
      () async {
    final broker = DocumentSessionBroker(
      cryptoService: _BridgeCryptoService('initial'),
    );
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform()..prepareResult = false;
    final bridge = ContentWindowHostBridge(broker: broker, platform: platform);
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');

    expect(await bridge.prepareAndCloseRootWindows('7'), isFalse);
    expect(platform.closedTokens, isEmpty);
    expect(platform.cancelledTokens, {lease.token});
    expect(broker.containsToken(lease.token), isTrue);
  });

  test('waits for an accepted save before closing the native root window',
      () async {
    final crypto = _DelayedWriteBridgeCryptoService('initial');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final lease = broker.open(
      rootSessionID: '7',
      path: '/note.txt',
      displayName: 'note.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(lease, localePreference: 'zh');
    final snapshot = await platform.call('document.read', {
      'token': lease.token,
    }) as Map;
    final saving = platform.call('document.save', {
      'token': lease.token,
      'revision': snapshot['revision'],
      'content': Uint8List.fromList(utf8.encode('saved before close')),
    });
    await crypto.writeStarted.future;

    final closing = bridge.closeRootWindows('7');
    await Future<void>.delayed(Duration.zero);
    expect(platform.closedTokens, isEmpty);
    await expectLater(
      platform.call('document.setDirty', {
        'token': lease.token,
        'dirty': true,
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'session_not_found',
        ),
      ),
    );

    crypto.allowWrite.complete();
    await saving;
    await closing;

    expect(crypto.content, 'saved before close');
    expect(platform.closedTokens, {lease.token});
    expect(broker.containsToken(lease.token), isFalse);
  });

  test('keeps every lease when a native window opens while a save drains',
      () async {
    final crypto = _DelayedWriteBridgeCryptoService('initial');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final first = broker.open(
      rootSessionID: '7',
      path: '/first.txt',
      displayName: 'first.txt',
    );
    final second = broker.open(
      rootSessionID: '7',
      path: '/second.txt',
      displayName: 'second.txt',
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);
    await bridge.openNotepad(first, localePreference: 'zh');
    final snapshot = await platform.call('document.read', {
      'token': first.token,
    }) as Map;
    final saving = platform.call('document.save', {
      'token': first.token,
      'revision': snapshot['revision'],
      'content': Uint8List.fromList(utf8.encode('saved before close')),
    });
    await crypto.writeStarted.future;

    final closing = bridge.prepareAndCloseRootWindows('7');
    await Future<void>.delayed(Duration.zero);
    expect(platform.preparedTokens, {first.token});
    expect(await bridge.openNotepad(second, localePreference: 'zh'), isTrue);
    crypto.allowWrite.complete();
    await saving;

    expect(await closing, isFalse);
    expect(platform.closedTokens, isEmpty);
    expect(platform.cancelledTokens, {first.token});
    expect(broker.containsToken(first.token), isTrue);
    expect(broker.containsToken(second.token), isTrue);
    final read = await platform.call('document.read', {
      'token': first.token,
    }) as Map;
    expect(utf8.decode(read['content'] as Uint8List), 'saved before close');
  });

  test('opens an image window through the same capability boundary', () async {
    final crypto = _BridgeCryptoService('image-bytes');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final lease = broker.open(
      rootSessionID: 'root-secret',
      path: '/private/image.png',
      displayName: 'image.png',
      knownContentBytes: 11,
      maxContentBytes: 11,
      readOnly: true,
    );
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);

    expect(await bridge.openImage(lease, localePreference: 'en'), isTrue);
    expect(platform.openedImages.single, {
      'token': lease.token,
      'documentID': lease.documentID,
      'title': 'image.png',
      'localePreference': 'en',
    });

    await expectLater(
      platform.call('document.save', {
        'token': lease.token,
        'revision': lease.snapshot.revision,
        'content': Uint8List.fromList([1]),
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'read_only',
        ),
      ),
    );

    crypto.content = 'image-bytes-expanded';
    await expectLater(
      platform.call('document.read', {'token': lease.token}),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'content_too_large',
        ),
      ),
    );
  });

  test('parses legacy and locale-snapshot content window arguments', () {
    final valid = jsonEncode({
      'version': 1,
      'kind': 'secure_notepad',
      'token': 'token',
      'documentID': 'document',
      'title': 'note.txt',
    });
    expect(
      DesktopMultiWindowPlatform.tryParseArguments(valid)?.title,
      'note.txt',
    );
    final image = DesktopMultiWindowPlatform.tryParseArguments(jsonEncode({
      'version': 1,
      'kind': 'secure_image',
      'token': 'token',
      'documentID': 'document',
      'title': 'image.png',
    }));
    expect(image?.kind, DesktopMultiWindowPlatform.imageWindowKind);
    expect(image?.localePreference, isNull);
    final current = DesktopMultiWindowPlatform.tryParseArguments(jsonEncode({
      'version': 2,
      'kind': 'secure_notepad',
      'token': 'token',
      'documentID': 'document',
      'title': 'note.txt',
      'localePreference': 'en',
    }));
    expect(current?.localePreference, 'en');
    expect(
      DesktopMultiWindowPlatform.tryParseArguments(
        jsonEncode({'version': 3, 'kind': 'secure_notepad'}),
      ),
      isNull,
    );
    expect(DesktopMultiWindowPlatform.tryParseArguments('not-json'), isNull);
  });

  test('touchActivity invokes the onActivity callback with the token', () async {
    final crypto = _BridgeCryptoService('content');
    final broker = DocumentSessionBroker(cryptoService: crypto);
    final platform = _FakeContentWindowPlatform();
    final bridge = ContentWindowHostBridge(
      broker: broker,
      platform: platform,
    );
    addTearDown(bridge.dispose);

    final lease = broker.open(
      rootSessionID: 'root-1',
      path: '/note.txt',
      displayName: 'note.txt',
    );

    // Start the bridge so the handler is registered
    await bridge.start();

    String? receivedToken;
    bridge.onActivity = (token) {
      receivedToken = token;
    };

    // Simulate a content window calling touchActivity
    await platform.call('document.touchActivity', {'token': lease.token});

    expect(receivedToken, lease.token);
  });
}

class _FakeContentWindowPlatform implements ContentWindowPlatform {
  final List<Map<String, String>> opened = [];
  final List<Map<String, String>> openedImages = [];
  final StreamController<Set<String>> alive =
      StreamController<Set<String>>.broadcast();
  ContentWindowCallHandler? handler;
  Future<void> Function(Set<String> tokens)? onCloseTokens;
  Future<ContentWindowLockResponse> Function(String token, String requestID)?
      onPrepareToken;
  Set<String> preparedTokens = {};
  Set<String> cancelledTokens = {};
  bool prepareResult = true;
  Set<String> closedTokens = {};

  @override
  Stream<Set<String>> get aliveTokens => alive.stream;

  @override
  Future<bool> openNotepad({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) async {
    opened.add({
      'token': token,
      'documentID': documentID,
      'title': title,
      'localePreference': localePreference,
    });
    return true;
  }

  @override
  Future<bool> openImage({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) async {
    openedImages.add({
      'token': token,
      'documentID': documentID,
      'title': title,
      'localePreference': localePreference,
    });
    return true;
  }

  @override
  Future<void> closeTokens(Set<String> tokens) async {
    closedTokens = {...tokens};
    await onCloseTokens?.call(tokens);
  }

  @override
  Future<ContentWindowLockResponse> prepareTokenForLock({
    required String token,
    required String lockRequestID,
  }) async {
    preparedTokens = {...preparedTokens, token};
    return onPrepareToken?.call(token, lockRequestID) ??
        ContentWindowLockResponse(
          token: token,
          lockRequestID: lockRequestID,
          prepared: prepareResult,
        );
  }

  @override
  Future<void> cancelTokenLock({
    required String token,
    required String lockRequestID,
  }) async {
    cancelledTokens = {...cancelledTokens, token};
  }

  @override
  Future<void> setHostHandler(ContentWindowCallHandler? handler) async {
    this.handler = handler;
  }

  Future<Object?> call(String method, Object? arguments) {
    return handler!(MethodCall(method, arguments));
  }
}

class _BridgeCryptoService extends CryptoService {
  _BridgeCryptoService(this.content);

  String content;
  Uint8List? draft;

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    if (path.contains('.__safedisk_notepad_draft_')) return draft!;
    return Uint8List.fromList(utf8.encode(content));
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (path.contains('.__safedisk_notepad_draft_')) {
      draft = Uint8List.fromList(data);
    } else {
      content = utf8.decode(data);
    }
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    return !path.contains('.__safedisk_notepad_draft_') || draft != null;
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    draft = null;
  }
}

class _DelayedWriteBridgeCryptoService extends _BridgeCryptoService {
  _DelayedWriteBridgeCryptoService(super.content);

  final writeStarted = Completer<void>();
  final allowWrite = Completer<void>();

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
