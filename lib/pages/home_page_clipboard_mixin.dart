import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/batch_operation_result.dart';
import '../models/cryption_config.dart';
import '../services/crypto_service.dart';
import '../services/file_service.dart';
import '../services/secure_clipboard_service.dart';
import '../services/secure_entry_move_service.dart';
import '../services/settings_service.dart';
import '../utils/error_diagnostics.dart';
import '../utils/error_messages.dart';
import '../l10n/error_localizations.dart';
import '../widgets/directory_background_actions.dart';
import '../widgets/batch_operation_result_dialog.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/entry_conflict_dialog.dart';
import '../widgets/file_browser.dart';
import '../widgets/file_item_actions.dart';

/// Clipboard and file-operation subsystem extracted from HomePage.
///
/// Handles: copy/cut/paste/rename/delete, keyboard selection,
/// and entry creation.
///
/// The host State must provide the abstract getters/setters and
/// methods declared below.
mixin HomePageClipboardMixin {
  // -- Abstract interface (implemented by _HomePageState) --

  EncryptedDirectory? get currentDir;
  CryptoService get cryptoService;
  FileService get fileService;
  SettingsService get settingsService;
  SecureClipboardService get secureClipboard;
  SecureEntryMoveService get secureEntryMover;
  String? get currentPath;
  List<FileSystemNode> get items;
  Set<FileSystemNode> get selectedFiles;
  FileSystemNode? get keyboardTarget;
  set keyboardTarget(FileSystemNode? value);
  String? get keyboardSelectionAnchorPath;
  set keyboardSelectionAnchorPath(String? value);
  bool get isSelectMode;
  set isSelectMode(bool value);
  bool get isLoading;
  set isLoading(bool value);
  GlobalKey<FileBrowserState> get fileBrowserKey;

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  bool validateSession();
  Future<bool> loadCurrentPath();
  void touchCurrentRoot();

  // -- Clipboard source operations --

  void copyItem(FileSystemNode item) {
    if (!validateSession()) return;
    secureClipboard.copy(SecureClipboardEntry(
      sourcePath: item.path,
      sourceSessionID: currentDir!.tempKeyID!,
      name: item.name,
      isDirectory: item.isDirectory,
    ));
    setState(() {});
    ErrorHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.copiedForPaste(item.name),
    );
  }

  void cutItem(FileSystemNode item) {
    if (!validateSession()) return;
    secureClipboard.cut(SecureClipboardEntry(
      sourcePath: item.path,
      sourceSessionID: currentDir!.tempKeyID!,
      name: item.name,
      isDirectory: item.isDirectory,
    ));
    setState(() {});
    ErrorHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.cutForMove(item.name),
    );
  }

  void copySelected({required bool move}) {
    if (selectedFiles.isEmpty) return;
    for (final item in selectedFiles) {
      if (move) {
        cutItem(item);
      } else {
        copyItem(item);
      }
    }
  }

  void copyKeyboardTarget({required bool move}) {
    final target = selectedFiles.length == 1
        ? selectedFiles.single
        : keyboardTarget;
    if (target != null && items.any((item) => item.path == target.path)) {
      copySelected(move: move);
    }
  }

  // -- Keyboard selection --

  void moveKeyboardTarget(
    int direction, {
    required bool extendSelection,
    bool vertical = false,
  }) {
    if (items.isEmpty) return;
    final currentTarget = keyboardTarget;
    final currentIndex = currentTarget != null
        ? items.indexWhere((item) => item.path == currentTarget.path)
        : -1;
    int nextIndex;
    if (currentIndex < 0) {
      nextIndex = direction > 0 ? 0 : items.length - 1;
    } else {
      nextIndex = currentIndex + direction;
      if (nextIndex < 0) nextIndex = items.length - 1;
      if (nextIndex >= items.length) nextIndex = 0;
    }
    final target = items[nextIndex];
    setState(() {
      keyboardTarget = target;
      if (!extendSelection) {
        keyboardSelectionAnchorPath = target.path;
        selectedFiles.clear();
        return;
      }
      final anchorPath = keyboardSelectionAnchorPath ?? target.path;
      final anchorIndex =
          items.indexWhere((item) => item.path == anchorPath);
      final start = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? anchorIndex : nextIndex);
      final end = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? nextIndex : anchorIndex);
      selectedFiles
        ..clear()
        ..addAll(items.sublist(start, end + 1));
      isSelectMode = selectedFiles.isNotEmpty;
    });
  }

  void moveKeyboardTargetToEdge({
    required bool end,
    required bool extendSelection,
  }) {
    if (items.isEmpty) return;
    final nextIndex = end ? items.length - 1 : 0;
    final target = items[nextIndex];
    setState(() {
      keyboardTarget = target;
      if (!extendSelection) {
        keyboardSelectionAnchorPath = target.path;
        return;
      }
      final anchorPath = keyboardSelectionAnchorPath ?? target.path;
      final anchorIndex =
          items.indexWhere((item) => item.path == anchorPath);
      final start = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? anchorIndex : nextIndex);
      final finish = anchorIndex < 0
          ? nextIndex
          : (anchorIndex < nextIndex ? nextIndex : anchorIndex);
      selectedFiles
        ..clear()
        ..addAll(items.sublist(start, finish + 1));
      isSelectMode = selectedFiles.isNotEmpty;
    });
  }

  void toggleKeyboardTargetSelection() {
    final target = keyboardTarget;
    if (target == null) return;
    setState(() {
      isSelectMode = true;
      if (selectedFiles.contains(target)) {
        selectedFiles.remove(target);
      } else {
        selectedFiles.add(target);
      }
    });
  }

  void selectAllItems() {
    if (items.isEmpty) return;
    setState(() {
      selectedFiles.addAll(items);
      isSelectMode = true;
    });
  }

  void cancelSelection() {
    if (!isSelectMode && selectedFiles.isEmpty) return;
    setState(() {
      isSelectMode = false;
      selectedFiles.clear();
      keyboardSelectionAnchorPath = null;
    });
  }

  // -- Create entry --

  Future<void> createEntry({required bool isDirectory}) async {
    if (!validateSession()) return;
    final name = await showCreateEntryDialog(
      context: context,
      isDirectory: isDirectory,
    );
    if (name == null || !mounted) return;
    if (items.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.operationFailed,
        originalError: 'entry-already-exists:$name',
        operation: 'create-entry',
      );
      return;
    }

    final path = joinLogicalPath(currentPath!, name);
    try {
      if (isDirectory) {
        await cryptoService.createDirectoryBySession(
          path,
          currentDir!.tempKeyID!,
        );
      } else {
        await cryptoService.createEmptyFileBySession(
          path,
          currentDir!.tempKeyID!,
        );
      }
      await loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          isDirectory
              ? AppLocalizations.of(context)!.directoryCreated(name)
              : AppLocalizations.of(context)!.fileCreated(name),
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

  // -- Paste --

  Future<void> pasteClipboard({String? targetDirectory}) async {
    if (!validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    final entries =
        List<SecureClipboardEntry>.from(secureClipboard.entries);
    if (entries.isEmpty) {
      ErrorHelper.showInfo(
        context,
        strings.noEncryptedClipboardEntries,
      );
      return;
    }

    final destinationDirectory = targetDirectory ?? currentPath!;
    final destinationSessionID = currentDir!.tempKeyID!;
    var successCount = 0;
    var cancelled = false;
    var processedCount = 0;
    final failures = <BatchOperationFailure>[];
    final conflictSession = EntryConflictSession();
    String? lastDestinationName;
    try {
      final destinationItems = List<FileSystemNode>.from(
        destinationDirectory == currentPath
            ? items
            : await fileService.listCurrentDirectory(destinationDirectory),
      );
      if (!mounted) return;
      for (final entry in entries) {
        if (entry.isDirectory &&
            entry.sourceSessionID == destinationSessionID &&
            isSameOrDescendantPath(
                destinationDirectory, entry.sourcePath)) {
          processedCount++;
          failures.add(BatchOperationFailure(
            name: entry.name,
            reason: strings.cannotPasteDirectoryIntoItself,
          ));
          continue;
        }
        var destinationName = entry.name;
        var overwrite = false;
        FileSystemNode? matching;
        for (final item in destinationItems) {
          if (item.name.toLowerCase() == destinationName.toLowerCase()) {
            matching = item;
            break;
          }
        }
        if (matching != null) {
          final destinationPath =
              joinLogicalPath(destinationDirectory, destinationName);
          var sameEntry = false;
          if (entry.sourceSessionID == currentDir!.tempKeyID) {
            final rootID = int.parse(entry.sourceSessionID);
            sameEntry = cryptoService.relativePathForRoot(
                  rootID,
                  entry.sourcePath,
                ) ==
                cryptoService.relativePathForRoot(rootID, destinationPath);
          }
          if (!mounted) return;
          final allowReplace =
              !sameEntry && matching.isDirectory == entry.isDirectory;
          var resolution = conflictSession.automaticResolution(
            allowReplace: allowReplace,
          );
          resolution ??= await showEntryConflictDialog(
            context: context,
            name: destinationName,
            isDirectory: entry.isDirectory,
            operation: entries.length == 1
                ? AppLocalizations.of(context)!.pasteOperation
                : AppLocalizations.of(context)!.batchPasteOperation,
            allowReplace: allowReplace,
            allowApplyToAll: entries.length > 1,
          );
          resolution = conflictSession.apply(resolution);
          if (resolution == EntryConflictResolution.cancel || !mounted) {
            cancelled = true;
            break;
          }
          if (resolution == EntryConflictResolution.keepBoth) {
            destinationName = nextAvailableEntryName(
              originalName: entry.name,
              isDirectory: entry.isDirectory,
              existingNames: destinationItems.map((item) => item.name),
              copyLabel: AppLocalizations.of(context)!.copySuffix,
            );
          } else {
            overwrite = true;
          }
        }

        try {
          if (mounted) setState(() => isLoading = true);
          final destinationPath =
              joinLogicalPath(destinationDirectory, destinationName);
          if (entry.isMove) {
            await secureEntryMover.move(
              entry: entry,
              destinationPath: destinationPath,
              destinationSessionID: destinationSessionID,
              overwrite: overwrite,
            );
          } else {
            await cryptoService.copyBySession(
              sourcePath: entry.sourcePath,
              sourceSessionID: entry.sourceSessionID,
              destinationPath: destinationPath,
              destinationSessionID: destinationSessionID,
              overwrite: overwrite,
            );
          }
          secureClipboard.remove(entry);
          if (matching != null && overwrite) {
            destinationItems.remove(matching);
          }
          destinationItems.add(FileSystemNode(
            name: destinationName,
            path: destinationPath,
            isDirectory: entry.isDirectory,
          ));
          successCount++;
          processedCount++;
          lastDestinationName = destinationName;
        } catch (error) {
          processedCount++;
          failures.add(BatchOperationFailure(
            name: entry.name,
            reason: clipboardMoveFailureReason(strings, error),
          ));
        } finally {
          if (mounted) setState(() => isLoading = false);
        }
      }
      if (destinationDirectory == currentPath) await loadCurrentPath();
      if (!mounted) return;
      setState(() {});
      if (entries.length > 1) {
        await showBatchOperationResultDialog(
          context: context,
          operation: entries.first.isMove
              ? strings.batchMove
              : strings.batchPaste,
          result: BatchOperationResult(
            total: entries.length,
            succeeded: successCount,
            skipped: 0,
            failures: failures,
            unprocessed: entries.length - processedCount,
            remaining: secureClipboard.entryCount,
            cancelled: cancelled,
          ),
        );
      } else if (successCount == 1) {
        ErrorHelper.showSuccess(
          context,
          entries.first.isMove
              ? strings.movedToDestination(lastDestinationName!)
              : strings.pastedToDestination(lastDestinationName!),
        );
      } else if (cancelled) {
        ErrorHelper.showInfo(
          context,
          strings.batchPasteCancelled(
            successCount,
            secureClipboard.entryCount,
          ),
        );
      } else if (failures.isNotEmpty) {
        if (entries.first.isMove) {
          await showBatchOperationResultDialog(
            context: context,
            operation: entries.first.isMove
                ? strings.batchMove
                : strings.batchPaste,
            result: BatchOperationResult(
              total: 1,
              succeeded: 0,
              skipped: 0,
              failures: failures,
              unprocessed: 0,
              remaining: secureClipboard.entryCount,
              cancelled: false,
            ),
          );
        } else {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.operationFailed,
            originalError: 'batch-paste-failed',
            operation: 'batch-paste',
          );
        }
      } else {
        ErrorHelper.showSuccess(
          context,
          entries.first.isMove
              ? strings.movedFiles(successCount)
              : strings.pastedFiles(successCount),
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
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String clipboardMoveFailureReason(
      AppLocalizations strings, Object error) {
    return switch (error) {
      SecureEntryMovePartialFailure() => strings.moveSourceDeleteFailed,
      _ => ErrorDiagnostics.sanitize(
          error.toString(),
          labels: strings.errorDiagnosticsLabels(),
        ),
    };
  }

  // -- Utilities --

  bool isSameOrDescendantPath(String candidate, String parent) {
    String normalize(String value) {
      final normalized = value.replaceAll('\\', '/');
      return normalized.endsWith('/') && normalized.length > 1
          ? normalized.substring(0, normalized.length - 1)
          : normalized;
    }

    final normalizedCandidate = normalize(candidate);
    final normalizedParent = normalize(parent);
    return normalizedCandidate == normalizedParent ||
        normalizedCandidate.startsWith('$normalizedParent/');
  }

  String joinLogicalPath(String directory, String name) {
    return directory.endsWith('/') ? '$directory$name' : '$directory/$name';
  }

  // -- Rename --

  Future<void> renameItem(FileSystemNode item) async {
    if (!validateSession()) return;
    final newName =
        await showRenameFileItemDialog(context: context, item: item);
    if (newName == null || newName == item.name || !mounted) return;

    final parentPath = File(item.path).parent.path;
    final newPath =
        parentPath == '/' ? '/$newName' : '$parentPath/$newName';
    try {
      await cryptoService.renameBySession(
        item.path,
        newPath,
        currentDir!.tempKeyID!,
      );
      await loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.renamedTo(newName),
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

  // -- Delete --

  Future<void> deleteFile(FileSystemNode item) async {
    if (item.isDirectory) return;
    final requireConfirmation =
        await settingsService.getConfirmBeforeDelete();
    if (!mounted) return;
    final confirm = requireConfirmation
        ? await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                AppLocalizations.of(dialogContext)!.confirmDeleteFile,
              ),
              content: Text(
                AppLocalizations.of(dialogContext)!
                    .confirmDeleteFileDescription(item.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child:
                      Text(AppLocalizations.of(dialogContext)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                  child:
                      Text(AppLocalizations.of(dialogContext)!.delete),
                ),
              ],
            ),
          )
        : true;

    if (confirm == true) {
      try {
        await cryptoService.deleteFileBySession(
          item.path,
          currentDir!.tempKeyID!,
        );
        loadCurrentPath();
        if (mounted) {
          ErrorHelper.showSuccess(
            context,
            AppLocalizations.of(context)!.fileDeleted,
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.deleteFileFailed,
            originalError: e.toString(),
          );
        }
      }
    }
  }
}
