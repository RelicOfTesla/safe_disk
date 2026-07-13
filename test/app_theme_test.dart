import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/theme/app_theme.dart';

void main() {
  test('Windows theme uses native UI font with Chinese fallbacks', () {
    final theme = buildSafeDiskTheme(
      brightness: Brightness.light,
      platform: TargetPlatform.windows,
    );

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Segoe UI');
    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback,
      contains('Microsoft YaHei UI'),
    );
    expect(theme.platform, TargetPlatform.windows);
  });

  test('non-Windows theme does not request unavailable Windows fonts', () {
    final theme = buildSafeDiskTheme(
      brightness: Brightness.dark,
      platform: TargetPlatform.linux,
    );

    expect(theme.textTheme.bodyMedium?.fontFamily, isNot('Segoe UI'));
    expect(
      theme.textTheme.bodyMedium?.fontFamilyFallback,
      isNot(contains('Microsoft YaHei UI')),
    );
  });
}
