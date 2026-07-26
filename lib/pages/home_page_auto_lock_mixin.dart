import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../services/content_window_host_bridge.dart';
import '../services/crypto_service.dart';
import '../services/directory_page_session.dart';
import '../services/root_close_coordinator.dart';
import '../services/root_idle_tracker.dart';
import '../services/secure_clipboard_service.dart';
import '../services/settings_service.dart';
import '../widgets/copyable_snackbar.dart';
import '../services/file_service.dart';

/// Auto-lock subsystem extracted from HomePage.
///
/// Handles: idle tracking, session TTL, app lifecycle locking,
/// pending auto-lock summaries, and safe root-close coordination.
///
/// The host State must provide the abstract getters/setters and
/// methods declared below.
mixin HomePageAutoLockMixin {
  // ── State owned by the mixin ──────────────────────────────────────

  bool _autoLockOnBackground = SettingsService.defaultAutoCloseSession;
  bool _isAutoLocking = false;
  final Map<String, Future<void>> _rootCloseTails = {};
  Timer? _idleTimer;
  String? _pendingAutoLockSummary;
  String? _lastIdleAutoLockSummary;

  /// Tracks the root session ID of the currently visible in-process notepad.
  String? inProcessNotepadSessionID;

  /// Tracks the root session ID of the currently visible in-process image viewer.
  String? inProcessImageViewerSessionID;

  // ── Abstract interface required from the host State ───────────────

  List<EncryptedDirectory> get openedDirs;
  EncryptedDirectory? get currentDir;
  set currentDir(EncryptedDirectory? value);
  String? get currentPath;
  set currentPath(String? value);

  CryptoService get cryptoService;
  SettingsService get settingsService;
  RootCloseCoordinator get rootCloseCoordinator;
  ContentWindowHostBridge get contentWindowBridge;
  SecureClipboardService get secureClipboard;
  RootIdleTracker get idleTracker;

  DirectoryPageSession? get pageSession;
  set pageSession(DirectoryPageSession? value);
  int get pageGeneration;
  set pageGeneration(int value);
  bool get isLoadingMore;
  set isLoadingMore(bool value);
  bool get isLoading;
  set isLoading(bool value);
  List<FileSystemNode> get items;
  set items(List<FileSystemNode> value);
  Set<FileSystemNode> get selectedFiles;
  FileSystemNode? get keyboardTarget;
  set keyboardTarget(FileSystemNode? value);
  String? get keyboardSelectionAnchorPath;
  set keyboardSelectionAnchorPath(String? value);
  bool get isSelectMode;
  set isSelectMode(bool value);

  Duration? get idleCheckInterval;

  // Methods the host must implement (will be extracted in later phases).

  void replaceWithLockedDirectory(
    EncryptedDirectory directory,
    EncryptedDirectory lockedDirectory, {
    String? expectedSessionID,
  });

  bool closeSession(String? sessionID);

  // ── Public API ────────────────────────────────────────────────────

  bool get isAutoLocking => _isAutoLocking;

  Future<void> loadAutoLockPreference() async {
    final enabled = await settingsService.getAutoCloseSession();
    if (mounted) setState(() => _autoLockOnBackground = enabled);
  }

  Future<void> loadSessionTTL() async {
    final seconds = await settingsService.getSessionTTL();
    if (!mounted) return;
    idleTracker.updateTimeout(Duration(seconds: seconds));
    _idleTimer?.cancel();
    if (idleTracker.isEnabled) {
      for (final directory in openedDirs) {
        final sessionID = directory.tempKeyID;
        if (sessionID != null) idleTracker.touch(sessionID);
      }
      _idleTimer = Timer.periodic(
        idleCheckInterval ?? const Duration(seconds: 1),
        (_) => unawaited(lockExpiredRoots()),
      );
    }
  }

  void touchCurrentRoot() {
    final sessionID = currentDir?.tempKeyID;
    if (sessionID != null) {
      idleTracker.touch(sessionID);
      _lastIdleAutoLockSummary = null;
    }
  }

  void cancelIdleTimer() {
    _idleTimer?.cancel();
    idleTracker.clear();
  }

  // Overrides WidgetsBindingObserver.didChangeAppLifecycleState
  // (resolved at mixin application site)
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(lockEligibleRoots(requireBackgroundPreference: true));
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _showPendingAutoLockSummary();
    }
  }

  // ── Locking logic ─────────────────────────────────────────────────

  Future<void> lockExpiredRoots() async {
    final expired = idleTracker.expiredSessionIDs();
    if (expired.isEmpty) {
      _lastIdleAutoLockSummary = null;
      return;
    }
    await lockEligibleRoots(sessionIDs: expired);
    final summary = _pendingAutoLockSummary;
    if (summary == null || summary == _lastIdleAutoLockSummary) return;
    _lastIdleAutoLockSummary = summary;
    _showPendingAutoLockSummary();
  }

  Future<void> lockEligibleRoots({
    Set<String>? sessionIDs,
    bool requireBackgroundPreference = false,
  }) async {
    if ((requireBackgroundPreference && !_autoLockOnBackground) ||
        _isAutoLocking) {
      return;
    }
    _isAutoLocking = true;
    var lockedCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    try {
      for (final directory in List<EncryptedDirectory>.from(openedDirs)) {
        final sessionID = directory.tempKeyID;
        if (sessionID == null) continue;
        if (sessionIDs != null && !sessionIDs.contains(sessionID)) continue;
        try {
          await runRootCloseOperation(sessionID, () async {
            if (!isCurrentDirectorySession(directory.path, sessionID)) return;
            final decision = rootCloseCoordinator.inspect(sessionID);

            if (decision.disposition ==
                    RootCloseDisposition.blockedByActiveWrites ||
                decision.disposition ==
                    RootCloseDisposition.blockedByUnsavedDocuments) {
              skippedCount++;
              return;
            }

            if (inProcessNotepadSessionID == sessionID) {
              await dismissInProcessNotepad();
            }

            if (inProcessImageViewerSessionID == sessionID) {
              await dismissInProcessImageViewer();
            }

            if (mounted) {
              replaceWithLockedDirectory(
                directory,
                EncryptedDirectory(
                  path: directory.path,
                  config: directory.config,
                  isVerified: false,
                  displayAlias: directory.displayAlias,
                ),
                expectedSessionID: sessionID,
              );
            }

            await Future<void>.delayed(Duration.zero);

            final nativeWindowCount =
                contentWindowBridge.nativeWindowCountForRoot(sessionID);
            if (nativeWindowCount != 0 &&
                !await contentWindowBridge.prepareAndCloseRootWindows(
                  sessionID,
                )) {
              failedCount++;
              return;
            }

            await disposeCurrentDirectoryPageSession(directory.path, sessionID);
            if (!isCurrentDirectorySession(directory.path, sessionID)) return;
            if (!closeSession(sessionID)) {
              failedCount++;
              return;
            }
            secureClipboard.removeSession(sessionID);
            rootCloseCoordinator.releaseRoot(sessionID);
            idleTracker.remove(sessionID);
            lockedCount++;
          });
        } on StateError catch (_) {
          skippedCount++;
        } on FormatException catch (_) {
          failedCount++;
        } catch (error) {
          failedCount++;
        }
      }
    } finally {
      _isAutoLocking = false;
    }
    if (!mounted) return;
    final strings = AppLocalizations.of(context)!;
    final messages = <String>[];
    if (lockedCount > 0) {
      messages.add(strings.autoLockSummaryLocked(lockedCount));
    }
    if (skippedCount > 0) {
      messages.add(strings.autoLockSummarySkipped(skippedCount));
    }
    if (failedCount > 0) {
      messages.add(strings.autoLockSummaryFailed(failedCount));
    }
    if (messages.isNotEmpty) {
      _pendingAutoLockSummary = messages.join(strings.messageListSeparator);
    }
  }

  bool isCurrentDirectorySession(String path, String sessionID) {
    final current = currentDir;
    return (current?.path == path && current?.tempKeyID == sessionID) ||
        openedDirs.any(
          (directory) =>
              directory.path == path && directory.tempKeyID == sessionID,
        );
  }

  Future<void> dismissInProcessNotepad() async {
    if (inProcessNotepadSessionID == null) return;
    Navigator.of(context).pop();
  }

  Future<void> dismissInProcessImageViewer() async {
    if (inProcessImageViewerSessionID == null) return;
    Navigator.of(context).pop();
  }

  Future<T> runRootCloseOperation<T>(
    String sessionID,
    Future<T> Function() operation,
  ) async {
    final previous = _rootCloseTails[sessionID];
    final completion = Completer<void>();
    _rootCloseTails[sessionID] = completion.future;
    if (previous != null) await previous;
    try {
      return await operation();
    } finally {
      completion.complete();
      if (identical(_rootCloseTails[sessionID], completion.future)) {
        _rootCloseTails.remove(sessionID);
      }
    }
  }

  Future<void> disposeCurrentDirectoryPageSession(
    String path,
    String sessionID,
  ) async {
    final current = currentDir;
    if (current?.path != path || current?.tempKeyID != sessionID) return;
    final session = pageSession;
    pageSession = null;
    pageGeneration++;
    isLoadingMore = false;
    isLoading = false;
    await session?.dispose();
  }

  // ── Internal helpers ──────────────────────────────────────────────

  void _showPendingAutoLockSummary() {
    final summary = _pendingAutoLockSummary;
    if (summary == null || !mounted) return;
    _pendingAutoLockSummary = null;
    ErrorHelper.showInfo(context, summary);
  }

  // ── Required from State (provided by State<T> base class) ─────────

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);
}
