import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

ThemeData buildSafeDiskTheme({
  required Brightness brightness,
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  final windows = target == TargetPlatform.windows;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    ),
    fontFamily: windows ? 'Segoe UI' : null,
    fontFamilyFallback: windows
        ? const ['Microsoft YaHei UI', 'Microsoft YaHei', 'SimSun']
        : null,
    platform: target,
    typography: Typography.material2021(platform: target),
    useMaterial3: true,
  );
}
