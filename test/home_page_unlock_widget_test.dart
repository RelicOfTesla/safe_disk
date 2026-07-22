import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/models/secure_image_policy.dart';
import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/pages/home_page.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/content_window_host_bridge.dart';
import 'package:safe_disk/services/directory_persistence_service.dart';
import 'package:safe_disk/services/directory_service.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/settings_service.dart';
import 'package:safe_disk/services/secure_notepad_policy.dart';
import 'package:safe_disk/utils/error_messages.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens settings from the main toolbar', (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final persistenceService = _FakePersistenceService(rootPath);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: persistenceService,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('安全草稿保存间隔'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('安全草稿保存间隔'), findsOneWidget);
    expect(find.text('30 秒'), findsWidgets);
  });

  testWidgets('sidebar root is read only after password authentication',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('vault'), findsOneWidget);
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();

    expect(find.text('请输入密码以解锁：'), findsOneWidget);
    expect(fileService.listCalls, 0);
    expect(find.text('无法读取目录内容。'), findsNothing);

    await tester.enterText(find.byType(TextField), 'wrong-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(find.text('请输入密码以解锁：'), findsOneWidget);
    expect(fileService.listCalls, 0);

    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(
      cryptoService.openedPasswords,
      ['wrong-password', 'correct-password'],
    );
    expect(fileService.listCalls, 1);
    expect(find.text('visible.txt'), findsOneWidget);
    expect(find.text('无法读取目录内容。'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    expect(cryptoService.closedRootIDs, [7]);
  });

  testWidgets('sidebar changes password only for a password-changeable root',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(
      rootPath,
      passwordChangeable: true,
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('vault').first),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改密码'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('root-password-current')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('root-password-current')),
      'correct-password',
    );
    await tester.enterText(
      find.byKey(const Key('root-password-new')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('root-password-confirm')),
      'new-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pumpAndSettle();

    expect(
      cryptoService.passwordChanges,
      [('correct-password', 'new-password')],
    );
    expect(cryptoService.closedRootIDs, [7]);
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
  });

  testWidgets('unlock password input disables suggestions and autocorrect',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: _FakeCryptoService(rootPath),
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(_FakeCryptoService(rootPath)),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: SettingsService(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();

    final passwordField = tester.widget<TextField>(find.byType(TextField));
    expect(passwordField.autocorrect, isFalse);
    expect(passwordField.enableSuggestions, isFalse);
    expect(passwordField.keyboardType, TextInputType.visiblePassword);
  });

  testWidgets('background lifecycle locks an eligible root when enabled',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    final settings = _AutoLockSettingsService(enabled: true);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: settings,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    expect(find.text('visible.txt'), findsOneWidget);
    expect(settings.reads, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, [7]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('visible.txt'), findsNothing);
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
  });

  testWidgets('background lifecycle locks every eligible unlocked root',
      (tester) async {
    const firstRootPath = '/tmp/safe-disk-home-test/vault-one';
    const secondRootPath = '/tmp/safe-disk-home-test/vault-two';
    final cryptoService = _FakeCryptoService(
      firstRootPath,
      additionalRootPaths: const [secondRootPath],
    );
    final settings = _AutoLockSettingsService(enabled: true);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(
          firstRootPath,
          rootPaths: const [firstRootPath, secondRootPath],
        ),
        settingsService: settings,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('vault-one'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('vault-two'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(settings.reads, greaterThan(0));
    expect(cryptoService.closedRootIDs, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();

    expect(cryptoService.closedRootIDs, unorderedEquals([7, 8]));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
    expect(find.text('visible.txt'), findsNothing);

    await tester.tap(find.text('vault-one'));
    await tester.pumpAndSettle();
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
  });

  testWidgets('background lifecycle does not lock roots by default',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: SettingsService(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, isEmpty);
    expect(find.text('visible.txt'), findsOneWidget);
  });

  testWidgets('idle TTL locks an eligible root without hiding the app',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final cryptoService = _FakeCryptoService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService:
            _AutoLockSettingsService(enabled: false, ttlSeconds: 1),
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    expect(cryptoService.closedRootIDs, [7]);
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
    expect(find.text('已自动锁定 1 个目录'), findsOneWidget);
  });

  testWidgets('idle TTL is reset by activity in the current root',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final cryptoService = _FakeCryptoService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService:
            _AutoLockSettingsService(enabled: false, ttlSeconds: 1),
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    now = now.add(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pump();
    now = now.add(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cryptoService.closedRootIDs, isEmpty);

    now = now.add(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cryptoService.closedRootIDs, [7]);
  });

  testWidgets('idle TTL prepares and locks a root with a clean content window',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform();
    addTearDown(platform.dispose);
    final image = FileSystemNode(
      name: '照片.png',
      path: '/照片.png',
      isDirectory: false,
      size: 128,
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [image]),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService:
            _AutoLockSettingsService(enabled: false, ttlSeconds: 1),
        contentWindowPlatform: platform,
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('照片.png')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中查看'));
    await tester.pumpAndSettle();
    expect(platform.openedImages, hasLength(1));

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cryptoService.closedRootIDs, [7]);
    expect(platform.closedTokens, hasLength(1));
    expect(find.text('照片.png'), findsNothing);
    expect(find.text('已自动锁定 1 个目录'), findsOneWidget);
  });

  testWidgets(
      'background auto-lock keeps root open when a content window rejects preparation',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform()..prepareResult = false;
    addTearDown(platform.dispose);
    final image = FileSystemNode(
      name: '照片.png',
      path: '/照片.png',
      isDirectory: false,
      size: 128,
    );
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [image]),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: _AutoLockSettingsService(enabled: true),
        contentWindowPlatform: platform,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('照片.png')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中查看'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, isEmpty);
    expect(platform.closedTokens, isEmpty);
    expect(find.text('照片.png'), findsOneWidget);
  });

  testWidgets('idle TTL keeps a root with a dirty secure notepad open',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final cryptoService = _FakeCryptoService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService:
            _AutoLockSettingsService(enabled: false, ttlSeconds: 1),
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('visible.txt'));
    await tester.pumpAndSettle();

    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.enterText(editor, '未保存的内容');
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));

    expect(cryptoService.closedRootIDs, isEmpty);
    expect(find.byKey(const Key('secure-notepad-editor')), findsOneWidget);
  });

  testWidgets('idle TTL keeps a root while a secure notepad save is active',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final writeGate = Completer<void>();
    final cryptoService = _FakeCryptoService(rootPath, writeGate: writeGate);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService:
            _AutoLockSettingsService(enabled: false, ttlSeconds: 1),
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('visible.txt'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('secure-notepad-editor')),
      '正在保存的内容',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));

    expect(cryptoService.closedRootIDs, isEmpty);
    writeGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('returning from settings reloads the current idle TTL',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    var now = DateTime(2026, 7, 18, 12);
    final cryptoService = _FakeCryptoService(rootPath);
    final settings = _AutoLockSettingsService(enabled: false);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: settings,
        idleCheckInterval: const Duration(milliseconds: 100),
        idleNow: () => now,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cryptoService.closedRootIDs, isEmpty);

    settings.ttlSeconds = 900;
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 15, seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(cryptoService.closedRootIDs, [7]);
  });

  testWidgets('secondary click opens the file context menu', (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('使用安全记事本编辑'), findsOneWidget);
    expect(find.text('导出解密文件'), findsOneWidget);
    expect(find.text('删除文件'), findsOneWidget);
    expect(find.text('打开目录'), findsNothing);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();

    final gridGesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gridGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('使用安全记事本编辑'), findsOneWidget);
    expect(find.text('导出解密文件'), findsOneWidget);
    expect(
      tester
          .widget<Card>(
            find.byKey(const ValueKey('file-grid-/visible.txt')),
          )
          .color,
      isNotNull,
    );
    final selectedGridCard = tester.widget<Card>(
      find.byKey(const ValueKey('file-grid-/visible.txt')),
    );
    expect((selectedGridCard.shape! as RoundedRectangleBorder).side.width, 2.5);

    await tester.tap(find.text('使用安全记事本编辑'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('secure-notepad-editor')), findsOneWidget);
    expect(find.text('右键菜单测试内容'), findsOneWidget);
  });

  testWidgets('Menu and Shift+F10 reopen the keyboard target context menu',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('使用安全记事本编辑'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('使用安全记事本编辑'), findsOneWidget);
  });

  testWidgets('Menu opens the directory menu when no file target exists',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(find.text('新建文件'), findsOneWidget);
    expect(find.text('新建目录'), findsOneWidget);
  });

  testWidgets('image context menu opens a capability-based native window',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform();
    addTearDown(platform.dispose);
    final image = FileSystemNode(
      name: '照片.png',
      path: '/照片.png',
      isDirectory: false,
      size: 128,
    );
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [image]),
        persistenceService: _FakePersistenceService(rootPath),
        contentWindowPlatform: platform,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('照片.png')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中查看'));
    await tester.pumpAndSettle();

    expect(platform.openedImages, hasLength(1));
    expect(platform.openedImages.single['title'], '照片.png');
    expect(platform.openedImages.single.values, isNot(contains('7')));
    expect(platform.openedImages.single.values, isNot(contains('/照片.png')));
  });

  testWidgets('background auto-lock prepares and closes a clean content window',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform();
    addTearDown(platform.dispose);
    final image = FileSystemNode(
      name: '照片.png',
      path: '/照片.png',
      isDirectory: false,
      size: 128,
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [image]),
        persistenceService: _FakePersistenceService(rootPath),
        settingsService: _AutoLockSettingsService(enabled: true),
        contentWindowPlatform: platform,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('照片.png')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中查看'));
    await tester.pumpAndSettle();
    expect(platform.openedImages, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(cryptoService.closedRootIDs, [7]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('照片.png'), findsNothing);
  });

  testWidgets('oversized image is rejected before opening a native window',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform();
    addTearDown(platform.dispose);
    final image = FileSystemNode(
      name: '超大图片.png',
      path: '/超大图片.png',
      isDirectory: false,
      size: kMaxSecureImageEncodedBytes + 1,
    );
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [image]),
        persistenceService: _FakePersistenceService(rootPath),
        contentWindowPlatform: platform,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('超大图片.png')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中查看'));
    await tester.pumpAndSettle();

    expect(platform.openedImages, isEmpty);
    expect(cryptoService.decryptedPaths, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('oversized text is rejected before opening either notepad view',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final platform = _FakeContentWindowPlatform();
    addTearDown(platform.dispose);
    final textFile = FileSystemNode(
      name: '超大文本.txt',
      path: '/超大文本.txt',
      isDirectory: false,
      size: kMaxSecureNotepadContentBytes + 1,
    );
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService, items: [textFile]),
        persistenceService: _FakePersistenceService(rootPath),
        contentWindowPlatform: platform,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    var gesture = await tester.startGesture(
      tester.getCenter(find.text('超大文本.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用安全记事本编辑'));
    await tester.pump();
    expect(cryptoService.decryptedPaths, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);

    gesture = await tester.startGesture(
      tester.getCenter(find.text('超大文本.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('在新窗口中编辑'));
    await tester.pumpAndSettle();
    expect(platform.notepadOpenRequests, 0);
    expect(cryptoService.decryptedPaths, isEmpty);
  });

  testWidgets('file context menu enters selection mode and batch exports',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '/outside/export',
        exportTargetExists: (_) async => false,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 项'), findsOneWidget);

    await tester.tap(find.byTooltip('更多批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出所选项'));
    await tester.pumpAndSettle();

    expect(fileService.exportCalls, [
      (
        name: 'visible.txt',
        path: '/outside/export/visible.txt',
        sessionID: '7',
      ),
    ]);
    expect(find.text('已选择 1 项'), findsNothing);
  });

  testWidgets('batch delete keeps failed files selected for retry',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(
      rootPath,
      deleteFailures: {'/failed.txt'},
    );
    final fileService = _FakeFileService(cryptoService, items: [
      FileSystemNode(
        name: 'success.txt',
        path: '/success.txt',
        isDirectory: false,
      ),
      FileSystemNode(
        name: 'failed.txt',
        path: '/failed.txt',
        isDirectory: false,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('success.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('failed.txt'));
    await tester.pump();
    expect(find.text('已选择 2 项'), findsOneWidget);

    await tester.tap(find.byTooltip('更多批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除所选项'));
    await tester.pumpAndSettle();
    expect(find.text('确认批量删除'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除所选项'));
    await tester.pumpAndSettle();

    expect(
      cryptoService.deletedFiles.map((entry) => entry.path).toSet(),
      {'/success.txt', '/failed.txt'},
    );
    expect(find.text('已选择 1 项'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('file-list-/failed.txt')),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('selected files enter one clipboard queue and paste in order',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(420, 700));
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService, items: [
      FileSystemNode(
        name: 'first.txt',
        path: '/first.txt',
        isDirectory: false,
      ),
      FileSystemNode(
        name: 'second.txt',
        path: '/second.txt',
        isDirectory: false,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('first.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('second.txt'));
    await tester.pump();

    await tester.tap(find.byTooltip('复制所选项'));
    await tester.pumpAndSettle();
    expect(find.textContaining('first.txt 等 2 项'), findsOneWidget);

    await tester.tap(find.byTooltip('粘贴到当前目录'));
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    await tester.tap(find.text('全部保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.copyCalls, [
      (
        sourcePath: '/first.txt',
        sourceSessionID: '7',
        destinationPath: '$rootPath/first - 副本.txt',
        destinationSessionID: '7',
        overwrite: false,
      ),
      (
        sourcePath: '/second.txt',
        sourceSessionID: '7',
        destinationPath: '$rootPath/second - 副本.txt',
        destinationSessionID: '7',
        overwrite: false,
      ),
    ]);
    expect(find.text('批量粘贴完成'), findsOneWidget);
    expect(find.text('成功：2'), findsOneWidget);
    expect(find.text('失败：0'), findsOneWidget);
    expect(find.text('剪贴板剩余：0'), findsOneWidget);
    expect(find.byKey(const Key('file-clipboard-status')), findsNothing);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('batch paste cancellation keeps every unprocessed clipboard item',
      (tester) async {
    final (:cryptoService, :fileService) = await _openTwoFileVault(tester);
    await _selectTwoEntries(tester, clipboardAction: '复制所选项');

    await tester.tap(find.byTooltip('粘贴到当前目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(cryptoService.copyCalls, isEmpty);
    expect(fileService.listCalls, 2);
    expect(find.text('批量粘贴已取消'), findsOneWidget);
    expect(find.text('未处理：2'), findsOneWidget);
    expect(find.text('剪贴板剩余：2'), findsOneWidget);
    expect(find.byKey(const Key('file-clipboard-status')), findsOneWidget);
  });

  testWidgets('batch paste reports partial failure and leaves it retryable',
      (tester) async {
    final (:cryptoService, :fileService) = await _openTwoFileVault(
      tester,
      copyFailures: const {'/second.txt'},
    );
    await _selectTwoEntries(tester, clipboardAction: '复制所选项');

    await tester.tap(find.byTooltip('粘贴到当前目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.copyCalls, hasLength(2));
    expect(fileService.listCalls, 2);
    expect(find.text('批量粘贴部分完成'), findsOneWidget);
    expect(find.text('成功：1'), findsOneWidget);
    expect(find.text('失败：1'), findsOneWidget);
    expect(find.text('剪贴板剩余：1'), findsOneWidget);
    expect(find.textContaining('copy failed'), findsOneWidget);
    expect(find.byKey(const Key('file-clipboard-status')), findsOneWidget);
  });

  testWidgets('batch cut applies keep-both policy once and renames each item',
      (tester) async {
    final (:cryptoService, :fileService) = await _openTwoFileVault(tester);
    await _selectTwoEntries(tester, clipboardAction: '剪切所选项');

    await tester.tap(find.byTooltip('移动到当前目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.renameCalls, [
      (
        oldPath: '/first.txt',
        newPath: '$_twoFileRootPath/first - 副本.txt',
        sessionID: '7',
      ),
      (
        oldPath: '/second.txt',
        newPath: '$_twoFileRootPath/second - 副本.txt',
        sessionID: '7',
      ),
    ]);
    expect(cryptoService.copyCalls, isEmpty);
    expect(fileService.listCalls, 2);
    expect(find.text('批量移动完成'), findsOneWidget);
    expect(find.text('成功：2'), findsOneWidget);
    expect(find.byKey(const Key('file-clipboard-status')), findsNothing);
  });

  testWidgets('context-menu export confirms plaintext before selecting target',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    var saveLocationRequests = 0;

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectSaveLocation: (suggestedName) async {
          saveLocationRequests++;
          expect(suggestedName, 'visible.txt');
          return const FileSaveLocation('/tmp/exported-visible.txt');
        },
        exportTargetExists: (_) async => false,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出解密文件'));
    await tester.pumpAndSettle();

    expect(find.text('确认导出明文'), findsOneWidget);
    expect(saveLocationRequests, 0);

    await tester.tap(find.text('继续导出'));
    await tester.pumpAndSettle();

    expect(saveLocationRequests, 1);
    expect(fileService.exportCalls, [
      (
        name: 'visible.txt',
        path: '/tmp/exported-visible.txt',
        sessionID: '7',
      ),
    ]);

    final deleteGesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await deleteGesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除文件'));
    await tester.pumpAndSettle();

    expect(find.text('确认删除文件'), findsOneWidget);
    expect(cryptoService.deletedFiles, isEmpty);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(cryptoService.deletedFiles, [
      (path: '/visible.txt', sessionID: '7'),
    ]);
  });

  testWidgets(
      'file export requires an explicit decision for an existing target',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final exportDirectory =
        Directory.systemTemp.createTempSync('safe-disk-ui-export-');
    addTearDown(() => exportDirectory.deleteSync(recursive: true));
    final target = File('${exportDirectory.path}/visible.txt');
    target.writeAsStringSync('existing');
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectSaveLocation: (_) async => FileSaveLocation(target.path),
        exportTargetExists: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出解密文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续导出'));
    await tester.pumpAndSettle();

    expect(find.text('目标已存在'), findsOneWidget);
    expect(fileService.exportCalls, isEmpty);
    await tester.tap(find.text('替换'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fileService.exportCalls.single.path, target.path);
    expect(fileService.exportOverwriteFlags, [true]);
  });

  testWidgets('delete confirmation setting changes the actual delete flow',
      (tester) async {
    SharedPreferences.setMockInitialValues({'confirm_before_delete': false});
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除文件'));
    await tester.pumpAndSettle();

    expect(find.text('确认删除文件'), findsNothing);
    expect(cryptoService.deletedFiles, [
      (path: '/visible.txt', sessionID: '7'),
    ]);
  });

  testWidgets('context menu copies metadata, shows properties and refreshes',
      (tester) async {
    Map<String, dynamic>? clipboardData;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardData = Map<String, dynamic>.from(
          call.arguments! as Map<dynamic, dynamic>,
        );
      }
      if (call.method == 'Clipboard.getData') return clipboardData;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    Future<void> openContextMenu() async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('visible.txt')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await openContextMenu();
    await tester.tap(find.text('复制名称（明文）'));
    await tester.pumpAndSettle();
    expect(clipboardData?['text'], 'visible.txt');

    await openContextMenu();
    await tester.tap(find.text('复制逻辑路径（明文）'));
    await tester.pumpAndSettle();
    expect(clipboardData?['text'], '/visible.txt');

    await openContextMenu();
    await tester.tap(find.text('属性'));
    await tester.pumpAndSettle();
    expect(find.text('逻辑路径：'), findsOneWidget);
    expect(find.text('/visible.txt'), findsOneWidget);
    expect(find.text('7 B'), findsWidgets);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(fileService.listCalls, 1);
    await openContextMenu();
    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(fileService.listCalls, 2);
  });

  testWidgets('context menu renames through the active root session',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(find.text('重命名文件'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'renamed.txt');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();

    expect(cryptoService.renameCalls, [
      (
        oldPath: '/visible.txt',
        newPath: '/renamed.txt',
        sessionID: '7',
      ),
    ]);
    expect(fileService.listCalls, 2);
  });

  testWidgets('desktop F5, Ctrl+V and F2 shortcuts use the active file context',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(fileService.listCalls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(fileService.listCalls, 2);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    expect(find.text('重命名文件'), findsOneWidget);
  });

  testWidgets('copy and paste asks before a same-name destination',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();

    expect(find.textContaining('visible.txt'), findsWidgets);
    expect(find.byKey(const Key('file-clipboard-status')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('file-clipboard-status'))).height,
      44,
    );
    expect(find.textContaining('文件剪贴板 ·'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(600, 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('待粘贴 · visible.txt'), findsOneWidget);
    expect(find.byTooltip('粘贴到当前目录'), findsOneWidget);

    await tester.tap(find.byTooltip('粘贴到当前目录'));
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    expect(find.text('替换'), findsNothing);
    expect(cryptoService.copyCalls, isEmpty);

    await tester.tap(find.text('保留两者'));
    await tester.pumpAndSettle();
    expect(cryptoService.copyCalls, [
      (
        sourcePath: '/visible.txt',
        sourceSessionID: '7',
        destinationPath: '$rootPath/visible - 副本.txt',
        destinationSessionID: '7',
        overwrite: false,
      ),
    ]);
    expect(fileService.listCalls, 2);
    expect(find.byKey(const Key('file-clipboard-status')), findsNothing);
  });

  testWidgets('same-root cut uses rename after conflict keeps both',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('剪切'));
    await tester.pumpAndSettle();

    expect(find.textContaining('待移动 · visible.txt'), findsOneWidget);
    await tester.tap(find.byTooltip('移动到当前目录'));
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    expect(find.text('替换'), findsNothing);
    await tester.tap(find.text('保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.renameCalls, [
      (
        oldPath: '/visible.txt',
        newPath: '$rootPath/visible - 副本.txt',
        sessionID: '7',
      ),
    ]);
    expect(cryptoService.copyCalls, isEmpty);
    expect(cryptoService.deletedFiles, isEmpty);
    expect(find.byKey(const Key('file-clipboard-status')), findsNothing);
  });

  testWidgets('cross-root directory cut resolves conflict then deletes source',
      (tester) async {
    const sourceRoot = '/tmp/safe-disk-home-test/source-vault';
    const destinationRoot = '/tmp/safe-disk-home-test/destination-vault';
    final cryptoService = _FakeCryptoService(
      sourceRoot,
      additionalRootPaths: const [destinationRoot],
    );
    final fileService = _FakeFileService(cryptoService, items: [
      FileSystemNode(
        name: '资料',
        path: '$sourceRoot/资料',
        isDirectory: true,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(
          sourceRoot,
          rootPaths: const [sourceRoot, destinationRoot],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('source-vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('资料')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('剪切'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('destination-vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移动到当前目录'));
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    await tester.tap(find.text('保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.copyCalls, [
      (
        sourcePath: '$sourceRoot/资料',
        sourceSessionID: '7',
        destinationPath: '$destinationRoot/资料 - 副本',
        destinationSessionID: '8',
        overwrite: false,
      ),
    ]);
    expect(cryptoService.deletedDirectories, [
      (path: '$sourceRoot/资料', sessionID: '7'),
    ]);
    expect(find.byKey(const Key('file-clipboard-status')), findsNothing);
  });

  testWidgets('cross-root directory partial move keeps clipboard entry',
      (tester) async {
    const sourceRoot = '/tmp/safe-disk-home-test/source-failure-vault';
    const destinationRoot =
        '/tmp/safe-disk-home-test/destination-failure-vault';
    final cryptoService = _FakeCryptoService(
      sourceRoot,
      additionalRootPaths: const [destinationRoot],
      failDirectoryDelete: true,
    );
    final fileService = _FakeFileService(cryptoService, items: [
      FileSystemNode(
        name: '资料',
        path: '$sourceRoot/资料',
        isDirectory: true,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: fileService,
        persistenceService: _FakePersistenceService(
          sourceRoot,
          rootPaths: const [sourceRoot, destinationRoot],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('source-failure-vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('资料')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('剪切'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('destination-failure-vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移动到当前目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留两者'));
    await tester.pumpAndSettle();

    expect(cryptoService.copyCalls, hasLength(1));
    expect(cryptoService.deletedDirectories, [
      (path: '$sourceRoot/资料', sessionID: '7'),
    ]);
    expect(
      find.textContaining('目标已复制，但无法删除源项。源项和目标均已保留，请确认内容后手动删除源项。'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('file-clipboard-status')), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('blank-area menu creates entries and item menu stays separate',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    final itemGesture = await tester.startGesture(
      tester.getCenter(find.text('visible.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await itemGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('新建文件'), findsNothing);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('file-list-/visible.txt')),
          )
          .selected,
      isTrue,
    );
    final selectedListContainer = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('file-list-/visible.txt')),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final selectedDecoration =
        selectedListContainer.decoration! as BoxDecoration;
    expect((selectedDecoration.border! as Border).left.width, 4);
    expect(
      tester
          .widget<Material>(
              find.byKey(const ValueKey('file-list-material-/visible.txt')))
          .color,
      isNot(Colors.transparent),
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    final browser = find.byKey(const Key('directory-browser-background'));
    final browserBox = tester.getRect(browser);
    expect(browserBox.height, greaterThan(100));
    final blankGesture = await tester.startGesture(
      browserBox.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await blankGesture.up();
    await tester.pumpAndSettle();

    expect(find.text('新建文件'), findsOneWidget);
    expect(find.text('新建目录'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);

    await tester.tap(find.text('新建文件'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-entry-name')),
      '新文件.txt',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(cryptoService.createdFiles, [
      (path: '$rootPath/新文件.txt', sessionID: '7'),
    ]);

    final secondBlankGesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const Key('directory-browser-background')),
      ),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await secondBlankGesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建目录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-entry-name')),
      '新目录',
    );
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(cryptoService.createdDirectories, [
      (path: '$rootPath/新目录', sessionID: '7'),
    ]);
  });

  testWidgets('ending the current root session keeps history and relocks it',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final persistenceService = _FakePersistenceService(rootPath);

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: persistenceService,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('关闭目录'));
    await tester.pumpAndSettle();
    expect(find.text('目录操作'), findsOneWidget);
    expect(find.textContaining('保留侧边栏历史'), findsOneWidget);

    await tester.tap(find.text('仅结束会话'));
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, [7]);
    expect(cryptoService.deletedFiles, isEmpty);
    expect(persistenceService.savedDirectoryLists, isEmpty);
    expect(find.text('vault'), findsOneWidget);
    expect(find.text('请输入密码以解锁：'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    expect(cryptoService.openedPasswords, [
      'correct-password',
      'correct-password',
    ]);
    expect(find.text('visible.txt'), findsOneWidget);
  });

  testWidgets('sidebar can end a session and remove only its history',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final persistenceService = _FakePersistenceService(rootPath);
    var deleteCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: persistenceService,
        deleteRootDirectory: (_) async {
          deleteCalls++;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多目录操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束会话并移除历史'));
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, [7]);
    expect(deleteCalls, 0);
    expect(persistenceService.savedDirectoryLists, [<String>[]]);
    expect(find.text('vault'), findsNothing);
  });

  testWidgets('root session removal follows the active English locale',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final persistenceService = _FakePersistenceService(rootPath);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: persistenceService,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(tester.element(find.byType(HomePage)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More directory actions'));
    await tester.pumpAndSettle();
    final removeHistory = find.byKey(const Key('root-action-remove-history'));
    await tester.ensureVisible(removeHistory);
    await tester.pumpAndSettle();
    await tester.tap(removeHistory);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Directory history removed. Files on disk were kept.'),
      findsOneWidget,
    );
    expect(cryptoService.closedRootIDs, [7]);
    expect(find.text('vault'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('deleting a root requires its exact name and removes history',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('safe-disk-root-delete-');
    File('${root.path}/encrypted-entry').writeAsStringSync('ciphertext');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final rootPath = root.path;
    final rootName =
        root.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
    final cryptoService = _FakeCryptoService(rootPath);
    final persistenceService = _FakePersistenceService(rootPath);
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: _FakeDirectoryService(),
        fileService: _FakeFileService(cryptoService),
        persistenceService: persistenceService,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(rootName));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多目录操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束会话、移除历史并删除目录'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除本地目录'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '永久删除目录'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('root-delete-confirmation')),
      rootName,
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '永久删除目录'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (persistenceService.savedDirectoryLists.isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(cryptoService.closedRootIDs, [7]);
    expect(root.existsSync(), isFalse);
    expect(persistenceService.savedDirectoryLists, [<String>[]]);
    expect(find.text(rootName), findsNothing);
  });

  testWidgets('file import conflict can cancel or explicitly replace',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final source = XFile.fromData(
      Uint8List.fromList([9, 8, 7]),
      path: '/outside/visible.txt',
      name: 'visible.txt',
    );
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService();

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        selectFile: (_) async => source,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入文件'));
    await tester.pumpAndSettle();
    expect(find.text('目标已存在'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(directoryService.importFileCalls, isEmpty);

    await tester.tap(find.byTooltip('导入文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换'));
    await tester.pumpAndSettle();
    expect(directoryService.importFileCalls, [
      (
        rootID: 7,
        source: '/outside/visible.txt',
        destination: 'visible.txt',
        overwrite: true,
      ),
    ]);
  });

  testWidgets('directory import waits for merge confirmation', (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService();
    final fileService = _FakeFileService(
      cryptoService,
      items: [
        FileSystemNode(
          name: 'incoming',
          path: '$rootPath/incoming',
          isDirectory: true,
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '/outside/incoming',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入目录'));
    await tester.pumpAndSettle();

    expect(find.text('目标已存在'), findsOneWidget);
    expect(directoryService.importCalls, isEmpty);

    await tester.tap(find.text('合并并替换'));
    await tester.pumpAndSettle();

    expect(directoryService.importCalls, [
      (
        rootID: 7,
        source: '/outside/incoming',
        destination: 'incoming',
        overwrite: true,
      ),
    ]);
  });

  testWidgets('directory import rejects a source inside the encrypted root',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService();
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '$rootPath/existing',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(isPathInsideDirectory('$rootPath/existing', rootPath), isTrue);
    final descriptor = ErrorMessages.descriptor(
      ErrorType.importDirectoryInsideCurrentRoot,
    );
    expect(descriptor.type, ErrorType.importDirectoryInsideCurrentRoot);
    expect(descriptor.isCritical, isFalse);

    await tester.tap(find.byTooltip('导入目录'));
    await tester.pump();
    await tester.pump();
    expect(directoryService.importCalls, isEmpty);
  });

  testWidgets('directory import failure closes progress and keeps root open',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(importError: 'disk full');

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
        selectDirectory: () async => '/outside/new-directory',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    await tester.tap(find.byTooltip('导入目录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(directoryService.importCalls, [
      (
        rootID: 7,
        source: '/outside/new-directory',
        destination: 'new-directory',
        overwrite: false,
      ),
    ]);
    expect(find.text('正在准备导入...'), findsNothing);
    expect(find.text('visible.txt'), findsOneWidget);
    expect(find.textContaining('无法将目录导入到加密目录。'), findsOneWidget);
  });

  testWidgets('file picker import uses V3 without implicit overwrite',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final source = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      path: 'selected.txt',
      name: 'selected.txt',
    );
    final cryptoService = _FakeCryptoService(rootPath);
    final fileService = _FakeFileService(cryptoService);
    final directoryService = _FakeDirectoryService();

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: fileService,
        persistenceService: _FakePersistenceService(rootPath),
        selectFile: (groups) async {
          expect(groups, isNotEmpty);
          expect(groups.single.label, '所有文件');
          return source;
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('导入文件'));
    await tester.pumpAndSettle();

    final import = directoryService.importFileCalls.single;
    expect(import.rootID, 7);
    expect(import.source, 'selected.txt');
    expect(import.destination, 'selected.txt');
    expect(import.overwrite, isFalse);
    expect(fileService.listCalls, 2);
  });

  testWidgets('unfinished operation can be rerun while unlocking',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final marker = <String, dynamic>{
      'op_id': 'unfinished-1',
      'type': 'import',
      'entry_kind': 'directory',
      'src': '/outside/source',
      'dst': 'restored',
    };
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(
      unfinishedMarkers: [marker],
    );

    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发现未完成的导入/导出'), findsOneWidget);
    expect(find.textContaining('这些操作无法继续'), findsOneWidget);
    await tester.tap(find.text('全量重跑'));
    await tester.pumpAndSettle();

    expect(directoryService.rerunCalls, [marker]);
    expect(find.text('visible.txt'), findsOneWidget);
  });

  testWidgets('unfinished transfer confirmation follows the active locale',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final marker = <String, dynamic>{
      'op_id': 'unfinished-english',
      'type': 'export',
      'entry_kind': 'file',
      'src': 'report.txt',
      'dst': '/outside/report.txt',
    };
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(
      unfinishedMarkers: [marker],
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Unfinished imports or exports found'), findsOneWidget);
    expect(find.textContaining('cannot be resumed'), findsOneWidget);
    expect(find.text('Rerun all'), findsOneWidget);
    await tester.tap(find.text('Rerun all'));
    await tester.pumpAndSettle();

    expect(directoryService.rerunCalls, [marker]);
  });

  testWidgets('corrupt unfinished state closes the new root session',
      (tester) async {
    const rootPath = '/tmp/safe-disk-home-test/vault';
    final cryptoService = _FakeCryptoService(rootPath);
    final directoryService = _FakeDirectoryService(
      unfinishedListError: const NativeOperationException(
        'secTransferV3ListUnfinished',
        'marker is corrupt',
        code: NativeErrorCode.transferMarkerCorrupt,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomePage(
        cryptoService: cryptoService,
        directoryService: directoryService,
        fileService: _FakeFileService(cryptoService),
        persistenceService: _FakePersistenceService(rootPath),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'correct-password');
    await tester.tap(find.text('解锁'));
    await tester.pumpAndSettle();

    expect(find.text('无法确认未完成传输状态'), findsOneWidget);
    expect(cryptoService.closedRootIDs, [7]);
    expect(find.text('visible.txt'), findsNothing);
  });
}

/// Keeps every HomePage test inside the same localization boundary as the app.
class MaterialApp extends material.MaterialApp {
  const MaterialApp({
    super.key,
    super.home,
    Locale? locale,
    Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates,
    Iterable<Locale>? supportedLocales,
  }) : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates:
              localizationsDelegates ?? AppLocalizations.localizationsDelegates,
          supportedLocales:
              supportedLocales ?? AppLocalizations.supportedLocales,
        );
}

const _twoFileRootPath = '/tmp/safe-disk-home-test/two-file-vault';

Future<
    ({
      _FakeCryptoService cryptoService,
      _FakeFileService fileService,
    })> _openTwoFileVault(
  WidgetTester tester, {
  Set<String> copyFailures = const {},
}) async {
  final cryptoService = _FakeCryptoService(
    _twoFileRootPath,
    copyFailures: copyFailures,
  );
  final fileService = _FakeFileService(cryptoService, items: [
    FileSystemNode(
      name: 'first.txt',
      path: '/first.txt',
      isDirectory: false,
    ),
    FileSystemNode(
      name: 'second.txt',
      path: '/second.txt',
      isDirectory: false,
    ),
  ]);
  await tester.pumpWidget(MaterialApp(
    home: HomePage(
      cryptoService: cryptoService,
      directoryService: _FakeDirectoryService(),
      fileService: fileService,
      persistenceService: _FakePersistenceService(_twoFileRootPath),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('two-file-vault'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'correct-password');
  await tester.tap(find.text('解锁'));
  await tester.pumpAndSettle();
  return (cryptoService: cryptoService, fileService: fileService);
}

Future<void> _selectTwoEntries(
  WidgetTester tester, {
  required String clipboardAction,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.text('first.txt')),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
  await tester.tap(find.text('选择'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('second.txt'));
  await tester.pump();
  await tester.tap(find.byTooltip(clipboardAction));
  await tester.pumpAndSettle();
}

class _FakeCryptoService extends CryptoService {
  _FakeCryptoService(
    this.rootPath, {
    this.additionalRootPaths = const [],
    this.deleteFailures = const {},
    this.failDirectoryDelete = false,
    this.copyFailures = const {},
    this.writeGate,
    this.passwordChangeable = false,
  });

  final String rootPath;
  final List<String> additionalRootPaths;
  final Set<String> deleteFailures;
  final bool failDirectoryDelete;
  final Set<String> copyFailures;
  final Completer<void>? writeGate;
  final bool passwordChangeable;
  final List<String> openedPasswords = [];
  final List<String> decryptedPaths = [];
  final List<int> closedRootIDs = [];
  final List<(String oldPassword, String newPassword)> passwordChanges = [];
  final List<({String path, String sessionID})> deletedFiles = [];
  final List<({String path, String sessionID})> deletedDirectories = [];
  final List<({String oldPath, String newPath, String sessionID})> renameCalls =
      [];
  final List<
      ({
        String sourcePath,
        String sourceSessionID,
        String destinationPath,
        String destinationSessionID,
        bool overwrite,
      })> copyCalls = [];
  final List<({String path, String sessionID, List<int> bytes})> fileWrites =
      [];
  final List<({String path, String sessionID})> createdFiles = [];
  final List<({String path, String sessionID})> createdDirectories = [];
  final Map<String, int> _rootIDs = {};
  final Map<int, String> _rootPaths = {};
  int _nextRootID = 7;

  @override
  CryptionConfig loadConfig(String rootPath) => CryptionConfig({
        'version': '1.0',
        'dataFactory': 'AES-CTR',
        'nameFactory': 'AES-256-GCM',
        if (passwordChangeable) 'sec_key_envelope_version': 1,
      });

  @override
  void changeRootPassword(
    String rootPath,
    String oldPassword,
    String newPassword,
  ) {
    if (rootPath != this.rootPath) throw StateError('Unknown root: $rootPath');
    passwordChanges.add((oldPassword, newPassword));
  }

  @override
  int openRoot(String rootPath, String password, String configJSON) {
    openedPasswords.add(password);
    if (password != 'correct-password') {
      throw StateError('invalid password');
    }
    if (rootPath != this.rootPath && !additionalRootPaths.contains(rootPath)) {
      throw StateError('Unknown root: $rootPath');
    }
    final rootID = _rootIDs.putIfAbsent(rootPath, () => _nextRootID++);
    _rootPaths[rootID] = rootPath;
    return rootID;
  }

  @override
  String relativePathForRoot(int rootID, String path) {
    final rootPath = _rootPaths[rootID];
    if (rootPath == null) throw StateError('Root $rootID is not open');
    if (path == rootPath) return '';
    if (path.startsWith('$rootPath/')) {
      return path.substring(rootPath.length + 1);
    }
    return path.startsWith('/') ? path.substring(1) : path;
  }

  @override
  void closeRoot(int rootID) {
    closedRootIDs.add(rootID);
  }

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    decryptedPaths.add(path);
    return Uint8List.fromList(utf8.encode('右键菜单测试内容'));
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    deletedFiles.add((path: path, sessionID: tempKeyID));
    if (deleteFailures.contains(path)) {
      throw StateError('delete failed');
    }
  }

  @override
  Future<void> deleteDirectoryBySession(String path, String tempKeyID) async {
    deletedDirectories.add((path: path, sessionID: tempKeyID));
    if (failDirectoryDelete) {
      throw StateError('directory delete failed');
    }
  }

  @override
  Future<void> renameBySession(
    String oldPath,
    String newPath,
    String tempKeyID,
  ) async {
    renameCalls.add((
      oldPath: oldPath,
      newPath: newPath,
      sessionID: tempKeyID,
    ));
  }

  @override
  Future<void> copyBySession({
    required String sourcePath,
    required String sourceSessionID,
    required String destinationPath,
    required String destinationSessionID,
    bool overwrite = false,
  }) async {
    copyCalls.add((
      sourcePath: sourcePath,
      sourceSessionID: sourceSessionID,
      destinationPath: destinationPath,
      destinationSessionID: destinationSessionID,
      overwrite: overwrite,
    ));
    if (copyFailures.contains(sourcePath)) {
      throw StateError('copy failed');
    }
  }

  @override
  Future<void> createEmptyFileBySession(
    String path,
    String tempKeyID,
  ) async {
    createdFiles.add((path: path, sessionID: tempKeyID));
  }

  @override
  Future<void> createDirectoryBySession(
    String path,
    String tempKeyID,
  ) async {
    createdDirectories.add((path: path, sessionID: tempKeyID));
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    fileWrites.add((
      path: path,
      sessionID: tempKeyID,
      bytes: List<int>.from(data),
    ));
    await writeGate?.future;
  }
}

class _FakeFileService extends FileService {
  _FakeFileService(
    CryptoService cryptoService, {
    List<FileSystemNode>? items,
  })  : items = items ??
            [
              FileSystemNode(
                name: 'visible.txt',
                path: '/visible.txt',
                isDirectory: false,
                size: 7,
              ),
            ],
        super(cryptoService: cryptoService);

  int listCalls = 0;
  final List<({String name, String path, String sessionID})> exportCalls = [];
  final List<bool> exportOverwriteFlags = [];
  final List<FileSystemNode> items;

  @override
  Future<List<FileSystemNode>> listCurrentDirectory(
    String path, {
    int offset = 0,
    int? limit,
  }) async {
    listCalls++;
    return items;
  }

  @override
  Future<void> exportFile(
    FileSystemNode item,
    String exportPath,
    String tempKeyID, {
    bool overwrite = false,
  }) async {
    exportOverwriteFlags.add(overwrite);
    exportCalls.add((
      name: item.name,
      path: exportPath,
      sessionID: tempKeyID,
    ));
  }
}

class _AutoLockSettingsService extends SettingsService {
  _AutoLockSettingsService({required this.enabled, this.ttlSeconds = 0});

  final bool enabled;
  int ttlSeconds;
  int reads = 0;

  @override
  Future<bool> getAutoCloseSession() async {
    reads++;
    return enabled;
  }

  @override
  Future<int> getSessionTTL() async => ttlSeconds;
}

class _FakeDirectoryService extends DirectoryService {
  _FakeDirectoryService({
    this.importError,
    this.unfinishedMarkers = const [],
    this.unfinishedListError,
  });

  final String? importError;
  final List<Map<String, dynamic>> unfinishedMarkers;
  final Object? unfinishedListError;
  final List<Map<String, dynamic>> rerunCalls = [];
  final List<
      ({
        int rootID,
        String source,
        String destination,
        bool overwrite,
      })> importCalls = [];
  final List<
      ({
        int rootID,
        String source,
        String destination,
        bool overwrite,
      })> importFileCalls = [];

  @override
  Future<List<Map<String, dynamic>>> listUnfinishedOperations(
      int rootID) async {
    final error = unfinishedListError;
    if (error != null) throw error;
    return unfinishedMarkers;
  }

  @override
  Future<void> rerunUnfinishedOperation(
    int rootID,
    Map<String, dynamic> marker, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    rerunCalls.add(marker);
    onProgress?.call(const DirectoryTransferProgress(
      percent: 100,
      currentFile: 'restored/payload.txt',
      completedFiles: 1,
      isComplete: true,
    ));
  }

  @override
  Future<void> importDirectory(
    int rootID,
    String srcPath,
    String destPath, {
    bool overwrite = false,
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    importCalls.add((
      rootID: rootID,
      source: srcPath,
      destination: destPath,
      overwrite: overwrite,
    ));
    final error = importError;
    if (error != null) {
      throw StateError(error);
    }
    onProgress?.call(const DirectoryTransferProgress(
      percent: 100,
      currentFile: 'payload.txt',
      completedFiles: 1,
    ));
  }

  @override
  Future<void> importFile(
    int rootID,
    String srcPath,
    String destPath, {
    bool overwrite = false,
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    importFileCalls.add((
      rootID: rootID,
      source: srcPath,
      destination: destPath,
      overwrite: overwrite,
    ));
  }
}

class _FakePersistenceService extends DirectoryPersistenceService {
  _FakePersistenceService(this.rootPath, {List<String>? rootPaths})
      : rootPaths = rootPaths ?? [rootPath];

  final String rootPath;
  final List<String> rootPaths;
  final List<List<String>> savedDirectoryLists = [];

  @override
  Future<List<String>> loadOpenedDirectories() async => rootPaths;

  @override
  Future<bool> loadDrawerPinned() async => true;

  @override
  Future<bool> isFirstTimeUser() async => false;

  @override
  Future<void> saveOpenedDirectories(List<String> paths) async {
    savedDirectoryLists.add(List<String>.from(paths));
  }

  @override
  Future<void> saveDrawerPinned(bool pinned) async {}
}

class _FakeContentWindowPlatform implements ContentWindowPlatform {
  final StreamController<Set<String>> _alive =
      StreamController<Set<String>>.broadcast();
  final List<Map<String, String>> openedImages = [];
  var notepadOpenRequests = 0;
  Set<String> closedTokens = {};
  bool prepareResult = true;

  @override
  Stream<Set<String>> get aliveTokens => _alive.stream;

  @override
  Future<bool> openImage({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) async {
    openedImages.add({
      'token': token,
      'documentID': documentID,
      'title': title,
      'localePreference': localePreference,
    });
    return true;
  }

  @override
  Future<bool> openNotepad({
    required String token,
    required String documentID,
    required String title,
    required String localePreference,
  }) async {
    notepadOpenRequests++;
    return false;
  }

  @override
  Future<void> closeTokens(Set<String> tokens) async {
    closedTokens = {...closedTokens, ...tokens};
  }

  @override
  Future<void> cancelTokenLock({
    required String token,
    required String lockRequestID,
  }) async {}

  @override
  Future<ContentWindowLockResponse> prepareTokenForLock({
    required String token,
    required String lockRequestID,
  }) async =>
      ContentWindowLockResponse(
        token: token,
        lockRequestID: lockRequestID,
        prepared: prepareResult,
      );

  @override
  Future<void> setHostHandler(ContentWindowCallHandler? handler) async {}

  Future<void> dispose() => _alive.close();
}
