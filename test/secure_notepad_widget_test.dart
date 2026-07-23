import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/error_reporting_service.dart';
import 'package:safe_disk/services/secure_notepad_draft_store.dart';
import 'package:safe_disk/services/system_text_clipboard.dart';
import 'package:safe_disk/widgets/secure_notepad.dart';

void main() {
  setUp(() {
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });

  tearDown(() {
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });

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

    await tester.tap(find.byTooltip('开始编辑'));
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

  testWidgets('localizes notepad status, clipboard monitor, and find UI',
      (tester) async {
    await _openNotepad(
      tester,
      _FakeCryptoService('alpha beta alpha'),
      initiallyReadOnly: true,
      initiallyMonitorClipboard: true,
      locale: const Locale('en'),
    );

    expect(find.text('Read-only'), findsOneWidget);
    expect(find.text('Clipboard monitor'), findsOneWidget);
    expect(find.byTooltip('Refresh clipboard now'), findsOneWidget);

    await tester.tap(find.byTooltip('Find and replace'));
    await tester.pumpAndSettle();

    expect(find.text('Find (\\n means newline)'), findsOneWidget);
    expect(find.byTooltip('Find previous'), findsOneWidget);
    expect(find.byTooltip('Replace all'), findsOneWidget);
  });

  testWidgets('notepad load error hides raw diagnostics unless enabled',
      (tester) async {
    await _openNotepad(
      tester,
      _FakeCryptoService('initial',
          readError: 'cannot read /private-note-path'),
    );

    expect(find.text('无法读取文件内容。请检查文件是否存在且可读，然后重试。'), findsOneWidget);
    expect(find.textContaining('private-note-path'), findsNothing);
    expect(find.byKey(const Key('error-technical-details')), findsNothing);

    ErrorReportingService.configure(detailedErrorsEnabled: true);
    await tester.pumpWidget(const SizedBox.shrink());
    await _openNotepad(
      tester,
      _FakeCryptoService('initial',
          readError: 'cannot read /private-note-path'),
    );
    expect(find.byKey(const Key('error-technical-details')), findsOneWidget);
    expect(find.textContaining('private-note-path'), findsNothing);
    expect(find.textContaining('[路径已隐藏]'), findsOneWidget);
  });

  testWidgets('notepad localizes binary-content errors through the UI',
      (tester) async {
    await _openNotepad(
      tester,
      _FakeCryptoService('MZ\x00binary'),
      locale: const Locale('en'),
    );

    expect(
      find.text(
        'The file contains binary content and cannot be opened in Secure Notepad.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('binary-content-nul-byte'), findsNothing);
  });

  testWidgets('notepad clipboard errors are localized without raw details',
      (tester) async {
    final clipboard = _FakeSystemTextClipboard(
      'short text',
      readError: 'cannot read /private-clipboard-path',
    );
    await _openNotepad(
      tester,
      _FakeCryptoService('initial'),
      initiallyMonitorClipboard: true,
      locale: const Locale('en'),
      systemClipboard: clipboard,
    );

    expect(
        find.text('Unable to read the clipboard. Try again.'), findsOneWidget);
    expect(find.textContaining('private-clipboard-path'), findsNothing);

    clipboard.readError = null;
    await tester.tap(find.byTooltip('Refresh clipboard now'));
    await tester.pumpAndSettle();
    clipboard.clearError = 'cannot clear /private-clipboard-path';
    await tester.tap(find.byTooltip('Clear system clipboard'));
    await tester.pumpAndSettle();

    expect(
        find.text('Unable to clear the clipboard. Try again.'), findsOneWidget);
    expect(find.textContaining('private-clipboard-path'), findsNothing);
  });

  testWidgets('notepad save error hides raw diagnostics by default',
      (tester) async {
    await _openNotepad(
      tester,
      _FakeCryptoService('initial',
          writeError: 'cannot write /private-note-path'),
    );
    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.enterText(editor, 'changed');
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败'), findsOneWidget);
    expect(find.textContaining('private-note-path'), findsNothing);
    expect(find.byKey(const Key('error-technical-details')), findsNothing);
  });

  testWidgets('Ctrl+F search focuses and both Enter keys navigate matches',
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
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    final editorEditable = _findRenderEditable(
      tester.renderObject<RenderObject>(editor),
    );
    expect(editorEditable, isNotNull);
    expect(
      editorEditable!.selection,
      tester.widget<TextField>(editor).controller!.selection,
    );
    expect(editorEditable.selectionColor, isNull);
    final highlight = find.byKey(const Key('secure-notepad-find-highlight'));
    expect(highlight, findsOneWidget);
    expect(tester.widget<CustomPaint>(highlight).painter, isNotNull);
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump();
    expect(find.text('2/2'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 11, extentOffset: 16),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(find.text('1/2'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(findField, findsNothing);
    expect(
      find.byKey(const Key('secure-notepad-find-highlight')),
      findsNothing,
    );
    expect(tester.widget<TextField>(editor).focusNode?.hasFocus, isTrue);
  });

  testWidgets('find centers a distant match without stealing query focus',
      (tester) async {
    final text = List<String>.generate(
      100,
      (index) => index == 90 ? 'needle' : 'line $index',
    ).join('\n');
    await _openNotepad(tester, _FakeCryptoService(text));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findField = find.byKey(const Key('secure-notepad-find-field'));
    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.enterText(findField, 'needle');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));

    final textField = tester.widget<TextField>(editor);
    expect(textField.controller!.selection.textInside(text), 'needle');
    expect(textField.scrollController!.offset, greaterThan(300));
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('find highlight paints every line of a cross-line match',
      (tester) async {
    const text = 'before needle\nsuffix after';
    await _openNotepad(tester, _FakeCryptoService(text));
    final editor = find.byKey(const Key('secure-notepad-editor'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final findField = find.byKey(const Key('secure-notepad-find-field'));
    await tester.enterText(findField, r'needle\nsuf');
    expect(
      tester.widget<TextField>(findField).controller!.text,
      r'needle\nsuf',
    );
    await tester.tap(find.byTooltip('查找下一个'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(editor).controller!.selection,
      const TextSelection(baseOffset: 7, extentOffset: 17),
    );
    final renderEditable = _findRenderEditable(
      tester.renderObject<RenderObject>(editor),
    );
    final renderSelection = renderEditable!.selection;
    expect(renderSelection, isNotNull);
    expect(
      renderEditable.getBoxesForSelection(renderSelection!).length,
      greaterThanOrEqualTo(2),
    );

    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const Key('secure-notepad-find-highlight')),
        )
        .painter!;
    expect((painter as dynamic).rects.length, greaterThanOrEqualTo(2));
    expect(tester.widget<TextField>(findField).focusNode?.hasFocus, isTrue);
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

  testWidgets('undo and redo use standard commands instead of history counts',
      (tester) async {
    await _openNotepad(tester, _FakeCryptoService('initial'));
    final editor = find.byKey(const Key('secure-notepad-editor'));
    await tester.enterText(editor, 'changed');
    await tester.pump();

    final undo = find.byTooltip('撤销（Ctrl/Cmd+Z）');
    final redo = find.byTooltip('重做（Ctrl/Cmd+Shift+Z）');
    final undoButton =
        find.ancestor(of: undo, matching: find.byType(IconButton));
    final redoButton =
        find.ancestor(of: redo, matching: find.byType(IconButton));
    expect(tester.widget<IconButton>(undoButton).onPressed, isNotNull);
    expect(tester.widget<IconButton>(redoButton).onPressed, isNull);
    expect(find.textContaining('撤销:'), findsNothing);
    expect(find.textContaining('重做:'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(tester.widget<TextField>(editor).controller!.text, 'initial');
    expect(tester.widget<IconButton>(redoButton).onPressed, isNotNull);

    await tester.tap(redoButton);
    await tester.pump();
    expect(tester.widget<TextField>(editor).controller!.text, 'changed');
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
    await tester.binding.handlePopRoute();
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
    expect(find.text('剪贴板中没有文本'), findsOneWidget);

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
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final readsAfterClose = clipboard.readCount;
    await tester.pump(const Duration(milliseconds: 50));
    expect(clipboard.readCount, readsAfterClose);
  });
}

RenderEditable? _findRenderEditable(RenderObject renderObject) {
  if (renderObject is RenderEditable) return renderObject;
  RenderEditable? result;
  renderObject.visitChildren((child) {
    result ??= _findRenderEditable(child);
  });
  return result;
}

Future<void> _openNotepad(
  WidgetTester tester,
  CryptoService service, {
  bool initiallyReadOnly = false,
  bool initiallyMonitorClipboard = false,
  Locale locale = const Locale('zh'),
  VoidCallback? onSaved,
  SystemTextClipboard systemClipboard = const FlutterSystemTextClipboard(),
  Duration clipboardMonitorInterval = Duration.zero,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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
  _FakeCryptoService(this.initialText, {this.writeError, this.readError}) {
    files['/vault/note.txt'] = initialText;
  }

  final String initialText;
  final String? writeError;
  final String? readError;
  final List<String> writes = [];
  final Map<String, String> files = {};

  @override
  Uint8List decryptFileToData(String path, String tempKeyID) {
    if (readError != null) throw StateError(readError!);
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
  _FakeSystemTextClipboard(this.text, {this.readError});

  String? text;
  String? readError;
  String? clearError;
  int readCount = 0;

  @override
  Future<String?> readText() async {
    readCount++;
    if (readError != null) throw StateError(readError!);
    return text;
  }

  @override
  Future<void> clear() async {
    if (clearError != null) throw StateError(clearError!);
    text = '';
  }
}
