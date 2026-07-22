import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/widgets/sidebar.dart';

void main() {
  testWidgets('Sidebar shows directory basename instead of config JSON',
      (tester) async {
    final directory = EncryptedDirectory(
      path: '/tmp/safe-disk-ui/root-name',
      config: CryptionConfig({
        'version': '1.0',
        'dataFactory': 'AES-CTR',
        'nameFactory': 'None',
      }),
      isVerified: true,
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SidebarWidget(
          openedDirs: [directory],
          currentDir: directory,
          drawerPinned: false,
          onOpenDirectory: () {},
          onCloseDirectory: (_) {},
          onSwitchDirectory: (_) {},
          onRenameDirectory: (_) {},
          onShowProperties: (_) {},
          onChangePassword: (_) {},
          onTogglePin: (_) async {},
        ),
      ),
    ));

    expect(find.text('root-name'), findsOneWidget);
    expect(find.textContaining('dataFactory'), findsNothing);
    expect(find.textContaining('nameFactory'), findsNothing);
  });

  testWidgets('Sidebar supports a right-click alias action', (tester) async {
    final directory = EncryptedDirectory(
      path: r'C:\safe\root-name',
      displayAlias: '工作资料',
      config: CryptionConfig(const {}),
    );
    EncryptedDirectory? renamed;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SidebarWidget(
          openedDirs: [directory],
          currentDir: directory,
          drawerPinned: true,
          onOpenDirectory: () {},
          onCloseDirectory: (_) {},
          onSwitchDirectory: (_) {},
          onRenameDirectory: (value) => renamed = value,
          onShowProperties: (_) {},
          onChangePassword: (_) {},
          onTogglePin: (_) async {},
        ),
      ),
    ));

    expect(find.text('工作资料'), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('工作资料')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('属性'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('设置别名'), findsOneWidget);
    await tester.tap(find.text('清除别名'));
    await tester.pumpAndSettle();
    expect(renamed?.displayAlias, isNull);
  });

  testWidgets('Sidebar uses the active English locale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SidebarWidget(
          openedDirs: const [],
          currentDir: null,
          drawerPinned: true,
          onOpenDirectory: () {},
          onCloseDirectory: (_) {},
          onSwitchDirectory: (_) {},
          onRenameDirectory: (_) {},
          onShowProperties: (_) {},
          onChangePassword: (_) {},
          onTogglePin: (_) async {},
        ),
      ),
    ));

    expect(find.text('0 directories open'), findsOneWidget);
    expect(find.text('Open or create encrypted directory'), findsOneWidget);
    expect(find.textContaining('No directories are open yet.'), findsOneWidget);
  });

  testWidgets('Sidebar alias action follows the active English locale',
      (tester) async {
    final directory = EncryptedDirectory(
      path: '/safe/root-name',
      config: CryptionConfig(const {}),
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SidebarWidget(
          openedDirs: [directory],
          currentDir: directory,
          drawerPinned: true,
          onOpenDirectory: () {},
          onCloseDirectory: (_) {},
          onSwitchDirectory: (_) {},
          onRenameDirectory: (_) {},
          onShowProperties: (_) {},
          onChangePassword: (_) {},
          onTogglePin: (_) async {},
        ),
      ),
    ));

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('root-name')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Set alias'), findsOneWidget);
  });
}
