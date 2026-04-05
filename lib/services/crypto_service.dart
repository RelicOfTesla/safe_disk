import 'dart:convert';
import 'dart:typed_data';

import '../native/native_lib.dart';

/// Crypto service for Safe Disk encryption operations.
///
/// **Architecture (V2)**:
/// - Root-based operations: Open a root directory, get a rootID
/// - All file operations use rootID
/// - ID mapping managed by Go backend (ffi_comm.Store)
///
/// **Usage**:
/// ```dart
/// final cryptoService = CryptoService();
///
/// // 1. Open root
/// final rootID = cryptoService.openRoot('/path/to/root', 'password', '{}');
///
/// // 2. Read file
/// final data = cryptoService.readFile(rootID, 'path/to/file.txt');
///
/// // 3. Write file
/// cryptoService.writeFile(rootID, 'path/to/file.txt', data);
///
/// // 4. Close root
/// cryptoService.closeRoot(rootID);
/// ```
class CryptoService {
  final NativeLib _native = NativeLib.instance;

  // ==================== ROOT OPERATIONS ====================

  /// Opens a secure root directory.
  ///
  /// [rootPath] - Full path to the root directory
  /// [password] - User password
  /// [configJSON] - Configuration JSON string
  /// Returns rootID on success, throws on error.
  int openRoot(String rootPath, String password, String configJSON) {
    return _native.secRootOpen(rootPath, password, configJSON);
  }

  /// Closes a secure root directory.
  void closeRoot(int rootID) {
    _native.secRootClose(rootID);
  }

  // ==================== FILE OPERATIONS ====================

  /// Reads a file from a secure root (async).
  ///
  /// [rootID] - Root ID from openRoot()
  /// [path] - Relative path to the file
  /// Returns file content as bytes.
  Future<Uint8List> readFile(int rootID, String path) async {
    // Use microtask to avoid blocking UI thread
    return Future.microtask(
      () => Uint8List.fromList(_native.secQuickReadFile(rootID, path)),
    );
  }

  /// Reads a file as string (async).
  Future<String> readTextFile(int rootID, String path) async {
    final bytes = await readFile(rootID, path);
    return utf8.decode(bytes);
  }

  /// Writes data to a file in a secure root (async).
  ///
  /// [rootID] - Root ID from openRoot()
  /// [path] - Relative path to the file
  /// [data] - File content as bytes
  Future<void> writeFile(int rootID, String path, Uint8List data) async {
    return Future.microtask(
      () => _native.secQuickWriteFile(rootID, path, data),
    );
  }

  /// Writes a string to a file (async).
  Future<void> writeTextFile(int rootID, String path, String content) async {
    await writeFile(rootID, path, Uint8List.fromList(utf8.encode(content)));
  }

  /// Deletes a file from a secure root (async).
  Future<void> deleteFile(int rootID, String path) async {
    return Future.microtask(
      () => _native.secFileDelete(rootID, path),
    );
  }

  /// Checks if a file exists in a secure root (async).
  Future<bool> fileExists(int rootID, String path) async {
    return Future.microtask(
      () => _native.secFileExists(rootID, path),
    );
  }

  // ==================== DIRECTORY OPERATIONS ====================

  /// Lists directory entries (async).
  ///
  /// [rootID] - Root ID from openRoot()
  /// [path] - Relative path to the directory (empty string for root)
  /// Returns list of directory entries.
  Future<List<DirEntry>> listDir(int rootID, String path) async {
    return Future.microtask(() {
      final entries = _native.secReadDir(rootID, path);
      return entries.map((e) => DirEntry.fromJson(e)).toList();
    });
  }

  /// Creates a directory in a secure root (async).
  Future<void> createDir(int rootID, String path) async {
    return Future.microtask(
      () => _native.secMkdirAll(rootID, path),
    );
  }

  // ==================== ADVANCED FILE OPERATIONS ====================

  /// Opens a file for streaming operations.
  ///
  /// Returns fileID for subsequent operations.
  int openFile(int rootID, String path, FileMode mode) {
    final modeInt = mode == FileMode.read ? 0 : (mode == FileMode.write ? 1 : 2);
    return _native.secFileOpen(rootID, path, modeInt);
  }

  /// Closes an open file.
  void closeFile(int fileID) {
    _native.secFileClose(fileID);
  }

  /// Reads from an open file.
  Uint8List readFileByID(int fileID, int size) {
    return Uint8List.fromList(_native.secFileRead(fileID, size));
  }

  /// Writes to an open file.
  void writeToFile(int fileID, Uint8List data) {
    _native.secFileWrite(fileID, data);
  }

  /// Seeks in an open file.
  int seekFile(int fileID, int offset, {int whence = 0}) {
    return _native.secFileSeek(fileID, offset, whence);
  }

  /// Truncates an open file.
  void truncateFile(int fileID, int size) {
    _native.secFileTruncate(fileID, size);
  }
}

/// File mode for open operations.
enum FileMode {
  read,
  write,
  readWrite,
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
