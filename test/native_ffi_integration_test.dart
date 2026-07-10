import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_service.dart';
import 'package:safe_disk/services/file_service.dart';

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
        'dataFactory': 'aes-ctr',
        'nameFactory': 'aes-gcm-name',
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

      native.secMkdirAll(rootID, '目录');
      native.secQuickWriteFile(rootID, '目录/文件.txt', utf8.encode('hello'));
      expect(
          utf8.decode(native.secQuickReadFile(rootID, '目录/文件.txt')), 'hello');

      final entries = native.secReadDir(rootID, '目录');
      expect(entries.map((entry) => entry['name']), contains('文件.txt'));

      final uiEntries =
          await FileService().listCurrentDirectory('$rootPath/目录');
      expect(uiEntries.map((entry) => entry.name), contains('文件.txt'));
      expect(uiEntries.single.modifiedTime, isNotNull);

      final rootDiskNames = await Directory(rootPath)
          .list()
          .map((entity) =>
              entity.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList();
      expect(rootDiskNames, isNot(contains('目录')));

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
      await directoryService.cleanUnfinishedOperation(
        rootID,
        canceledMarkers.single['op_id']! as String,
      );

      expect(await directoryService.listUnfinishedOperations(rootID), isEmpty);
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
      expect(cliConfig['sec_deriver_factory'], 'argon2id');
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
        jsonEncode({'dataFactory': 'aes-ctr', 'nameFactory': 'none'}),
      );
      final ffiConfig = jsonDecode(
        await File('$ffiRoot/_cryption.json').readAsString(),
      ) as Map<String, dynamic>;
      expect(ffiConfig['sec_deriver_factory'], 'argon2id');
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
          'dataFactory': 'aes-ctr',
          'nameFactory': 'aes-gcm-name',
          'deriverFactory': 'pbkdf2',
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

    test('clears secure byte buffers through FFI binding', () {
      final data = Uint8List.fromList(utf8.encode('sensitive dart bytes'));
      final native = NativeLib.instance;

      native.clearSecureBytes(data);

      expect(data, everyElement(0));
    });
  });
}
