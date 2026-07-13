import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import '../models/secure_image_policy.dart';
import '../services/content_window_host_bridge.dart';
import '../services/crypto_service.dart';
import '../services/document_session_broker.dart';
import '../services/document_window_client.dart';
import '../services/remote_document_crypto_service.dart';
import '../windows/secure_image_window.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final current = await WindowController.fromCurrentEngine();
  final arguments =
      DesktopMultiWindowPlatform.tryParseArguments(current.arguments);
  if (arguments != null) {
    final client = DocumentWindowClient(arguments.token);
    final snapshot = await client.read();
    runApp(SafeDiskImageWindow(
      arguments: arguments,
      client: client,
      cryptoService: RemoteDocumentCryptoService(
        client: client,
        initialSnapshot: snapshot,
      ),
    ));
    return;
  }
  runApp(const _ImageSmokeHost());
}

class _ImageSmokeHost extends StatefulWidget {
  const _ImageSmokeHost();

  @override
  State<_ImageSmokeHost> createState() => _ImageSmokeHostState();
}

class _ImageSmokeHostState extends State<_ImageSmokeHost> {
  late final DocumentSessionBroker _broker;
  late final ContentWindowHostBridge _bridge;
  String _status = '正在建立图片安全通道';

  @override
  void initState() {
    super.initState();
    _broker = DocumentSessionBroker(cryptoService: _SmokeImageCryptoService());
    _bridge = ContentWindowHostBridge(broker: _broker);
    unawaited(_openImage());
  }

  Future<void> _openImage() async {
    try {
      final lease = _broker.open(
        rootSessionID: 'smoke-root',
        path: '/pixel.png',
        displayName: '跨窗口图片.png',
        maxContentBytes: kMaxSecureImageEncodedBytes,
        readOnly: true,
      );
      final opened = await _bridge.openImage(lease);
      if (mounted) setState(() => _status = opened ? '图片安全通道已连接' : '创建失败');
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
      home: Scaffold(body: Center(child: Text(_status))),
    );
  }
}

class _SmokeImageCryptoService extends CryptoService {
  final Uint8List image = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL9WQAAAABJRU5ErkJggg==',
  ));

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    return Uint8List.fromList(image);
  }
}
