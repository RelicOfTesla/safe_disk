import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/widgets/progress_dialog.dart';

void main() {
  testWidgets('Progress dialog stays open when cancellation is not active',
      (tester) async {
    late ProgressController controller;
    var allowCancel = false;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            controller = ProgressHelper.showProgressDialog(
              context,
              title: '传输中',
              total: 1,
              onCancel: () => allowCancel,
            );
          },
          child: const Text('开始'),
        ),
      ),
    ));

    await tester.tap(find.text('开始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('传输中'), findsOneWidget);

    controller.update(current: 1, currentFileName: '报告.txt');
    await tester.pump();
    expect(find.text('已处理：1 / 1'), findsOneWidget);
    expect(find.text('当前：报告.txt'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(find.text('传输中'), findsOneWidget);
    expect(controller.isCancelled, isFalse);

    allowCancel = true;
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('传输中'), findsNothing);
    expect(controller.isCancelled, isTrue);
  });
}
