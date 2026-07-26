import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../services/crypto_service.dart';
import '../services/directory_service.dart';
import '../services/drag_drop_controller.dart';
import '../services/file_service.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import '../widgets/entry_conflict_dialog.dart';
import '../widgets/progress_dialog.dart';

/// Import/Export and batch-delete operations extracted from HomePage.
///
/// The host State must implement the abstract getters/setters below.
mixin HomePageImportExportMixin {
  // -- Abstract interface --

  EncryptedDirectory? get currentDir;
  String? get currentPath;
  List<FileSystemNode> get items;
  bool get isLoading;
  set isLoading(bool value);
  bool get isSelectMode;
  set isSelectMode(bool value);
  Set<FileSystemNode> get selectedFiles;

  CryptoService get cryptoService;
  DirectoryService get directoryService;
  FileService get fileService;
  DragDropController get dragDropController;

  Future<String?> Function()? get selectDirectoryFn;
  Future<XFile?> Function(List<XTypeGroup>)? get selectFileFn;
  Future<FileSaveLocation?> Function(String)? get selectSaveLocationFn;
  Future<bool> Function(String)? get exportTargetExistsFn;

  bool validateSession();
  Future<bool> loadCurrentPath();

  BuildContext get context;
  bool get mounted;
  void setState(VoidCallback fn);

  // -- Implementation --

  Future<void> importFile() async {
    if (!validateSession()) return;

    final typeGroup = XTypeGroup(label: AppLocalizations.of(context)!.allFiles);
    final XFile? file = selectFileFn != null
        ? await selectFileFn!([typeGroup])
        : await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null || !mounted) return;

    await importFilePath(file.path, file.name);
  }

  Future<void> importFilePath(String sourcePath, String sourceName) async {
    if (!validateSession()) return;

    var destinationName = sourceName;
    var overwrite = false;
    if (items
        .any((item) => item.name.toLowerCase() == sourceName.toLowerCase())) {
      final existing = items.firstWhere(
        (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
      );
      final resolution = await showEntryConflictDialog(
        context: context,
        name: sourceName,
        isDirectory: false,
        operation: AppLocalizations.of(context)!.importOperation,
        allowReplace: !existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        destinationName = nextAvailableEntryName(
          originalName: sourceName,
          isDirectory: false,
          existingNames: items.map((item) => item.name),
          copyLabel: AppLocalizations.of(context)!.copySuffix,
        );
      } else {
        overwrite = true;
      }
    }

    try {
      setState(() => isLoading = true);

      final rootID = int.parse(currentDir!.tempKeyID!);
      final currentRelative =
          cryptoService.relativePathForRoot(rootID, currentPath!);
      final destination = currentRelative.isEmpty
          ? destinationName
          : '$currentRelative/$destinationName';
      await directoryService.importFile(
        rootID,
        sourcePath,
        destination,
        overwrite: overwrite,
      );
      await loadCurrentPath();

      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.fileImportCompleted(destinationName),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.importFileFailed,
          originalError: e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> importDirectory() async {
    if (!validateSession()) return;

    final sourcePath = selectDirectoryFn != null
        ? await selectDirectoryFn!()
        : await getDirectoryPath();
    if (sourcePath == null || !mounted) return;
    await importDirectoryPath(sourcePath);
  }

  Future<void> importDirectoryPath(String sourcePath) async {
    if (!validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    if (isPathInsideDirectory(sourcePath, currentDir!.path)) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.importDirectoryInsideCurrentRoot,
      );
      return;
    }

    var destPath = buildDirectoryImportDestination(
      rootPath: currentDir!.path,
      currentPath: currentPath!,
      sourcePath: sourcePath,
    );
    final sourceName = destPath.split('/').last;
    var overwrite = false;
    if (items.any(
      (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
    )) {
      final existing = items.firstWhere(
        (item) => item.name.toLowerCase() == sourceName.toLowerCase(),
      );
      final resolution = await showEntryConflictDialog(
        context: context,
        name: sourceName,
        isDirectory: true,
        operation: AppLocalizations.of(context)!.importOperation,
        allowReplace: existing.isDirectory,
      );
      if (resolution == EntryConflictResolution.cancel || !mounted) return;
      if (resolution == EntryConflictResolution.keepBoth) {
        final newName = nextAvailableEntryName(
          originalName: sourceName,
          isDirectory: true,
          existingNames: items.map((item) => item.name),
          copyLabel: AppLocalizations.of(context)!.copySuffix,
        );
        final separator = destPath.lastIndexOf('/');
        destPath = separator < 0
            ? newName
            : '${destPath.substring(0, separator + 1)}$newName';
      } else {
        overwrite = true;
      }
    }

    final rootID = int.parse(currentDir!.tempKeyID!);
    final cancellationToken = DirectoryTransferCancellationToken();
    var completedFiles = 0;
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.importDirectory,
      total: 100,
      status: strings.preparingImport,
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: strings.preparingCannotCancel);
        }
        return accepted;
      },
    );

    try {
      await directoryService.importDirectory(
        rootID,
        sourcePath,
        destPath,
        overwrite: overwrite,
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          completedFiles = progress.completedFiles;
          progressController.update(
            current: progress.percent,
            currentFileName: progress.currentFile,
            status: strings.importing,
          );
        },
      );
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (!mounted) return;
      await loadCurrentPath();
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          strings.directoryImportCompleted(completedFiles),
        );
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && cancellationToken.isCancelled) {
        ErrorHelper.showInfo(
          context,
          strings.transferCancelledWithUnfinishedState,
        );
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.importDirectoryFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> importDroppedCandidates(
    List<DragDropCandidate> candidates,
  ) async {
    if (!validateSession()) return;
    final directory = currentDir!;
    final requests = dragDropController.importRequests(
      candidates: candidates,
      rootPath: directory.path,
    );
    for (final request in requests) {
      if (!mounted || !validateSession()) return;
      switch (request.kind) {
        case DragDropImportKind.file:
          await importFilePath(
            request.path,
            File(request.path).uri.pathSegments.last,
          );
        case DragDropImportKind.directory:
          await importDirectoryPath(request.path);
      }
    }
  }

  Future<void> exportFile(FileSystemNode item) async {
    if (!validateSession()) return;
    if (!await confirmPlaintextExport(item)) return;

    final FileSaveLocation? saveLocation = selectSaveLocationFn != null
        ? await selectSaveLocationFn!(item.name)
        : await getSaveLocation(suggestedName: item.name);
    if (saveLocation == null || !mounted) return;
    final destination = await resolveExportDestination(
      saveLocation.path,
      operation: AppLocalizations.of(context)!.exportOperation,
    );
    if (destination == null || !mounted) return;

    try {
      await fileService.exportFile(
        item,
        destination.path,
        currentDir!.tempKeyID!,
        overwrite: destination.overwrite,
      );
      if (mounted) {
        ErrorHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.fileExportCompleted(destination.path),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> exportDirectory(FileSystemNode item) async {
    if (!validateSession()) return;
    final strings = AppLocalizations.of(context)!;
    if (!await confirmPlaintextExport(item)) return;

    final String? exportDir = selectDirectoryFn != null
        ? await selectDirectoryFn!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final String? dstDir;
    try {
      dstDir = await resolveDirectoryExportDestination(
        '$exportDir/${item.name}',
        operation: strings.exportOperation,
      );
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportDirectoryFailed,
          originalError: error.toString(),
          operation: 'resolve-directory-export-destination',
        );
      }
      return;
    }
    if (dstDir == null || !mounted) return;
    final cancellationToken = DirectoryTransferCancellationToken();
    late final ProgressController progressController;
    progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.exportDirectory,
      total: 100,
      status: strings.preparingExport,
      onCancel: () {
        final accepted = cancellationToken.cancel();
        if (!accepted) {
          progressController.update(status: strings.preparingCannotCancel);
        }
        return accepted;
      },
    );

    try {
      final progress = await directoryService.decryptDirectory(
        item.path,
        dstDir,
        currentDir!.tempKeyID!,
        cancellationToken: cancellationToken,
        onProgress: (jobProgress) {
          progressController.update(
            current: jobProgress.percent,
            currentFileName: jobProgress.currentFile,
            status: strings.exporting,
          );
        },
      );

      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }

      if (mounted) {
        if (progress.isCancelled) {
          ErrorHelper.showInfo(
            context,
            strings.transferCancelledWithUnfinishedState,
          );
        } else if (progress.isComplete &&
            !progress.isFailed &&
            !progress.isCancelled) {
          ErrorHelper.showSuccess(context,
              strings.directoryExportCompleted(progress.processedFiles));
        } else if (progress.isFailed) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.exportDirectoryFailed,
            originalError:
                progress.error ?? 'directory-export-failed-without-error',
          );
        }
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(
          context,
          strings.transferCancelledWithUnfinishedState,
        );
      } else if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportDirectoryFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<void> batchExport() async {
    if (!validateSession()) return;
    final strings = AppLocalizations.of(context)!;

    final String? exportDir = selectDirectoryFn != null
        ? await selectDirectoryFn!()
        : await getDirectoryPath();
    if (exportDir == null) return;
    if (!mounted) return;

    final jobs = <({FileSystemNode item, String path, bool overwrite})>[];
    for (final item in selectedFiles) {
      final destination = await resolveExportDestination(
        '$exportDir/${item.name}',
        operation: AppLocalizations.of(context)!.batchExportOperation,
      );
      if (destination == null || !mounted) return;
      jobs.add((
        item: item,
        path: destination.path,
        overwrite: destination.overwrite,
      ));
    }

    final totalFiles = jobs.length;
    final progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.batchExport,
      total: totalFiles,
      status: strings.preparingExport,
    );

    final startTime = DateTime.now();
    int successCount = 0;
    int failCount = 0;

    try {
      for (final job in jobs) {
        if (progressController.isCancelled) break;

        progressController.update(
          current: successCount + failCount + 1,
          currentFileName: job.item.name,
          status: strings.exporting,
        );
        progressController.estimateTimeRemaining(
          startTime: startTime,
          processedCount: successCount + failCount + 1,
        );

        try {
          await fileService.exportFile(
            job.item,
            job.path,
            currentDir!.tempKeyID!,
            overwrite: job.overwrite,
          );
          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }

      setState(() {
        isSelectMode = false;
        selectedFiles.clear();
      });

      if (mounted && !progressController.isCancelled) {
        final message = failCount > 0
            ? strings.batchExportCompleted(successCount, failCount)
            : strings.batchExportCompletedAll(successCount);
        ErrorHelper.showSuccess(context, message);
      } else if (mounted && progressController.isCancelled) {
        ErrorHelper.showInfo(
            context, strings.batchExportCancelled(successCount, failCount));
      }
    } catch (e) {
      if (mounted && !progressController.isCancelled) {
        progressController.close(context);
      }
      if (mounted) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.exportFileFailed,
          originalError: e.toString(),
        );
      }
    }
  }

  Future<({String path, bool overwrite})?> resolveExportDestination(
    String path, {
    required String operation,
  }) async {
    final destination = File(path);
    final exists = exportTargetExistsFn != null
        ? await exportTargetExistsFn!(path)
        : await destination.exists();
    if (!exists) {
      return (path: path, overwrite: false);
    }
    if (!mounted) return null;

    final name = baseName(destination.path);
    final resolution = await showEntryConflictDialog(
      context: context,
      name: name,
      isDirectory: false,
      operation: operation,
    );
    if (resolution == EntryConflictResolution.cancel || !mounted) return null;
    if (resolution == EntryConflictResolution.replace) {
      return (path: path, overwrite: true);
    }

    final parent = destination.parent;
    final existingNames = <String>[];
    await for (final entry in parent.list(followLinks: false)) {
      existingNames.add(baseName(entry.path));
    }
    final availableName = nextAvailableEntryName(
      originalName: name,
      isDirectory: false,
      existingNames: existingNames,
      copyLabel: AppLocalizations.of(context)!.copySuffix,
    );
    return (
      path: '${parent.path}${Platform.pathSeparator}$availableName',
      overwrite: false,
    );
  }

  Future<String?> resolveDirectoryExportDestination(
    String path, {
    required String operation,
  }) async {
    final destination = Directory(path);
    final exists = exportTargetExistsFn != null
        ? await exportTargetExistsFn!(path)
        : await destination.exists();
    if (!exists) return path;
    if (!mounted) return null;

    final resolution = await showEntryConflictDialog(
      context: context,
      name: baseName(destination.path),
      isDirectory: true,
      operation: operation,
      allowReplace: false,
    );
    if (resolution == EntryConflictResolution.cancel || !mounted) return null;

    final parent = destination.parent;
    final existingNames = <String>[];
    await for (final entry in parent.list(followLinks: false)) {
      existingNames.add(baseName(entry.path));
    }
    final availableName = nextAvailableEntryName(
      originalName: baseName(destination.path),
      isDirectory: true,
      existingNames: existingNames,
      copyLabel: AppLocalizations.of(context)!.copySuffix,
    );
    return '${parent.path}${Platform.pathSeparator}$availableName';
  }

  Future<void> batchDelete() async {
    if (!validateSession() || selectedFiles.isEmpty) return;
    final strings = AppLocalizations.of(context)!;
    final selected = Set<FileSystemNode>.from(selectedFiles);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmBatchDeletion),
        content: Text(strings.confirmBatchDeletionDescription(selected.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(strings.deleteSelected),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final progressController = ProgressHelper.showProgressDialog(
      context,
      title: strings.batchDelete,
      total: selected.length,
      status: strings.preparingDelete,
    );
    final succeeded = <FileSystemNode>{};
    final failed = <FileSystemNode>{};
    var processed = 0;
    for (final item in selected) {
      if (progressController.isCancelled) break;
      progressController.update(
        current: processed + 1,
        currentFileName: item.name,
        status: strings.deleting,
      );
      try {
        await cryptoService.deleteFileBySession(
          item.path,
          currentDir!.tempKeyID!,
        );
        succeeded.add(item);
      } catch (_) {
        failed.add(item);
      }
      processed++;
    }

    if (mounted && !progressController.isCancelled) {
      progressController.close(context);
    }
    if (!mounted) return;
    await loadCurrentPath();
    if (!mounted) return;
    setState(() {
      selectedFiles.removeAll(succeeded);
      isSelectMode = selectedFiles.isNotEmpty;
    });

    if (progressController.isCancelled) {
      ErrorHelper.showInfo(
        context,
        strings.batchDeleteCancelled(succeeded.length, selectedFiles.length),
      );
    } else if (failed.isNotEmpty) {
      ErrorHelper.showError(
        context,
        errorType: ErrorType.deleteFileFailed,
        originalError: 'batch-delete-failed',
        operation: 'batch-delete',
      );
    } else {
      ErrorHelper.showSuccess(
          context, strings.batchDeleteCompleted(succeeded.length));
    }
  }

  String baseName(String path) {
    return path.replaceAll('\\', '/').split('/').last;
  }

  Future<bool> confirmPlaintextExport(FileSystemNode item) async {
    final strings = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmPlaintextExport),
        content: Text(strings.confirmPlaintextExportDescription(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.continueExport),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}
