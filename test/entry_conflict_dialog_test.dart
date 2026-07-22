import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/widgets/entry_conflict_dialog.dart';

class MaterialApp extends material.MaterialApp {
  const MaterialApp({super.key, super.home, Locale? locale})
      : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

void main() {
  test('generates a case-insensitive keep-both name before the extension', () {
    expect(
      nextAvailableEntryName(
        originalName: '记录.txt',
        isDirectory: false,
        existingNames: const ['记录.txt'],
        copyLabel: '副本',
      ),
      '记录 - 副本.txt',
    );
    expect(
      nextAvailableEntryName(
        originalName: '记录.txt',
        isDirectory: false,
        existingNames: const ['记录.txt', '记录 - 副本.TXT'],
        copyLabel: '副本',
      ),
      '记录 - 副本 (2).txt',
    );
    expect(
      nextAvailableEntryName(
        originalName: '资料.v1',
        isDirectory: true,
        existingNames: const ['资料.v1'],
        copyLabel: '副本',
      ),
      '资料.v1 - 副本',
    );
  });

  test('batch conflict policy is scoped to one session and respects replace',
      () {
    final session = EntryConflictSession();
    expect(
      session.automaticResolution(allowReplace: true),
      isNull,
    );

    expect(
      session.apply(EntryConflictResolution.replaceForAll),
      EntryConflictResolution.replace,
    );
    expect(
      session.automaticResolution(allowReplace: true),
      EntryConflictResolution.replace,
    );
    expect(
      session.automaticResolution(allowReplace: false),
      isNull,
    );
  });

  testWidgets('single conflict hides batch actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEntryConflictDialog(
            context: context,
            name: 'note.txt',
            isDirectory: false,
            operation: '粘贴',
          ),
          child: const Text('打开'),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('保留两者'), findsOneWidget);
    expect(find.text('替换'), findsOneWidget);
    expect(find.text('全部保留两者'), findsNothing);
    expect(find.text('全部替换'), findsNothing);
  });

  testWidgets('batch conflict exposes apply-to-all actions', (tester) async {
    EntryConflictResolution? selected;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            selected = await showEntryConflictDialog(
              context: context,
              name: 'note.txt',
              isDirectory: false,
              operation: '批量粘贴',
              allowApplyToAll: true,
            );
          },
          child: const Text('打开'),
        ),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('全部保留两者'), findsOneWidget);
    expect(find.text('全部替换'), findsOneWidget);

    await tester.tap(find.text('全部替换'));
    await tester.pumpAndSettle();
    expect(selected, EntryConflictResolution.replaceForAll);
  });

  testWidgets('English conflict dialog uses localized actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showEntryConflictDialog(
            context: context,
            name: 'note.txt',
            isDirectory: false,
            operation: 'paste',
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Destination already exists'), findsOneWidget);
    expect(find.text('Keep both'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(
      nextAvailableEntryName(
        originalName: 'note.txt',
        isDirectory: false,
        existingNames: const ['note.txt'],
        copyLabel: 'copy',
      ),
      'note - copy.txt',
    );
  });
}
