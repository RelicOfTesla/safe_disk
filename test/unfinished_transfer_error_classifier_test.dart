import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/utils/error_messages.dart';
import 'package:safe_disk/utils/unfinished_transfer_error_classifier.dart';

void main() {
  test('transfer state codes have explicit UI presentations', () {
    final expected = <int, (ErrorType, String)>{
      NativeErrorCode.rootSessionNotFound: (
        ErrorType.sessionExpired,
        'transfer-state/session'
      ),
      NativeErrorCode.transferMarkerCorrupt: (
        ErrorType.unfinishedTransferStateUnavailable,
        'transfer-state/marker'
      ),
      NativeErrorCode.transferV3Unavailable: (
        ErrorType.unfinishedTransferStateUnavailable,
        'transfer-state/component'
      ),
    };

    for (final entry in expected.entries) {
      final result = classifyUnfinishedTransferError(
        NativeOperationException('secTransferV3ListUnfinished', 'native',
            code: entry.key),
      );
      expect(result.type, entry.value.$1);
      expect(result.operation, entry.value.$2);
    }
  });

  test('unknown transfer state errors remain generic', () {
    final result = classifyUnfinishedTransferError(
      const NativeOperationException('secTransferV3ListUnfinished', 'native'),
    );
    expect(result.type, ErrorType.operationFailed);
    expect(result.operation, 'transfer-state/list');
  });
}
