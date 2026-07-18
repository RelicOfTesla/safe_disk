class RootIdleTracker {
  RootIdleTracker({
    required this.timeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Duration timeout;
  final Map<String, DateTime> _lastActivity = {};

  bool get isEnabled => timeout > Duration.zero;

  void touch(String sessionID) {
    if (!isEnabled) return;
    _lastActivity[sessionID] = _now();
  }

  void remove(String sessionID) => _lastActivity.remove(sessionID);

  void clear() => _lastActivity.clear();

  void updateTimeout(Duration value) {
    timeout = value;
    if (!isEnabled) clear();
  }

  Set<String> expiredSessionIDs() {
    if (!isEnabled) return const {};
    final now = _now();
    return _lastActivity.entries
        .where((entry) => now.difference(entry.value) >= timeout)
        .map((entry) => entry.key)
        .toSet();
  }
}
