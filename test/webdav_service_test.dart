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
}
