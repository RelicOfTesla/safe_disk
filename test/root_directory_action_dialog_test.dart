import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/root_directory_action_dialog.dart';

void main() {
  testWidgets('root action dialog preserves its three operation levels',
      (tester) async {
    RootDirectoryAction? result;
    await tester.pumpWidget(_app(
      locale: const Locale('zh'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showRootDirectoryActionDialog(
              context: context,
              directoryName: '资料库',
              hasActiveSession: true,
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('仅结束会话'), findsOneWidget);
    expect(find.text('结束会话并移除历史'), findsOneWidget);
    expect(find.text('结束会话、移除历史并删除目录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('root-action-remove-history')));
    await tester.pumpAndSettle();
    expect(result, RootDirectoryAction.removeHistory);
  });

  testWidgets('root deletion requires the exact directory name',
      (tester) async {
    Future<bool> openDeletion(BuildContext context) {
      return confirmRootDirectoryDeletion(
        context: context,
        directoryPath: '/vault/资料库',
      );
    }

    var result = false;
    await tester.pumpWidget(_app(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await openDeletion(context),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Permanently delete local directory'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('root-delete-confirmation')),
      '资料库',
    );
    await tester.pump();
    await tester.tap(find.text('Permanently delete directory'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

Widget _app({required Locale locale, required Widget child}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
