import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/services/webdav_service.dart';
import 'package:safe_disk/widgets/webdav_sessions_dialog.dart';

void main() {
  testWidgets('requires explicit confirmation before exposing content',
      (tester) async {
    bool? confirmed;
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            confirmed = await confirmWebDavReadOnlyExposure(
              context: context,
              displayName: 'notes',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('向第三方工具暴露内容？'), findsOneWidget);
    expect(find.text('创建只读访问'), findsOneWidget);

    await tester.tap(find.text('创建只读访问'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('lists token-free status and revokes a session', (tester) async {
    final session = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-1',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-1/',
        'read_only': true,
        'active_requests': 0,
      },
    );
    var revoked = false;
    var refreshes = 0;
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showWebDavSessionsDialog(
            context: context,
            sessions: [session],
            onRevoke: (_) async {
              revoked = true;
              return true;
            },
            onRefresh: () async {
              refreshes++;
              return [session];
            },
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('权限：只读'), findsOneWidget);
    expect(find.text('访问令牌'), findsNothing);

    await tester.tap(find.text('刷新'));
    await tester.pumpAndSettle();
    expect(refreshes, 1);

    await tester.tap(find.text('撤销访问'));
    await tester.pumpAndSettle();
    expect(revoked, isTrue);
    expect(find.text('当前没有活跃的第三方访问。'), findsOneWidget);
  });
}

Widget _localizedApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}
