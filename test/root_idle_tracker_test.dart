import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/root_idle_tracker.dart';

void main() {
  test('tracks roots independently and resets only the touched root', () {
    var now = DateTime(2026, 7, 18, 12);
    final tracker = RootIdleTracker(
      timeout: const Duration(minutes: 5),
      now: () => now,
    );

    tracker.touch('first');
    tracker.touch('second');
    now = now.add(const Duration(minutes: 4));
    tracker.touch('second');
    now = now.add(const Duration(minutes: 2));

    expect(tracker.expiredSessionIDs(), {'first'});
  });

  test('disabled timeout does not retain or expire sessions', () {
    final tracker = RootIdleTracker(timeout: Duration.zero);
    tracker.touch('root');
    expect(tracker.expiredSessionIDs(), isEmpty);
  });
}
