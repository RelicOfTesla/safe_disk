import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/pages/dialogs.dart';

void main() {
  testWidgets('path selection accepts a directory that does not exist yet',
      (tester) async {
    final path =
        '${Directory.systemTemp.path}/safe-disk-new-root-never-created';
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                selected = await showDialog<String>(
                  context: context,
                  builder: (_) => const PathSelectionDialog(),
                );
              },
              child: const Text('选择'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    expect(find.text('目录路径'), findsOneWidget);
    expect(find.text('输入目录路径或浏览选择'), findsOneWidget);
    await tester.enterText(find.byType(TextField), path);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(selected, path);
  });
}
