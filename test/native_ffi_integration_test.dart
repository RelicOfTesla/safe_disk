import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/controllers/secure_notepad_controller.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_service.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/secure_clipboard_service.dart';
import 'package:safe_disk/services/secure_entry_move_service.dart';
import 'package:safe_disk/widgets/secure_image_viewer.dart';

import 'support/image_fixtures.dart';

void main() {
  final ffiLibrary = Platform.environment['SAFE_DISK_FFI_LIBRARY'];
  final hasFfiLibrary = ffiLibrary != null && ffiLibrary.isNotEmpty;

  group('NativeLib FFI integration',
      skip: hasFfiLibrary
          ? null
          : 'Set SAFE_DISK_FFI_LIBRARY to run native FFI tests', () {
    test(
        'handles encrypted file and directory names through root and transfer APIs',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-dart-ffi-');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final rootPath = '${tmp.path}/root';
      final plainPath = '${tmp.path}/plain';
      final outPath = '${tmp.path}/out';
      await Directory(rootPath).create(recursive: true);
      await Directory('$plainPath/nested').create(recursive: true);
      await Directory('$plainPath/nested/空目录').create(recursive: true);
      await File('$plainPath/nested/source.txt')
          .writeAsString('transfer content');

      final native = NativeLib.instance;
      final cryptoService = CryptoService();
      const password = 'dart-ffi-password';
      final options = jsonEncode({
        'dataFactory': 'AES-CTR',
        'nameFactory': 'AES-256-GCM',
      });

      native.secCreateRootConfig(rootPath, password, options);
      expect(
        () => native.secRootOpen(rootPath, 'wrong-password', ''),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('invalid password'),
          ),
        ),
      );
      final rootID = cryptoService.openRoot(rootPath, password, '');
      addTearDown(() {
        try {
          cryptoService.closeRoot(rootID);
        } catch (_) {
          // The root may already be closed by the assertion path.
        }
      });

      await cryptoService.createDirectoryBySession(
        '$rootPath/新建目录',
        '$rootID',
      );
      await cryptoService.createEmptyFileBySession(
        '$rootPath/新建目录/空文件.txt',
        '$rootID',
      );
      expect(
        native.secQuickReadFile(rootID, '新建目录/空文件.txt'),
        isEmpty,
      );
      await expectLater(
        cryptoService.createEmptyFileBySession(
          '$rootPath/新建目录/空文件.txt',
          '$rootID',
        ),
        throwsA(isA<Exception>()),
      );

      native.secMkdirAll(rootID, '目录');
      native.secQuickWriteFile(rootID, '目录/文件.txt', utf8.encode('hello'));
      expect(
          utf8.decode(native.secQuickReadFile(rootID, '目录/文件.txt')), 'hello');

      final entries = native.secReadDir(rootID, '目录');
      expect(entries.map((entry) => entry['name']), contains('文件.txt'));

      native.secRename(rootID, '目录/文件.txt', '目录/重命名.txt');
      expect(native.secFileExists(rootID, '目录/文件.txt'), isFalse);
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '目录/重命名.txt')),
        'hello',
      );
      native.secQuickWriteFile(rootID, '目录/已存在.txt', utf8.encode('target'));
      expect(
        () => native.secRename(rootID, '目录/重命名.txt', '目录/已存在.txt'),
        throwsA(isA<Exception>()),
      );
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '目录/重命名.txt')),
        'hello',
      );
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '目录/已存在.txt')),
        'target',
      );
      native.secMkdirAll(rootID, '旧目录/子目录');
      native.secRename(rootID, '旧目录', '新目录');
      expect(native.secReadDir(rootID, '新目录/子目录'), isEmpty);

      final uiEntries =
          await FileService().listCurrentDirectory('$rootPath/目录');
      expect(uiEntries.map((entry) => entry.name), contains('重命名.txt'));
      expect(
        uiEntries.singleWhere((entry) => entry.name == '重命名.txt').modifiedTime,
        isNotNull,
      );

      final rootDiskNames = await Directory(rootPath)
          .list()
          .map((entity) =>
              entity.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList();
      expect(rootDiskNames, isNot(contains('目录')));
      expect(rootDiskNames, isNot(contains('新建目录')));

      final directoryService = DirectoryService();
      final importProgress = <DirectoryTransferProgress>[];
      final eventLoopTurn = Completer<void>();
      Timer.run(eventLoopTurn.complete);
      var importCompleted = false;
      final importFuture = directoryService
          .importDirectory(
            rootID,
            plainPath,
            '导入',
            onProgress: importProgress.add,
          )
          .whenComplete(() => importCompleted = true);
      await eventLoopTurn.future.timeout(const Duration(seconds: 5));
      expect(importCompleted, isFalse,
          reason: 'Transfer must not block the caller isolate');
      await importFuture;
      expect(importProgress, isNotEmpty);
      expect(importProgress.last.isComplete, isTrue);
      expect(importProgress.last.totalFiles, 1);
      expect(importProgress.last.completedFiles, 1);
      expect(native.secReadDir(rootID, '导入/nested/空目录'), isEmpty);

      final exportProgress = <DirectoryTransferProgress>[];
      await directoryService.exportDirectory(
        rootID,
        '导入',
        outPath,
        onProgress: exportProgress.add,
      );
      expect(exportProgress, isNotEmpty);
      expect(exportProgress.last.isComplete, isTrue);
      expect(exportProgress.last.totalFiles, 1);
      expect(exportProgress.last.completedFiles, 1);
      expect(await File('$outPath/nested/source.txt').readAsString(),
          'transfer content');
      expect(await Directory('$outPath/nested/空目录').exists(), isTrue);

      final noCallbackOutPath = '${tmp.path}/out-no-callback';
      final noCallbackEventLoopTurn = Completer<void>();
      Timer.run(noCallbackEventLoopTurn.complete);
      var noCallbackExportCompleted = false;
      final noCallbackExport = directoryService
          .exportDirectory(rootID, '导入', noCallbackOutPath)
          .whenComplete(() => noCallbackExportCompleted = true);
      await noCallbackEventLoopTurn.future.timeout(const Duration(seconds: 5));
      expect(noCallbackExportCompleted, isFalse,
          reason: 'Transfer without a progress listener must remain async');
      await noCallbackExport;
      expect(
        await File('$noCallbackOutPath/nested/source.txt').readAsString(),
        'transfer content',
      );

      final listenerErrorOutPath = '${tmp.path}/out-listener-error';
      await expectLater(
        directoryService.exportDirectory(
          rootID,
          '导入',
          listenerErrorOutPath,
          onProgress: (_) => throw StateError('listener failed'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'listener failed',
          ),
        ),
      );
      expect(
        await File('$listenerErrorOutPath/nested/source.txt').readAsString(),
        'transfer content',
        reason: 'A Dart listener error must not invalidate the native callback',
      );

      await expectLater(
        directoryService.exportDirectory(
          rootID,
          '不存在',
          '${tmp.path}/out-missing-source',
        ),
        throwsA(isA<StateError>()),
      );
      final failedMarkers =
          await directoryService.listUnfinishedOperations(rootID);
      expect(failedMarkers, hasLength(1));
      expect(failedMarkers.single['type'], 'export');
      expect(failedMarkers.single['entry_kind'], 'directory');
      await directoryService.cleanUnfinishedOperation(
        rootID,
        failedMarkers.single['op_id']! as String,
      );

      final cancelPlainPath = '${tmp.path}/cancel-plain';
      await Directory(cancelPlainPath).create();
      await File('$cancelPlainPath/large.bin')
          .writeAsBytes(Uint8List(16 * 1024 * 1024), flush: true);
      final cancellationToken = DirectoryTransferCancellationToken();
      var cancelAccepted = false;
      await expectLater(
        directoryService.importDirectory(
          rootID,
          cancelPlainPath,
          '取消',
          cancellationToken: cancellationToken,
          onProgress: (progress) {
            if (!progress.isComplete && !cancelAccepted) {
              cancelAccepted = cancellationToken.cancel();
            }
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(cancelAccepted, isTrue);
      expect(cancellationToken.isComplete, isTrue);
      expect(cancellationToken.isActive, isFalse);
      expect(native.secFileExists(rootID, '取消/large.bin'), isFalse);
      final canceledMarkers =
          await directoryService.listUnfinishedOperations(rootID);
      expect(canceledMarkers, hasLength(1));
      expect(canceledMarkers.single['type'], 'import');
      expect(canceledMarkers.single['entry_kind'], 'directory');
      await directoryService.rerunUnfinishedOperation(
        rootID,
        canceledMarkers.single,
      );
      expect(native.secFileExists(rootID, '取消/large.bin'), isTrue);

      expect(await directoryService.listUnfinishedOperations(rootID), isEmpty);
    });

    test('reports a corrupt unfinished marker instead of hiding it', () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-marker-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final rootPath = '${tmp.path}/root';
      await Directory(rootPath).create(recursive: true);
      final native = NativeLib.instance;
      native.secCreateRootConfig(
        rootPath,
        'marker-password',
        jsonEncode({'dataFactory': 'AES-CTR', 'nameFactory': 'None'}),
      );
      final rootID = native.secRootOpen(rootPath, 'marker-password', '');
      addTearDown(() => native.secRootClose(rootID));

      expect(
          await DirectoryService().listUnfinishedOperations(rootID), isEmpty);

      final markerDirectory = Directory('$rootPath/.transfer_v3/active');
      await markerDirectory.create(recursive: true);
      await File('${markerDirectory.path}/broken.json').writeAsString('{');

      await expectLater(
        DirectoryService().listUnfinishedOperations(rootID),
        throwsA(
          isA<NativeOperationException>().having(
            (error) => error.code,
            'code',
            NativeErrorCode.transferMarkerCorrupt,
          ),
        ),
      );
    });

    test(
        'copies across encrypted roots and imports only after overwrite consent',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-copy-ffi-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final sourceRootPath = '${tmp.path}/source-root';
      final destinationRootPath = '${tmp.path}/destination-root';
      final plainSourcePath = '${tmp.path}/incoming.txt';
      await File(plainSourcePath).writeAsString('import replacement');
      final options = jsonEncode({
        'dataFactory': 'AES-CTR',
        'nameFactory': 'AES-256-GCM',
      });
      final crypto = CryptoService();
      crypto.createRootConfig(sourceRootPath, 'source-password', options);
      crypto.createRootConfig(
        destinationRootPath,
        'destination-password',
        options,
      );
      final sourceID = crypto.openRoot(sourceRootPath, 'source-password', '');
      final destinationID =
          crypto.openRoot(destinationRootPath, 'destination-password', '');
      addTearDown(() {
        try {
          crypto.closeRoot(sourceID);
        } catch (_) {}
        try {
          crypto.closeRoot(destinationID);
        } catch (_) {}
      });

      await crypto.writeTextFile(sourceID, '资料/中文.txt', 'copied content');
      await crypto.writeTextFile(destinationID, '副本/中文.txt', 'old content');
      await expectLater(
        crypto.copyBySession(
          sourcePath: '$sourceRootPath/资料',
          sourceSessionID: '$sourceID',
          destinationPath: '$destinationRootPath/副本',
          destinationSessionID: '$destinationID',
        ),
        throwsA(anything),
      );
      expect(
        await crypto.readTextFile(destinationID, '副本/中文.txt'),
        'old content',
      );

      await crypto.copyBySession(
        sourcePath: '$sourceRootPath/资料',
        sourceSessionID: '$sourceID',
        destinationPath: '$destinationRootPath/副本',
        destinationSessionID: '$destinationID',
        overwrite: true,
      );
      expect(
        await crypto.readTextFile(destinationID, '副本/中文.txt'),
        'copied content',
      );
      expect(
        await crypto.readTextFile(sourceID, '资料/中文.txt'),
        'copied content',
      );

      await crypto.writeTextFile(sourceID, '待移动.txt', 'moved content');
      await SecureEntryMoveService(crypto).move(
        entry: SecureClipboardEntry(
          sourcePath: '$sourceRootPath/待移动.txt',
          sourceSessionID: '$sourceID',
          name: '待移动.txt',
          isDirectory: false,
          operation: SecureClipboardOperation.move,
        ),
        destinationPath: '$destinationRootPath/已移动.txt',
        destinationSessionID: '$destinationID',
        overwrite: false,
      );
      expect(await crypto.fileExists(sourceID, '待移动.txt'), isFalse);
      expect(
        await crypto.readTextFile(destinationID, '已移动.txt'),
        'moved content',
      );

      await crypto.writeTextFile(destinationID, '导入.txt', 'old import');
      final directories = DirectoryService();
      await expectLater(
        directories.importFile(
          destinationID,
          plainSourcePath,
          '导入.txt',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        await crypto.readTextFile(destinationID, '导入.txt'),
        'old import',
      );
      for (final marker
          in await directories.listUnfinishedOperations(destinationID)) {
        await directories.cleanUnfinishedOperation(
          destinationID,
          marker['op_id']! as String,
        );
      }
      await directories.importFile(
        destinationID,
        plainSourcePath,
        '导入.txt',
        overwrite: true,
      );
      expect(
        await crypto.readTextFile(destinationID, '导入.txt'),
        'import replacement',
      );
    });

    test('secure notepad persists text across encrypted root sessions',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-note-ffi-');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final rootPath = '${tmp.path}/root';
      const password = 'notepad-ffi-password';
      final options = jsonEncode({
        'dataFactory': 'AES-CTR',
        'nameFactory': 'AES-256-GCM',
      });
      final cryptoService = CryptoService();
      cryptoService.createRootConfig(rootPath, password, options);

      var rootID = cryptoService.openRoot(rootPath, password, '');
      addTearDown(() {
        try {
          cryptoService.closeRoot(rootID);
        } catch (_) {
          // The test explicitly closes and reopens the root session.
        }
      });

      const relativePath = '私人/安全记事.txt';
      await cryptoService.createDir(rootID, '私人');
      await cryptoService.writeTextFile(rootID, relativePath, '初始内容');

      final firstController = SecureNotepadController(
        file: EncryptedFile(
          name: '安全记事.txt',
          encryptedPath: '$rootPath/$relativePath',
          modifiedTime: DateTime(2026),
        ),
        cryptoService: cryptoService,
        tempKeyID: '$rootID',
        autoSaveInterval: Duration.zero,
      );
      await firstController.load();
      expect(firstController.textController.text, '初始内容');
      firstController.textController.text = '关闭根目录后仍应保留的内容';
      expect(await firstController.save(), isTrue);
      firstController.dispose();

      cryptoService.closeRoot(rootID);
      rootID = cryptoService.openRoot(rootPath, password, '');

      final reopenedController = SecureNotepadController(
        file: EncryptedFile(
          name: '安全记事.txt',
          encryptedPath: '$rootPath/$relativePath',
          modifiedTime: DateTime(2026),
        ),
        cryptoService: cryptoService,
        tempKeyID: '$rootID',
        autoSaveInterval: Duration.zero,
      );
      addTearDown(reopenedController.dispose);
      await reopenedController.load();

      expect(reopenedController.loadError, isNull);
      expect(reopenedController.textController.text, '关闭根目录后仍应保留的内容');
      expect(
        NativeLib.instance
            .secReadDir(rootID, '私人')
            .map((entry) => entry['name']),
        contains('安全记事.txt'),
      );
      final diskNames = await Directory(rootPath)
          .list()
          .map((entry) =>
              entry.uri.pathSegments.where((part) => part.isNotEmpty).last)
          .toList();
      expect(diskNames, isNot(contains('私人')));
    });

    testWidgets(
        'secure image viewer renders WebP through a real encrypted root',
        (tester) async {
      final setup = await tester.runAsync(() async {
        final tmp =
            await Directory.systemTemp.createTemp('safe-disk-image-ffi-');
        final rootPath = '${tmp.path}/root';
        const password = 'image-ffi-password';
        final options = jsonEncode({
          'dataFactory': 'AES-CTR',
          'nameFactory': 'AES-256-GCM',
        });
        final cryptoService = CryptoService();
        cryptoService.createRootConfig(rootPath, password, options);
        final rootID = cryptoService.openRoot(rootPath, password, '');
        await cryptoService.createDir(rootID, '私人图片');
        final webp = imageFixture('webp');
        await cryptoService.writeFile(rootID, '私人图片/照片.webp', webp);
        final fileService = FileService(cryptoService: cryptoService);
        final items = await fileService.listCurrentDirectory(
          '$rootPath/私人图片',
        );
        final diskNames = await Directory(rootPath)
            .list()
            .map((entry) =>
                entry.uri.pathSegments.where((part) => part.isNotEmpty).last)
            .toList();
        return (
          tmp: tmp,
          rootPath: rootPath,
          rootID: rootID,
          cryptoService: cryptoService,
          fileService: fileService,
          image: items.single,
          imageLength: webp.length,
          diskNames: diskNames,
        );
      });
      final (
        :tmp,
        :rootPath,
        :rootID,
        :cryptoService,
        :fileService,
        :image,
        :imageLength,
        :diskNames,
      ) = setup!;
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      addTearDown(() {
        try {
          cryptoService.closeRoot(rootID);
        } catch (_) {}
      });

      expect(image.name, '照片.webp');
      expect(image.size, imageLength);
      expect(diskNames, isNot(contains('私人图片')));

      await tester.pumpWidget(MaterialApp(
        home: SecureImageViewer(
          file: EncryptedFile(
            name: image.name,
            encryptedPath: image.path,
            originalSize: image.size,
            modifiedTime: image.modifiedTime ?? DateTime(2026),
          ),
          cryptoService: cryptoService,
          tempKeyID: '$rootID',
          directoryPath: '$rootPath/私人图片',
          fileService: fileService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('secure-image-content')), findsOneWidget);
      expect(find.textContaining('动画'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    test('recovers a notepad draft through the encrypted root interface',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-draft-ffi-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final rootPath = '${tmp.path}/root';
      const password = 'draft-recovery-password';
      final native = NativeLib.instance;
      final crypto = CryptoService();
      native.secCreateRootConfig(
        rootPath,
        password,
        jsonEncode({
          'dataFactory': 'AES-CTR',
          'nameFactory': 'AES-256-GCM',
        }),
      );

      var rootID = crypto.openRoot(rootPath, password, '');
      var rootOpen = true;
      addTearDown(() {
        if (rootOpen) crypto.closeRoot(rootID);
      });
      native.secMkdirAll(rootID, '记事本');
      native.secQuickWriteFile(
        rootID,
        '记事本/断电恢复.txt',
        utf8.encode('original'),
      );
      final file = EncryptedFile(
        name: '断电恢复.txt',
        encryptedPath: '$rootPath/记事本/断电恢复.txt',
        modifiedTime: DateTime.now(),
      );
      final first = SecureNotepadController(
        file: file,
        cryptoService: crypto,
        tempKeyID: '$rootID',
        autoSaveInterval: const Duration(milliseconds: 10),
      );
      await first.load();
      first.textController.text = 'recovered after outage';
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final draftPath = first.draftPath;
      final draftRelative = crypto.relativePathForRoot(rootID, draftPath);
      expect(native.secFileExists(rootID, draftRelative), isTrue);
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '记事本/断电恢复.txt')),
        'original',
      );
      first.dispose();
      crypto.closeRoot(rootID);
      rootOpen = false;

      rootID = crypto.openRoot(rootPath, password, '');
      rootOpen = true;
      final second = SecureNotepadController(
        file: file,
        cryptoService: crypto,
        tempKeyID: '$rootID',
        autoSaveInterval: Duration.zero,
      );
      addTearDown(second.dispose);
      await second.load();
      expect(second.hasRecoveryDraft, isTrue);
      expect(second.textController.text, 'original');
      second.restoreRecoveryDraft();
      expect(await second.save(), isTrue);
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '记事本/断电恢复.txt')),
        'recovered after outage',
      );
      expect(native.secFileExists(rootID, draftRelative), isFalse);
    });

    test('opens CLI roots and allows CLI to use FFI-created roots', () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-cli-ffi-');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final cliBin = '${tmp.path}/safe-disk-test';
      final buildResult = await Process.run(
        'go',
        ['build', '-o', cliBin, '.'],
        workingDirectory: 'native/cli',
      ).timeout(const Duration(seconds: 60));
      expect(buildResult.exitCode, 0,
          reason: '${buildResult.stdout}\n${buildResult.stderr}');

      const password = 'dart-cli-compat-password';
      final native = NativeLib.instance;

      final cliRoot = '${tmp.path}/cli-root';
      final cliCreate = await Process.run(
        cliBin,
        ['create', '--path', cliRoot, '--password', password],
      ).timeout(const Duration(seconds: 60));
      expect(cliCreate.exitCode, 0,
          reason: '${cliCreate.stdout}\n${cliCreate.stderr}');
      final cliConfig = jsonDecode(
        await File('$cliRoot/_cryption.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(cliConfig['sec_deriver_factory'], 'Argon2id');
      expect(
        () => native.secRootOpen(cliRoot, 'wrong-password', ''),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('invalid password'),
          ),
        ),
      );
      final cliRootID = native.secRootOpen(cliRoot, password, '');
      native.secMkdirAll(cliRootID, 'dart-dir');
      native.secQuickWriteFile(cliRootID, 'dart-dir/from-dart.txt',
          utf8.encode('dart writes cli root'));
      expect(
        utf8.decode(
            native.secQuickReadFile(cliRootID, 'dart-dir/from-dart.txt')),
        'dart writes cli root',
      );
      native.secRootClose(cliRootID);

      final ffiRoot = '${tmp.path}/ffi-root';
      native.secCreateRootConfig(
        ffiRoot,
        password,
        jsonEncode({'dataFactory': 'AES-CTR', 'nameFactory': 'None'}),
      );
      final ffiConfig = jsonDecode(
        await File('$ffiRoot/_cryption.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(ffiConfig['sec_deriver_factory'], 'Argon2id');
      expect(
        ffiConfig['argon2_salt'],
        isNot(cliConfig['argon2_salt']),
        reason: 'CLI and FFI roots using one password need independent salts',
      );
      final cliWrongPassword = await Process.run(
        cliBin,
        [
          'list',
          '--password',
          'wrong-password',
          '--path',
          ffiRoot,
        ],
      ).timeout(const Duration(seconds: 60));
      expect(cliWrongPassword.exitCode, isNot(0));
      expect(
        '${cliWrongPassword.stdout}\n${cliWrongPassword.stderr}',
        contains('invalid password'),
      );
      final plainFile = '${tmp.path}/plain.txt';
      await File(plainFile).writeAsString('cli imports into ffi root');
      final cliImport = await Process.run(
        cliBin,
        [
          'import',
          '--password',
          password,
          '--source',
          plainFile,
          '--dest',
          '$ffiRoot/from-cli.txt',
        ],
      ).timeout(const Duration(seconds: 60));
      expect(cliImport.exitCode, 0,
          reason: '${cliImport.stdout}\n${cliImport.stderr}');

      final exportPath = '${tmp.path}/cli-exported.txt';
      final cliExport = await Process.run(
        cliBin,
        [
          'export',
          '--password',
          password,
          '--source',
          '$ffiRoot/from-cli.txt',
          '--dest',
          exportPath,
        ],
      ).timeout(const Duration(seconds: 60));
      expect(cliExport.exitCode, 0,
          reason: '${cliExport.stdout}\n${cliExport.stderr}');
      expect(
          await File(exportPath).readAsString(), 'cli imports into ffi root');

      final ffiRootID = native.secRootOpen(ffiRoot, password, '');
      addTearDown(() {
        try {
          native.secRootClose(ffiRootID);
        } catch (_) {}
      });
      expect(utf8.decode(native.secQuickReadFile(ffiRootID, 'from-cli.txt')),
          'cli imports into ffi root');
    });

    test('rejects a wrong password after a directory import', () async {
      final tmp =
          await Directory.systemTemp.createTemp('safe-disk-import-password-');
      addTearDown(() async {
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final rootPath = '${tmp.path}/root';
      final sourcePath = '${tmp.path}/source';
      await Directory('$sourcePath/子目录').create(recursive: true);
      await File('$sourcePath/子目录/内容.txt').writeAsString('imported');

      const password = 'correct-import-password';
      final native = NativeLib.instance;
      native.secCreateRootConfig(
        rootPath,
        password,
        jsonEncode({
          'dataFactory': 'AES-CTR',
          'nameFactory': 'AES-256-GCM',
          'deriverFactory': 'PBKDF2',
        }),
      );
      var rootID = native.secRootOpen(rootPath, password, '');
      await DirectoryService().importDirectory(
        rootID,
        sourcePath,
        '已导入',
      );
      native.secRootClose(rootID);

      expect(
        () => native.secRootOpen(rootPath, 'any-wrong-password', ''),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('invalid password'),
          ),
        ),
      );

      rootID = native.secRootOpen(rootPath, password, '');
      addTearDown(() {
        try {
          native.secRootClose(rootID);
        } catch (_) {}
      });
      expect(
        utf8.decode(native.secQuickReadFile(rootID, '已导入/子目录/内容.txt')),
        'imported',
      );
    });

    test('creates and reopens every crypto family exposed by the root dialog',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-ui-algos-');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final native = NativeLib.instance;
      const combinations = [
        ('AES-CTR', 'AES-256-GCM', 'Argon2id'),
        ('AES-XTS', 'None', 'PBKDF2'),
        ('ChaCha20', 'AES-256-GCM', 'scrypt'),
      ];

      for (final combination in combinations) {
        final (dataFactory, nameFactory, deriverFactory) = combination;
        final rootPath = '${tmp.path}/$dataFactory-$deriverFactory';
        final password = 'password-$deriverFactory';
        native.secCreateRootConfig(
          rootPath,
          password,
          jsonEncode({
            'dataFactory': dataFactory,
            'nameFactory': nameFactory,
            'deriverFactory': deriverFactory,
            'keyStrengthMs': 1,
          }),
        );
        final config = jsonDecode(
          await File('$rootPath/_cryption.json').readAsString(),
        ) as Map<String, dynamic>;
        expect(config['sec_fs_factory'], dataFactory);
        expect(config['sec_name_factory'], nameFactory);
        expect(config['sec_deriver_factory'], deriverFactory);

        final rootID = native.secRootOpen(rootPath, password, '');
        native.secQuickWriteFile(rootID, '互通.txt', utf8.encode(combination.$1));
        native.secRootClose(rootID);
        final reopened = native.secRootOpen(rootPath, password, '');
        expect(
          utf8.decode(native.secQuickReadFile(reopened, '互通.txt')),
          dataFactory,
        );
        native.secRootClose(reopened);
      }
    });

    test('clears secure byte buffers through FFI binding', () {
      final data = Uint8List.fromList(utf8.encode('sensitive dart bytes'));
      final native = NativeLib.instance;

      native.clearSecureBytes(data);

      expect(data, everyElement(0));
    });

    test(
        'opens FileService directory page sessions through the real cursor ABI',
        () async {
      final tmp = await Directory.systemTemp.createTemp('safe-disk-cursor-');
      addTearDown(() => tmp.delete(recursive: true));
      final rootPath = '${tmp.path}/root';
      final native = NativeLib.instance;
      native.secCreateRootConfig(
          rootPath,
          'pw',
          jsonEncode({
            'dataFactory': 'AES-CTR',
            'nameFactory': 'AES-256-GCM',
            'keyStrengthMs': 1,
          }));
      final crypto = CryptoService();
      final rootID = crypto.openRoot(rootPath, 'pw', '');
      addTearDown(() => crypto.closeRoot(rootID));
      for (final name in ['a.txt', 'b.txt', 'c.txt']) {
        native.secQuickWriteFile(rootID, name, utf8.encode(name));
      }

      final session = FileService(cryptoService: crypto)
          .openCurrentDirectorySession(rootPath)!;
      await session.loadNext(limit: 2);
      expect(session.entries, hasLength(2));
      expect(session.done, isFalse);
      await session.loadNext(limit: 2);
      expect(session.entries.map((entry) => entry.name), hasLength(3));
      expect(session.done, isTrue);
      await session.dispose();
    });
  });
}
