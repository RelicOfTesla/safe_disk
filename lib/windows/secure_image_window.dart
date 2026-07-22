import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../services/content_window_host_bridge.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../widgets/secure_image_viewer.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/app_locale.dart';

class SafeDiskImageWindow extends StatelessWidget {
  const SafeDiskImageWindow({
    super.key,
    required this.arguments,
    required this.client,
    required this.cryptoService,
    this.themeMode = ThemeMode.system,
    this.locale,
  });

  final ContentWindowArguments arguments;
  final DocumentWindowClient client;
  final RemoteDocumentCryptoService cryptoService;
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
      home: SecureImageViewer(
        file: EncryptedFile(
          name: arguments.title,
          encryptedPath: RemoteDocumentCryptoService.logicalSourcePath,
          modifiedTime: DateTime.now(),
        ),
        cryptoService: cryptoService,
        tempKeyID: arguments.token,
      ),
    );
  }
}
