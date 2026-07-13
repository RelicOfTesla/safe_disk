import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/file_service.dart';

void main() {
  test('file export rejects implicit overwrite and allows explicit replace',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('safe-disk-export-');
    addTearDown(() => directory.delete(recursive: true));
    final destination = File('${directory.path}/note.txt');
    await destination.writeAsString('existing');
    final service = FileService(cryptoService: _ExportCryptoService('secret'));
    final item = FileSystemNode(
      name: 'note.txt',
      path: '/note.txt',
      isDirectory: false,
    );

    await expectLater(
      service.exportFile(item, destination.path, 'root-session'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await destination.readAsString(), 'existing');

    await service.exportFile(
      item,
      destination.path,
      'root-session',
      overwrite: true,
    );
    expect(await destination.readAsString(), 'secret');

    final newDestination = File('${directory.path}/new.txt');
    await service.exportFile(item, newDestination.path, 'root-session');
    expect(await newDestination.readAsString(), 'secret');
  });
}

class _ExportCryptoService extends CryptoService {
  _ExportCryptoService(this.content);

  final String content;

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    return Uint8List.fromList(utf8.encode(content));
  }
}
