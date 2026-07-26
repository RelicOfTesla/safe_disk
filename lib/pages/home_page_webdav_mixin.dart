import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../services/crypto_service.dart';
import '../services/settings_service.dart';
import '../services/file_service.dart';
import '../services/webdav_service.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/webdav_sessions_dialog.dart';

/// WebDAV subsystem extracted from HomePage.
///
/// Handles: WebDAV session lifecycle, mount/unmount, session badges,
/// expose-to-third-party flow, and global enable/disable toggle.
///
/// The host State must provide the abstract getters/setters below.
mixin HomePageWebDavMixin {
  // -- Abstract interface (implemented by _HomePageState) --

  EncryptedDirectory? get currentDir;
  List<EncryptedDirectory> get openedDirs;
  CryptoService get cryptoService;
  SettingsService get settingsService;
  WebDavService get webDavService;

  // State owned by the mixin — host must NOT redeclare these.
  Map<int, int> get webDavSessionCounts;
  Map<String, String> get webDavMountOperations;
  int get webDavOperationSequence;
  set webDavOperationSequence(int value);
  bool get webDavEnabled;
  set webDavEnabled(bool value);

  // Cross-mixin / host methods the mixin calls.
  bool isCurrentDirectorySession(String path, String sessionID);
  bool validateSession();

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  // -- Implementation --

  Future<void> loadWebDavEnabled() async {
    final enabled = await settingsService.getWebDavEnabled();
    if (mounted) setState(() => webDavEnabled = enabled);
  }

  Future<void> exposeToThirdParty(FileSystemNode item) async {
    if (!webDavEnabled) {
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.webDavDisabledMessage,
      );
      return;
    }
    if (!validateSession()) return;
    final directory = currentDir;
    final activeSessionID = directory?.tempKeyID;
    if (directory == null || activeSessionID == null) return;
    final rootID = int.tryParse(activeSessionID);
    if (rootID == null) return;

    final confirmed = await confirmWebDavReadOnlyExposure(
      context: context,
      displayName: item.name,
    );
    if (!confirmed || !mounted) return;
    final options = await chooseWebDavOpenOptions(
        context: context, webdavService: webDavService);
    if (options == null || !mounted) return;
    if (!isCurrentDirectorySession(directory.path, activeSessionID)) return;

    try {
      final session = webDavService.open(
        rootID: rootID,
        logicalPath: item.path,
        displayName: item.name,
        authMode: options.authMode,
        credentialVisibility: options.credentialVisibility,
        sessionLifetime: options.sessionLifetime,
        tls: options.tls,
        writePolicy: options.writePolicy,
      );
      if (!mounted ||
          !isCurrentDirectorySession(directory.path, activeSessionID)) {
        webDavService.close(session.id);
        return;
      }
      await showWebDavCredentialsDialog(context: context, session: session);
      await refreshWebDavSessionCount(rootID);
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/open',
        );
      }
    }
  }

  Future<void> showWebDavSessions() async {
    if (!webDavEnabled) return;
    final directory = currentDir;
    final activeSessionID = directory?.tempKeyID;
    if (directory == null || activeSessionID == null) return;
    final rootID = int.tryParse(activeSessionID);
    if (rootID == null) return;
    final sessions = await listWebDavSessions(rootID, reportErrors: true);
    if (sessions == null ||
        !mounted ||
        !isCurrentDirectorySession(directory.path, activeSessionID)) {
      return;
    }
    await setWebDavSessionCount(rootID, sessions.length);
    if (!mounted) return;
    await showWebDavSessionsDialog(
      context: context,
      sessions: sessions,
      onRevoke: revokeWebDavSession,
      onMount: mountWebDavSession,
      onUnmount: unmountWebDavSession,
      onCancelMount: cancelWebDavMount,
      onReveal: revealWebDavSession,
      onRefresh: () => refreshWebDavSessionsForDialog(rootID),
    );
  }

  Future<bool> revokeWebDavSession(WebDavSessionStatus session) async {
    try {
      webDavService.close(session.id);
      await refreshWebDavSessionCount(session.rootID);
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.webDavSessionRevoked,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/close',
        );
      }
      return false;
    }
  }

  Future<bool> runWebDavMountOperation(
    WebDavSessionStatus session, {
    required bool mount,
  }) async {
    final operationID =
        'webdav-${++webDavOperationSequence}-${DateTime.now().microsecondsSinceEpoch}';
    webDavMountOperations[session.id] = operationID;
    try {
      if (mount) {
        webDavService.startMount(
          operationID: operationID,
          sessionID: session.id,
        );
      } else {
        webDavService.startUnmount(
          operationID: operationID,
          sessionID: session.id,
        );
      }
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final result = webDavService.pollOperation(operationID);
        final state = result['state'];
        if (state == 'running') continue;
        if (state == 'cancelled') return true;
        final response = result['response'];
        if (response is! Map || response['success'] != true) {
          throw StateError(
            response is Map
                ? response['error']?.toString() ?? 'webdav-operation-failed'
                : 'webdav-operation-response-missing',
          );
        }
        if (mounted && mount) {
          final data = response['data'];
          final path = data is Map ? data['mount_path']?.toString() : null;
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.webDavMountedAt(path ?? ''),
          );
        } else if (mounted) {
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.webDavUnmounted,
          );
        }
        return true;
      }
      return false;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: mount ? 'webdav/mount' : 'webdav/unmount',
        );
      }
      return false;
    } finally {
      try {
        webDavService.cancelOperation(operationID);
      } catch (_) {}
      webDavMountOperations.remove(session.id);
    }
  }

  Future<bool> mountWebDavSession(WebDavSessionStatus session) {
    return runWebDavMountOperation(session, mount: true);
  }

  Future<bool> unmountWebDavSession(WebDavSessionStatus session) {
    return runWebDavMountOperation(session, mount: false);
  }

  Future<bool> cancelWebDavMount(WebDavSessionStatus session) async {
    final operationID = webDavMountOperations[session.id];
    if (operationID == null) return false;
    try {
      return webDavService.cancelOperation(operationID);
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/cancel-mount',
        );
      }
      return false;
    }
  }

  Future<bool> revealWebDavSession(WebDavSessionStatus session) async {
    try {
      final opened = webDavService.reveal(session.id, rootID: session.rootID);
      if (mounted) {
        await showWebDavCredentialsDialog(context: context, session: opened);
      }
      return true;
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/reveal',
        );
      }
      return false;
    }
  }

  Future<void> refreshWebDavSessionCount(int rootID) async {
    final sessions = await listWebDavSessions(rootID, reportErrors: false);
    if (sessions != null) await setWebDavSessionCount(rootID, sessions.length);
  }

  Future<List<WebDavSessionStatus>?> refreshWebDavSessionsForDialog(
    int rootID,
  ) async {
    final sessions = await listWebDavSessions(rootID, reportErrors: true);
    if (sessions != null) await setWebDavSessionCount(rootID, sessions.length);
    return sessions;
  }

  Future<void> setWebDavSessionCount(int rootID, int count) async {
    if (!mounted || webDavSessionCounts[rootID] == count) return;
    setState(() => webDavSessionCounts[rootID] = count);
  }

  Future<void> setWebDavEnabled(bool enabled) async {
    if (mounted) setState(() => webDavEnabled = enabled);
    if (enabled) return;

    for (final operationID in webDavMountOperations.values.toList()) {
      try {
        webDavService.cancelOperation(operationID);
      } catch (_) {}
    }

    for (final directory in List<EncryptedDirectory>.from(openedDirs)) {
      final sessionID = directory.tempKeyID;
      final rootID = sessionID == null ? null : int.tryParse(sessionID);
      if (rootID == null) continue;
      final sessions = await listWebDavSessions(rootID, reportErrors: false);
      if (sessions == null) continue;
      await revokeWebDavSessionsForRoot(rootID, sessions: sessions);
      final remaining = await listWebDavSessions(rootID, reportErrors: false);
      if (mounted) {
        setState(() => webDavSessionCounts[rootID] =
            remaining?.length ?? sessions.length);
      }
    }
  }

  Future<void> revokeWebDavSessionsForRoot(
    int rootID, {
    List<WebDavSessionStatus>? sessions,
  }) async {
    final active = sessions ??
        await listWebDavSessions(
          rootID,
          reportErrors: false,
        );
    if (active == null) return;
    for (final session in active) {
      try {
        webDavService.close(session.id);
      } catch (_) {}
    }
  }

  Future<List<WebDavSessionStatus>?> listWebDavSessions(
    int rootID, {
    required bool reportErrors,
  }) async {
    try {
      final result = webDavService.list(rootID: rootID);
      return result;
    } catch (error) {
      if (reportErrors && mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
          operation: 'webdav/list',
        );
      }
      return null;
    }
  }
}
