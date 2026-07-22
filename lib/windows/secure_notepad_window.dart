import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../services/content_window_host_bridge.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../widgets/secure_notepad.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/error_localizations.dart';
import '../l10n/app_locale.dart';
import '../utils/error_diagnostics.dart';

class SafeDiskNotepadWindow extends StatelessWidget {
  const SafeDiskNotepadWindow({
    super.key,
    required this.arguments,
    required this.client,
    required this.cryptoService,
    this.autoSaveInterval = const Duration(seconds: 30),
    this.initiallyReadOnly = false,
    this.initiallyMonitorClipboard = false,
    this.themeMode = ThemeMode.system,
    this.locale,
  });

  final ContentWindowArguments arguments;
  final DocumentWindowClient client;
  final RemoteDocumentCryptoService cryptoService;
  final Duration autoSaveInterval;
  final bool initiallyReadOnly;
  final bool initiallyMonitorClipboard;
  final ThemeMode themeMode;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: arguments.title,
      locale: locale,
      localeResolutionCallback: resolveSafeDiskLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: buildSafeDiskTheme(brightness: Brightness.light),
      darkTheme: buildSafeDiskTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      home: SecureNotepad(
        file: EncryptedFile(
          name: arguments.title,
          encryptedPath: RemoteDocumentCryptoService.logicalSourcePath,
          modifiedTime: DateTime.now(),
        ),
        cryptoService: cryptoService,
        tempKeyID: arguments.token,
        autoSaveInterval: autoSaveInterval,
        initiallyReadOnly: initiallyReadOnly,
        initiallyMonitorClipboard: initiallyMonitorClipboard,
        onDirtyChanged: (dirty) => _ignoreChannelError(client.setDirty(dirty)),
      ),
    );
  }

  void _ignoreChannelError(Future<void> request) {
    unawaited(request.catchError((_) {}));
  }
}

class ContentWindowStartupErrorApp extends StatelessWidget {
  const ContentWindowStartupErrorApp({
    super.key,
    required this.title,
    required this.error,
    required this.onClose,
    this.locale,
    this.showDiagnostics = false,
  });

  final String title;
  final Object error;
  final Future<void> Function() onClose;
  final Locale? locale;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveSafeDiskLocale,
      debugShowCheckedModeBanner: false,
      home: _ContentWindowStartupErrorPage(
        error: error,
        onClose: onClose,
        showDiagnostics: showDiagnostics,
      ),
    );
  }
}

class _ContentWindowStartupErrorPage extends StatelessWidget {
  const _ContentWindowStartupErrorPage({
    required this.error,
    required this.onClose,
    required this.showDiagnostics,
  });

  final Object error;
  final Future<void> Function() onClose;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 48),
                const SizedBox(height: 20),
                Text(
                  strings.contentWindowUnavailable,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  strings.contentWindowUnavailableDescription,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (showDiagnostics)
                  SelectableText(
                    strings.underlyingError(
                      ErrorDiagnostics.sanitize(
                        error.toString(),
                        labels: strings.errorDiagnosticsLabels(),
                      ),
                    ),
                    key: const Key('content-window-error-diagnostics'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _ignoreCloseError(onClose()),
                  child: Text(strings.closeWindow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _ignoreCloseError(Future<void> request) {
    unawaited(request.catchError((_) {}));
  }
}
