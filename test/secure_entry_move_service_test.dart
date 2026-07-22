import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/secure_clipboard_service.dart';
import 'package:safe_disk/services/secure_entry_move_service.dart';

void main() {
  const file = SecureClipboardEntry(
    sourcePath: '/source.txt',
    sourceSessionID: '1',
    name: 'source.txt',
    isDirectory: false,
    operation: SecureClipboardOperation.move,
  );

  test('same-root move without replacement uses rename only', () async {
    final crypto = _MoveCryptoService();
    final service = SecureEntryMoveService(crypto);

    await service.move(
      entry: file,
      destinationPath: '/folder/source.txt',
      destinationSessionID: '1',
      overwrite: false,
    );

    expect(crypto.operations, ['rename:1:/source.txt:/folder/source.txt']);
  });

  test('cross-root file move copies before deleting the source', () async {
    final crypto = _MoveCryptoService();
    final service = SecureEntryMoveService(crypto);

    await service.move(
      entry: file,
      destinationPath: '/target/source.txt',
      destinationSessionID: '2',
      overwrite: false,
    );

    expect(crypto.operations, [
      'copy:1:/source.txt:2:/target/source.txt:false',
      'delete:1:/source.txt',
    ]);
  });

  test('copy success and source deletion failure is reported as partial',
      () async {
    final crypto = _MoveCryptoService(failDelete: true);
    final service = SecureEntryMoveService(crypto);

    await expectLater(
      service.move(
        entry: file,
        destinationPath: '/target/source.txt',
        destinationSessionID: '2',
        overwrite: true,
      ),
      throwsA(isA<SecureEntryMovePartialFailure>()),
    );
    expect(crypto.operations, [
      'copy:1:/source.txt:2:/target/source.txt:true',
      'delete:1:/source.txt',
    ]);
  });

  test('cross-root directory move is rejected before copying', () async {
    final crypto = _MoveCryptoService();
    final service = SecureEntryMoveService(crypto);
    const directory = SecureClipboardEntry(
      sourcePath: '/folder',
      sourceSessionID: '1',
      name: 'folder',
      isDirectory: true,
      operation: SecureClipboardOperation.move,
    );

    await expectLater(
      service.move(
        entry: directory,
        destinationPath: '/target/folder',
        destinationSessionID: '2',
        overwrite: false,
      ),
      throwsA(isA<SecureEntryMoveDirectoryUnsupported>()),
    );
    expect(crypto.operations, isEmpty);
  });
}

class _MoveCryptoService extends CryptoService {
  _MoveCryptoService({this.failDelete = false});

  final bool failDelete;
  final List<String> operations = [];

  @override
  Future<void> renameBySession(
    String oldPath,
    String newPath,
    String tempKeyID,
  ) async {
    operations.add('rename:$tempKeyID:$oldPath:$newPath');
  }

  @override
  Future<void> copyBySession({
    required String sourcePath,
    required String sourceSessionID,
    required String destinationPath,
    required String destinationSessionID,
    bool overwrite = false,
  }) async {
    operations.add(
      'copy:$sourceSessionID:$sourcePath:'
      '$destinationSessionID:$destinationPath:$overwrite',
    );
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    operations.add('delete:$tempKeyID:$path');
    if (failDelete) throw StateError('delete failed');
  }
}
