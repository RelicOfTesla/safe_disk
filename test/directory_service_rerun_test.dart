import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/directory_service.dart';

void main() {
  for (final type in ['import', 'export']) {
    for (final entryKind in ['file', 'directory']) {
      test('reruns $type $entryKind from a validated marker', () async {
        final service = _RecordingDirectoryService();
        await service.rerunUnfinishedOperation(7, {
          'op_id': 'old-op',
          'type': type,
          'entry_kind': entryKind,
          'src': type == 'export' ? 'inside/path' : '/plain/source',
          'dst': type == 'export' ? '/plain/output' : 'inside/destination',
        });

        expect(service.calls, [
          'clean:7:old-op',
          '$type:$entryKind:7:'
              '${type == 'export' ? 'inside/path' : '/plain/source'}:'
              '${type == 'export' ? '/plain/output' : 'inside/destination'}',
        ]);
      });
    }
  }

  test('rejects a legacy marker before cleaning it', () async {
    final service = _RecordingDirectoryService();
    await expectLater(
      service.rerunUnfinishedOperation(7, {
        'op_id': 'legacy-op',
        'type': 'import',
        'src': '/plain/source',
        'dst': 'inside/destination',
      }),
      throwsA(isA<StateError>()),
    );
    expect(service.calls, isEmpty);
  });
}

class _RecordingDirectoryService extends DirectoryService {
  final List<String> calls = [];

  @override
  Future<void> cleanUnfinishedOperation(int rootID, String opID) async {
    calls.add('clean:$rootID:$opID');
  }

  @override
  Future<void> importFile(int rootID, String srcPath, String destPath,
      {void Function(DirectoryTransferProgress progress)? onProgress,
      DirectoryTransferCancellationToken? cancellationToken}) async {
    calls.add('import:file:$rootID:$srcPath:$destPath');
  }

  @override
  Future<void> importDirectory(int rootID, String srcPath, String destPath,
      {void Function(DirectoryTransferProgress progress)? onProgress,
      DirectoryTransferCancellationToken? cancellationToken}) async {
    calls.add('import:directory:$rootID:$srcPath:$destPath');
  }

  @override
  Future<void> exportFile(int rootID, String srcPath, String destPath,
      {void Function(DirectoryTransferProgress progress)? onProgress,
      DirectoryTransferCancellationToken? cancellationToken}) async {
    calls.add('export:file:$rootID:$srcPath:$destPath');
  }

  @override
  Future<void> exportDirectory(int rootID, String srcPath, String destPath,
      {void Function(DirectoryTransferProgress progress)? onProgress,
      DirectoryTransferCancellationToken? cancellationToken}) async {
    calls.add('export:directory:$rootID:$srcPath:$destPath');
  }
}
