import '../native/native_lib.dart';
import 'error_messages.dart';

class UnlockErrorPresentation {
  const UnlockErrorPresentation({
    required this.type,
    required this.operation,
  });

  final ErrorType type;
  final String operation;
}

UnlockErrorPresentation classifyRootOpenError(Object error) {
  if (error is NativeOperationException) {
    switch (error.code) {
      case NativeErrorCode.invalidPassword:
        return const UnlockErrorPresentation(
          type: ErrorType.invalidPassword,
          operation: 'root-open/authenticate',
        );
      case NativeErrorCode.passwordVerifierAbsent:
      case NativeErrorCode.invalidConfig:
        return const UnlockErrorPresentation(
          type: ErrorType.loadConfigFailed,
          operation: 'root-open/config',
        );
    }
  }
  return const UnlockErrorPresentation(
    type: ErrorType.operationFailed,
    operation: 'root-open',
  );
}
