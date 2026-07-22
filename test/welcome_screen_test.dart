import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/welcome_screen.dart';

void main() {
  testWidgets('welcome screen follows the active locale', (tester) async {
    Future<void> pump(Locale locale) {
      return tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: WelcomeScreen()),
        ),
      );
    }

    await pump(const Locale('zh'));
    expect(find.text('加密文件管理器'), findsOneWidget);
    expect(find.text('请从侧边栏打开或创建加密目录'), findsOneWidget);

    await pump(const Locale('en'));
    expect(find.text('Encrypted file manager'), findsOneWidget);
    expect(
      find.text('Open or create an encrypted directory from the sidebar.'),
      findsOneWidget,
    );
  });
}
