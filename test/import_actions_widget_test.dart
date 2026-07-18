import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/widgets/import_actions.dart';

void main() {
  testWidgets('Import actions expose separate file and directory entries',
      (tester) async {
    var fileImports = 0;
    var directoryImports = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ImportActions(
              onImportFile: () => fileImports++,
              onImportDirectory: () => directoryImports++,
            ),
          ],
        ),
      ),
    ));

    await tester.tap(find.byTooltip('导入文件'));
    await tester.tap(find.byTooltip('导入目录'));

    expect(fileImports, 1);
    expect(directoryImports, 1);
  });
}
