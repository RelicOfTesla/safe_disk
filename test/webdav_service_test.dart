import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/webdav_service.dart';

void main() {
  test('open result accepts the one-time read-only capability', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-1',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-1/',
        'token': 'one-time-token',
        'read_only': true,
      },
    );

    expect(result.rootID, 7);
    expect(result.token, 'one-time-token');
  });

  test('status accepts token-free Go monitoring data', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-1',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-1/',
        'read_only': true,
        'last_accessed_at': '2026-07-23T08:00:00Z',
        'active_requests': 0,
      },
    );

    expect(status.rootID, 7);
    expect(status.lastAccessedAt, DateTime.utc(2026, 7, 23, 8));
    expect(status.activeRequests, 0);
  });

  test('status rejects a non-read-only native session', () {
    expect(
      () => WebDavSessionStatus.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-1',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-1/',
          'read_only': false,
          'active_requests': 0,
        },
      ),
      throwsStateError,
    );
  });

  test('open result accepts one-time Digest credentials', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-2',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-2/',
        'auth_mode': 'digest',
        'username': 'user-1',
        'password': 'password-1',
        'realm': 'realm-1',
        'read_only': true,
      },
    );

    expect(result.authMode, WebDavAuthMode.digest);
    expect(result.token, isNull);
    expect(result.username, 'user-1');
    expect(result.password, 'password-1');
    expect(result.realm, 'realm-1');
  });

  test('open result accepts Basic Auth credentials', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-basic',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-basic/',
        'auth_mode': 'basic',
        'username': 'basic-user',
        'password': 'basic-pass',
        'read_only': true,
      },
    );

    expect(result.authMode, WebDavAuthMode.basic);
    expect(result.token, isNull);
    expect(result.username, 'basic-user');
    expect(result.password, 'basic-pass');
    expect(result.realm, isNull);
  });

  test('open result parses TLS flag true', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-tls',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'https://127.0.0.1:8443/webdav/session-tls/',
        'token': 'tls-token',
        'read_only': true,
        'tls': true,
      },
    );

    expect(result.tls, isTrue);
    expect(result.url, startsWith('https://'));
  });

  test('open result parses TLS flag false by default', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-no-tls',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-no-tls/',
        'token': 'token',
        'read_only': true,
      },
    );

    expect(result.tls, isFalse);
  });

  test('status parses Basic Auth mode without leaking credentials', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-basic-status',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-basic-status/',
        'auth_mode': 'basic',
        'read_only': true,
        'active_requests': 0,
      },
    );

    expect(status.authMode, WebDavAuthMode.basic);
  });

  test('status parses TLS flag and port', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-tls-status',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'https://127.0.0.1:8443/webdav/session-tls-status/',
        'auth_mode': 'bearer',
        'read_only': true,
        'tls': true,
        'port': 8443,
        'active_requests': 0,
      },
    );

    expect(status.tls, isTrue);
    expect(status.port, 8443);
    expect(status.url, startsWith('https://'));
  });

  test('WebDavAuthMode wireName returns correct names', () {
    expect(WebDavAuthMode.bearer.wireName, 'bearer');
    expect(WebDavAuthMode.digest.wireName, 'digest');
    expect(WebDavAuthMode.basic.wireName, 'basic');
  });

  test('status rejects an unrecognized auth mode', () {
    expect(
      () => WebDavSessionStatus.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-unknown',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-unknown/',
          'auth_mode': 'ntlm',
          'read_only': true,
          'active_requests': 0,
        },
      ),
      throwsStateError,
    );
  });

  test('open result rejects an unrecognized auth mode', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-unknown',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-unknown/',
          'auth_mode': 'ntlm',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });
  test('status parses Digest auth mode', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-digest',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:4567/webdav/status-digest/',
        'auth_mode': 'digest',
        'read_only': true,
        'active_requests': 5,
      },
    );

    expect(status.authMode, WebDavAuthMode.digest);
    expect(status.activeRequests, 5);
  });

  test('status defaults empty auth_mode to bearer', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-default',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/status-default/',
        'read_only': true,
        'active_requests': 0,
      },
    );

    expect(status.authMode, WebDavAuthMode.bearer);
  });

  test('open result defaults empty auth_mode to bearer', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'open-default',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/open-default/',
        'token': 'token',
        'read_only': true,
      },
    );

    expect(result.authMode, WebDavAuthMode.bearer);
    expect(result.token, 'token');
  });

  test('status parses mounted flag and mount path', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-mounted',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/status-mounted/',
        'read_only': true,
        'mounted': true,
        'mount_path': '/home/user/mount/notes',
        'active_requests': 0,
      },
    );

    expect(status.mounted, isTrue);
    expect(status.mountPath, '/home/user/mount/notes');
  });

  test('status not mounted has null mount path', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-not-mounted',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/status-not-mounted/',
        'read_only': true,
        'mounted': false,
        'active_requests': 0,
      },
    );

    expect(status.mounted, isFalse);
    expect(status.mountPath, isNull);
  });

  test('status lastAccessedAt is null when not provided', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-no-access',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/status-no-access/',
        'read_only': true,
        'active_requests': 0,
      },
    );

    expect(status.lastAccessedAt, isNull);
  });

  test('status port defaults to 0 when not provided', () {
    final status = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'status-no-port',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/status-no-port/',
        'read_only': true,
        'active_requests': 0,
      },
    );

    expect(status.port, 0);
  });

  test('open port defaults to 0 when not provided', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'open-no-port',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/open-no-port/',
        'token': 'token',
        'read_only': true,
      },
    );

    expect(result.port, 0);
  });

  test('open parses credential visibility persistent', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'open-persist',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/open-persist/',
        'token': 'token',
        'read_only': true,
        'credential_visibility': 'persistent',
      },
    );

    expect(result.credentialVisibility, WebDavCredentialVisibility.persistent);
  });

  test('open parses session lifetime persistent', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 7,
      data: const {
        'id': 'open-lifetime',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/open-lifetime/',
        'token': 'token',
        'read_only': true,
        'session_lifetime': 'persistent',
      },
    );

    expect(result.sessionLifetime, WebDavSessionLifetime.persistent);
  });

  test('open rejects missing id', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': '',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/',
          'token': 'token',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open bearer rejects missing token', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-1',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-1/',
          'token': '',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open digest rejects missing username', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-digest',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-digest/',
          'auth_mode': 'digest',
          'username': '',
          'password': 'pass',
          'realm': 'realm',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open digest rejects missing password', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-digest',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-digest/',
          'auth_mode': 'digest',
          'username': 'user',
          'password': '',
          'realm': 'realm',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open digest rejects missing realm', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-digest',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-digest/',
          'auth_mode': 'digest',
          'username': 'user',
          'password': 'pass',
          'realm': '',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open basic rejects missing username', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-basic',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-basic/',
          'auth_mode': 'basic',
          'username': '',
          'password': 'pass',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open basic rejects missing password', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-basic',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-basic/',
          'auth_mode': 'basic',
          'username': 'user',
          'password': '',
          'read_only': true,
        },
      ),
      throwsStateError,
    );
  });

  test('open non-read-only is rejected', () {
    expect(
      () => WebDavOpenedSession.fromNative(
        rootID: 7,
        data: const {
          'id': 'session-write',
          'display_name': 'notes',
          'exposed_path': 'notes',
          'url': 'http://127.0.0.1:1234/webdav/session-write/',
          'token': 'token',
          'read_only': false,
        },
      ),
      throwsStateError,
    );
  });

  test('credential visibility wireName', () {
    expect(WebDavCredentialVisibility.once.wireName, 'once');
    expect(WebDavCredentialVisibility.persistent.wireName, 'persistent');
  });

  test('session lifetime wireName', () {
    expect(WebDavSessionLifetime.ephemeral.wireName, 'ephemeral');
    expect(WebDavSessionLifetime.persistent.wireName, 'persistent');
  });

  test('open result parse with full options set', () {
    final result = WebDavOpenedSession.fromNative(
      rootID: 42,
      data: const {
        'id': 'full-options',
        'display_name': 'docs',
        'exposed_path': 'docs',
        'url': 'https://127.0.0.1:8443/webdav/full-options/',
        'auth_mode': 'digest',
        'credential_visibility': 'persistent',
        'session_lifetime': 'persistent',
        'port': 8443,
        'tls': true,
        'username': 'digest-user',
        'password': 'digest-pass',
        'realm': 'safe-disk',
        'read_only': true,
      },
    );

    expect(result.rootID, 42);
    expect(result.authMode, WebDavAuthMode.digest);
    expect(result.credentialVisibility, WebDavCredentialVisibility.persistent);
    expect(result.sessionLifetime, WebDavSessionLifetime.persistent);
    expect(result.port, 8443);
    expect(result.tls, isTrue);
    expect(result.username, 'digest-user');
    expect(result.password, 'digest-pass');
    expect(result.realm, 'safe-disk');
  });
}
