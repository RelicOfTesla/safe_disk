import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';

void main() {
  test('create root rejects a non-empty directory before loading FFI', () {
    final directory = Directory.systemTemp.createTempSync('safe-disk-create-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/existing.txt').writeAsStringSync('keep me');

    expect(
      () => CryptoService().createRootConfig(
        directory.path,
        'password',
        '{}',
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.path,
          'path',
          directory.path,
        ),
      ),
    );
    expect(
        File('${directory.path}/existing.txt').readAsStringSync(), 'keep me');
    expect(File('${directory.path}/_cryption.json').existsSync(), isFalse);
  });
}
