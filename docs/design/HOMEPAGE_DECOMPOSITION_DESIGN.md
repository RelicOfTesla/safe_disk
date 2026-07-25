# HomePage 无损拆解设计

## 现状

`lib/pages/home_page.dart` 当前约 3650 行，包含 ~80 个方法，涵盖 12 个职责域：

| 域 | 行范围 | 方法数 | 描述 |
|---|---|---|---|
| Lifecycle & Init | ~97-264 | 10 | initState/dispose/didChange/lifecycle |
| Auto-Lock | ~264-462 | 8 | lockExpiredRoots/lockEligibleRoots/runRootCloseOperation |
| First Launch | ~463-540 | 3 | checkFirstLaunchAntiScreenshot/checkFirstTimeUser |
| Sidebar/Drawer | ~541-660 | 6 | loadPersistedDirectories/renameDirectoryAlias/moveDirectory |
| Directory Lifecycle | ~642-1490 | 13 | createEncryptedDirectory/loadDirectory/verifyPassword/closeDirectory/changeRootPassword |
| Navigation | ~1492-1518 | 3 | navigateToDirectory/navigateUp/openItem |
| File Openers | ~1520-1730 | 4 | openNotepad/openNotepadInNewWindow/openImageViewer |
| Context Menus | ~1729-1890 | 6 | showFileContextMenu/showBackgroundContextMenu/executeFileItemAction |
| WebDAV | ~1889-2200 | 15 | exposeToThirdParty/showWebDavSessions/mountWebDavSession/revokeWebDavSessionsForRoot |
| Import/Export | ~2197-2732 | 10 | importFile/importDirectory/exportFile/batchExport/resolveExportDestination |
| Batch Ops | ~2732-2817 | 2 | batchDelete/confirmPlaintextExport |
| Clipboard/Selection | ~2839-3058 | 11 | copyItem/cutItem/copySelected/pasteClipboard/selectAllItems |
| Entry CRUD | ~3008-3420 | 4 | createEntry/renameItem/deleteFile |
| Settings | ~3418-3438 | 1 | openSettings |
| Build | ~3439-3650 | 1 | build |

## 拆分策略

采用混合方案：核心协调保留在 HomePage，复杂子系统提取为 mixin，UI 子树提取为 widget。

### 原则
- 每部分 ≤ 500 行
- 所有方法保持 private（`_` 前缀），通过 mixin `on` 约束绑定到 `_HomePageState`
- UI 子树提取为独立 `StatefulWidget`/`StatelessWidget`
- 拆解后 HomePage 主要承担：状态持有、服务注入、路由协调
- 每阶段完成后 `dart analyze` 零告警、已存在的 widget 测试全通过

### 分阶段计划

#### Phase 1: Sidebar/Drawer → `HomeSidebar` widget
**提取内容：**
- `_loadPersistedDirectories()` → `HomeSidebar`
- `_saveOpenedDirectories()` → `HomeSidebar`
- `_renameDirectoryAlias()` → `HomeSidebar`
- `_applyDirectoryAlias()` → `HomeSidebar`
- `_moveDirectory()` → `HomeSidebar`
- `_loadDrawerPinnedState()` → 迁移到 `_HomePageState`
- `_openedDirs` 列表 → `HomeSidebar` 通过 callback 与 HomePage 通信
- Drawer UI (`build` 中的 `NavigationDrawer` 部分)

**通信接口：**
```dart
class HomeSidebar extends StatefulWidget {
  final List<EncryptedDirectory> directories;
  final int? activeSessionID;
  final ValueChanged<EncryptedDirectory> onSelectDirectory;
  final ValueChanged<EncryptedDirectory> onCloseDirectory;
  final ValueChanged<EncryptedDirectory> onRenameDirectory;
  final VoidCallback onCreateDirectory;
  final ValueChanged<int> onReorderDirectory;
}
```

#### Phase 2: Auto-Lock → `HomePageAutoLockMixin`
**提取内容：**
- `_idleTimer` / `_idleTracker` / `_autoLockOnBackground` / `_isAutoLocking` 状态
- `_loadAutoLockPreference()` / `_loadSessionTTL()`
- `_touchCurrentRoot()`
- `didChangeAppLifecycleState()`
- `_showPendingAutoLockSummary()`
- `_lockExpiredRoots()`
- `_lockEligibleRoots()`
- `_isCurrentDirectorySession()`
- `_dismissInProcessNotepad()`
- `_dismissInProcessImageViewer()`
- `_runRootCloseOperation()`
- `_disposeCurrentDirectoryPageSession()`

**Mixin 约束：**
```dart
mixin HomePageAutoLockMixin on State<HomePage> {
  // 通过 State 访问 context / widget / 其他 state 成员
}
```

#### Phase 3: WebDAV → `HomePageWebDavMixin`
**提取内容：**
- `_webDavSessionCounts` / `_webDavMountOperations` / `_webDavEnabled` 状态
- 所有 `_webDav*` / `_mountWebDav*` / `_unmountWebDav*` / `_cancelWebDav*` 方法
- `_revokeWebDavSessionsForRoot()` / `_listWebDavSessions()`
- `_exposeToThirdParty()`
- `_loadWebDavEnabled()`
- `_setWebDavEnabled()`

#### Phase 4: 文件操作 → `HomePageFileOpsMixin`
**提取内容：**
- Import: `_importFile()` / `_importFilePath()` / `_importDirectory()` / `_importDirectoryPath()` / `_importDroppedCandidates()`
- Export: `_exportFile()` / `_exportDirectory()` / `_batchExport()` / `_resolveExportDestination()` / `_resolveDirectoryExportDestination()` / `_confirmPlaintextExport()`
- Clipboard: `_copyItem()` / `_cutItem()` / `_copySelected()` / `_copyKeyboardTarget()` / `_moveKeyboardTarget()` / `_moveKeyboardTargetToEdge()` / `_toggleKeyboardTargetSelection()` / `_selectAllItems()` / `_cancelSelection()` / `_pasteClipboard()`
- CRUD: `_createEntry()` / `_renameItem()` / `_deleteFile()`
- Batch: `_batchDelete()`

#### Phase 5: 上下文菜单 → `HomePageContextMenuMixin`
**提取内容：**
- `_showFileOptions()` / `_showFileContextMenu()`
- `_showRootDirectoryPropertiesAfterMenu()`
- `_showBackgroundContextMenu()` / `_showKeyboardContextMenu()`
- `_executeFileItemAction()`

#### Phase 6: 目录生命周期 → `HomePageDirectoryMixin`
**提取内容：**
- `_openOrCreateEncryptedDirectory()` / `_createEncryptedDirectoryWithPath()`
- `_loadDirectory()` / `_loadCurrentPath()` / `_loadMoreCurrentPath()`
- `_verifyPassword()` / `_handleUnfinishedOperations()` / `_rerunUnfinishedOperations()`
- `_switchToDirectory()`
- `_closeDirectory()` / `_closeDirectoryAfterDecision()`
- `_lockRootForPasswordChange()` / `_lockRootForPasswordChangeAfterGate()`
- `_changeRootPassword()` / `_manageRootPasswordHint()`
- `_replaceWithLockedDirectory()`

### 不拆分的部分
- `initState()` / `dispose()`: 保留在 HomePage，负责初始化各 mixin 和服务
- `build()`: 保留在 HomePage，组装各子 widget
- `_navigateToDirectory()` / `_navigateUp()` / `_openItem()`: 保留，是轻量协调方法
- `_openNotepad()` / `_openImageViewer()` 等: 保留，与 ContentWindowPlatform 紧密耦合
- `_openSettings()`: 保留，单行委托

### 预期结果
- HomePage 从 3650 行降至 ~400 行
- 6 个 mixin/widget 各 ~200-500 行
- 每个文件可独立理解和修改
- 现存测试无需修改（测试通过公开 API）
