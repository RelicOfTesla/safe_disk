import 'dart:typed_data';

import 'crypto_service.dart';
import 'document_window_client.dart';
import 'secure_notepad_draft_store.dart';

class RemoteDocumentCryptoService extends CryptoService {
  RemoteDocumentCryptoService({
    required DocumentWindowClient client,
    required RemoteDocumentSnapshot initialSnapshot,
  })  : _client = client,
        _content = Uint8List.fromList(initialSnapshot.content),
        _revision = initialSnapshot.revision;

  static const logicalSourcePath = '/document/content.txt';

  final DocumentWindowClient _client;
  Uint8List _content;
  int _revision;
  Uint8List? _draft;

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    if (_isDraft(path)) {
      final draft = _draft;
      if (draft == null) throw StateError('remote-document-draft-not-found');
      return Uint8List.fromList(draft);
    }
    return Uint8List.fromList(_content);
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (_isDraft(path)) {
      await _client.writeDraft(data);
      _draft = Uint8List.fromList(data);
      return;
    }
    final snapshot = await _client.save(_revision, data);
    _content = Uint8List.fromList(snapshot.content);
    _revision = snapshot.revision;
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    if (!_isDraft(path)) return true;
    _draft = await _client.readDraft();
    return _draft != null;
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    if (!_isDraft(path)) {
      throw UnsupportedError('remote-document-cannot-delete-source');
    }
    await _client.deleteDraft();
    _draft = null;
  }

  bool _isDraft(String path) {
    return SecureNotepadDraftStore.isDraftName(
      path.replaceAll('\\', '/').split('/').last,
    );
  }
}
