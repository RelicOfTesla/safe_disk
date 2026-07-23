import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/pages/home_page.dart';
import 'package:safe_disk/pages/dialogs.dart';
import 'package:safe_disk/models/create_root_options.dart';
import 'package:safe_disk/services/directory_persistence_service.dart';
import 'package:safe_disk/services/error_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErrorReportingService.configure(detailedErrorsEnabled: true);
  });
  tearDown(() {
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });

  testWidgets('create root rejects a non-empty directory before password entry',
      (tester) async {
    final directory =
        Directory.systemTemp.createTempSync('safe-disk-ui-create-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final existing = File('${directory.path}/existing.txt')
      ..writeAsStringSync('keep');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(persistenceService: _EmptyPersistenceService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开或创建加密目录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), directory.path);
    await tester.tap(find.text('确定'));
    for (var attempt = 0;
        attempt < 10 && find.byType(SnackBar).evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('目录不是空目录'), findsOneWidget);
    expect(find.textContaining('validate-create-root-path'), findsOneWidget);
    expect(find.text('创建加密目录'), findsNothing);
    expect(existing.readAsStringSync(), 'keep');
  });

  testWidgets(
      'create dialog exposes constrained crypto parameters and password-change choice',
      (tester) async {
    CreateRootRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<CreateRootRequest>(
                context: context,
                builder: (_) => const CreateEncryptedDirectoryDialog(
                  initialKeyStrengthMs: 2000,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final passwordFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .take(2)
        .toList(growable: false);
    expect(passwordFields, hasLength(2));
    for (final field in passwordFields) {
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.keyboardType, TextInputType.visiblePassword);
    }
    expect(find.byTooltip('显示密码'), findsNWidgets(2));
    final passwordChangeable = find.widgetWithText(
      SwitchListTile,
      '允许以后修改密码',
    );
    expect(passwordChangeable, findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(passwordChangeable).value,
      isTrue,
    );
    await tester.enterText(find.byType(TextField).at(0), 'secret');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(passwordChangeable);
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(passwordChangeable).value,
      isFalse,
    );
    await tester.tap(find.text('高级加密参数'));
    await tester.pumpAndSettle();

    expect(find.text('数据加密'), findsOneWidget);
    expect(find.text('文件名加密'), findsOneWidget);
    expect(find.text('密码派生'), findsOneWidget);
    expect(find.text('派生强度'), findsOneWidget);
    expect(find.text('允许以后修改密码'), findsOneWidget);
    expect(find.text('密码提示'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      2000,
    );
    final keyStrength = find.byType(DropdownButtonFormField<int>);
    await tester.ensureVisible(keyStrength);
    await tester.tap(keyStrength);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5000 毫秒').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'first pet');

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('不加密（None）'), findsOneWidget);
    await tester.tap(find.text('不加密（None）'));
    await tester.pumpAndSettle();
    expect(find.textContaining('文件名和目录名不会加密'), findsOneWidget);

    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result?.nameFactory, 'None');
    expect(result?.deriverFactory, 'Argon2id');
    expect(result?.keyStrengthMs, 5000);
    expect(result?.passwordChangeable, isFalse);
    expect(result?.passwordHint, 'first pet');
  });

  testWidgets(
      'new-root dialog receives the persisted default derivation profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({'key_strength_ms': 2000});
    final directory =
        Directory.systemTemp.createTempSync('safe-disk-ui-create-profile-');
    addTearDown(() => directory.deleteSync(recursive: true));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(persistenceService: _EmptyPersistenceService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开或创建加密目录'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PathSelectionDialog),
        matching: find.byType(TextField),
      ),
      directory.path,
    );
    await tester.tap(find.text('确定'));
    for (var attempt = 0;
        attempt < 10 && find.text('创建加密目录').evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('创建加密目录'), findsOneWidget);
    await tester.tap(find.text('高级加密参数'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .initialValue,
      2000,
    );
  });
}

class _EmptyPersistenceService extends DirectoryPersistenceService {
  @override
  Future<List<String>> loadOpenedDirectories() async => [];

  @override
  Future<bool> loadDrawerPinned() async => true;

  @override
  Future<bool> isFirstTimeUser() async => false;

  @override
  Future<void> saveOpenedDirectories(List<String> paths) async {}

  @override
  Future<void> saveDrawerPinned(bool pinned) async {}
}
