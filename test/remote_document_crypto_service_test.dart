import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/content_window_host_bridge.dart';
import 'package:safe_disk/services/document_window_client.dart';
import 'package:safe_disk/services/remote_document_crypto_service.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';
import 'package:safe_disk/windows/secure_notepad_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remote crypto routes source and encrypted draft operations to host',
      () async {
    final client = _FakeDocumentWindowClient('initial');
    final service = RemoteDocumentCryptoService(
      client: client,
      initialSnapshot: client.snapshot,
    );
    final draftPath = SecureNotepadDraftStore.draftPathFor(
      RemoteDocumentCryptoService.logicalSourcePath,
    );

    expect(
      utf8.decode(service.decryptFileToData(
        RemoteDocumentCryptoService.logicalSourcePath,
        client.token,
      )),
      'initial',
    );
    expect(await service.fileExistsBySession(draftPath, client.token), isFalse);

    await service.writeFileBySession(
      draftPath,
      client.token,
      utf8.encode('draft'),
    );
    expect(await service.fileExistsBySession(draftPath, client.token), isTrue);
    expect(
      utf8.decode(service.decryptFileToData(draftPath, client.token)),
      'draft',
    );

    await service.writeFileBySession(
      RemoteDocumentCryptoService.logicalSourcePath,
      client.token,
      utf8.encode('saved'),
    );
    expect(client.content, 'saved');
    expect(client.lastBaseRevision, 1);
    await service.deleteFileBySession(draftPath, client.token);
    expect(client.draft, isNull);
  });

  testWidgets('native notepad avoids channel calls while its engine disposes',
      (tester) async {
    final client = _FakeDocumentWindowClient('initial');
    final service = RemoteDocumentCryptoService(
      client: client,
      initialSnapshot: client.snapshot,
    );
    await tester.pumpWidget(SafeDiskNotepadWindow(
      arguments: ContentWindowArguments(
        kind: DesktopMultiWindowPlatform.notepadWindowKind,
        token: client.token,
        documentID: 'document-id',
        title: 'note.txt',
      ),
      client: client,
      cryptoService: service,
      autoSaveInterval: Duration.zero,
      initiallyReadOnly: true,
      initiallyMonitorClipboard: true,
    ));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('secure-notepad-editor')),
          )
          .readOnly,
      isTrue,
    );
    expect(find.byKey(const Key('secure-clipboard-monitor')), findsOneWidget);
    await tester.tap(find.byTooltip('开始编辑'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('secure-notepad-editor')),
      'native edit',
    );
    await tester.pump();
    expect(client.dirtyStates, contains(true));
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(client.content, 'native edit');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(client.closed, isFalse);
  });
}

class _FakeDocumentWindowClient extends DocumentWindowClient {
  _FakeDocumentWindowClient(this.content) : super('window-token');

  String content;
  Uint8List? draft;
  int revision = 1;
  int? lastBaseRevision;
  bool closed = false;
  final List<bool> dirtyStates = [];

  RemoteDocumentSnapshot get snapshot => RemoteDocumentSnapshot(
        content: Uint8List.fromList(utf8.encode(content)),
        revision: revision,
      );

  @override
  Future<RemoteDocumentSnapshot> read() async => snapshot;

  @override
  Future<RemoteDocumentSnapshot> save(
    int revision,
    List<int> content,
  ) async {
    lastBaseRevision = revision;
    this.content = utf8.decode(content);
    this.revision++;
    return snapshot;
  }

  @override
  Future<Uint8List?> readDraft() async {
    return draft == null ? null : Uint8List.fromList(draft!);
  }

  @override
  Future<void> writeDraft(List<int> content) async {
    draft = Uint8List.fromList(content);
  }

  @override
  Future<void> deleteDraft() async {
    draft = null;
  }

  @override
  Future<void> setDirty(bool dirty) async {
    dirtyStates.add(dirty);
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
