import 'dart:async';

import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../services/content_window_host_bridge.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../widgets/secure_notepad.dart';
import '../theme/app_theme.dart';

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
  });

  final ContentWindowArguments arguments;
  final DocumentWindowClient client;
  final RemoteDocumentCryptoService cryptoService;
  final Duration autoSaveInterval;
  final bool initiallyReadOnly;
  final bool initiallyMonitorClipboard;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: arguments.title,
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
  });

  final String title;
  final Object error;
  final Future<void> Function() onClose;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
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
                  const Text(
                    '无法连接主窗口',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '文档会话可能已结束。为避免在失效会话中编辑，请关闭此窗口后从主界面重新打开。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _ignoreCloseError(onClose()),
                    child: const Text('关闭窗口'),
                  ),
                ],
              ),
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
