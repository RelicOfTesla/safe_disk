import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/content_window_lock_endpoint.dart';

void main() {
  test('confirms a matching lock request only after preparation succeeds',
      () async {
    var preparations = 0;
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() async {
        preparations++;
        return true;
      });

    expect(
      await endpoint.handle(const MethodCall('document.prepareLock', {
        'token': 'capability-token',
        'lockRequestID': 'request-1',
      })),
      {
        'token': 'capability-token',
        'lockRequestID': 'request-1',
        'status': 'prepared',
      },
    );
    expect(preparations, 1);
  });

  test('rejects a lock request for another capability token', () async {
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token');

    await expectLater(
      endpoint.handle(const MethodCall('document.prepareLock', {
        'token': 'other-token',
        'lockRequestID': 'request-1',
      })),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('reports failed when the editor cannot persist its draft', () async {
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() async => false);

    expect(
      await endpoint.handle(const MethodCall('document.prepareLock', {
        'token': 'capability-token',
        'lockRequestID': 'request-1',
      })),
      containsPair('status', 'failed'),
    );
  });

  test('shares one preparation for duplicate matching lock requests', () async {
    final prepared = Completer<bool>();
    var preparations = 0;
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() {
        preparations++;
        return prepared.future;
      });
    final first = endpoint.handle(const MethodCall('document.prepareLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));
    final duplicate = endpoint.handle(const MethodCall('document.prepareLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));

    expect(preparations, 1);
    prepared.complete(true);
    expect(await first, containsPair('status', 'prepared'));
    expect(await duplicate, containsPair('status', 'prepared'));
    expect(preparations, 1);
  });

  test('rejects a competing request while a lock preparation is active',
      () async {
    final prepared = Completer<bool>();
    var preparations = 0;
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() {
        preparations++;
        return prepared.future;
      });
    final first = endpoint.handle(const MethodCall('document.prepareLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));

    expect(
      await endpoint.handle(const MethodCall('document.prepareLock', {
        'token': 'capability-token',
        'lockRequestID': 'request-2',
      })),
      containsPair('status', 'failed'),
    );
    expect(preparations, 1);
    prepared.complete(true);
    expect(await first, containsPair('status', 'prepared'));
  });

  test('cancels only the matching prepared lock request', () async {
    var cancellations = 0;
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() async => true)
      ..setCancelLockPreparation(() => cancellations++);
    await endpoint.handle(const MethodCall('document.prepareLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));

    await endpoint.handle(const MethodCall('document.cancelLock', {
      'token': 'capability-token',
      'lockRequestID': 'other-request',
    }));
    expect(cancellations, 0);
    await endpoint.handle(const MethodCall('document.cancelLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));
    expect(cancellations, 1);
  });

  test('cancels a preparation that completes after the host timeout', () async {
    final prepared = Completer<bool>();
    var cancellations = 0;
    final endpoint = ContentWindowLockEndpoint(token: 'capability-token')
      ..setPrepareForLock(() => prepared.future)
      ..setCancelLockPreparation(() => cancellations++);
    final preparing = endpoint.handle(const MethodCall('document.prepareLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));

    await endpoint.handle(const MethodCall('document.cancelLock', {
      'token': 'capability-token',
      'lockRequestID': 'request-1',
    }));
    prepared.complete(true);

    expect(await preparing, containsPair('status', 'cancelled'));
    expect(cancellations, 1);
  });
}
