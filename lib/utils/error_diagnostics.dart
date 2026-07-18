import 'dart:io';

import 'error_messages.dart';

class ErrorDiagnostics {
  ErrorDiagnostics._();

  static const int _maxDetailLength = 4096;

  static String build({
    required ErrorType type,
    required String originalError,
    String? operation,
  }) {
    final sanitized = sanitize(originalError);
    return [
      '错误类型：${type.name}',
      if (operation != null && operation.isNotEmpty) '操作阶段：$operation',
      '底层错误：$sanitized',
    ].join('\n');
  }

  static String sanitize(String value) {
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
      (match) => '${match.group(1)}[已隐藏]',
    );
    result = result.replaceAllMapped(
      RegExp(
        r'(--password(?:-stdin|-env)?(?:=|\s+))[^\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[已隐藏]',
    );
    result = result.replaceAllMapped(
      RegExp(r'(SAFE_DISK_PASSWORD\s*=\s*)[^\s]+', caseSensitive: false),
      (match) => '${match.group(1)}[已隐藏]',
    );
    // Diagnostics may contain loader paths outside the user's home directory.
    // Do not expose either Unix or Windows absolute paths, even after opt-in.
    result = result.replaceAllMapped(
      RegExp(r'''(?<![A-Za-z0-9_])/(?:[^\s"'`,;:])+'''),
      (_) => '[路径已隐藏]',
    );
    result = result.replaceAllMapped(
      RegExp(r'''(?<![A-Za-z0-9_])[A-Za-z]:\\(?:[^\s"'`,;:])+'''),
      (_) => '[路径已隐藏]',
    );
    if (result.length > _maxDetailLength) {
      result = '${result.substring(0, _maxDetailLength)}\n[详细信息已截断]';
    }
    return result;
  }
}
