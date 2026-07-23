import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../models/view_mode.dart';
import '../services/file_service.dart';
import '../services/secure_clipboard_service.dart';
import '../services/drag_drop_controller.dart';
import 'file_browser.dart';
import 'import_actions.dart';
import 'password_prompt.dart';
import 'sidebar.dart';
import 'welcome_screen.dart';
import 'secure_external_drop_target.dart';

enum _BatchSelectionAction { selectAll, export, delete }

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.scaffoldKey,
    required this.openedDirectories,
    required this.currentDirectory,
    required this.currentPath,
    required this.items,
    required this.drawerPinned,
    required this.viewMode,
    this.openOnDoubleClick = false,
    required this.selectMode,
    required this.selectedFiles,
    required this.fileService,
    required this.onOpenDirectory,
    required this.onCloseDirectory,
    required this.onSwitchDirectory,
    required this.onRenameDirectory,
    required this.onShowRootProperties,
    required this.onChangeRootPassword,
    required this.onToggleDrawerPin,
    required this.onUnlock,
    required this.onImportFile,
    required this.onImportDirectory,
    required this.onPaste,
    required this.onClearClipboard,
    required this.onOpenSettings,
    required this.onViewModeChanged,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onBatchCopy,
    required this.onBatchCut,
    required this.onBatchExport,
    required this.onBatchDelete,
    required this.onNavigateToDirectory,
    required this.onNavigateUp,
    required this.onOpenItem,
    required this.onShowItemOptions,
    required this.onShowItemContextMenu,
    required this.onShowBackgroundContextMenu,
    required this.onCloseCurrentRoot,
    required this.onToggleSelectMode,
    required this.onSelectionToggle,
    required this.onExternalDrop,
    this.loading = false,
    this.canPaste = false,
    this.clipboardEntry,
    this.clipboardEntryCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.onLoadMore,
    this.onRetryLoadMore,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final List<EncryptedDirectory> openedDirectories;
  final EncryptedDirectory? currentDirectory;
  final String? currentPath;
  final List<FileSystemNode> items;
  final bool drawerPinned;
  final ViewMode viewMode;
  final bool openOnDoubleClick;
  final bool selectMode;
  final Set<FileSystemNode> selectedFiles;
  final FileService fileService;
  final bool loading;
  final bool canPaste;
  final SecureClipboardEntry? clipboardEntry;
  final int clipboardEntryCount;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRetryLoadMore;

  final VoidCallback onOpenDirectory;
  final ValueChanged<EncryptedDirectory> onCloseDirectory;
  final ValueChanged<EncryptedDirectory> onSwitchDirectory;
  final ValueChanged<EncryptedDirectory> onRenameDirectory;
  final ValueChanged<EncryptedDirectory> onShowRootProperties;
  final ValueChanged<EncryptedDirectory> onChangeRootPassword;
  final Future<void> Function(bool pinned) onToggleDrawerPin;
  final Future<bool> Function(String password) onUnlock;
  final VoidCallback onImportFile;
  final VoidCallback onImportDirectory;
  final VoidCallback onPaste;
  final VoidCallback onClearClipboard;
  final VoidCallback onOpenSettings;
  final ValueChanged<ViewMode> onViewModeChanged;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onBatchCopy;
  final VoidCallback onBatchCut;
  final VoidCallback onBatchExport;
  final VoidCallback onBatchDelete;
  final ValueChanged<String> onNavigateToDirectory;
  final VoidCallback onNavigateUp;
  final ValueChanged<FileSystemNode> onOpenItem;
  final ValueChanged<FileSystemNode> onShowItemOptions;
  final void Function(FileSystemNode item, Offset globalPosition)
      onShowItemContextMenu;
  final ValueChanged<Offset> onShowBackgroundContextMenu;
  final VoidCallback onCloseCurrentRoot;
  final ValueChanged<bool> onToggleSelectMode;
  final void Function(FileSystemNode item, bool selected) onSelectionToggle;
  final ValueChanged<List<DragDropCandidate>> onExternalDrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveDrawerPinned =
            drawerPinned && constraints.maxWidth >= 720;
        return Scaffold(
          key: scaffoldKey,
          appBar: _buildAppBar(context, effectiveDrawerPinned),
          drawer: effectiveDrawerPinned ? null : _buildDrawer(context),
          body: Row(
            children: [
              if (effectiveDrawerPinned)
                SizedBox(
                  width: 280,
                  child: _buildSidebar(context),
                ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool effectiveDrawerPinned,
  ) {
    final strings = AppLocalizations.of(context)!;
    return AppBar(
      title: selectMode
          ? Text(strings.selectedItems(selectedFiles.length))
          : Text(strings.appTitle),
      leading: selectMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: onCancelSelection,
              tooltip: strings.exitSelectionMode,
            )
          : effectiveDrawerPinned
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
      actions: selectMode
          ? _buildSelectActions(context)
          : _buildNormalActions(context),
    );
  }

  List<Widget> _buildSelectActions(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return [
      if (selectedFiles.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          onPressed: onBatchCopy,
          tooltip: strings.copySelected,
        ),
      if (selectedFiles.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.content_cut),
          onPressed: onBatchCut,
          tooltip: strings.cutSelected,
        ),
      PopupMenuButton<_BatchSelectionAction>(
        tooltip: strings.moreBatchActions,
        onSelected: (action) {
          switch (action) {
            case _BatchSelectionAction.selectAll:
              onSelectAll();
              break;
            case _BatchSelectionAction.export:
              onBatchExport();
              break;
            case _BatchSelectionAction.delete:
              onBatchDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _BatchSelectionAction.selectAll,
            child: ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(strings.selectAll),
            ),
          ),
          if (selectedFiles.isNotEmpty)
            PopupMenuItem(
              value: _BatchSelectionAction.export,
              child: ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(strings.exportSelected),
              ),
            ),
          if (selectedFiles.isNotEmpty)
            PopupMenuItem(
              value: _BatchSelectionAction.delete,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(strings.deleteSelected),
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildNormalActions(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return [
      ImportActions(
        onImportFile: onImportFile,
        onImportDirectory: onImportDirectory,
      ),
      if (currentDirectory?.isVerified == true)
        IconButton(
          icon: const Icon(Icons.folder_off_outlined),
          onPressed: onCloseCurrentRoot,
          tooltip: strings.closeDirectory,
        ),
      IconButton(
        icon: const Icon(Icons.settings_outlined),
        onPressed: onOpenSettings,
        tooltip: strings.settings,
      ),
    ];
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(child: _buildSidebar(context, closeAfterSwitch: true));
  }

  Widget _buildSidebar(
    BuildContext context, {
    bool closeAfterSwitch = false,
  }) {
    return SidebarWidget(
      openedDirs: openedDirectories,
      currentDir: currentDirectory,
      drawerPinned: drawerPinned,
      onOpenDirectory: onOpenDirectory,
      onCloseDirectory: onCloseDirectory,
      onSwitchDirectory: (directory) {
        if (closeAfterSwitch) Navigator.of(context).maybePop();
        onSwitchDirectory(directory);
      },
      onRenameDirectory: onRenameDirectory,
      onShowProperties: onShowRootProperties,
      onChangePassword: onChangeRootPassword,
      onTogglePin: onToggleDrawerPin,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final directory = currentDirectory;
    if (directory == null) {
      return const WelcomeScreen();
    }
    if (!directory.isVerified) {
      return PasswordPrompt(
        directoryPath: directory.path,
        onUnlock: onUnlock,
        passwordHint: directory.config.passwordHint,
      );
    }

    return Column(
      children: [
        if (clipboardEntry != null)
          _buildClipboardBanner(context, clipboardEntry!),
        Expanded(
          child: SecureExternalDropTarget(
            rootPath: directory.path,
            onDrop: onExternalDrop,
            child: FileBrowser(
              items: items,
              currentPath: currentPath,
              rootPath: directory.path,
              viewMode: viewMode,
              openOnDoubleClick: openOnDoubleClick,
              isSelectMode: selectMode,
              selectedFiles: selectedFiles,
              fileService: fileService,
              onNavigateToDirectory: onNavigateToDirectory,
              onNavigateUp: onNavigateUp,
              onOpenItem: onOpenItem,
              onItemLongPress: onShowItemOptions,
              onItemSecondaryTap: onShowItemContextMenu,
              onBackgroundSecondaryTap: onShowBackgroundContextMenu,
              onViewModeChanged: onViewModeChanged,
              onToggleSelectMode: onToggleSelectMode,
              onSelectionToggle: onSelectionToggle,
              onSelectAll: onSelectAll,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
              loadMoreError: loadMoreError,
              onLoadMore: onLoadMore,
              onRetryLoadMore: onRetryLoadMore,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClipboardBanner(
    BuildContext context,
    SecureClipboardEntry entry,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final strings = AppLocalizations.of(context)!;
        final wide = constraints.maxWidth >= 640;
        final targetName =
            currentPath?.split('/').last ?? strings.currentDirectory;
        final isMove = entry.isMove;
        final count = clipboardEntryCount > 0 ? clipboardEntryCount : 1;
        final entryLabel = count == 1
            ? entry.name
            : strings.clipboardMultipleEntries(entry.name, count);
        final actionLabel = isMove
            ? strings.moveToCurrentDirectory
            : strings.pasteToCurrentDirectory;
        final statusLabel = wide
            ? (isMove ? strings.clipboardMovePending : strings.fileClipboard)
            : (isMove
                ? strings.clipboardMovePending
                : strings.clipboardPastePending);
        return Material(
          key: const Key('file-clipboard-status'),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  entry.isDirectory
                      ? (isMove
                          ? Icons.drive_file_move_outlined
                          : Icons.folder_copy_outlined)
                      : (isMove ? Icons.content_cut : Icons.copy_outlined),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    wide
                        ? strings.clipboardStatusWide(
                            statusLabel,
                            entryLabel,
                            targetName,
                          )
                        : strings.clipboardStatusNarrow(
                            statusLabel, entryLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (wide)
                  Tooltip(
                    message: actionLabel,
                    child: TextButton.icon(
                      onPressed: canPaste ? onPaste : null,
                      icon:
                          const Icon(Icons.content_paste_go_outlined, size: 18),
                      label: Text(actionLabel),
                    ),
                  )
                else
                  IconButton(
                    onPressed: canPaste ? onPaste : null,
                    icon: const Icon(Icons.content_paste_go_outlined, size: 18),
                    tooltip: actionLabel,
                  ),
                IconButton(
                  onPressed: onClearClipboard,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: strings.clearFileClipboard,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
