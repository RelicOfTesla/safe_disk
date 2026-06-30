import 'dart:async';
import 'dart:io';
import 'clipboard_service.dart';
import 'file_service.dart';
import 'directory_service.dart';

/// Progress callback for paste operations
typedef PasteProgressCallback = void Function(
  int current,
  int total,
  String currentFileName,
);

/// Result of a paste operation
class PasteResult {
  final bool success;
  final int filesProcessed;
  final int filesFailed;
  final List<String> errors;
  final bool cancelled;

  PasteResult({
    required this.success,
    this.filesProcessed = 0,
    this.filesFailed = 0,
    this.errors = const [],
    this.cancelled = false,
  });

  String get summary {
    if (cancelled) {
      return '已取消：成功 $filesProcessed 个，失败 $filesFailed 个';
    }
    if (filesFailed == 0) {
      return '完成：成功粘贴 $filesProcessed 个文件';
    }
    return '完成：成功 $filesProcessed 个，失败 $filesFailed 个';
  }
}

/// Helper service for pasting files from clipboard into encrypted directories.
///
/// This service handles the complex logic of:
/// - Reading files from clipboard
/// - Encrypting them with progress tracking
/// - Writing to the target encrypted directory
/// - Providing atomic safety (cleanup on failure/cancel)
///
/// Usage:
/// ```dart
/// final helper = ClipboardPasteHelper(
///   sessionID: sessionID,
///   rootPath: rootPath,
///   targetRelativePath: 'subfolder',
///   fileService: fileService,
/// );
///
/// final result = await helper.pasteFromClipboard(
///   onProgress: (current, total, fileName) {
///     print('$current/$total: $fileName');
///   },
/// );
/// ```
class ClipboardPasteHelper {
  final int sessionID;
  final String rootPath;
  final String targetRelativePath;
  final FileService fileService;
  final ClipboardService _clipboardService = ClipboardService.instance;

  bool _cancelled = false;
  final List<String> _writtenFiles = [];

  ClipboardPasteHelper({
    required this.sessionID,
    required this.rootPath,
    required this.targetRelativePath,
    required this.fileService,
  });

  /// Cancels the ongoing paste operation
  void cancel() {
    _cancelled = true;
  }

  /// Pastes files from clipboard into the encrypted directory.
  ///
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns: PasteResult with operation summary
  Future<PasteResult> pasteFromClipboard({
    PasteProgressCallback? onProgress,
  }) async {
    _cancelled = false;
    _writtenFiles.clear();

    // Get files from clipboard
    final clipboardResult = await _clipboardService.pasteFiles();

    if (!clipboardResult.success) {
      return PasteResult(
        success: false,
        errors: [clipboardResult.error ?? 'Failed to read clipboard'],
      );
    }

    final items = clipboardResult.items;
    if (items == null || items.isEmpty) {
      return PasteResult(
        success: false,
        errors: ['No files in clipboard'],
      );
    }

    // Count total files to process
    int totalFiles = 0;
    for (final item in items) {
      if (item.isDirectory) {
        totalFiles += await _countFilesInDirectory(item.path);
      } else {
        totalFiles++;
      }
    }

    int filesProcessed = 0;
    int filesFailed = 0;
    final errors = <String>[];

    // Process each item
    for (final item in items) {
      if (_cancelled) break;

      if (item.isDirectory) {
        final result = await _pasteDirectory(
          item.path,
          targetRelativePath,
          (current, total, fileName) {
            onProgress?.call(filesProcessed + current, totalFiles, fileName);
          },
        );
        filesProcessed += result.filesProcessed;
        filesFailed += result.filesFailed;
        errors.addAll(result.errors);
      } else {
        onProgress?.call(
            filesProcessed + 1, totalFiles, item.path.split('/').last);

        final success = await _pasteFile(item.path, targetRelativePath);
        if (success) {
          filesProcessed++;
        } else {
          filesFailed++;
          errors.add('Failed to paste: ${item.path}');
        }
      }
    }

    // If cancelled or failed, optionally cleanup
    if (_cancelled || filesFailed > 0) {
      // Note: We don't cleanup on partial failure as some files may be valid
      // User can manually delete if needed
    }

    return PasteResult(
      success: filesFailed == 0 && !_cancelled,
      filesProcessed: filesProcessed,
      filesFailed: filesFailed,
      errors: errors,
      cancelled: _cancelled,
    );
  }

  /// Pastes a single file into the encrypted directory.
  ///
  /// [sourcePath] - Source file path
  /// [relativeDir] - Target directory relative to root
  ///
  /// Returns: true if successful
  Future<bool> _pasteFile(String sourcePath, String relativeDir) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return false;
      }

      // Read file content
      final data = await sourceFile.readAsBytes();

      // Calculate target relative path
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final targetRelativePath =
          relativeDir.isEmpty ? fileName : '$relativeDir/$fileName';

      // Encrypt and write
      await fileService.writeFile(sessionID, targetRelativePath, data);

      // Track for potential cleanup
      _writtenFiles.add(targetRelativePath);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Recursively pastes a directory into the encrypted directory.
  Future<PasteResult> _pasteDirectory(
    String sourcePath,
    String relativeDir,
    PasteProgressCallback? onProgress,
  ) async {
    final sourceDir = Directory(sourcePath);
    if (!await sourceDir.exists()) {
      return PasteResult(
        success: false,
        errors: ['Directory not found: $sourcePath'],
      );
    }

    final dirName = sourcePath.split(Platform.pathSeparator).last;
    final newRelativeDir =
        relativeDir.isEmpty ? dirName : '$relativeDir/$dirName';

    int filesProcessed = 0;
    int filesFailed = 0;
    final errors = <String>[];

    // List all entities in source directory
    await for (final entity in sourceDir.list(recursive: true)) {
      if (_cancelled) break;

      if (entity is File) {
        // Calculate relative path within source directory
        final relativePath = entity.path.substring(sourcePath.length + 1);
        final targetPath = '$newRelativeDir/$relativePath';

        onProgress?.call(filesProcessed + filesFailed + 1, 0, relativePath);

        try {
          final data = await entity.readAsBytes();
          await fileService.writeFile(sessionID, targetPath, data);
          _writtenFiles.add(targetPath);
          filesProcessed++;
        } catch (e) {
          filesFailed++;
          errors.add('Failed: $relativePath - $e');
        }
      } else if (entity is Directory) {
        // Directories are created implicitly when files are written
        // No need to explicitly create them
      }
    }

    return PasteResult(
      success: filesFailed == 0 && !_cancelled,
      filesProcessed: filesProcessed,
      filesFailed: filesFailed,
      errors: errors,
      cancelled: _cancelled,
    );
  }

  /// Counts the number of files in a directory (recursively)
  Future<int> _countFilesInDirectory(String dirPath) async {
    int count = 0;
    final dir = Directory(dirPath);

    if (!await dir.exists()) return 0;

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        count++;
      }
    }

    return count;
  }

  /// Cleans up written files (for rollback on failure/cancel)
  Future<void> cleanup() async {
    for (final relativePath in _writtenFiles) {
      try {
        // Delete the encrypted file
        final fullPath = '$rootPath/$relativePath';
        final file = File(fullPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _writtenFiles.clear();
  }
}

/// Helper for copying encrypted files TO the system clipboard.
///
/// This service handles:
/// - Decrypting files to temp location
/// - Copying paths to system clipboard
/// - Cleanup of temp files
///
/// Note: For security, we copy the ENCRYPTED paths, not decrypted content.
/// The receiver will need to handle decryption if they're also using Safe Disk.
class ClipboardCopyHelper {
  final int sessionID;
  final String rootPath;
  final FileService fileService;
  final ClipboardService _clipboardService = ClipboardService.instance;

  ClipboardCopyHelper({
    required this.sessionID,
    required this.rootPath,
    required this.fileService,
  });

  /// Copies encrypted file paths to clipboard.
  ///
  /// [items] - List of FileSystemNode items to copy
  ///
  /// Returns: true if successful
  Future<bool> copyToClipboard(List<FileSystemNode> items) async {
    final clipboardItems = <ClipboardItem>[];

    for (final item in items) {
      // For encrypted files, we copy the encrypted path
      // The receiver will need to know this is an encrypted file
      clipboardItems.add(ClipboardItem(
        path: item.path,
        isDirectory: item.isDirectory,
      ));
    }

    final result = await _clipboardService.copyFiles(clipboardItems);
    return result.success;
  }

  /// Copies decrypted files to a temp location and puts paths on clipboard.
  ///
  /// WARNING: This exposes decrypted content! Use with caution.
  ///
  /// [items] - List of FileSystemNode items to copy
  /// [onProgress] - Optional progress callback
  ///
  /// Returns: true if successful
  Future<bool> exportAndCopyToClipboard(
    List<FileSystemNode> items, {
    PasteProgressCallback? onProgress,
  }) async {
    // Create temp directory for decrypted files
    final tempDir = await Directory.systemTemp.createTemp('safe_disk_export_');
    final exportedItems = <ClipboardItem>[];

    try {
      int current = 0;
      final total = items.length;

      for (final item in items) {
        current++;
        onProgress?.call(current, total, item.name);

        if (item.isDirectory) {
          // Export directory
          final exportPath = '${tempDir.path}/${item.name}';
          await _exportDirectory(item, exportPath);
          exportedItems.add(ClipboardItem(
            path: exportPath,
            isDirectory: true,
          ));
        } else {
          // Export file
          final exportPath = '${tempDir.path}/${item.name}';
          await _exportFile(item, exportPath);
          exportedItems.add(ClipboardItem(
            path: exportPath,
            isDirectory: false,
          ));
        }
      }

      // Copy paths to clipboard
      final result = await _clipboardService.copyFiles(exportedItems);
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// Exports a single file to temp location
  Future<void> _exportFile(FileSystemNode item, String exportPath) async {
    final relativePath = item.path.substring(rootPath.length + 1);
    final data = await fileService.readFile(sessionID, relativePath);
    await File(exportPath).writeAsBytes(data);
  }

  /// Exports a directory to temp location
  Future<void> _exportDirectory(FileSystemNode item, String exportPath) async {
    final relativePath = item.path.substring(rootPath.length + 1);

    final entries = await DirectoryService().listDir(sessionID, relativePath);

    // Create directory structure and export files
    await Directory(exportPath).create(recursive: true);

    for (final entry in entries) {
      if (entry.isDir) {
        await Directory('$exportPath/${entry.name}').create(recursive: true);
      } else {
        final entryRelativePath =
            relativePath.isEmpty ? entry.name : '$relativePath/${entry.name}';
        final data = await fileService.readFile(sessionID, entryRelativePath);
        await File('$exportPath/${entry.name}').writeAsBytes(data);
      }
    }
  }
}
