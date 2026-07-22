import 'package:flutter/services.dart';

/// Handles the host-to-child lock RPC for exactly one capability token.
/// The endpoint contains no root path, root session, or document plaintext.
class ContentWindowLockEndpoint {
  ContentWindowLockEndpoint({required this.token});

  final String token;
  Future<bool> Function()? _prepareForLock;
  VoidCallback? _cancelLockPreparation;
  String? _preparedRequestID;

  void setPrepareForLock(Future<bool> Function() prepareForLock) {
    _prepareForLock = prepareForLock;
  }

  void setCancelLockPreparation(VoidCallback cancelLockPreparation) {
    _cancelLockPreparation = cancelLockPreparation;
  }

  Future<Object?> handle(MethodCall call) async {
    if (call.method != 'document.prepareLock' &&
        call.method != 'document.cancelLock') {
      throw PlatformException(
        code: 'unsupported_method',
        message: 'unsupported-content-window-lock-method',
      );
    }
    final arguments = call.arguments;
    if (arguments is! Map ||
        arguments['token'] != token ||
        arguments['lockRequestID'] is! String ||
        (arguments['lockRequestID'] as String).isEmpty) {
      throw PlatformException(
        code: 'invalid_request',
        message: 'invalid-content-window-lock-request',
      );
    }
    final requestID = arguments['lockRequestID'] as String;
    if (call.method == 'document.cancelLock') {
      if (_preparedRequestID == requestID) {
        _preparedRequestID = null;
        _cancelLockPreparation?.call();
      }
      return {
        'token': token,
        'lockRequestID': requestID,
        'status': 'cancelled',
      };
    }
    final prepareForLock = _prepareForLock;
    final prepared = prepareForLock != null && await prepareForLock();
    _preparedRequestID = prepared ? requestID : null;
    return {
      'token': token,
      'lockRequestID': requestID,
      'status': prepared ? 'prepared' : 'failed',
    };
  }
}
