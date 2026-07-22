import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/root_password_change_dialog.dart';

void main() {
  testWidgets('validates and returns current and confirmed new passwords',
      (tester) async {
    RootPasswordChangeRequest? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showRootPasswordChangeDialog(
              context: context,
              directoryName: '工作目录',
            );
          },
          child: const Text('打开'),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final passwordFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList(growable: false);
    expect(passwordFields, hasLength(3));
    for (final field in passwordFields) {
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.keyboardType, TextInputType.visiblePassword);
    }

    await tester.enterText(
      find.byKey(const Key('root-password-current')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('root-password-new')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('root-password-confirm')),
      'different-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pump();
    expect(find.text('两次输入的新密码不一致'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('root-password-confirm')),
      'new-password',
    );
    await tester.tap(find.widgetWithText(FilledButton, '修改密码'));
    await tester.pumpAndSettle();

    expect(result?.oldPassword, 'old-password');
    expect(result?.newPassword, 'new-password');
  });

  testWidgets('uses the active English locale', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootPasswordChangeDialog(
            context: context,
            directoryName: 'Documents',
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsNWidgets(2));
    expect(find.text('Directory: Documents'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
  });
}
