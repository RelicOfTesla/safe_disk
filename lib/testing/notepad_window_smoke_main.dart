import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../services/content_window_host_bridge.dart';
import '../services/crypto_service.dart';
import '../services/document_session_broker.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../windows/secure_notepad_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final current = await WindowController.fromCurrentEngine();
  final arguments =
      DesktopMultiWindowPlatform.tryParseArguments(current.arguments);
  if (arguments != null) {
    final client = DocumentWindowClient(arguments.token);
    final snapshot = await client.read();
    runApp(SafeDiskNotepadWindow(
      arguments: arguments,
      client: client,
      cryptoService: RemoteDocumentCryptoService(
        client: client,
        initialSnapshot: snapshot,
      ),
      autoSaveInterval: Duration.zero,
    ));
    return;
  }
  runApp(const _NotepadSmokeHost());
}

class _NotepadSmokeHost extends StatefulWidget {
  const _NotepadSmokeHost();

  @override
  State<_NotepadSmokeHost> createState() => _NotepadSmokeHostState();
}

class _NotepadSmokeHostState extends State<_NotepadSmokeHost> {
  late final DocumentSessionBroker _broker;
  late final ContentWindowHostBridge _bridge;
  String _status = '正在建立跨窗口安全通道';

  @override
  void initState() {
    super.initState();
    _broker = DocumentSessionBroker(cryptoService: _SmokeCryptoService());
    _bridge = ContentWindowHostBridge(broker: _broker);
    unawaited(_openNotepad());
  }

  Future<void> _openNotepad() async {
    try {
      final lease = _broker.open(
        rootSessionID: 'smoke-root',
        path: '/note.txt',
        displayName: '跨窗口记事本.txt',
      );
      final opened = await _bridge.openNotepad(lease);
      if (mounted) setState(() => _status = opened ? '安全通道已连接' : '创建失败');
    } catch (error) {
      if (mounted) setState(() => _status = '创建失败：$error');
    }
  }

  @override
  void dispose() {
    unawaited(_bridge.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text(_status)),
      ),
    );
  }
}

class _SmokeCryptoService extends CryptoService {
  String content = '跨 engine 加密正文已读取';
  Uint8List? draft;

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    if (path.contains('.__safedisk_notepad_draft_')) return draft!;
    return Uint8List.fromList(utf8.encode(content));
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (path.contains('.__safedisk_notepad_draft_')) {
      draft = Uint8List.fromList(data);
    } else {
      content = utf8.decode(data);
    }
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    return !path.contains('.__safedisk_notepad_draft_') || draft != null;
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    draft = null;
  }
}
