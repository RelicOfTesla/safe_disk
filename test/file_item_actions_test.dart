import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/widgets/file_item_actions.dart';

class MaterialApp extends material.MaterialApp {
  const MaterialApp({
    super.key,
    super.home,
    super.navigatorObservers,
    Locale? locale,
  }) : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

void main() {
  test('exposes only actions supported by each item type', () {
    final directory = _node('资料', isDirectory: true);
    final text = _node('记录.md');
    final image = _node('照片.webp');
    final binary = _node('归档.bin');

    expect(
      fileItemActionsFor(directory),
      [
        FileItemAction.open,
        FileItemAction.rename,
        FileItemAction.copy,
        FileItemAction.cut,
        FileItemAction.export,
        FileItemAction.copyName,
        FileItemAction.copyPath,
        FileItemAction.properties,
        FileItemAction.refresh,
      ],
    );
    expect(
      fileItemActionsFor(text),
      [
        FileItemAction.edit,
        FileItemAction.openInNewWindow,
        FileItemAction.select,
        FileItemAction.rename,
        FileItemAction.copy,
        FileItemAction.cut,
        FileItemAction.export,
        FileItemAction.copyName,
        FileItemAction.copyPath,
        FileItemAction.properties,
        FileItemAction.refresh,
        FileItemAction.delete,
      ],
    );
    expect(
      fileItemActionsFor(image),
      [
        FileItemAction.open,
        FileItemAction.openInNewWindow,
        FileItemAction.select,
        FileItemAction.rename,
        FileItemAction.copy,
        FileItemAction.cut,
        FileItemAction.export,
        FileItemAction.copyName,
        FileItemAction.copyPath,
        FileItemAction.properties,
        FileItemAction.refresh,
        FileItemAction.delete,
      ],
    );
    expect(
      fileItemActionsFor(binary),
      [
        FileItemAction.edit,
        FileItemAction.openInNewWindow,
        FileItemAction.select,
        FileItemAction.rename,
        FileItemAction.copy,
        FileItemAction.cut,
        FileItemAction.export,
        FileItemAction.copyName,
        FileItemAction.copyPath,
        FileItemAction.properties,
        FileItemAction.refresh,
        FileItemAction.delete,
      ],
    );
  });

  test('offers paste only for directories when clipboard content exists', () {
    final directory = _node('资料', isDirectory: true);
    final file = _node('记录.txt');

    expect(
      fileItemActionsFor(directory, canPasteInto: true),
      contains(FileItemAction.pasteInto),
    );
    expect(
      fileItemActionsFor(file, canPasteInto: true),
      isNot(contains(FileItemAction.pasteInto)),
    );
  });

  test('resolves file action labels from Chinese and English ARB resources',
      () async {
    final file = _node('记录.txt');
    final chinese = await AppLocalizations.delegate.load(const Locale('zh'));
    final english = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      fileItemActionLabel(chinese, FileItemAction.edit, file),
      '使用安全记事本编辑',
    );
    expect(
      fileItemActionLabel(chinese, FileItemAction.openInNewWindow, file),
      '在新窗口中编辑',
    );
    expect(
      fileItemActionLabel(
        chinese,
        FileItemAction.openInNewWindow,
        _node('照片.webp'),
      ),
      '在新窗口中查看',
    );
    expect(
      fileItemActionLabel(chinese, FileItemAction.export, file),
      '导出解密文件',
    );
    expect(
      fileItemActionLabel(chinese, FileItemAction.delete, file),
      '删除文件',
    );
    expect(fileItemActionLabel(chinese, FileItemAction.select, file), '选择');
    expect(fileItemActionLabel(chinese, FileItemAction.cut, file), '剪切');
    expect(
      fileItemActionLabel(chinese, FileItemAction.copyPath, file),
      '复制逻辑路径（明文）',
    );
    expect(
      fileItemActionLabel(english, FileItemAction.edit, file),
      'Edit with Secure Notepad',
    );
    expect(
      fileItemActionLabel(english, FileItemAction.copyPath, file),
      'Copy logical path (plaintext)',
    );
  });

  test('validates rename input for cross-platform file systems', () {
    expect(validateFileItemName('新名称.txt'), isNull);
    expect(validateFileItemName(''), isNotNull);
    expect(validateFileItemName('..'), isNotNull);
    expect(validateFileItemName('a/b'), isNotNull);
    expect(validateFileItemName(r'a\b'), isNotNull);
    expect(validateFileItemName('bad:name'), isNotNull);
    expect(validateFileItemName('CON.txt'), isNotNull);
    expect(validateFileItemName('trailing.'), isNotNull);
    expect(validateFileItemName(' name.txt'), isNotNull);
    expect(validateFileItemName(List.filled(86, '中').join()), isNotNull);
  });

  testWidgets('properties are built without a dialog transition frame',
      (tester) async {
    final item = _node('记录.txt');
    final observer = _PushCountingObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFileItemProperties(
              context: context,
              item: item,
            ),
            child: const Text('打开属性'),
          ),
        ),
      ),
    );
    final pushesBeforeOpen = observer.pushCount;

    await tester.tap(find.text('打开属性'));
    await tester.pump();

    expect(observer.pushCount, pushesBeforeOpen);
    expect(find.text('属性'), findsOneWidget);
    expect(find.text('/vault/记录.txt'), findsOneWidget);
  });

  testWidgets('context-menu properties are visible on the next frame',
      (tester) async {
    final item = _node('冷启动.txt');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => GestureDetector(
            onSecondaryTapDown: (details) async {
              final action = await showFileItemContextMenu(
                context: context,
                item: item,
                globalPosition: details.globalPosition,
              );
              if (action == FileItemAction.properties && context.mounted) {
                await showFileItemProperties(context: context, item: item);
              }
            },
            child: const SizedBox.expand(
              child: Center(child: Text('文件条目')),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('文件条目')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    expect(find.text('属性'), findsOneWidget);

    await tester.tap(find.text('属性'));
    await tester.pump();
    expect(find.text('/vault/冷启动.txt'), findsOneWidget);
  });

  testWidgets('file action sheet displays English action labels',
      (tester) async {
    final item = _node('notes.txt');
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFileItemActionSheet(
              context: context,
              item: item,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Edit with Secure Notepad'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Delete file'), findsOneWidget);
  });
}

class _PushCountingObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

FileSystemNode _node(String name, {bool isDirectory = false}) {
  return FileSystemNode(
    name: name,
    path: '/vault/$name',
    isDirectory: isDirectory,
  );
}
