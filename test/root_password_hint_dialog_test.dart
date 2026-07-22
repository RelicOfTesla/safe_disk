import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/root_password_hint_dialog.dart';

void main() {
  testWidgets('password hint dialog requires current password and can clear',
      (tester) async {
    RootPasswordHintRequest? request;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              request = await showRootPasswordHintDialog(
                context: context,
                directoryName: '工作盘',
                currentHint: '旧提示',
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('旧提示'), findsOneWidget);
    await tester.tap(find.text('保存提示'));
    await tester.pump();
    expect(find.text('请输入当前密码以更新密码提示'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('root-password-hint')), '');
    await tester.enterText(
      find.byKey(const Key('root-password-hint-current-password')),
      'current-password',
    );
    await tester.tap(find.text('保存提示'));
    await tester.pumpAndSettle();

    expect(request?.password, 'current-password');
    expect(request?.hint, isEmpty);
  });
}
