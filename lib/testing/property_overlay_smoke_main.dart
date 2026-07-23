import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../services/file_service.dart';
import '../widgets/file_item_actions.dart';
import '../widgets/root_directory_properties.dart';
import '../widgets/sidebar.dart';

const _smokeKind = String.fromEnvironment(
  'SAFE_DISK_PROPERTY_SMOKE_KIND',
  defaultValue: 'file',
);

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

    final context = _scaffoldKey.currentContext;
    if (context == null) return;
    if (!context.mounted) return;
    if (_smokeKind == 'root') {
      final menuFuture = showMenu<SidebarDirectoryAction>(
        context: context,
        position: const RelativeRect.fromLTRB(80, 80, 80, 80),
        items: const [
          PopupMenuItem(
            value: SidebarDirectoryAction.properties,
            child: Text('属性'),
          ),
        ],
      );
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          final navigatorContext = _scaffoldKey.currentContext;
          if (navigatorContext != null) {
            Navigator.of(navigatorContext).pop(
              SidebarDirectoryAction.properties,
            );
          }
        }
      });
      final action = await menuFuture;
      if (action != SidebarDirectoryAction.properties) {
        throw StateError('root property menu did not select properties');
      }
    } else {
      final menuFuture = showFileItemContextMenu(
        context: context,
        item: FileSystemNode(
          name: '首次属性.txt',
          path: '/vault/首次属性.txt',
          isDirectory: false,
          size: 1024,
          modifiedTime: DateTime(2026, 7, 16),
        ),
        globalPosition: const Offset(80, 80),
      );
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          final navigatorContext = _scaffoldKey.currentContext;
          if (navigatorContext != null) {
            Navigator.of(navigatorContext).pop(FileItemAction.properties);
          }
        }
      });
      final action = await menuFuture;
      if (action != FileItemAction.properties) {
        throw StateError('file property menu did not select properties');
      }
    }

    if (_smokeKind == 'delayed') {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;
    final propertyContext = _scaffoldKey.currentContext;
    if (propertyContext == null) return;
    if (!propertyContext.mounted) return;
    WidgetsBinding.instance.addTimingsCallback(timingsCallback);
    final stopwatch = Stopwatch()..start();
    if (_smokeKind == 'menu') {
      // Keep the menu-close frame as a control measurement.
    } else if (_smokeKind == 'root') {
      unawaited(showRootDirectoryProperties(
        context: propertyContext,
        directory: EncryptedDirectory(
          path: '/vault',
          isVerified: true,
          displayAlias: '工作盘',
          config: CryptionConfig({
            'version': '2',
            'sec_fs_factory': 'AES-256-CTR',
            'sec_name_factory': 'AES-256-GCM',
            'sec_deriver_factory': 'Argon2id',
            'sec_password_verifier_version': 1,
            'sec_password_hint': '第一只宠物',
          }),
        ),
      ));
    } else {
      unawaited(showFileItemProperties(
        context: propertyContext,
        item: FileSystemNode(
          name: '首次属性.txt',
          path: '/vault/首次属性.txt',
          isDirectory: false,
          size: 1024,
          modifiedTime: DateTime(2026, 7, 16),
        ),
      ));
    }
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        key: _scaffoldKey,
        body: const Center(child: Text('属性性能测试')),
      ),
    );
  }
}
