import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/widgets/root_directory_properties.dart';

void main() {
  final directory = EncryptedDirectory(
    path: '/safe/root',
    displayAlias: '工作盘',
    isVerified: true,
    config: CryptionConfig({
      'version': '2',
      'sec_fs_factory': 'AES-256-CTR',
      'sec_name_factory': 'AES-256-GCM',
      'sec_deriver_factory': 'Argon2id',
      'sec_password_verifier_version': 1,
      'sec_password_verifier_challenge': 'secret-challenge',
      'sec_password_verifier_tag': 'secret-tag',
      'argon2_salt': 'secret-salt',
      'argon2_time': 3,
      'argon2_memory': 65536,
      'sec_password_hint': '第一只宠物',
    }),
  );

  testWidgets('root 属性只显示安全配置字段', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootDirectoryProperties(
            context: context,
            directory: directory,
          ),
          child: const Text('打开'),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump();

    expect(find.text('加密目录属性'), findsOneWidget);
    expect(find.text('工作盘'), findsOneWidget);
    expect(find.text('AES-256-CTR'), findsOneWidget);
    expect(find.text('Argon2id'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('secret-challenge'), findsNothing);
    expect(find.text('secret-tag'), findsNothing);
    expect(find.text('secret-salt'), findsNothing);
    expect(find.text('第一只宠物'), findsOneWidget);
  });

  testWidgets('当前格式明确拒绝伪原地改密', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showUnsupportedRootPasswordChange(
            context: context,
            directory: directory,
          ),
          child: const Text('修改'),
        ),
      ),
    ));
    await tester.tap(find.text('修改'));
    await tester.pump();

    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('此目录不能直接修改密码'), findsOneWidget);
    expect(find.textContaining('较早的加密格式'), findsOneWidget);
    expect(find.textContaining('导出并导入需要保留的内容'), findsOneWidget);
  });

  testWidgets('新格式在属性中显示支持安全改密', (tester) async {
    final changeableDirectory = EncryptedDirectory(
      path: '/safe/changeable-root',
      config: CryptionConfig({
        'sec_key_envelope_version': 1,
        'sec_fs_factory': 'AES-CTR',
        'sec_name_factory': 'AES-256-GCM',
        'sec_deriver_factory': 'Argon2id',
      }),
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootDirectoryProperties(
            context: context,
            directory: changeableDirectory,
          ),
          child: const Text('打开'),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump();

    expect(find.text('可直接修改'), findsOneWidget);
    expect(rootSupportsPasswordChange(changeableDirectory), isTrue);
  });

  testWidgets('unlocked root properties close before opening hint management',
      (tester) async {
    var managed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootDirectoryProperties(
            context: context,
            directory: directory,
            onManagePasswordHint: () async {
              managed = true;
            },
          ),
          child: const Text('打开'),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump();
    final manageButton = find.text('管理密码提示');
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
    await tester.pump();

    expect(managed, isTrue);
    expect(find.byKey(const Key('property-overlay')), findsNothing);
  });

  testWidgets('root properties use the active English locale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootDirectoryProperties(
            context: context,
            directory: directory,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.text('Encrypted directory properties'), findsOneWidget);
    expect(find.text('Display name:'), findsOneWidget);
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.text('Change password:'), findsOneWidget);
  });
}
