import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('create dialog exposes constrained advanced crypto parameters',
      (tester) async {
    CreateRootRequest? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<CreateRootRequest>(
              context: context,
              builder: (_) => const CreateEncryptedDirectoryDialog(),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'secret');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('高级加密参数'));
    await tester.pumpAndSettle();

    expect(find.text('数据加密'), findsOneWidget);
    expect(find.text('文件名加密'), findsOneWidget);
    expect(find.text('密码派生'), findsOneWidget);
    expect(find.text('派生强度'), findsOneWidget);
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(result?.nameFactory, 'AES-256-GCM');
    expect(result?.deriverFactory, 'Argon2id');
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
