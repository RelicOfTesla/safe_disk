import 'crypto_service.dart';

enum WebDavAuthMode {
  bearer('bearer'),
  digest('digest');

  const WebDavAuthMode(this.wireName);

  final String wireName;
}

enum WebDavCredentialVisibility {
  once('once'),
  persistent('persistent');

  const WebDavCredentialVisibility(this.wireName);

  final String wireName;
}

enum WebDavSessionLifetime {
  ephemeral('ephemeral'),
  persistent('persistent');

  const WebDavSessionLifetime(this.wireName);

  final String wireName;
}

/// The capability material returned exactly once when a session is opened.
class WebDavOpenedSession {
  const WebDavOpenedSession({
    required this.id,
    required this.rootID,
    required this.displayName,
    required this.exposedPath,
    required this.url,
    required this.authMode,
    required this.credentialVisibility,
    required this.sessionLifetime,
    required this.port,
    this.token,
    this.username,
    this.password,
    this.realm,
  });

  final String id;
  final int rootID;
  final String displayName;
  final String exposedPath;
  final String url;
  final WebDavAuthMode authMode;
  final WebDavCredentialVisibility credentialVisibility;
  final WebDavSessionLifetime sessionLifetime;
  final int port;
  final String? token;
  final String? username;
  final String? password;
  final String? realm;

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
    final authMode = switch (data['auth_mode'] as String? ?? 'bearer') {
      'bearer' => WebDavAuthMode.bearer,
      'digest' => WebDavAuthMode.digest,
      _ => throw StateError('webdav-invalid-native-response:auth_mode'),
    };
    final credentialVisibility =
        switch (data['credential_visibility'] as String? ?? 'once') {
      'once' => WebDavCredentialVisibility.once,
      'persistent' => WebDavCredentialVisibility.persistent,
      _ => throw StateError(
          'webdav-invalid-native-response:credential_visibility'),
    };
    final sessionLifetime =
        switch (data['session_lifetime'] as String? ?? 'ephemeral') {
      'ephemeral' => WebDavSessionLifetime.ephemeral,
      'persistent' => WebDavSessionLifetime.persistent,
      _ => throw StateError('webdav-invalid-native-response:session_lifetime'),
    };
    final port = data['port'] is num ? (data['port'] as num).toInt() : 0;
    String requiredCredential(String key) {
      final value = data[key];
      if (value is! String || value.isEmpty) {
        throw StateError('webdav-invalid-native-response:$key');
      }
      return value;
    }

    return WebDavOpenedSession(
      id: requiredString('id'),
      rootID: rootID,
      displayName: requiredString('display_name'),
      exposedPath: requiredString('exposed_path'),
      url: requiredString('url'),
      authMode: authMode,
      credentialVisibility: credentialVisibility,
      sessionLifetime: sessionLifetime,
      port: port,
      token: authMode == WebDavAuthMode.bearer
          ? requiredCredential('token')
          : null,
      username: authMode == WebDavAuthMode.digest
          ? requiredCredential('username')
          : null,
      password: authMode == WebDavAuthMode.digest
          ? requiredCredential('password')
          : null,
      realm: authMode == WebDavAuthMode.digest
          ? requiredCredential('realm')
          : null,
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
    required this.authMode,
    required this.credentialVisibility,
    required this.sessionLifetime,
    required this.port,
    required this.mounted,
    required this.mountPath,
    required this.lastAccessedAt,
    required this.activeRequests,
  });

  final String id;
  final int rootID;
  final String displayName;
  final String exposedPath;
  final String url;
  final bool readOnly;
  final WebDavAuthMode authMode;
  final WebDavCredentialVisibility credentialVisibility;
  final WebDavSessionLifetime sessionLifetime;
  final int port;
  final bool mounted;
  final String? mountPath;
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
    final authMode = switch (data['auth_mode'] as String? ?? 'bearer') {
      'bearer' => WebDavAuthMode.bearer,
      'digest' => WebDavAuthMode.digest,
      _ => throw StateError('webdav-invalid-native-status:auth_mode'),
    };
    final credentialVisibility =
        switch (data['credential_visibility'] as String? ?? 'once') {
      'once' => WebDavCredentialVisibility.once,
      'persistent' => WebDavCredentialVisibility.persistent,
      _ =>
        throw StateError('webdav-invalid-native-status:credential_visibility'),
    };
    final sessionLifetime =
        switch (data['session_lifetime'] as String? ?? 'ephemeral') {
      'ephemeral' => WebDavSessionLifetime.ephemeral,
      'persistent' => WebDavSessionLifetime.persistent,
      _ => throw StateError('webdav-invalid-native-status:session_lifetime'),
    };
    final port = data['port'] is num ? (data['port'] as num).toInt() : 0;
    return WebDavSessionStatus(
      id: requiredString('id'),
      rootID: rootID,
      displayName: requiredString('display_name'),
      exposedPath: requiredString('exposed_path'),
      url: requiredString('url'),
      readOnly: true,
      authMode: authMode,
      credentialVisibility: credentialVisibility,
      sessionLifetime: sessionLifetime,
      port: port,
      mounted: data['mounted'] == true,
      mountPath: data['mount_path'] as String?,
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
    WebDavAuthMode authMode = WebDavAuthMode.bearer,
    WebDavCredentialVisibility credentialVisibility =
        WebDavCredentialVisibility.once,
    WebDavSessionLifetime sessionLifetime = WebDavSessionLifetime.ephemeral,
    int port = 0,
  }) {
    final exposedPath = _cryptoService.relativePathForRoot(rootID, logicalPath);
    final data = _cryptoService.openWebDavSession(
      rootID: rootID,
      exposedPath: exposedPath,
      displayName: displayName,
      authMode: authMode.wireName,
      credentialVisibility: credentialVisibility.wireName,
      sessionLifetime: sessionLifetime.wireName,
      port: port,
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

  WebDavOpenedSession reveal(String sessionID, {required int rootID}) {
    final data = _cryptoService.revealWebDavSession(sessionID);
    return WebDavOpenedSession.fromNative(rootID: rootID, data: data);
  }

  String mount(String sessionID) {
    final data = _cryptoService.mountWebDavSession(sessionID);
    if (data['mounted'] != true || data['mount_path'] is! String) {
      throw StateError('webdav-invalid-mount-response');
    }
    return data['mount_path'] as String;
  }

  void unmount(String sessionID) {
    final data = _cryptoService.unmountWebDavSession(sessionID);
    if (data['mounted'] != false) {
      throw StateError('webdav-invalid-unmount-response');
    }
  }

  void startMount({required String operationID, required String sessionID}) {
    final data = _cryptoService.startWebDavMount(operationID, sessionID);
    if (data['operation_id'] != operationID || data['state'] != 'running') {
      throw StateError('webdav-invalid-mount-start-response');
    }
  }

  void startUnmount({required String operationID, required String sessionID}) {
    final data = _cryptoService.startWebDavUnmount(operationID, sessionID);
    if (data['operation_id'] != operationID || data['state'] != 'running') {
      throw StateError('webdav-invalid-unmount-start-response');
    }
  }

  Map<String, dynamic> pollOperation(String operationID) {
    return _cryptoService.pollWebDavOperation(operationID);
  }

  bool cancelOperation(String operationID) {
    return _cryptoService.cancelWebDavOperation(operationID);
  }
}
