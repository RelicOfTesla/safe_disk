import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/pages/home_page.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_persistence_service.dart';
import 'package:safe_disk/services/directory_service.dart';
import 'package:safe_disk/services/file_service.dart';

void main() {
  testWidgets('sidebar root is read only after password authentication',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('vault'), findsOneWidget);
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();

    expect(find.text('Enter password for:'), findsOneWidget);
    expect(fileService.listCalls, 0);
    expect(find.text('无法读取目录内容。'), findsNothing);

    await tester.enterText(find.byType(TextField), 'wrong-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Enter password for:'), findsOneWidget);
    expect(fileService.listCalls, 0);

    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(
      cryptoService.openedPasswords,
      ['wrong-password', 'correct-password'],
    );
    expect(fileService.listCalls, 1);
    expect(find.text('visible.txt'), findsOneWidget);
    expect(find.text('无法读取目录内容。'), findsNothing);
  });

  testWidgets('directory import waits for merge confirmation', (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService();
    final fileService = _FakeFileService(
      cryptoService,
      items: [
        FileSystemNode(
          name: 'incoming',
          path: '$rootPath/incoming',
          isDirectory: true,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '/outside/incoming',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Import Directory'));
    await tester.pumpAndSettle();

    expect(find.text('目标已存在'), findsOneWidget);
    expect(directoryService.importCalls, isEmpty);

    await tester.tap(find.text('继续导入'));
    await tester.pumpAndSettle();

    expect(directoryService.importCalls, [
      (rootID: 7, source: '/outside/incoming', destination: 'incoming'),
    ]);
  });

  testWidgets('directory import failure closes progress and keeps root open',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(importError: 'disk full');

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '/outside/new-directory',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byTooltip('Import Directory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(directoryService.importCalls, [
      (
        rootID: 7,
        source: '/outside/new-directory',
        destination: 'new-directory'
      ),
    ]);
    expect(find.text('正在准备导入...'), findsNothing);
    expect(find.text('visible.txt'), findsOneWidget);
    expect(find.textContaining('无法将目录导入到加密目录。'), findsOneWidget);
  });

  testWidgets('file picker import writes selected bytes to current root',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final source = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      path: 'selected.txt',
      name: 'selected.txt',
    );
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectFile: (groups) async {
          expect(groups, isNotEmpty);
          return source;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Import File'));
    await tester.pumpAndSettle();

    expect(cryptoService.fileWrites, hasLength(1));
    final write = cryptoService.fileWrites.single;
    expect(write.path, '$rootPath/selected.txt');
    expect(write.sessionID, '7');
    expect(write.bytes, orderedEquals([1, 2, 3, 4]));
    expect(fileService.listCalls, 2);
  });

  testWidgets('unfinished operation can be rerun while unlocking',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final marker = <String, dynamic>{
      'op_id': 'unfinished-1',
      'type': 'import',
      'entry_kind': 'directory',
      'src': '/outside/source',
      'dst': 'restored',
    };
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(
      unfinishedMarkers: [marker],
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发现未完成的导入/导出'), findsOneWidget);
    await tester.tap(find.text('全量重跑'));
    await tester.pumpAndSettle();

    expect(directoryService.rerunCalls, [marker]);
    expect(find.text('visible.txt'), findsOneWidget);
  });
}

class _FakeCryptoService extends CryptoService {
  _FakeCryptoService(this.rootPath);

  final String rootPath;
  final List<String> openedPasswords = [];
  final List<({String path, String sessionID, List<int> bytes})> fileWrites =
      [];

  @override
  CryptionConfig loadConfig(String rootPath) => CryptionConfig({
        'version': '1.0',
        'dataFactory': 'aes-ctr',
        'nameFactory': 'aes-gcm-name',
      });

  @override
  int openRoot(String rootPath, String password, String configJSON) {
    openedPasswords.add(password);
    if (password != 'correct-password') {
      throw StateError('invalid password');
    }
    return 7;
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    fileWrites.add((
      path: path,
      sessionID: tempKeyID,
      bytes: List<int>.from(data),
    ));
  }
}

class _FakeFileService extends FileService {
  _FakeFileService(
    CryptoService cryptoService, {
    List<FileSystemNode>? items,
  })  : items = items ??
            [
              FileSystemNode(
                name: 'visible.txt',
                path: '/visible.txt',
                isDirectory: false,
                size: 7,
              ),
            ],
        super(cryptoService: cryptoService);

  int listCalls = 0;
  final List<FileSystemNode> items;

  @override
  Future<List<FileSystemNode>> listCurrentDirectory(
    String path, {
    int offset = 0,
    int? limit,
  }) async {
    listCalls++;
    return items;
  }
}

class _FakeDirectoryService extends DirectoryService {
  _FakeDirectoryService({this.importError, this.unfinishedMarkers = const []});

  final String? importError;
  final List<Map<String, dynamic>> unfinishedMarkers;
  final List<Map<String, dynamic>> rerunCalls = [];
  final List<({int rootID, String source, String destination})> importCalls =
      [];

  @override
  Future<List<Map<String, dynamic>>> listUnfinishedOperations(
          int rootID) async =>
      unfinishedMarkers;

  @override
  Future<void> rerunUnfinishedOperation(
    int rootID,
    Map<String, dynamic> marker, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    rerunCalls.add(marker);
    onProgress?.call(const DirectoryTransferProgress(
      percent: 100,
      currentFile: 'restored/payload.txt',
      completedFiles: 1,
      isComplete: true,
    ));
  }

  @override
  Future<void> importDirectory(
    int rootID,
    String srcPath,
    String destPath, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    importCalls.add((
      rootID: rootID,
      source: srcPath,
      destination: destPath,
    ));
    final error = importError;
    if (error != null) {
      throw StateError(error);
    }
    onProgress?.call(const DirectoryTransferProgress(
      percent: 100,
      currentFile: 'payload.txt',
      completedFiles: 1,
    ));
  }
}

class _FakePersistenceService extends DirectoryPersistenceService {
  _FakePersistenceService(this.rootPath);

  final String rootPath;

  @override
  Future<List<String>> loadOpenedDirectories() async => [rootPath];

  @override
  Future<bool> loadDrawerPinned() async => true;

  @override
  Future<bool> isFirstTimeUser() async => false;

  @override
  Future<void> saveOpenedDirectories(List<String> paths) async {}

  @override
  Future<void> saveDrawerPinned(bool pinned) async {}
}
