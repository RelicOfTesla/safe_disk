import '../native/native_lib.dart';
import '../models/ffi_results.dart';

/// Service for directory operations using the sec_* series interface.
class DirectoryService {
  final NativeLib _native = NativeLib.instance;

  // ==================== SEC SERIES DIRECTORY OPERATIONS ====================
  //
  // The sec_* series provides a cleaner, session-based API for directory traversal.
  // Migration guide:
  // - listCurrentDirectory(dirPath) → secWalkDirectory(sessionID, relativePath)
  //

  /// Starts walking a directory using the sec_* series interface.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the directory within the root ("" for root)
  ///
  /// Returns: SecDirWalker for iterating through entries
  /// Throws: Exception if the directory cannot be opened
  SecDirWalker secWalkDirectory(int sessionID, String relativePath) {
    final resultStr = _native.secDirWalk(sessionID, relativePath);
    final result = SecDirWalkResult.fromJson(resultStr);
    final walkerID = result.walkerIDOrThrow;
    return SecDirWalker(
      walkerID: walkerID,
      numFiles: result.numFiles ?? 0,
      native: _native,
    );
  }

  /// Lists all entries in a directory using the sec_* series interface.
  ///
  /// This is a convenience method that handles the walk/next/close cycle.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the directory within the root ("" for root)
  ///
  /// Returns: List of SecDirEntry
  /// Throws: Exception if the directory cannot be read
  List<SecDirEntry> secListDirectory(int sessionID, String relativePath) {
    final walker = secWalkDirectory(sessionID, relativePath);
    final entries = <SecDirEntry>[];

    try {
      while (true) {
        final next = walker.next();
        if (next.done) break;
        if (next.entry != null) {
          entries.add(next.entry!);
        }
      }
    } finally {
      walker.close();
    }

    return entries;
  }
}

/// Directory walker for sec_* series operations
///
/// Use this class to iterate through directory entries.
/// Remember to call close() when done to release resources.
class SecDirWalker {
  final int walkerID;
  final int numFiles;
  final NativeLib _native;

  bool _closed = false;

  SecDirWalker({
    required this.walkerID,
    required this.numFiles,
    required NativeLib native,
  }) : _native = native;

  /// Whether the walker has been closed
  bool get isClosed => _closed;

  /// Gets the next entry from the directory.
  ///
  /// Returns: SecDirWalkNextResult with done=true when finished
  /// Throws: Exception if walker is closed or error occurs
  SecDirWalkNextResult next() {
    if (_closed) {
      throw Exception('Walker is closed');
    }

    final resultStr = _native.secDirWalkNext(walkerID);
    return SecDirWalkNextResult.fromJson(resultStr);
  }

  /// Closes the directory walker.
  ///
  /// After calling this method, the walker can no longer be used.
  void close() {
    if (_closed) return;

    final resultStr = _native.secDirWalkClose(walkerID);
    final result = FFIResult.fromJson(resultStr);
    _closed = true;

    if (!result.success) {
      // Log warning but don't throw - walker is still closed
      print('Warning: Failed to close walker: ${result.error}');
    }
  }
}
