import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/password_prompt.dart';

void main() {
  testWidgets('password prompt follows the active locale', (tester) async {
    Future<void> pump(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PasswordPrompt(
              directoryPath: '/vault',
              onUnlock: (_) async {},
            ),
          ),
        ),
      );
    }

    await pump(const Locale('zh'));
    expect(find.text('请输入密码以解锁：'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('解锁'), findsOneWidget);

    await pump(const Locale('en'));
    expect(find.text('Enter the password to unlock:'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('password hint stays hidden until explicitly revealed',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PasswordPrompt(
            directoryPath: '/vault',
            passwordHint: '第一只宠物',
            onUnlock: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('显示密码提示'), findsOneWidget);
    expect(find.text('第一只宠物'), findsNothing);
    await tester.tap(find.text('显示密码提示'));
    await tester.pump();
    expect(find.text('第一只宠物'), findsOneWidget);
    expect(find.text('提示会显示给能访问此目录的人，不能用于找回密码。'), findsOneWidget);
  });
}
