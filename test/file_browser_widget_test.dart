import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/view_mode.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/widgets/directory_tree.dart';
import 'package:safe_disk/widgets/file_browser.dart';

class MaterialApp extends material.MaterialApp {
  const MaterialApp({
    super.key,
    super.home,
    super.theme,
    Locale? locale,
  }) : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

void main() {
  testWidgets('Windows 路径直接支持面包屑和向上导航', (tester) async {
    var upCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowser(
            items: const [],
            currentPath: r'C:\safe\私密盘\源码',
            rootPath: r'C:\safe\私密盘',
            viewMode: ViewMode.list,
            isSelectMode: false,
            selectedFiles: const {},
            fileService: _TreeFileService(),
            onNavigateToDirectory: (_) {},
            onNavigateUp: () => upCount++,
            onOpenItem: (_) {},
            onItemLongPress: (_) {},
            onItemSecondaryTap: (_, __) {},
            onBackgroundSecondaryTap: (_) {},
            onViewModeChanged: (_) {},
            onToggleSelectMode: (_) {},
            onSelectionToggle: (_, __) {},
            onSelectAll: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('私密盘'), findsOneWidget);
    expect(find.text(r'C:\safe\私密盘'), findsNothing);
    await tester.tap(find.byTooltip('返回上级目录'));
    expect(upCount, 1);
  });

  testWidgets('分页失败显示刷新重试而不是继续追加', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileBrowser(
            items: const [],
            currentPath: '/root',
            rootPath: '/root',
            viewMode: ViewMode.list,
            isSelectMode: false,
            selectedFiles: const {},
            fileService: _TreeFileService(),
            onNavigateToDirectory: (_) {},
            onNavigateUp: () {},
            onOpenItem: (_) {},
            onItemLongPress: (_) {},
            onItemSecondaryTap: (_, __) {},
            onBackgroundSecondaryTap: (_) {},
            onViewModeChanged: (_) {},
            onToggleSelectMode: (_) {},
            onSelectionToggle: (_, __) {},
            onSelectAll: () {},
            loadMoreError: StateError('cursor failed'),
            onRetryLoadMore: () => retryCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('读取目录失败，刷新后重试'), findsOneWidget);
    await tester.tap(find.text('读取目录失败，刷新后重试'));
    expect(retryCount, 1);
  });

  testWidgets('目录浏览器按英文显示工具栏、状态和可访问性标签', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: _BrowserHarness(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Go up'), findsOneWidget);
    expect(find.byTooltip('Filter current directory'), findsOneWidget);
    expect(find.text('1 folders, 2 files'), findsOneWidget);
    expect(find.bySemanticsLabel('alpha.txt, File'), findsOneWidget);

    await tester.tap(find.byKey(const Key('file-sort-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Name: Z to A'), findsOneWidget);
  });

  testWidgets('current-directory filter keeps focus and clears on navigation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('筛选当前目录'));
    await tester.pumpAndSettle();
    final filter = find.byKey(const Key('current-directory-filter'));
    await tester.enterText(filter, 'alpha');
    await tester.pump();
    expect(find.text('alpha.txt'), findsOneWidget);
    expect(find.text('beta.txt'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tap(find.byTooltip('返回上级目录'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(filter).controller?.text, isEmpty);
    expect(find.text('beta.txt'), findsOneWidget);
  });

  testWidgets('double-click open mode defers opening until the second click',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _BrowserHarness(openOnDoubleClick: true)),
    );
    await tester.pumpAndSettle();

    final item = find.byKey(const ValueKey('file-list-/root/sub/alpha.txt'));
    await tester.tap(item);
    await tester.pump();
    expect(find.text('opened: 0'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('file-list-/root/sub/alpha.txt')),
          )
          .selected,
      isTrue,
    );

    // The first tap is intentionally settled before sending a desktop-style
    // double click; the latter is represented by the following two taps.
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(item);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('opened: 1'), findsOneWidget);
  });

  testWidgets('double-click mode highlights the first grid click',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: _BrowserHarness(openOnDoubleClick: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();

    final item = find.byKey(const ValueKey('file-grid-/root/sub/alpha.txt'));
    await tester.tap(item);
    await tester.pump();

    final label = find.bySemanticsLabel('alpha.txt，文件');
    expect(
      tester.getSemantics(label).flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 400));
    semantics.dispose();
  });

  testWidgets('grid icons keep a stable box at narrow widths', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 700));
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();

    final icon = find.descendant(
      of: find.byKey(const ValueKey('file-grid-/root/sub/alpha.txt')),
      matching: find.byType(Icon),
    );
    expect(tester.getSize(icon), const Size(48, 48));
    final iconBox = find.ancestor(
      of: icon,
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(iconBox.first), const Size(56, 56));
  });

  testWidgets('ctrl and shift clicks select a range in list view',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    final alpha = find.byKey(const ValueKey('file-list-/root/sub/alpha.txt'));
    final beta = find.byKey(const ValueKey('file-list-/root/sub/beta.txt'));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      HardwareKeyboard.instance.logicalKeysPressed,
      contains(LogicalKeyboardKey.controlLeft),
    );
    await tester.tap(alpha);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(find.text('selected: 1'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.tap(beta);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(find.text('selected: 2'), findsOneWidget);

    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Card>(
            find.byKey(const ValueKey('file-grid-/root/sub/alpha.txt')),
          )
          .color,
      Theme.of(tester.element(find.byType(FileBrowser)))
          .colorScheme
          .primaryContainer,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(
              const ValueKey('file-grid-select-/root/sub/alpha.txt'),
            ),
          )
          .value,
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('file-grid-select-/root/sub/alpha.txt')),
    );
    await tester.pump();
    expect(find.text('selected: 1'), findsOneWidget);
  });

  testWidgets('directories participate in range and keyboard-style selection',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    final notes = find.byKey(const ValueKey('file-list-/root/sub/notes'));
    final beta = find.byKey(const ValueKey('file-list-/root/sub/beta.txt'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(notes);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('selected: 1'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('file-list-/root/sub/notes')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(beta);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(find.text('selected: 3'), findsOneWidget);
  });

  testWidgets('mouse drag selects intersecting files', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    final alpha = tester.getCenter(
      find.byKey(const ValueKey('file-list-/root/sub/alpha.txt')),
    );
    final beta = tester.getCenter(
      find.byKey(const ValueKey('file-list-/root/sub/beta.txt')),
    );
    final gesture = await tester.startGesture(
      alpha - const Offset(0, 20),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
    );
    await gesture.moveTo(beta + const Offset(0, 20));
    await tester.pump();
    expect(find.byKey(const Key('file-selection-marquee')), findsOneWidget);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('selected: 2'), findsOneWidget);
    expect(find.byKey(const Key('file-selection-marquee')), findsNothing);
  });

  testWidgets('tree is a side navigator on wide layouts and a sheet on narrow',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('显示目录导航'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('directory-tree-pane')), findsOneWidget);
    expect(find.text('alpha.txt'), findsOneWidget);
    expect(find.text('tree-folder'), findsOneWidget);
    expect(find.text('tree-file.bin'), findsNothing);

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('显示目录导航'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('directory-tree-pane')), findsNothing);
    expect(find.byType(DirectoryTreeWidget), findsOneWidget);
  });

  testWidgets('grid empty area handles a secondary click as background',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();

    final background = find.byKey(const Key('directory-browser-background'));
    final gesture = await tester.startGesture(
      tester.getCenter(background),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();

    expect(find.text('background-clicks: 1'), findsOneWidget);
    expect(find.text('item-clicks: 0'), findsOneWidget);
  });

  testWidgets('list and grid expose entry type and context selection semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    final fileLabel = find.bySemanticsLabel('alpha.txt，文件');
    expect(fileLabel, findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('alpha.txt')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    expect(
      tester.getSemantics(fileLabel).flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('alpha.txt，文件'), findsOneWidget);
    expect(find.bySemanticsLabel('notes，目录'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('list and grid share the selected sort order', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _BrowserHarness()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('file-sort-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称：Z 到 A').last);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('beta.txt')).dy,
      lessThan(tester.getTopLeft(find.text('alpha.txt')).dy),
    );
    expect(find.byTooltip('排序：名称：Z 到 A'), findsOneWidget);

    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('beta.txt')).dx,
      lessThan(tester.getTopLeft(find.text('alpha.txt')).dx),
    );
  });

  testWidgets('grid reports its actual column count for keyboard navigation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(500, 700));
    var columns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _BrowserHarness(
          onGridColumnCountChanged: (value) => columns = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(columns, 3);
  });

  testWidgets('incomplete directories preserve cursor order in list and grid',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _PagedBrowserHarness()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('目录尚未完整加载，暂不可排序'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('zeta.txt')).dy,
      lessThan(tester.getTopLeft(find.text('alpha.txt')).dy),
    );

    await tester.tap(find.byTooltip('网格视图'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('zeta.txt')).dx,
      lessThan(tester.getTopLeft(find.text('alpha.txt')).dx),
    );
  });

  testWidgets(
      'incomplete directory filter declares its scope and can load more',
      (tester) async {
    final key = GlobalKey<_PagedBrowserHarnessState>();
    await tester.pumpWidget(MaterialApp(home: _PagedBrowserHarness(key: key)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('筛选当前目录'));
    await tester.pumpAndSettle();
    expect(find.text('仅筛选已加载条目；继续加载可扩大范围'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('current-directory-filter')),
      'missing',
    );
    await tester.pump();
    expect(find.text('已加载条目中没有匹配“missing”的内容'), findsOneWidget);
    expect(find.text('仍有未加载条目，可继续加载后再筛选'), findsOneWidget);
    await tester.tap(find.text('加载更多条目'));
    expect(key.currentState!.loadMoreCalls, 1);

    key.currentState!.finishLoading();
    await tester.pumpAndSettle();
    expect(find.byTooltip('排序：名称：A 到 Z'), findsOneWidget);
    await tester.tap(find.byKey(const Key('file-sort-menu')));
    await tester.pumpAndSettle();
    expect(find.text('名称：Z 到 A').last, findsOneWidget);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('right-click highlight is explicit in ${brightness.name} mode',
        (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const _BrowserHarness(),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> rightClick() async {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('alpha.txt')),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.up();
        await tester.pump();
      }

      await rightClick();
      final listHighlight = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('file-list-/root/sub/alpha.txt')),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final listDecoration = listHighlight.decoration! as BoxDecoration;
      expect((listDecoration.border! as Border).left.width, 4);
      expect(
        tester
            .widget<Material>(find.byKey(
                const ValueKey('file-list-material-/root/sub/alpha.txt')))
            .color,
        scheme.primaryContainer,
      );

      await tester.tap(find.byTooltip('网格视图'));
      await tester.pumpAndSettle();
      await rightClick();
      final gridCard = tester.widget<Card>(
        find.byKey(const ValueKey('file-grid-/root/sub/alpha.txt')),
      );
      expect(gridCard.color, scheme.primaryContainer);
      expect((gridCard.shape! as RoundedRectangleBorder).side.width, 2.5);
    });
  }
}

class _BrowserHarness extends StatefulWidget {
  const _BrowserHarness({
    this.openOnDoubleClick = false,
    this.onGridColumnCountChanged,
  });

  final bool openOnDoubleClick;
  final ValueChanged<int>? onGridColumnCountChanged;

  @override
  State<_BrowserHarness> createState() => _BrowserHarnessState();
}

class _BrowserHarnessState extends State<_BrowserHarness> {
  String currentPath = '/root/sub';
  ViewMode viewMode = ViewMode.list;
  int backgroundClicks = 0;
  int itemClicks = 0;
  int openedItems = 0;
  bool selectMode = false;
  final Set<FileSystemNode> selectedItems = {};

  final items = [
    FileSystemNode(
      name: 'notes',
      path: '/root/sub/notes',
      isDirectory: true,
    ),
    FileSystemNode(
      name: 'alpha.txt',
      path: '/root/sub/alpha.txt',
      isDirectory: false,
    ),
    FileSystemNode(
      name: 'beta.txt',
      path: '/root/sub/beta.txt',
      isDirectory: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FileBrowser(
            items: items,
            currentPath: currentPath,
            rootPath: '/root',
            viewMode: viewMode,
            isSelectMode: selectMode,
            selectedFiles: selectedItems,
            fileService: _TreeFileService(),
            onNavigateToDirectory: (path) => setState(() => currentPath = path),
            onNavigateUp: () => setState(() => currentPath = '/root'),
            onOpenItem: (_) => setState(() => openedItems++),
            onItemLongPress: (_) {},
            onItemSecondaryTap: (_, __) => setState(() => itemClicks++),
            onBackgroundSecondaryTap: (_) => setState(() => backgroundClicks++),
            onViewModeChanged: (mode) => setState(() => viewMode = mode),
            onToggleSelectMode: (value) => setState(() => selectMode = value),
            onSelectionToggle: (item, selected) => setState(() {
              selectMode = true;
              if (selected) {
                selectedItems.add(item);
              } else {
                selectedItems.remove(item);
              }
            }),
            onSelectAll: () {},
            onSelectionChanged: (items) => setState(() {
              selectedItems
                ..clear()
                ..addAll(items);
              selectMode = items.isNotEmpty;
            }),
            onGridColumnCountChanged: widget.onGridColumnCountChanged,
            openOnDoubleClick: widget.openOnDoubleClick,
          ),
          IgnorePointer(
            child: Column(
              children: [
                Text('background-clicks: $backgroundClicks'),
                Text('item-clicks: $itemClicks'),
                Text('opened: $openedItems'),
                Text('selected: ${selectedItems.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PagedBrowserHarness extends StatefulWidget {
  const _PagedBrowserHarness({super.key});

  @override
  State<_PagedBrowserHarness> createState() => _PagedBrowserHarnessState();
}

class _PagedBrowserHarnessState extends State<_PagedBrowserHarness> {
  var hasMore = true;
  var loadMoreCalls = 0;
  var viewMode = ViewMode.list;

  final items = [
    FileSystemNode(
      name: 'zeta.txt',
      path: '/root/zeta.txt',
      isDirectory: false,
    ),
    FileSystemNode(
      name: 'alpha.txt',
      path: '/root/alpha.txt',
      isDirectory: false,
    ),
  ];

  void finishLoading() => setState(() => hasMore = false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FileBrowser(
        items: items,
        currentPath: '/root',
        rootPath: '/root',
        viewMode: viewMode,
        isSelectMode: false,
        selectedFiles: const {},
        fileService: _TreeFileService(),
        onNavigateToDirectory: (_) {},
        onNavigateUp: () {},
        onOpenItem: (_) {},
        onItemLongPress: (_) {},
        onItemSecondaryTap: (_, __) {},
        onBackgroundSecondaryTap: (_) {},
        onViewModeChanged: (mode) => setState(() => viewMode = mode),
        onToggleSelectMode: (_) {},
        onSelectionToggle: (_, __) {},
        onSelectAll: () {},
        hasMore: hasMore,
        onLoadMore: () => setState(() => loadMoreCalls++),
      ),
    );
  }
}

class _TreeFileService extends FileService {
  @override
  Future<List<FileSystemNode>> listCurrentDirectory(
    String path, {
    int offset = 0,
    int? limit,
  }) async {
    return [
      FileSystemNode(
        name: 'tree-folder',
        path: '$path/tree-folder',
        isDirectory: true,
      ),
      FileSystemNode(
        name: 'tree-file.bin',
        path: '$path/tree-file.bin',
        isDirectory: false,
      ),
    ];
  }
}
