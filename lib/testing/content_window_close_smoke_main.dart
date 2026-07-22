import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(current.show());
    });
    return;
  }
  runApp(const _CloseSmokeHost());
}

class _CloseSmokeHost extends StatefulWidget {
  const _CloseSmokeHost();

  @override
  State<_CloseSmokeHost> createState() => _CloseSmokeHostState();
}

class _CloseSmokeHostState extends State<_CloseSmokeHost> {
  late final DocumentSessionBroker _broker;
  late final ContentWindowHostBridge _bridge;
  String _status = '准备原生窗口关闭测试';

  @override
  void initState() {
    super.initState();
    _broker = DocumentSessionBroker(cryptoService: _CloseSmokeCryptoService());
    _bridge = ContentWindowHostBridge(broker: _broker);
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      for (var index = 1; index <= 5; index++) {
        final lease = _broker.open(
          rootSessionID: 'smoke-root',
          path: '/note-$index.txt',
          displayName: '关闭测试-$index.txt',
        );
        if (!await _bridge.openNotepad(lease, localePreference: 'zh')) {
          throw StateError('第 $index 个子窗口创建失败');
        }
        if (mounted) setState(() => _status = '已创建第 $index 个子窗口');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _bridge.closeRootWindows('smoke-root');
        await _waitUntilClosed();
        if (_broker.containsToken(lease.token)) {
          throw StateError('第 $index 个窗口关闭后 lease 未释放');
        }
      }
      stdout.writeln('SAFE_DISK_CLOSE_SMOKE_PASS');
      await stdout.flush();
      exit(0);
    } catch (error, stackTrace) {
      stderr.writeln('SAFE_DISK_CLOSE_SMOKE_FAIL: $error');
      stderr.writeln(stackTrace);
      await stderr.flush();
      exit(1);
    }
  }

  Future<void> _waitUntilClosed() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final windows = await WindowController.getAll();
      final contentWindows = windows.where(
        (window) =>
            DesktopMultiWindowPlatform.tryParseArguments(window.arguments) !=
            null,
      );
      if (contentWindows.isEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw TimeoutException('子窗口未在 5 秒内从窗口集合移除');
  }

  @override
  void dispose() {
    unawaited(_bridge.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Center(child: Text(_status))),
    );
  }
}

class _CloseSmokeCryptoService extends CryptoService {
  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    return Uint8List.fromList(utf8.encode('原生窗口关闭 smoke'));
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    return false;
  }
}
