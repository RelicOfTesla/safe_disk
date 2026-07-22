import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'l10n/app_locale.dart';
import 'l10n/generated/app_localizations.dart';
import 'pages/home_page.dart';
import 'services/content_window_host_bridge.dart';
import 'services/document_window_client.dart';
import 'services/remote_document_crypto_service.dart';
import 'services/settings_service.dart';
import 'services/error_reporting_service.dart';
import 'models/text_file_policy.dart';
import 'native/bindings.dart';
import 'native/native_lib.dart';
import 'theme/app_theme.dart';
import 'widgets/native_library_startup_error.dart';
import 'windows/secure_notepad_window.dart';
import 'windows/secure_image_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final contentWindow = await _currentContentWindow();
  if (contentWindow != null) {
    final arguments = contentWindow.arguments;
    final settings = SettingsService();
    final localePreference =
        arguments.localePreference ?? await settings.getLocale();
    final locale = appLocaleFromPreference(localePreference);
    final client = DocumentWindowClient(arguments.token);
    RemoteDocumentSnapshot snapshot;
    try {
      snapshot = await client.read();
    } catch (error) {
      final showDiagnostics = await _readDetailedErrorReports(settings);
      runApp(ContentWindowStartupErrorApp(
        title: arguments.title,
        error: error,
        onClose: contentWindow.controller.close,
        locale: locale,
        showDiagnostics: showDiagnostics,
      ));
      _showContentWindowAfterFirstFrame(contentWindow.controller);
      return;
    }
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
        locale: locale,
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
      locale: locale,
    ));
    _showContentWindowAfterFirstFrame(contentWindow.controller);
    return;
  }
  runApp(const SafeDiskApp());
}

Future<bool> _readDetailedErrorReports(SettingsService settings) async {
  try {
    return await settings.getDetailedErrorReports();
  } catch (_) {
    return false;
  }
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

typedef NativeLibraryProbe = Future<void> Function();

class SafeDiskApp extends StatefulWidget {
  const SafeDiskApp({
    super.key,
    this.settingsService,
    this.nativeLibraryProbe,
  });

  final SettingsService? settingsService;
  final NativeLibraryProbe? nativeLibraryProbe;

  @override
  State<SafeDiskApp> createState() => _SafeDiskAppState();
}

class _SafeDiskAppState extends State<SafeDiskApp> {
  late final SettingsService _settingsService;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  bool _nativeReady = false;
  NativeLibraryException? _nativeError;

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? SettingsService();
    _loadSettings();
    _probeNativeLibrary();
  }

  Future<void> _probeNativeLibrary() async {
    if (mounted) {
      setState(() {
        _nativeReady = false;
        _nativeError = null;
      });
    }
    try {
      await (widget.nativeLibraryProbe ?? _defaultNativeLibraryProbe)();
      if (mounted) setState(() => _nativeReady = true);
    } on NativeLibraryException catch (error) {
      if (mounted) setState(() => _nativeError = error);
    } on Object catch (error) {
      if (mounted) {
        setState(
          () => _nativeError = NativeLibraryException(
            NativeLibraryFailureStage.unknown,
            error,
          ),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final values = await Future.wait<Object>([
      _settingsService.getThemeMode(),
      _settingsService.getLocale(),
      _settingsService.getDetailedErrorReports(),
    ]);
    ErrorReportingService.configure(
      detailedErrorsEnabled: values[2] as bool,
    );
    if (mounted) {
      setState(() {
        _themeMode = _parseThemeMode(values[0] as String);
        _locale = appLocaleFromPreference(values[1] as String);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Disk',
      locale: _locale,
      localeResolutionCallback: resolveSafeDiskLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildSafeDiskTheme(brightness: Brightness.light),
      darkTheme: buildSafeDiskTheme(brightness: Brightness.dark),
      themeMode: _themeMode,
      home: _nativeError != null
          ? NativeLibraryStartupErrorPage(
              error: _nativeError!,
              onRetry: _probeNativeLibrary,
              showDiagnostics: ErrorReportingService.detailedErrorsEnabled,
            )
          : !_nativeReady
              ? const NativeLibraryLoadingPage()
              : HomePage(
                  settingsService: _settingsService,
                  onThemeModeChanged: (mode) =>
                      setState(() => _themeMode = mode),
                  onLocaleChanged: (locale) => setState(() => _locale = locale),
                ),
    );
  }
}

Future<void> _defaultNativeLibraryProbe() async {
  NativeLib.ensureAvailable();
}

ThemeMode _parseThemeMode(String mode) => switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
