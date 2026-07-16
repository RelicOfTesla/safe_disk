import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../widgets/file_item_actions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PropertyOverlaySmokeApp());
}

class _PropertyOverlaySmokeApp extends StatefulWidget {
  const _PropertyOverlaySmokeApp();

  @override
  State<_PropertyOverlaySmokeApp> createState() =>
      _PropertyOverlaySmokeAppState();
}

class _PropertyOverlaySmokeAppState extends State<_PropertyOverlaySmokeApp> {
  final _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_measure()));
  }

  Future<void> _measure() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final timingCompleter = Completer<FrameTiming>();
    void timingsCallback(List<FrameTiming> timings) {
      if (!timingCompleter.isCompleted && timings.isNotEmpty) {
        timingCompleter.complete(timings.first);
      }
    }

    WidgetsBinding.instance.addTimingsCallback(timingsCallback);
    final stopwatch = Stopwatch()..start();
    unawaited(showFileItemProperties(
      context: _scaffoldKey.currentContext!,
      item: FileSystemNode(
        name: '首次属性.txt',
        path: '/vault/首次属性.txt',
        isDirectory: false,
        size: 1024,
        modifiedTime: DateTime(2026, 7, 16),
      ),
    ));
    try {
      final timing = await timingCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      stopwatch.stop();
      stdout.writeln(
        'SAFE_DISK_PROPERTY_OVERLAY_FRAME '
        'wall_us=${stopwatch.elapsedMicroseconds} '
        'build_us=${timing.buildDuration.inMicroseconds} '
        'raster_us=${timing.rasterDuration.inMicroseconds} '
        'total_us=${timing.totalSpan.inMicroseconds}',
      );
      await stdout.flush();
      exit(0);
    } catch (error) {
      stderr.writeln('SAFE_DISK_PROPERTY_OVERLAY_FAIL: $error');
      await stderr.flush();
      exit(1);
    } finally {
      WidgetsBinding.instance.removeTimingsCallback(timingsCallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        body: const Center(child: Text('属性性能测试')),
      ),
    );
  }
}
