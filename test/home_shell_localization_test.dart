import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/models/view_mode.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/secure_clipboard_service.dart';
import 'package:safe_disk/widgets/home_shell.dart';
import 'package:safe_disk/widgets/secure_external_drop_target.dart';

void main() {
  testWidgets('home shell localizes batch selection and clipboard status',
      (tester) async {
    await tester.pumpWidget(
      _localizedShell(
        selectMode: true,
        selectedFiles: {
          FileSystemNode(
              name: 'first.txt', path: '/first.txt', isDirectory: false),
          FileSystemNode(
              name: 'second.txt', path: '/second.txt', isDirectory: false),
        },
      ),
    );

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byTooltip('Exit selection mode'), findsOneWidget);
    expect(find.byTooltip('Copy selected'), findsOneWidget);
    expect(find.byTooltip('Cut selected'), findsOneWidget);
    expect(find.byType(SecureExternalDropTarget), findsOneWidget);

    await tester.pumpWidget(
      _localizedShell(
        canPaste: true,
        clipboardEntry: const SecureClipboardEntry(
          sourcePath: '/report.txt',
          sourceSessionID: 'source-session',
          name: 'report.txt',
          isDirectory: false,
        ),
        clipboardEntryCount: 2,
      ),
    );

    expect(
      find.text('File clipboard · report.txt and 2 items → target'),
      findsOneWidget,
    );
    expect(find.byTooltip('Paste to current directory'), findsOneWidget);
    expect(find.byTooltip('Clear file clipboard'), findsOneWidget);
  });
}

Widget _localizedShell({
  bool selectMode = false,
  Set<FileSystemNode> selectedFiles = const {},
  SecureClipboardEntry? clipboardEntry,
  int clipboardEntryCount = 0,
  bool canPaste = false,
}) {
  final directory = EncryptedDirectory(
    path: '/vault',
    config: CryptionConfig(const {}),
    isVerified: true,
  );
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeShell(
      scaffoldKey: GlobalKey<ScaffoldState>(),
      openedDirectories: [directory],
      currentDirectory: directory,
      currentPath: '/vault/target',
      items: const [],
      drawerPinned: false,
      viewMode: ViewMode.list,
      selectMode: selectMode,
      selectedFiles: selectedFiles,
      fileService: FileService(),
      onOpenDirectory: () {},
      onCloseDirectory: (_) {},
      onSwitchDirectory: (_) {},
      onRenameDirectory: (_) {},
      onShowRootProperties: (_) {},
      onChangeRootPassword: (_) {},
      onToggleDrawerPin: (_) async {},
      onUnlock: (_) async => true,
      onImportFile: () {},
      onImportDirectory: () {},
      onPaste: () {},
      onClearClipboard: () {},
      onOpenSettings: () {},
      onViewModeChanged: (_) {},
      onCancelSelection: () {},
      onSelectAll: () {},
      onBatchCopy: () {},
      onBatchCut: () {},
      onBatchExport: () {},
      onBatchDelete: () {},
      onNavigateToDirectory: (_) {},
      onNavigateUp: () {},
      onOpenItem: (_) {},
      onShowItemOptions: (_) {},
      onShowItemContextMenu: (_, __) {},
      onShowBackgroundContextMenu: (_) {},
      onCloseCurrentRoot: () {},
      onToggleSelectMode: (_) {},
      onSelectionToggle: (_, __) {},
      onExternalDrop: (_) {},
      clipboardEntry: clipboardEntry,
      clipboardEntryCount: clipboardEntryCount,
      canPaste: canPaste,
    ),
  );
}
