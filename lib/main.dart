import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/content_window_host_bridge.dart';
import 'services/document_window_client.dart';
import 'services/remote_document_crypto_service.dart';
import 'services/settings_service.dart';
import 'services/error_reporting_service.dart';
import 'models/text_file_policy.dart';
import 'theme/app_theme.dart';
import 'windows/secure_notepad_window.dart';
import 'windows/secure_image_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final contentWindow = await _currentContentWindow();
  if (contentWindow != null) {
    final arguments = contentWindow.arguments;
    final client = DocumentWindowClient(arguments.token);
    RemoteDocumentSnapshot snapshot;
    try {
      snapshot = await client.read();
    } catch (error) {
      runApp(ContentWindowStartupErrorApp(
        title: arguments.title,
        error: error,
        onClose: contentWindow.controller.close,
      ));
      _showContentWindowAfterFirstFrame(contentWindow.controller);
      return;
    }
    final settings = SettingsService();
    final themeMode = _parseThemeMode(await settings.getThemeMode());
    final cryptoService = RemoteDocumentCryptoService(
      client: client,
      initialSnapshot: snapshot,
    );
    if (arguments.kind == DesktopMultiWindowPlatform.imageWindowKind) {
      runApp(SafeDiskImageWindow(
        arguments: arguments,
        client: client,
        cryptoService: cryptoService,
        themeMode: themeMode,
      ));
      _showContentWindowAfterFirstFrame(contentWindow.controller);
      return;
    }
    final autoSaveSeconds = await settings.getNotepadAutoSaveSeconds();
    final initiallyReadOnly = await settings.getNotepadDefaultReadOnly();
    final initiallyMonitorClipboard =
        await settings.getNotepadDefaultMonitorClipboard();
    runApp(SafeDiskNotepadWindow(
      arguments: arguments,
      client: client,
      cryptoService: cryptoService,
      autoSaveInterval: Duration(seconds: autoSaveSeconds),
      initiallyReadOnly:
          initiallyReadOnly || shouldOpenFallbackTextReadOnly(arguments.title),
      initiallyMonitorClipboard: initiallyMonitorClipboard,
      themeMode: themeMode,
    ));
    _showContentWindowAfterFirstFrame(contentWindow.controller);
    return;
  }
  runApp(const SafeDiskApp());
}

void _showContentWindowAfterFirstFrame(WindowController controller) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(controller.show());
  });
}

Future<_CurrentContentWindow?> _currentContentWindow() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    final arguments =
        DesktopMultiWindowPlatform.tryParseArguments(controller.arguments);
    if (arguments == null) return null;
    return _CurrentContentWindow(
      arguments: arguments,
      controller: controller,
    );
  } catch (_) {
    return null;
  }
}

class _CurrentContentWindow {
  const _CurrentContentWindow({
    required this.arguments,
    required this.controller,
  });

  final ContentWindowArguments arguments;
  final WindowController controller;
}

class SafeDiskApp extends StatefulWidget {
  const SafeDiskApp({super.key, this.settingsService});

  final SettingsService? settingsService;

  @override
  State<SafeDiskApp> createState() => _SafeDiskAppState();
}

class _SafeDiskAppState extends State<SafeDiskApp> {
  late final SettingsService _settingsService;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? SettingsService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final values = await Future.wait<Object>([
      _settingsService.getThemeMode(),
      _settingsService.getDetailedErrorReports(),
    ]);
    ErrorReportingService.configure(
      detailedErrorsEnabled: values[1] as bool,
    );
    if (mounted) {
      setState(() => _themeMode = _parseThemeMode(values[0] as String));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Disk',
      debugShowCheckedModeBanner: false,
      theme: buildSafeDiskTheme(brightness: Brightness.light),
      darkTheme: buildSafeDiskTheme(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: HomePage(
        settingsService: _settingsService,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

ThemeMode _parseThemeMode(String mode) => switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
