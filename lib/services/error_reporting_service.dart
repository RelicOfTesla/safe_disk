/// Process-wide error reporting preference.
///
/// Detailed diagnostics are opt-in and remain in memory. Safe Disk does not
/// write plaintext diagnostic logs to disk.
class ErrorReportingService {
  ErrorReportingService._();

  static bool _detailedErrorsEnabled = false;

  static bool get detailedErrorsEnabled => _detailedErrorsEnabled;

  static void configure({required bool detailedErrorsEnabled}) {
    _detailedErrorsEnabled = detailedErrorsEnabled;
  }
}
