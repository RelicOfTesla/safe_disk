import 'package:ffi/ffi.dart';
import 'bindings.dart';

/// Native library wrapper for Safe Disk encryption operations
class NativeLib {
  final NativeBindings _bindings = NativeBindings.instance;

  static NativeLib? _instance;

  static NativeLib get instance {
    _instance ??= NativeLib._();
    return _instance!;
  }

  NativeLib._();

  // ==================== PRESERVED FUNCTIONS ====================

  /// Generates complete encryption configuration
  /// password: user password
  /// keyStrengthMs: target key derivation time in milliseconds (e.g., 1000 for 1 second)
  /// mutable: whether to use mutable mode (unique file key)
  /// challengeId: optional challenge ID (use empty string for default "safe_disk")
  /// Returns: JSON string with config (salt, encryptedChallengeId, iterN, key, etc.)
  String generateEncryptionConfig(
      String password, int keyStrengthMs, bool mutable, String challengeId) {
    final passwordPtr = password.toNativeUtf8();
    final challengeIdPtr = challengeId.toNativeUtf8();

    try {
      final resultPtr = _bindings.generateEncryptionConfig(
          passwordPtr, keyStrengthMs, mutable ? 1 : 0, challengeIdPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(passwordPtr);
      calloc.free(challengeIdPtr);
    }
  }

  /// Loads _cryption.json from a directory
  /// dirPath: directory path
  /// Returns: JSON string of config, or empty string if not found
  String loadCryptionConfig(String dirPath) {
    final dirPathPtr = dirPath.toNativeUtf8();

    try {
      final resultPtr = _bindings.loadCryptionConfig(dirPathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dirPathPtr);
    }
  }

  /// Finds the encrypted root directory (search upward like .git)
  /// path: starting path
  /// Returns: root directory path or empty string if not found
  String findCryptionRoot(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.findCryptionRoot(pathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Creates an encrypted directory with config file
  /// dirPath: directory path
  /// configJSON: config JSON string
  /// Returns: JSON result {"success": true} or {"success": false, "error": "..."}
  String createEncryptedDirectory(String dirPath, String configJSON) {
    final dirPathPtr = dirPath.toNativeUtf8();
    final configJSONPtr = configJSON.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.createEncryptedDirectory(dirPathPtr, configJSONPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dirPathPtr);
      calloc.free(configJSONPtr);
    }
  }

  // ==================== MEMORY MANAGEMENT ====================

  /// Clears sensitive data from memory securely.
  /// dataBase64: base64-encoded data to clear
  /// Returns: JSON result {"success": true} or error
  String clearSecureMemory(String dataBase64) {
    final dataPtr = dataBase64.toNativeUtf8();

    try {
      final resultPtr = _bindings.clearSecureMemory(dataPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dataPtr);
    }
  }

  // ==================== SEC ROOT SERIES ====================

  /// Opens an encrypted root directory and creates a session.
  /// This replaces verifyPassword + makeTemporaryKeyID.
  ///
  /// [rootPath] - path to the encrypted root directory (containing _cryption.json)
  /// [password] - user password
  /// [ttlSeconds] - session TTL in seconds (0 = default 3600s)
  ///
  /// Returns: JSON result {"success": true, "sessionID": ..., "rootPath": ...} or error
  String secRootOpen(String rootPath, String password, {int ttlSeconds = 0}) {
    final rootPathPtr = rootPath.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();

    try {
      final resultPtr = _bindings.secRootOpen(rootPathPtr, passwordPtr, ttlSeconds);
      return resultPtr.toDartString();
    } finally {
      calloc.free(rootPathPtr);
      calloc.free(passwordPtr);
    }
  }

  /// Closes a root session and releases resources.
  ///
  /// [sessionID] - session ID from secRootOpen
  ///
  /// Returns: JSON result {"success": true} or error
  String secRootClose(int sessionID) {
    final resultPtr = _bindings.secRootClose(sessionID);
    return resultPtr.toDartString();
  }

  /// Gets information about a root session.
  ///
  /// [sessionID] - session ID from secRootOpen
  ///
  /// Returns: JSON result {"success": true, "rootPath": ..., "config": {...}} or error
  String secRootGetInfo(int sessionID) {
    final resultPtr = _bindings.secRootGetInfo(sessionID);
    return resultPtr.toDartString();
  }

  // ==================== SEC FILE SERIES ====================

  /// Opens an encrypted file.
  ///
  /// [sessionID] - session ID from secRootOpen
  /// [filePath] - relative path to the file within the root
  /// [mode] - open mode: "r" (read), "w" (write), "a" (append)
  ///
  /// Returns: JSON result {"success": true, "fileHandle": ..., "size": ...} or error
  String secFopen(int sessionID, String filePath, String mode) {
    final filePathPtr = filePath.toNativeUtf8();
    final modePtr = mode.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFopen(sessionID, filePathPtr, modePtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(filePathPtr);
      calloc.free(modePtr);
    }
  }

  /// Reads data from an open file.
  ///
  /// [fileHandle] - file handle from secFopen
  /// [size] - number of bytes to read (0 = read all)
  ///
  /// Returns: JSON result {"success": true, "data": "...base64...", "bytesRead": ...} or error
  String secFread(int fileHandle, {int size = 0}) {
    final resultPtr = _bindings.secFread(fileHandle, size);
    return resultPtr.toDartString();
  }

  /// Writes data to an open file.
  ///
  /// [fileHandle] - file handle from secFopen
  /// [dataBase64] - base64-encoded data to write
  ///
  /// Returns: JSON result {"success": true, "bytesWritten": ...} or error
  String secFwrite(int fileHandle, String dataBase64) {
    final dataPtr = dataBase64.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFwrite(fileHandle, dataPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Closes an open file and writes changes if modified.
  ///
  /// [fileHandle] - file handle from secFopen
  ///
  /// Returns: JSON result {"success": true} or error
  String secFclose(int fileHandle) {
    final resultPtr = _bindings.secFclose(fileHandle);
    return resultPtr.toDartString();
  }

  /// Sets the file position.
  ///
  /// [fileHandle] - file handle from secFopen
  /// [offset] - offset from origin
  /// [whence] - 0 = SEEK_SET, 1 = SEEK_CUR, 2 = SEEK_END
  ///
  /// Returns: JSON result {"success": true, "position": ...} or error
  String secFseek(int fileHandle, int offset, {int whence = 0}) {
    final resultPtr = _bindings.secFseek(fileHandle, offset, whence);
    return resultPtr.toDartString();
  }

  /// Returns the current file position.
  ///
  /// [fileHandle] - file handle from secFopen
  ///
  /// Returns: JSON result {"success": true, "position": ...} or error
  String secFtell(int fileHandle) {
    final resultPtr = _bindings.secFtell(fileHandle);
    return resultPtr.toDartString();
  }

  /// Returns file status.
  ///
  /// [fileHandle] - file handle from secFopen
  ///
  /// Returns: JSON result {"success": true, "size": ...} or error
  String secFstat(int fileHandle) {
    final resultPtr = _bindings.secFstat(fileHandle);
    return resultPtr.toDartString();
  }

  /// Returns detailed file information without opening.
  ///
  /// [sessionID] - session ID from secRootOpen
  /// [filePath] - relative path to the file within the root
  ///
  /// Returns: JSON result {"success": true, "exists": ..., "size": ..., "isChunked": ..., "modTime": ...} or error
  String secFstatInfo(int sessionID, String filePath) {
    final filePathPtr = filePath.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFstatInfo(sessionID, filePathPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(filePathPtr);
    }
  }

  // ==================== SEC SHORTCUT FUNCTIONS ====================

  /// Reads an entire file at once.
  /// This is a convenience function that combines secFopen + secFread + secFclose.
  ///
  /// [sessionID] - session ID from secRootOpen
  /// [filePath] - relative path to the file within the root
  ///
  /// Returns: JSON result {"success": true, "data": "...base64..."} or error
  String secReadfile(int sessionID, String filePath) {
    final filePathPtr = filePath.toNativeUtf8();

    try {
      final resultPtr = _bindings.secReadfile(sessionID, filePathPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(filePathPtr);
    }
  }

  /// Writes an entire file at once.
  /// This is a convenience function that combines secFopen + secFwrite + secFclose.
  ///
  /// [sessionID] - session ID from secRootOpen
  /// [filePath] - relative path to the file within the root
  /// [dataBase64] - base64-encoded data to write
  ///
  /// Returns: JSON result {"success": true} or error
  String secWritefile(int sessionID, String filePath, String dataBase64) {
    final filePathPtr = filePath.toNativeUtf8();
    final dataPtr = dataBase64.toNativeUtf8();

    try {
      final resultPtr = _bindings.secWritefile(sessionID, filePathPtr, dataPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(filePathPtr);
      calloc.free(dataPtr);
    }
  }

  // ==================== SEC DIR WALK SERIES ====================

  /// Starts walking a directory.
  ///
  /// [sessionID] - session ID from secRootOpen
  /// [dirPath] - relative path to the directory within the root
  ///
  /// Returns: JSON result {"success": true, "walkerID": ..., "numFiles": ...} or error
  String secDirWalk(int sessionID, String dirPath) {
    final dirPathPtr = dirPath.toNativeUtf8();

    try {
      final resultPtr = _bindings.secDirWalk(sessionID, dirPathPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(dirPathPtr);
    }
  }

  /// Gets the next entry from a directory walker.
  ///
  /// [walkerID] - walker ID from secDirWalk
  ///
  /// Returns: JSON result {"success": true, "name": ..., "isDir": ..., "size": ..., "modTime": ..., "done": false}
  ///         or {"done": true} when finished, or error
  String secDirWalkNext(int walkerID) {
    final resultPtr = _bindings.secDirWalkNext(walkerID);
    return resultPtr.toDartString();
  }

  /// Closes a directory walker.
  ///
  /// [walkerID] - walker ID from secDirWalk
  ///
  /// Returns: JSON result {"success": true} or error
  String secDirWalkClose(int walkerID) {
    final resultPtr = _bindings.secDirWalkClose(walkerID);
    return resultPtr.toDartString();
  }
}
