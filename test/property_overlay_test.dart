import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/property_overlay.dart';

void main() {
  testWidgets('copies a safe property value without showing it in feedback',
      (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_app());
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy-property-Path')));
    await tester.pump();

    expect(copiedText, '/safe/root/notes.txt');
    expect(find.text('Property value copied'), findsOneWidget);
    expect(find.text('/safe/root/notes.txt'), findsOneWidget);
  });

  testWidgets('does not expose a copy action for a sensitive property',
      (tester) async {
    await tester.pumpWidget(_app(sensitive: true));
    await tester.tap(find.text('open'));
    await tester.pump();

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byKey(const Key('copy-property-Secret')), findsNothing);
  });
}

Widget _app({bool sensitive = false}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPropertyOverlay(
            context: context,
            title: 'Properties',
            values: [
              PropertyValue(
                sensitive ? 'Secret' : 'Path',
                sensitive ? 'not-for-clipboard' : '/safe/root/notes.txt',
                copyable: !sensitive,
              ),
            ],
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}
