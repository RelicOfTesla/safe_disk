import '../native/native_lib.dart';
import 'crypto_service.dart';

/// Service for directory operations.
///
/// **Architecture (V2)**:
/// - Uses rootID-based operations
/// - Directory export/import via ffi_sec_transfer
/// - No tempKeyID required (password managed by backend)
class DirectoryService {
  final NativeLib _native = NativeLib.instance;
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

  /// Exports a directory from secure storage to normal filesystem.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [srcPath] - Relative path in secure storage
  /// [destPath] - Full path in normal filesystem
  /// Returns job ID for tracking progress.
  Future<String> exportDirectory(int rootID, String srcPath, String destPath) async {
    // TODO: Implement with ffi_sec_transfer
    // return _native.secExportDirectoryAsync(rootID, srcPath, destPath);
    throw UnimplementedError('Directory export not yet implemented in FFI bindings');
  }

  /// Imports a directory from normal filesystem to secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [srcPath] - Full path in normal filesystem
  /// [destPath] - Relative path in secure storage
  /// Returns job ID for tracking progress.
  Future<String> importDirectory(int rootID, String srcPath, String destPath) async {
    // TODO: Implement with ffi_sec_transfer
    // return _native.secImportDirectoryAsync(rootID, srcPath, destPath);
    throw UnimplementedError('Directory import not yet implemented in FFI bindings');
  }

  // ==================== Directory Management ====================

  /// Creates a directory in secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [path] - Relative path to create
  Future<void> createDir(int rootID, String path) async {
    _native.secMkdirAll(rootID, path);
  }
}

/// Directory entry information.
class DirEntry {
  final String name;
  final bool isDir;
  final int size;
  final int modTime;
  final int mode;
  final String path;

  DirEntry({
    required this.name,
    required this.isDir,
    required this.size,
    required this.modTime,
    required this.mode,
    required this.path,
  });

  factory DirEntry.fromJson(Map<String, dynamic> json) {
    return DirEntry(
      name: json['name'] as String,
      isDir: json['is_dir'] as bool,
      size: json['size'] as int,
      modTime: json['mod_time'] as int,
      mode: json['mode'] as int,
      path: json['path'] as String,
    );
  }
}
