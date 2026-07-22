import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/directory_background_actions.dart';

class MaterialApp extends material.MaterialApp {
  const MaterialApp({super.key, super.home, Locale? locale})
      : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

void main() {
  testWidgets('directory background menu displays English actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDirectoryBackgroundContextMenu(
              context: context,
              globalPosition: const Offset(20, 20),
              canPaste: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New file'), findsOneWidget);
    expect(find.text('New directory'), findsOneWidget);
    expect(find.text('Paste to current directory'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('new entry dialog localizes default name and validation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCreateEntryDialog(
              context: context,
              isDirectory: false,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('New file'), findsOneWidget);
    expect(find.text('New file.txt'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('create-entry-name')), '');
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(find.text('A name is required'), findsOneWidget);
  });
}
