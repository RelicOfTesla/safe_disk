import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

const _childArgument = 'safe-disk-multi-window-smoke-child';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final current = await WindowController.fromCurrentEngine();
  if (current.arguments == _childArgument) {
    runApp(const _SmokeApp(label: 'Safe Disk 子窗口'));
    return;
  }
  runApp(const _SmokeHost());
}

class _SmokeHost extends StatefulWidget {
  const _SmokeHost();

  @override
  State<_SmokeHost> createState() => _SmokeHostState();
}

class _SmokeHostState extends State<_SmokeHost> {
  String _status = '正在创建子窗口';

  @override
  void initState() {
    super.initState();
    unawaited(_openChild());
  }

  Future<void> _openChild() async {
    try {
      final controller = await WindowController.create(
        const WindowConfiguration(
          arguments: _childArgument,
          hiddenAtLaunch: true,
        ),
      );
      await controller.show();
      if (mounted) setState(() => _status = '子窗口已创建');
    } catch (error) {
      if (mounted) setState(() => _status = '创建失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SmokeApp(label: 'Safe Disk 主窗口\n$_status');
  }
}

class _SmokeApp extends StatelessWidget {
  const _SmokeApp({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Disk Multi Window Smoke',
      home: Scaffold(
        body: Center(
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
