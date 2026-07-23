import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/pages/dialogs.dart';

void main() {
  testWidgets('welcome guide follows the active locale', (tester) async {
    await tester.pumpWidget(_app(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const WelcomeGuideDialog(),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Safe Disk'), findsOneWidget);
    expect(
      find.text(
        'Safe Disk helps you encrypt and manage private files.\n\n'
        'You need the correct password to access content in an encrypted '
        'directory.',
      ),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Encrypted directories'), findsOneWidget);
  });

  testWidgets('create encrypted directory dialog follows the active locale',
      (tester) async {
    await tester.pumpWidget(_app(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const CreateEncryptedDirectoryDialog(),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Create encrypted directory'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Allow password changes later'), findsOneWidget);
    expect(find.text('Advanced encryption parameters'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsNWidgets(2));
  });

  testWidgets('path selection dialog follows the active locale',
      (tester) async {
    await tester.pumpWidget(_app(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const PathSelectionDialog(),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Select directory'), findsOneWidget);
    expect(find.text('Directory path'), findsOneWidget);
    expect(find.text('Enter a directory path or browse to select one'),
        findsOneWidget);
    expect(find.byTooltip('Browse'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('directory removal dialog follows the active locale',
      (tester) async {
    await tester.pumpWidget(_app(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const DeleteDirectoryDialog(
              directoryPath: '/vault/archive',
              directoryName: 'archive',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm removal'), findsOneWidget);
    expect(find.text('archive'), findsOneWidget);
    expect(find.text('Remove only'), findsOneWidget);
    expect(find.text('Delete disk directory'), findsOneWidget);
  });
}

Widget _app({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}
