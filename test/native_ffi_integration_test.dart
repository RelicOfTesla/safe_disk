import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/services/directory_service.dart';

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
      await File('$plainPath/nested/source.txt')
          .writeAsString('transfer content');

      final native = NativeLib.instance;
      const password = 'dart-ffi-password';
      final options = jsonEncode({
        'dataFactory': 'aes-ctr',
        'nameFactory': 'aes-gcm-name',
      });

      native.secCreateRootConfig(rootPath, password, options);
      final rootID = native.secRootOpen(rootPath, password, '');
      addTearDown(() {
        try {
          native.secRootClose(rootID);
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

      final rootDiskNames = await Directory(rootPath)
          .list()
          .map((entity) =>
              entity.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList();
      expect(rootDiskNames, isNot(contains('目录')));

      final directoryService = DirectoryService();
      await directoryService.importDirectory(rootID, plainPath, '导入');
      await directoryService.exportDirectory(rootID, '导入', outPath);
      expect(await File('$outPath/nested/source.txt').readAsString(),
          'transfer content');

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

    test('clears secure byte buffers through FFI binding', () {
      final data = Uint8List.fromList(utf8.encode('sensitive dart bytes'));
      final native = NativeLib.instance;

      native.clearSecureBytes(data);

      expect(data, everyElement(0));
    });
  });
}
