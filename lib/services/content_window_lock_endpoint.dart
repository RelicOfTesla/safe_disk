import 'package:flutter/services.dart';

/// Handles the host-to-child lock RPC for exactly one capability token.
/// The endpoint contains no root path, root session, or document plaintext.
class ContentWindowLockEndpoint {
  ContentWindowLockEndpoint({required this.token});

  final String token;
  Future<bool> Function()? _prepareForLock;
  VoidCallback? _cancelLockPreparation;
  String? _preparedRequestID;
  String? _activeRequestID;
  Future<Map<String, String>>? _activePreparation;
  String? _cancelledRequestID;
  String? _completedRequestID;
  String? _completedStatus;

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
      } else if (_activeRequestID == requestID) {
        _cancelledRequestID = requestID;
      }
      _completedRequestID = requestID;
      _completedStatus = 'cancelled';
      return _response(requestID, 'cancelled');
    }
    if (_completedRequestID == requestID && _completedStatus != null) {
      return _response(requestID, _completedStatus!);
    }
    if (_preparedRequestID == requestID) {
      return _response(requestID, 'prepared');
    }
    final activePreparation = _activePreparation;
    if (_activeRequestID == requestID && activePreparation != null) {
      return activePreparation;
    }
    if (_activeRequestID != null || _preparedRequestID != null) {
      return _response(requestID, 'failed');
    }

    final preparation = _prepare(requestID);
    _activeRequestID = requestID;
    _activePreparation = preparation;
    try {
      return await preparation;
    } finally {
      if (identical(_activePreparation, preparation)) {
        _activePreparation = null;
        _activeRequestID = null;
      }
    }
  }

  Future<Map<String, String>> _prepare(String requestID) async {
    final prepareForLock = _prepareForLock;
    final prepared = prepareForLock != null && await prepareForLock();
    if (_cancelledRequestID == requestID) {
      _cancelledRequestID = null;
      _cancelLockPreparation?.call();
      _completedRequestID = requestID;
      _completedStatus = 'cancelled';
      return _response(requestID, 'cancelled');
    }
    final status = prepared ? 'prepared' : 'failed';
    if (prepared) _preparedRequestID = requestID;
    _completedRequestID = requestID;
    _completedStatus = status;
    return _response(requestID, status);
  }

  Map<String, String> _response(String requestID, String status) => {
        'token': token,
        'lockRequestID': requestID,
        'status': status,
      };
}
