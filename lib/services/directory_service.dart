import '../native/native_lib.dart';
import 'crypto_service.dart';

/// Service for directory operations.
///
/// **Architecture (Transfer V3)**:
/// - Uses rootID-based operations
/// - Directory export/import via V3 FFI functions
/// - Import/export runs in a worker isolate and only persists unfinished markers
class DirectoryService {
  NativeLib get _native => NativeLib.instance;
  final CryptoService _cryptoService = CryptoService();

  // ==================== Directory Listing ====================

  /// Lists directory entries.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [path] - Relative path to the directory
  /// Returns list of directory entries.
  Future<List<DirEntry>> listDir(int rootID, String path) async {
    return _cryptoService.listDir(rootID, path);
  }

  // ==================== Directory Export/Import ====================

  Future<void> importFile(
    int rootID,
    String srcPath,
    String destPath, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    await _native.secTransferV3ImportFileWithProgress(
      rootID,
      srcPath,
      destPath,
      (event) => onProgress?.call(_fromNativeProgress(event)),
      cancellationToken: cancellationToken?._native,
    );
  }

  /// Exports a directory from secure storage to normal filesystem.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [srcPath] - Relative path in secure storage
  /// [destPath] - Full path in normal filesystem
  Future<void> exportDirectory(
    int rootID,
    String srcPath,
    String destPath, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    await _native.secTransferV3ExportDirectoryWithProgress(
      rootID,
      srcPath,
      destPath,
      (event) => onProgress?.call(_fromNativeProgress(event)),
      cancellationToken: cancellationToken?._native,
    );
  }

  /// Imports a directory from normal filesystem to secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [srcPath] - Full path in normal filesystem
  /// [destPath] - Relative path in secure storage
  Future<void> importDirectory(
    int rootID,
    String srcPath,
    String destPath, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    await _native.secTransferV3ImportDirectoryWithProgress(
      rootID,
      srcPath,
      destPath,
      (event) => onProgress?.call(_fromNativeProgress(event)),
      cancellationToken: cancellationToken?._native,
    );
  }

  Future<void> exportFile(
    int rootID,
    String srcPath,
    String destPath, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    await _native.secTransferV3ExportFileWithProgress(
      rootID,
      srcPath,
      destPath,
      (event) => onProgress?.call(_fromNativeProgress(event)),
      cancellationToken: cancellationToken?._native,
    );
  }

  /// Lists unfinished import/export operation markers on this root.
  Future<List<Map<String, dynamic>>> listUnfinishedOperations(
      int rootID) async {
    return _native.secTransferV3ListUnfinished(rootID);
  }

  /// Cleans one unfinished import/export marker by operation ID.
  Future<void> cleanUnfinishedOperation(int rootID, String opID) async {
    _native.secTransferV3CleanUnfinished(rootID, opID);
  }

  Future<void> rerunUnfinishedOperation(
    int rootID,
    Map<String, dynamic> marker, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    final opID = _requiredMarkerString(marker, 'op_id');
    final type = _requiredMarkerString(marker, 'type');
    final entryKind = _requiredMarkerString(marker, 'entry_kind');
    final src = marker['src'] as String? ?? '';
    final dst = marker['dst'] as String? ?? '';
    if (entryKind != 'file' && entryKind != 'directory') {
      throw StateError('Unfinished operation $opID has invalid entry_kind');
    }
    if (type != 'import' && type != 'export') {
      throw StateError('Unfinished operation $opID has unsupported type');
    }
    if (type == 'import' && src.isEmpty) {
      throw StateError('Unfinished import $opID has no source path');
    }
    if (type == 'export' && dst.isEmpty) {
      throw StateError('Unfinished export $opID has no destination path');
    }
    if (entryKind == 'file' && dst.isEmpty) {
      throw StateError('Unfinished file operation $opID has no destination');
    }

    await cleanUnfinishedOperation(rootID, opID);
    if (type == 'import' && entryKind == 'file') {
      return importFile(rootID, src, dst,
          onProgress: onProgress, cancellationToken: cancellationToken);
    }
    if (type == 'import') {
      return importDirectory(rootID, src, dst,
          onProgress: onProgress, cancellationToken: cancellationToken);
    }
    if (entryKind == 'file') {
      return exportFile(rootID, src, dst,
          onProgress: onProgress, cancellationToken: cancellationToken);
    }
    return exportDirectory(rootID, src, dst,
        onProgress: onProgress, cancellationToken: cancellationToken);
  }

  String _requiredMarkerString(Map<String, dynamic> marker, String key) {
    final value = marker[key];
    if (value is! String || value.isEmpty) {
      throw StateError('Unfinished operation marker has no $key');
    }
    return value;
  }

  // ==================== Directory Management ====================

  /// Creates a directory in secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [path] - Relative path to create
  Future<void> createDir(int rootID, String path) async {
    _native.secMkdirAll(rootID, path);
  }

  Future<DirectoryTransferResult> decryptDirectory(
    String srcPath,
    String destPath,
    String tempKeyID, {
    void Function(DirectoryTransferProgress progress)? onProgress,
    DirectoryTransferCancellationToken? cancellationToken,
  }) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = _cryptoService.relativePathForRoot(rootID, srcPath);
    var completedFiles = 0;
    try {
      await exportDirectory(
        rootID,
        relativePath,
        destPath,
        onProgress: (progress) {
          completedFiles = progress.completedFiles;
          onProgress?.call(progress);
        },
        cancellationToken: cancellationToken,
      );
      return DirectoryTransferResult(
        isComplete: true,
        processedFiles: completedFiles,
      );
    } catch (e) {
      return DirectoryTransferResult(
        isComplete: false,
        isFailed: cancellationToken?.isCancelled != true,
        isCancelled: cancellationToken?.isCancelled == true,
        processedFiles: 0,
        error: e.toString(),
      );
    }
  }

  DirectoryTransferProgress _fromNativeProgress(TransferProgressEvent event) {
    return DirectoryTransferProgress(
      percent: event.percent,
      currentFile: event.currentFile,
      completedFiles: event.completedFiles,
      totalFiles: event.totalFiles,
      isComplete: event.isComplete,
      error: event.errorMessage,
    );
  }
}

class DirectoryTransferProgress {
  final int percent;
  final String currentFile;
  final int completedFiles;
  final int totalFiles;
  final bool isComplete;
  final String? error;

  const DirectoryTransferProgress({
    required this.percent,
    required this.currentFile,
    this.completedFiles = 0,
    this.totalFiles = 0,
    this.isComplete = false,
    this.error,
  });
}

class DirectoryTransferCancellationToken {
  final TransferCancellationToken _native = TransferCancellationToken();

  bool get isActive => _native.isActive;
  bool get isComplete => _native.isComplete;
  bool get isCancelled => _native.isCancelled;

  bool cancel() => _native.cancel();
}

class DirectoryTransferResult {
  final bool isComplete;
  final bool isFailed;
  final bool isCancelled;
  final int processedFiles;
  final String? error;

  const DirectoryTransferResult({
    required this.isComplete,
    required this.processedFiles,
    this.isFailed = false,
    this.isCancelled = false,
    this.error,
  });
}

String buildDirectoryImportDestination({
  required String rootPath,
  required String currentPath,
  required String sourcePath,
}) {
  final root = _normalizeTransferPath(rootPath);
  final current = _normalizeTransferPath(currentPath);
  final source = _normalizeTransferPath(sourcePath);
  if (root.isEmpty || current.isEmpty || source.isEmpty) {
    throw ArgumentError('Directory import paths must not be empty');
  }
  if (current != root && !current.startsWith('$root/')) {
    throw StateError('Current path is outside the open root');
  }
  final sourceName = source.split('/').last;
  if (sourceName.isEmpty) {
    throw ArgumentError('Source directory must have a name');
  }
  final currentRelative =
      current == root ? '' : current.substring(root.length + 1);
  return currentRelative.isEmpty ? sourceName : '$currentRelative/$sourceName';
}

bool isPathInsideDirectory(String path, String directory) {
  final normalizedPath = _normalizeTransferPath(path);
  final normalizedDirectory = _normalizeTransferPath(directory);
  return normalizedPath == normalizedDirectory ||
      normalizedPath.startsWith('$normalizedDirectory/');
}

String _normalizeTransferPath(String path) {
  var normalized = path.trim().replaceAll('\\', '/');
  while (normalized.length > 1 && normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
