import '../native/native_lib.dart';
import 'error_messages.dart';

class UnfinishedTransferErrorPresentation {
  const UnfinishedTransferErrorPresentation({
    required this.type,
    required this.operation,
  });

  final ErrorType type;
  final String operation;
}

UnfinishedTransferErrorPresentation classifyUnfinishedTransferError(
  Object error,
) {
  if (error is NativeOperationException) {
    switch (error.code) {
      case NativeErrorCode.rootSessionNotFound:
        return const UnfinishedTransferErrorPresentation(
          type: ErrorType.sessionExpired,
          operation: 'transfer-state/session',
        );
      case NativeErrorCode.transferMarkerCorrupt:
        return const UnfinishedTransferErrorPresentation(
          type: ErrorType.unfinishedTransferStateUnavailable,
          operation: 'transfer-state/marker',
        );
      case NativeErrorCode.transferV3Unavailable:
        return const UnfinishedTransferErrorPresentation(
          type: ErrorType.unfinishedTransferStateUnavailable,
          operation: 'transfer-state/component',
        );
    }
  }
  return const UnfinishedTransferErrorPresentation(
    type: ErrorType.operationFailed,
    operation: 'transfer-state/list',
  );
}
