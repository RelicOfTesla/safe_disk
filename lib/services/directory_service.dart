import '../native/native_lib.dart';
import 'crypto_service.dart';

/// Service for directory operations.
///
/// **Architecture (Transfer V3)**:
/// - Uses rootID-based operations
/// - Directory export/import via V3 FFI functions
/// - Import/export is synchronous and only keeps unfinished operation markers
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
  Future<void> exportDirectory(
      int rootID, String srcPath, String destPath) async {
    _native.secTransferV3ExportDirectory(rootID, srcPath, destPath);
  }

  /// Imports a directory from normal filesystem to secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [srcPath] - Full path in normal filesystem
  /// [destPath] - Relative path in secure storage
  Future<void> importDirectory(
      int rootID, String srcPath, String destPath) async {
    _native.secTransferV3ImportDirectory(rootID, srcPath, destPath);
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

  // ==================== Directory Management ====================

  /// Creates a directory in secure storage.
  ///
  /// [rootID] - Root ID from CryptoService.openRoot()
  /// [path] - Relative path to create
  Future<void> createDir(int rootID, String path) async {
    _native.secMkdirAll(rootID, path);
  }
}
