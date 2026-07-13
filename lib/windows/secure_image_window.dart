import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../services/content_window_host_bridge.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../widgets/secure_image_viewer.dart';
import '../theme/app_theme.dart';

class SafeDiskImageWindow extends StatelessWidget {
  const SafeDiskImageWindow({
    super.key,
    required this.arguments,
    required this.client,
    required this.cryptoService,
    this.themeMode = ThemeMode.system,
  });

  final ContentWindowArguments arguments;
  final DocumentWindowClient client;
  final RemoteDocumentCryptoService cryptoService;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: arguments.title,
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
