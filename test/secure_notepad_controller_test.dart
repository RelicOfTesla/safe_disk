import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/controllers/secure_notepad_controller.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/document_session_broker.dart';
import 'package:safe_disk/services/root_close_coordinator.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads, edits, undoes, redoes and saves encrypted text', () async {
    final service = _FakeCryptoService('initial text');
    final controller = _controller(service);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.textController.text, 'initial text');
    expect(controller.hasChanges, isFalse);

    controller.textController.text = 'edited text';
    expect(controller.hasChanges, isTrue);
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.textController.text, 'initial text');
    expect(controller.hasChanges, isFalse);

    controller.redo();
    expect(controller.textController.text, 'edited text');
    expect(controller.hasChanges, isTrue);

    expect(await controller.save(), isTrue);
    expect(controller.hasChanges, isFalse);
    expect(service.writes.single, 'edited text');
  });

  test('keeps dirty state when encrypted save fails', () async {
    final service = _FakeCryptoService('initial', writeError: 'disk full');
    final controller = _controller(service);
    addTearDown(controller.dispose);
    await controller.load();

    controller.textController.text = 'unsaved';
    expect(await controller.save(), isFalse);
    expect(controller.hasChanges, isTrue);
    expect(controller.saveError, contains('disk full'));
  });

  test('rejects obvious binary content opened by the fallback notepad',
      () async {
    final controller = _controller(_FakeCryptoService('MZ\x00binary'));
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.loadError, SecureNotepadLoadError.binaryContent);
    expect(controller.loadTechnicalError,
        'FormatException: binary-content-nul-byte');
    expect(controller.textController.text, isEmpty);
  });

  test('keeps a failed load diagnostic separate from user-facing text',
      () async {
    final controller = _controller(_FailingReadCryptoService());
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.loadError, SecureNotepadLoadError.readFailed);
    expect(controller.loadTechnicalError, contains('private-note-path'));
  });

  test('keeps a failed draft save diagnostic separate from status text',
      () async {
    final service = _FakeCryptoService('initial');
    final controller = _controller(
      service,
      draftStore: _FailingDraftStore(service),
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.textController.text = 'edited';
    expect(await controller.saveDraft(), isFalse);
    expect(controller.draftError, SecureNotepadDraftError.saveRecoveryDraft);
    expect(controller.draftTechnicalError, contains('private-draft-path'));
  });

  test('supports read-only toggle and find/replace history', () async {
    final controller = _controller(
      _FakeCryptoService('alpha beta alpha'),
      initiallyReadOnly: true,
    );
    addTearDown(controller.dispose);
    await controller.load();

    expect(controller.isReadOnly, isTrue);
    controller.toggleReadOnly();
    expect(controller.isReadOnly, isFalse);

    expect(controller.findNext('alpha'), isTrue);
    expect(controller.replaceSelection('alpha', 'gamma'), isTrue);
    expect(controller.textController.text, 'gamma beta alpha');
    expect(controller.replaceAll('alpha', 'delta'), 1);
    expect(controller.textController.text, 'gamma beta delta');

    controller.undo();
    expect(controller.textController.text, 'gamma beta alpha');
  });

  test('read-only mode disables undo and redo', () async {
    final controller = _controller(_FakeCryptoService('initial'));
    addTearDown(controller.dispose);
    await controller.load();

    controller.textController.text = 'changed';
    expect(controller.canUndo, isTrue);
    controller.toggleReadOnly();
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);

    controller.undo();
    expect(controller.textController.text, 'changed');
  });

  test('periodically saves an encrypted draft without overwriting the source',
      () async {
    final service = _FakeCryptoService('initial');
    final controller = _controller(
      service,
      autoSaveInterval: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    await controller.load();

    controller.textController.text = 'auto saved';
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(service.originalWrites, isEmpty);
    expect(service.draftWrites, ['auto saved']);
    expect(controller.hasChanges, isTrue);
    expect(controller.hasDraftBackup, isTrue);
  });

  test('restores a draft and explicit save removes it', () async {
    final service = _FakeCryptoService('original');
    final draftPath = SecureNotepadDraftStore.draftPathFor('/vault/note.txt');
    service.files[draftPath] = 'recovered text';
    final controller = _controller(service);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.hasRecoveryDraft, isTrue);
    expect(controller.textController.text, 'original');

    controller.restoreRecoveryDraft();
    expect(controller.textController.text, 'recovered text');
    expect(controller.hasChanges, isTrue);
    expect(await controller.save(), isTrue);

    expect(service.originalWrites, ['recovered text']);
    expect(service.files.containsKey(draftPath), isFalse);
    expect(controller.hasDraftBackup, isFalse);
  });

  test('broker tracks dirty leases and rejects stale notepad saves', () async {
    final service = _FakeCryptoService('original');
    final broker = DocumentSessionBroker(cryptoService: service);
    final closeCoordinator = RootCloseCoordinator(broker);
    final firstLease = broker.open(
      rootSessionID: '7',
      path: '/vault/note.txt',
      displayName: 'note.txt',
    );
    final secondLease = broker.open(
      rootSessionID: '7',
      path: '/vault/note.txt',
      displayName: 'note.txt',
    );
    final first = _controller(
      service,
      documentBroker: broker,
      documentLease: firstLease,
    );
    final second = _controller(
      service,
      documentBroker: broker,
      documentLease: secondLease,
    );

    await first.load();
    await second.load();
    first.textController.text = 'first window';
    expect(
      closeCoordinator.inspect('7').disposition,
      RootCloseDisposition.blockedByUnsavedDocuments,
    );
    expect(await first.save(), isTrue);

    second.textController.text = 'stale second window';
    expect(await second.save(), isFalse);
    expect(
      second.saveError,
      'document-session-conflict:externalModification',
    );
    expect(service.files['/vault/note.txt'], 'first window');

    first.dispose();
    second.dispose();
    expect(closeCoordinator.inspect('7').windowCount, 0);
  });
}

SecureNotepadController _controller(
  CryptoService service, {
  Duration autoSaveInterval = Duration.zero,
  bool initiallyReadOnly = false,
  SecureNotepadDraftStore? draftStore,
  DocumentSessionBroker? documentBroker,
  DocumentLease? documentLease,
}) {
  return SecureNotepadController(
    file: EncryptedFile(
      name: 'note.txt',
      encryptedPath: '/vault/note.txt',
      modifiedTime: DateTime(2026),
    ),
    cryptoService: service,
    tempKeyID: '7',
    autoSaveInterval: autoSaveInterval,
    initiallyReadOnly: initiallyReadOnly,
    draftStore: draftStore,
    documentBroker: documentBroker,
    documentLease: documentLease,
  );
}

class _FakeCryptoService extends CryptoService {
  _FakeCryptoService(this.initialText, {this.writeError}) {
    files['/vault/note.txt'] = initialText;
  }

  final String initialText;
  final String? writeError;
  final List<String> writes = [];
  final List<({String path, String content})> pathWrites = [];
  final Map<String, String> files = {};

  List<String> get originalWrites => pathWrites
      .where((write) => write.path == '/vault/note.txt')
      .map((write) => write.content)
      .toList();

  List<String> get draftWrites => pathWrites
      .where((write) => SecureNotepadDraftStore.isDraftName(
            write.path.split('/').last,
          ))
      .map((write) => write.content)
      .toList();

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    final content = files[path];
    if (content == null) throw StateError('missing file: $path');
    return Uint8List.fromList(content.codeUnits);
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (writeError != null) throw StateError(writeError!);
    final content = String.fromCharCodes(data);
    writes.add(content);
    pathWrites.add((path: path, content: content));
    files[path] = content;
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

class _FailingReadCryptoService extends CryptoService {
  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    throw StateError('cannot read /private-note-path/note.txt');
  }
}

class _FailingDraftStore extends SecureNotepadDraftStore {
  _FailingDraftStore(CryptoService cryptoService)
      : super(cryptoService: cryptoService);

  @override
  Future<void> write(
    String sourcePath,
    String tempKeyID,
    String content,
  ) =>
      Future<void>.error(StateError('cannot write /private-draft-path'));
}
