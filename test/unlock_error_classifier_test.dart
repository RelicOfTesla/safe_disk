import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/utils/error_messages.dart';
import 'package:safe_disk/utils/unlock_error_classifier.dart';

void main() {
  test('only explicit native authentication code is a password error', () {
    final result = classifyRootOpenError(
      const NativeOperationException(
        'secRootOpen',
        'invalid password',
        code: NativeErrorCode.invalidPassword,
      ),
    );

    expect(result.type, ErrorType.invalidPassword);
    expect(result.operation, 'root-open/authenticate');
  });

  test('config and verifier failures are not reported as wrong passwords', () {
    for (final code in [
      NativeErrorCode.passwordVerifierAbsent,
      NativeErrorCode.invalidConfig,
    ]) {
      final result = classifyRootOpenError(
        NativeOperationException('secRootOpen', 'config failure', code: code),
      );
      expect(result.type, ErrorType.loadConfigFailed);
      expect(result.operation, 'root-open/config');
    }
  });

  test('unknown failures remain generic even if text mentions password', () {
    final result = classifyRootOpenError(
      const NativeOperationException('secRootOpen', 'invalid password'),
    );

    expect(result.type, ErrorType.operationFailed);
    expect(result.operation, 'root-open');
  });
}
