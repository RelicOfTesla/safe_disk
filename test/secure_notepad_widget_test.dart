import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';
import 'package:safe_disk/services/system_text_clipboard.dart';
import 'package:safe_disk/widgets/secure_notepad.dart';

void main() {
  testWidgets('switches from read-only mode and saves encrypted text',
      (tester) async {
    final service = _FakeCryptoService('initial');
    var savedCallbacks = 0;

    await _openNotepad(
      tester,
      service,
      initiallyReadOnly: true,
      onSaved: () => savedCallbacks++,
    );

    final editorFinder = find.byKey(const Key('secure-notepad-editor'));
    expect(tester.widget<TextField>(editorFinder).readOnly, isTrue);
    expect(find.text('只读'), findsOneWidget);

    await tester.tap(find.byTooltip('切换到编辑模式'));
    await tester.pump();
    expect(tester.widget<TextField>(editorFinder).readOnly, isFalse);
    expect(find.text('编辑'), findsOneWidget);

    await tester.enterText(editorFinder, 'changed');
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(service.writes, ['changed']);
    expect(savedCallbacks, 1);
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('Ctrl+F search focuses, selects and navigates matches',
      (tester) async {
    await _openNotepad(tester, _FakeCryptoService('alpha beta alpha'));
    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.tap(editor);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findField = find.byKey(const Key('secure-notepad-find-field'));
    expect(findField, findsOneWidget);
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
    await tester.enterText(findField, 'alpha');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 11, extentOffset: 16),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(findField, findsNothing);
    expect(tester.widget<TextField>(editor).focusNode?.hasFocus, isTrue);
  });

  testWidgets('Ctrl+S saves the current note', (tester) async {
    final service = _FakeCryptoService('initial');
    await _openNotepad(tester, service);
    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.enterText(editor, 'saved by shortcut');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(service.writes, ['saved by shortcut']);
  });

  testWidgets('failed save while closing keeps the editor open',
      (tester) async {
    final service = _FakeCryptoService('initial', writeError: 'disk full');

    await _openNotepad(tester, service);

    await tester.enterText(
      find.byKey(const Key('secure-notepad-editor')),
      'must survive',
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('未保存的更改'), findsOneWidget);

    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();

    expect(find.byType(SecureNotepad), findsOneWidget);
    expect(find.text('must survive'), findsOneWidget);
    expect(find.textContaining('无法保存文件更改'), findsOneWidget);
  });

  testWidgets('monitors short clipboard text and clears it explicitly',
      (tester) async {
    final service = _FakeCryptoService('initial');
    final longText = List.filled(200, 'x').join();
    final clipboard = _FakeSystemTextClipboard(longText);

    await _openNotepad(
      tester,
      service,
      systemClipboard: clipboard,
      clipboardMonitorInterval: Duration.zero,
    );

    await tester.tap(find.byTooltip('监视剪贴板'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('secure-clipboard-monitor')), findsOneWidget);
    final preview = tester.widget<Text>(
      find.byKey(const Key('secure-clipboard-preview')),
    );
    expect(preview.data, '${List.filled(160, 'x').join()}…');
    expect(clipboard.readCount, 1);

    await tester.tap(find.byTooltip('快速清空系统剪贴板'));
    await tester.pumpAndSettle();
    expect(clipboard.text, '');
    expect(find.text('剪贴板中没有短文本'), findsOneWidget);

    await tester.tap(find.byTooltip('停止剪贴板监视').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('secure-clipboard-monitor')), findsNothing);
  });

  testWidgets('applies read-only and clipboard-monitor defaults on open',
      (tester) async {
    final clipboard = _FakeSystemTextClipboard('default preview');
    await _openNotepad(
      tester,
      _FakeCryptoService('initial'),
      initiallyReadOnly: true,
      initiallyMonitorClipboard: true,
      systemClipboard: clipboard,
      clipboardMonitorInterval: Duration.zero,
    );

    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('secure-notepad-editor')),
          )
          .readOnly,
      isTrue,
    );
    expect(find.byKey(const Key('secure-clipboard-monitor')), findsOneWidget);
    expect(find.text('default preview'), findsOneWidget);
    expect(clipboard.readCount, 1);
  });

  testWidgets('asks before restoring an encrypted recovery draft',
      (tester) async {
    final service = _FakeCryptoService('original');
    final draftPath = SecureNotepadDraftStore.draftPathFor('/vault/note.txt');
    service.files[draftPath] = 'draft after outage';

    await _openNotepad(tester, service);
    expect(find.text('发现安全草稿'), findsOneWidget);
    expect(find.text('original'), findsOneWidget);

    await tester.tap(find.text('恢复草稿'));
    await tester.pumpAndSettle();
    expect(find.text('draft after outage'), findsOneWidget);
    expect(find.text('未保存'), findsOneWidget);

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(service.files['/vault/note.txt'], 'draft after outage');
    expect(service.files.containsKey(draftPath), isFalse);
  });

  testWidgets('stopping or closing clipboard monitoring cancels periodic reads',
      (tester) async {
    final clipboard = _FakeSystemTextClipboard('short secret');
    await _openNotepad(
      tester,
      _FakeCryptoService('initial'),
      systemClipboard: clipboard,
      clipboardMonitorInterval: const Duration(milliseconds: 10),
    );

    await tester.tap(find.byTooltip('监视剪贴板'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    expect(clipboard.readCount, greaterThan(1));

    await tester.tap(find.byTooltip('停止剪贴板监视').last);
    await tester.pump();
    final readsAfterStop = clipboard.readCount;
    await tester.pump(const Duration(milliseconds: 50));
    expect(clipboard.readCount, readsAfterStop);

    await tester.tap(find.byTooltip('监视剪贴板'));
    await tester.pump(const Duration(milliseconds: 35));
    await tester.pageBack();
    await tester.pumpAndSettle();
    final readsAfterClose = clipboard.readCount;
    await tester.pump(const Duration(milliseconds: 50));
    expect(clipboard.readCount, readsAfterClose);
  });
}

Future<void> _openNotepad(
  WidgetTester tester,
  CryptoService service, {
  bool initiallyReadOnly = false,
  bool initiallyMonitorClipboard = false,
  VoidCallback? onSaved,
  SystemTextClipboard systemClipboard = const FlutterSystemTextClipboard(),
  Duration clipboardMonitorInterval = Duration.zero,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: FilledButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SecureNotepad(
                file: _file,
                cryptoService: service,
                tempKeyID: '7',
                initiallyReadOnly: initiallyReadOnly,
                initiallyMonitorClipboard: initiallyMonitorClipboard,
                autoSaveInterval: Duration.zero,
                onSaved: onSaved,
                systemClipboard: systemClipboard,
                clipboardMonitorInterval: clipboardMonitorInterval,
              ),
            ));
          },
          child: const Text('Open note'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Open note'));
  await tester.pumpAndSettle();
}

final _file = EncryptedFile(
  name: 'note.txt',
  encryptedPath: '/vault/note.txt',
  modifiedTime: DateTime(2026),
);

class _FakeCryptoService extends CryptoService {
  _FakeCryptoService(this.initialText, {this.writeError}) {
    files['/vault/note.txt'] = initialText;
  }

  final String initialText;
  final String? writeError;
  final List<String> writes = [];
  final Map<String, String> files = {};

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    final content = files[path];
    if (content == null) throw StateError('missing file: $path');
    return Uint8List.fromList(content.codeUnits);
  }

  @override
  Future<void> writeFileBySession(
    String path,
    String tempKeyID,
    List<int> data,
  ) async {
    if (writeError != null) throw StateError(writeError!);
    final content = String.fromCharCodes(data);
    writes.add(content);
    files[path] = content;
  }

  @override
  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    return files.containsKey(path);
  }

  @override
  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    files.remove(path);
  }
}

class _FakeSystemTextClipboard implements SystemTextClipboard {
  _FakeSystemTextClipboard(this.text);

  String? text;
  int readCount = 0;

  @override
  Future<String?> readText() async {
    readCount++;
    return text;
  }

  @override
  Future<void> clear() async {
    text = '';
  }
}
