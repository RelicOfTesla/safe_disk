import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../models/secure_image_policy.dart';
import '../models/text_file_policy.dart';
import '../services/content_window_host_bridge.dart';
import '../services/crypto_service.dart';
import '../services/document_session_broker.dart';
import '../services/file_service.dart';
import '../services/secure_notepad_policy.dart';
import '../services/settings_service.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/secure_image_viewer.dart';
import '../widgets/secure_notepad.dart';

/// File-opening subsystem extracted from HomePage.
///
/// Handles: opening notepads, image viewers (in-process and new-window),
/// and the file-item dispatch logic.
///
/// The host State must provide the abstract getters/setters and
/// methods declared below.
mixin HomePageFileOpeningMixin {
  // -- Abstract interface (implemented by _HomePageState) --

  EncryptedDirectory? get currentDir;
  CryptoService get cryptoService;
  SettingsService get settingsService;
  DocumentSessionBroker get documentBroker;
  ContentWindowHostBridge get contentWindowBridge;
  FileService get fileService;
  String? get currentPath;

  String? inProcessNotepadSessionID;
  String? inProcessImageViewerSessionID;

  Future<bool> loadCurrentPath();
  void touchCurrentRoot();
  void navigateToDirectory(String path);

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  // -- File opening --

  void openItem(FileSystemNode item) {
    if (item.isDirectory) {
      navigateToDirectory(item.path);
      return;
    }
    if (isSupportedImageFormat(item.extension)) {
      unawaited(openImageViewer(item));
    } else {
      openNotepad(item);
    }
  }

  Future<void> openNotepad(FileSystemNode item) async {
    final directory = currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    final settings = await Future.wait<Object>([
      settingsService.getNotepadAutoSaveSeconds(),
      settingsService.getNotepadDefaultReadOnly(),
      settingsService.getNotepadDefaultMonitorClipboard(),
    ]);
    final autoSaveSeconds = settings[0] as int;
    final isZeroByte = item.size != null && item.size == 0;
    final initiallyReadOnly = isZeroByte
        ? false
        : settings[1] as bool || shouldOpenFallbackTextReadOnly(item.name);
    final initiallyMonitorClipboard = settings[2] as bool;
    if (!mounted || currentDir?.tempKeyID != directory!.tempKeyID) return;
    try {
      final lease = documentBroker.open(
        rootSessionID: directory.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureNotepadContentBytes,
      );
      inProcessNotepadSessionID = directory.tempKeyID;
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SecureNotepad(
              tempKeyID: directory.tempKeyID!,
              file: EncryptedFile(
                name: item.name,
                encryptedPath: item.path,
                modifiedTime: DateTime.now(),
              ),
              cryptoService: cryptoService,
              autoSaveInterval: Duration(seconds: autoSaveSeconds),
              initiallyReadOnly: initiallyReadOnly,
              initiallyMonitorClipboard: initiallyMonitorClipboard,
              onSaved: () => loadCurrentPath(),
              onActivity: touchCurrentRoot,
              documentBroker: documentBroker,
              documentLease: lease,
            ),
          ),
        );
      } finally {
        inProcessNotepadSessionID = null;
      }
    } on DocumentContentSizeUnknown catch (_) {
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } on DocumentContentLimitExceeded catch (_) {
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!
              .notepadFileTooLarge(kSecureNotepadContentLimitLabel),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  Future<void> openNotepadInNewWindow(FileSystemNode item) async {
    final directory = currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    DocumentLease? lease;
    try {
      final localePreference = await settingsService.getLocale();
      if (!mounted) return;
      lease = documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureNotepadContentBytes,
      );
      if (await contentWindowBridge.openNotepad(
        lease,
        localePreference: localePreference,
      )) {
        return;
      }
      documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.nativeContentWindowUnavailable,
      );
      await openNotepad(item);
    } on DocumentContentSizeUnknown catch (_) {
      if (lease != null) documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } on DocumentContentLimitExceeded catch (_) {
      if (lease != null) documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!
              .notepadFileTooLarge(kSecureNotepadContentLimitLabel),
        );
      }
    } catch (error) {
      if (lease != null) documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }

  Future<void> openImageViewer(FileSystemNode item) async {
    if (item.isDirectory) return;
    final sessionID = currentDir?.tempKeyID;
    if (sessionID == null) return;
    inProcessImageViewerSessionID = sessionID;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SecureImageViewer(
            tempKeyID: currentDir!.tempKeyID!,
            file: EncryptedFile(
              name: item.name,
              encryptedPath: item.path,
              originalSize: item.size,
              modifiedTime: DateTime.now(),
            ),
            cryptoService: cryptoService,
            directoryPath: currentPath,
            fileService: fileService,
          ),
        ),
      );
    } finally {
      inProcessImageViewerSessionID = null;
    }
  }

  Future<void> openImageViewerInNewWindow(FileSystemNode item) async {
    final directory = currentDir;
    if (item.isDirectory || directory?.tempKeyID == null) return;
    DocumentLease? lease;
    try {
      final localePreference = await settingsService.getLocale();
      if (!mounted) return;
      lease = documentBroker.open(
        rootSessionID: directory!.tempKeyID!,
        path: item.path,
        displayName: item.name,
        knownContentBytes: item.size,
        maxContentBytes: kMaxSecureImageEncodedBytes,
        readOnly: true,
      );
      if (await contentWindowBridge.openImage(
        lease,
        localePreference: localePreference,
      )) {
        return;
      }
      documentBroker.close(lease.token);
      lease = null;
      if (!mounted) return;
      ErrorHelper.showInfo(
        context,
        AppLocalizations.of(context)!.nativeContentWindowUnavailable,
      );
      await openImageViewer(item);
    } on DocumentContentSizeUnknown catch (_) {
      if (lease != null) documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showInfo(
          context,
          AppLocalizations.of(context)!.contentFileSizeUnknown,
        );
      }
    } catch (error) {
      if (lease != null) documentBroker.close(lease.token);
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.operationFailed,
          originalError: error.toString(),
        );
      }
    }
  }
}
