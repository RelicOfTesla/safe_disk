import 'dart:io';

import 'error_messages.dart';

class ErrorDiagnosticsLabels {
  const ErrorDiagnosticsLabels({
    required this.errorType,
    required this.operation,
    required this.underlyingError,
    required this.redacted,
    required this.pathRedacted,
    required this.truncated,
  });

  final String Function(String value) errorType;
  final String Function(String value) operation;
  final String Function(String value) underlyingError;
  final String redacted;
  final String pathRedacted;
  final String truncated;
}

class ErrorDiagnostics {
  ErrorDiagnostics._();

  static const int _maxDetailLength = 4096;

  static String build({
    required ErrorType type,
    required String originalError,
    required ErrorDiagnosticsLabels labels,
    String? operation,
  }) {
    final sanitized = sanitize(originalError, labels: labels);
    return [
      labels.errorType(type.name),
      if (operation != null && operation.isNotEmpty)
        labels.operation(operation),
      labels.underlyingError(sanitized),
    ].join('\n');
  }

  static String sanitize(
    String value, {
    required ErrorDiagnosticsLabels labels,
  }) {
    var result = value;
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.length > 2) {
      result = result.replaceAll(home, '~');
    }
    result = result.replaceAllMapped(
      RegExp(
        r'("?(?:password|passphrase|derived[_-]?key|secret|token)"?\s*[:=]\s*)'
        r'''("[^"]*"|'[^']*'|[^\s,;]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${labels.redacted}',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'(--password(?:-stdin|-env)?(?:=|\s+))[^\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}${labels.redacted}',
    );
    result = result.replaceAllMapped(
      RegExp(r'(SAFE_DISK_PASSWORD\s*=\s*)[^\s]+', caseSensitive: false),
      (match) => '${match.group(1)}${labels.redacted}',
    );
    // Diagnostics may contain loader paths outside the user's home directory.
    // Do not expose either Unix or Windows absolute paths, even after opt-in.
    result = result.replaceAllMapped(
      RegExp(r'''(?<![A-Za-z0-9_])/(?:[^\s"'`,;:])+'''),
      (_) => labels.pathRedacted,
    );
    result = result.replaceAllMapped(
      RegExp(r'''(?<![A-Za-z0-9_])[A-Za-z]:\\(?:[^\s"'`,;:])+'''),
      (_) => labels.pathRedacted,
    );
    if (result.length > _maxDetailLength) {
      result = '${result.substring(0, _maxDetailLength)}\n${labels.truncated}';
    }
    return result;
  }
}
