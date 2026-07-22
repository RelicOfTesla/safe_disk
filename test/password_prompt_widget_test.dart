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
}
