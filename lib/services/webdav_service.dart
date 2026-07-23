import 'crypto_service.dart';

/// The capability material returned exactly once when a session is opened.
class WebDavOpenedSession {
  const WebDavOpenedSession({
    required this.id,
    required this.rootID,
    required this.displayName,
    required this.exposedPath,
    required this.url,
    required this.token,
  });

  final String id;
  final int rootID;
  final String displayName;
  final String exposedPath;
  final String url;
  final String token;

  factory WebDavOpenedSession.fromNative({
    required int rootID,
    required Map<String, dynamic> data,
  }) {
    String requiredString(String key) {
      final value = data[key];
      if (value is! String || value.isEmpty) {
        throw StateError('webdav-invalid-native-response:$key');
      }
      return value;
    }

    if (data['read_only'] != true) {
      throw StateError('webdav-non-read-only-session');
    }
    return WebDavOpenedSession(
      id: requiredString('id'),
      rootID: rootID,
      displayName: requiredString('display_name'),
      exposedPath: requiredString('exposed_path'),
      url: requiredString('url'),
      token: requiredString('token'),
    );
  }
}

/// Token-free monitoring state returned by the Go WebDAV session manager.
class WebDavSessionStatus {
  const WebDavSessionStatus({
    required this.id,
    required this.rootID,
    required this.displayName,
    required this.exposedPath,
    required this.url,
    required this.readOnly,
    required this.lastAccessedAt,
    required this.activeRequests,
  });

  final String id;
  final int rootID;
  final String displayName;
  final String exposedPath;
  final String url;
  final bool readOnly;
  final DateTime? lastAccessedAt;
  final int activeRequests;

  factory WebDavSessionStatus.fromNative({
    required int rootID,
    required Map<String, dynamic> data,
  }) {
    String requiredString(String key) {
      final value = data[key];
      if (value is! String || value.isEmpty) {
        throw StateError('webdav-invalid-native-status:$key');
      }
      return value;
    }

    final timestamp = data['last_accessed_at'];
    if (data['read_only'] != true) {
      throw StateError('webdav-non-read-only-status');
    }
    return WebDavSessionStatus(
      id: requiredString('id'),
      rootID: rootID,
      displayName: requiredString('display_name'),
      exposedPath: requiredString('exposed_path'),
      url: requiredString('url'),
      readOnly: true,
      lastAccessedAt: timestamp is String ? DateTime.tryParse(timestamp) : null,
      activeRequests:
          data['active_requests'] is int ? data['active_requests'] as int : 0,
    );
  }
}

/// Maps Flutter logical paths to the native read-only WebDAV ABI.
class WebDavService {
  WebDavService({required CryptoService cryptoService})
      : _cryptoService = cryptoService;

  final CryptoService _cryptoService;

  WebDavOpenedSession open({
    required int rootID,
    required String logicalPath,
    required String displayName,
  }) {
    final exposedPath = _cryptoService.relativePathForRoot(rootID, logicalPath);
    final data = _cryptoService.openWebDavSession(
      rootID: rootID,
      exposedPath: exposedPath,
      displayName: displayName,
    );
    return WebDavOpenedSession.fromNative(rootID: rootID, data: data);
  }

  List<WebDavSessionStatus> list({required int rootID}) {
    return _cryptoService
        .listWebDavSessions(rootID)
        .map((data) => WebDavSessionStatus.fromNative(
              rootID: rootID,
              data: data,
            ))
        .toList(growable: false);
  }

  void close(String sessionID) {
    _cryptoService.closeWebDavSession(sessionID);
  }
}
