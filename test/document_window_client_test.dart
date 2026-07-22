import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/document_window_client.dart';
import 'package:safe_disk/windows/secure_notepad_window.dart';

void main() {
  test('document client sends its token and parses the host snapshot',
      () async {
    final channel = _FakeDocumentWindowChannel((method, arguments) async {
      expect(method, 'document.read');
      expect(arguments, {'token': 'window-token'});
      return {
        'revision': 7,
        'content': Uint8List.fromList([1, 2, 3]),
      };
    });
    final client = DocumentWindowClient('window-token', channel: channel);

    final snapshot = await client.read();

    expect(snapshot.revision, 7);
    expect(snapshot.content, [1, 2, 3]);
  });

  test('document client reports an unresponsive host as a bounded timeout',
      () async {
    final channel = _FakeDocumentWindowChannel(
      (_, __) => Completer<Object?>().future,
    );
    final client = DocumentWindowClient(
      'window-token',
      channel: channel,
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.read(),
      throwsA(isA<DocumentWindowRequestTimeout>()),
    );
  });

  testWidgets('content window startup failure is visible and closable',
      (tester) async {
    var closed = false;
    await tester.pumpWidget(ContentWindowStartupErrorApp(
      title: 'note.txt',
      error: const DocumentWindowRequestTimeout('读取文档'),
      onClose: () async => closed = true,
      locale: const Locale('zh'),
    ));

    expect(find.text('无法连接主窗口'), findsOneWidget);
    expect(find.textContaining('读取文档'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '关闭窗口'));
    await tester.pump();
    expect(closed, isTrue);
  });

  testWidgets('content window startup failure uses its locale snapshot',
      (tester) async {
    await tester.pumpWidget(ContentWindowStartupErrorApp(
      title: 'note.txt',
      error: const DocumentWindowRequestTimeout('read-document'),
      onClose: () async {},
      locale: const Locale('en'),
    ));

    expect(find.text('Cannot connect to main window'), findsOneWidget);
    expect(find.text('Close window'), findsOneWidget);
  });
}

class _FakeDocumentWindowChannel implements DocumentWindowChannel {
  _FakeDocumentWindowChannel(this.handler);

  final Future<Object?> Function(String method, Object? arguments) handler;

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    return await handler(method, arguments) as T?;
  }
}
