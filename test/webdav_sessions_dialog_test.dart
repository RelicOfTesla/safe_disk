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
            onMount: (_) async => true,
            onUnmount: (_) async => true,
            onReveal: (_) async => true,
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

  testWidgets('selects Digest authentication and shows its credentials',
      (tester) async {
    WebDavAuthMode? selected;
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            selected = await chooseWebDavAuthMode(context: context);
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('选择鉴权方式'), findsOneWidget);
    await tester.tap(find.text('Digest（用户名和密码）'));
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(selected, WebDavAuthMode.digest);

    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showWebDavCredentialsDialog(
            context: context,
            session: WebDavOpenedSession.fromNative(
              rootID: 7,
              data: const {
                'id': 'session-2',
                'display_name': 'notes',
                'exposed_path': 'notes',
                'url': 'http://127.0.0.1:1234/webdav/session-2/',
                'auth_mode': 'digest',
                'username': 'user-1',
                'password': 'password-1',
                'realm': 'realm-1',
                'read_only': true,
              },
            ),
          ),
          child: const Text('credentials'),
        ),
      ),
    ));
    await tester.tap(find.text('credentials'));
    await tester.pumpAndSettle();
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('Realm'), findsOneWidget);
    expect(find.text('访问令牌'), findsNothing);
  });

  testWidgets('selects persistent credential display and session lifetime',
      (tester) async {
    WebDavCredentialVisibility? visibility;
    WebDavSessionLifetime? lifetime;
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () async {
                visibility = await chooseWebDavCredentialVisibility(
                  context: context,
                );
              },
              child: const Text('visibility'),
            ),
            TextButton(
              onPressed: () async {
                lifetime = await chooseWebDavSessionLifetime(context: context);
              },
              child: const Text('lifetime'),
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.text('visibility'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('允许再次显示'));
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(visibility, WebDavCredentialVisibility.persistent);

    await tester.tap(find.text('lifetime'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('持久会话'));
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(lifetime, WebDavSessionLifetime.persistent);
  });

  testWidgets(
      'allows persistent credentials to be revealed from the session list',
      (tester) async {
    var revealed = false;
    final session = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-persistent',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-persistent/',
        'auth_mode': 'bearer',
        'credential_visibility': 'persistent',
        'read_only': true,
        'active_requests': 0,
      },
    );
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showWebDavSessionsDialog(
            context: context,
            sessions: [session],
            onRevoke: (_) async => true,
            onMount: (_) async => true,
            onUnmount: (_) async => true,
            onReveal: (_) async {
              revealed = true;
              return true;
            },
            onRefresh: () async => [session],
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('显示凭据'), findsOneWidget);
    await tester.tap(find.text('显示凭据'));
    await tester.pumpAndSettle();
    expect(revealed, isTrue);
  });

  testWidgets('mounts and unmounts a Digest session through callbacks',
      (tester) async {
    var mounted = false;
    final base = WebDavSessionStatus.fromNative(
      rootID: 7,
      data: const {
        'id': 'session-3',
        'display_name': 'notes',
        'exposed_path': 'notes',
        'url': 'http://127.0.0.1:1234/webdav/session-3/',
        'auth_mode': 'digest',
        'read_only': true,
        'active_requests': 0,
      },
    );
    await tester.pumpWidget(_localizedApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showWebDavSessionsDialog(
            context: context,
            sessions: [base],
            onRevoke: (_) async => true,
            onMount: (_) async {
              mounted = true;
              return true;
            },
            onUnmount: (_) async {
              mounted = false;
              return true;
            },
            onReveal: (_) async => true,
            onRefresh: () async => [
              WebDavSessionStatus.fromNative(
                rootID: 7,
                data: {
                  'id': 'session-3',
                  'display_name': 'notes',
                  'exposed_path': 'notes',
                  'url': 'http://127.0.0.1:1234/webdav/session-3/',
                  'auth_mode': 'digest',
                  'read_only': true,
                  'mounted': mounted,
                  if (mounted) 'mount_path': '/cache/safe-disk/webdav',
                  'active_requests': 0,
                },
              ),
            ],
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('挂载到系统'));
    await tester.pumpAndSettle();
    expect(mounted, isTrue);
    expect(find.text('已挂载到系统'), findsOneWidget);
    expect(find.text('/cache/safe-disk/webdav'), findsOneWidget);

    await tester.tap(find.text('卸载'));
    await tester.pumpAndSettle();
    expect(mounted, isFalse);
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
