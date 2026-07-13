import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../native/native_lib.dart';
import '../models/cryption_config.dart';

/// Crypto service for Safe Disk encryption operations.
///
/// **Architecture**:
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
  NativeLib get _native => NativeLib.instance;
  static final Map<int, String> _rootPaths = {};

  // ==================== ROOT OPERATIONS ====================

  /// Opens a secure root directory.
  ///
  /// [rootPath] - Full path to the root directory
  /// [password] - User password
  /// [configJSON] - Configuration JSON string
  /// Returns rootID on success, throws on error.
  int openRoot(String rootPath, String password, String configJSON) {
    final rootID = _native.secRootOpen(rootPath, password, configJSON);
    _rootPaths[rootID] = _normalizePath(rootPath);
    return rootID;
  }

  /// Closes a secure root directory.
  void closeRoot(int rootID) {
    _native.secRootClose(rootID);
    _rootPaths.remove(rootID);
  }

  /// Creates a secure root configuration.
  void createRootConfig(String rootPath, String password, String optionsJSON) {
    final directory = Directory(rootPath);
    if (directory.existsSync()) {
      if (directory.listSync(followLinks: false).isNotEmpty) {
        throw FileSystemException(
          'Encrypted root must be created in an empty directory',
          rootPath,
        );
      }
    } else {
      directory.createSync(recursive: true);
    }
    _native.secCreateRootConfig(rootPath, password, optionsJSON);
  }

  /// Finds the nearest parent directory containing `_cryption.json`.
  String findCryptionRoot(String path) {
    var current = FileSystemEntity.isDirectorySync(path)
        ? Directory(path)
        : File(path).parent;
    while (true) {
      if (File('${current.path}/_cryption.json').existsSync()) {
        return _normalizePath(current.path);
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        return '';
      }
      current = parent;
    }
  }

  /// Loads the raw root config for UI display and persistence.
  CryptionConfig loadConfig(String rootPath) {
    final file = File('$rootPath/_cryption.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return CryptionConfig.fromJson(data);
  }

  String? rootPathForID(int rootID) => _rootPaths[rootID];

  int? rootIDForPath(String path) {
    final normalized = _normalizePath(path);
    for (final entry in _rootPaths.entries) {
      final root = entry.value;
      if (normalized == root || normalized.startsWith('$root/')) {
        return entry.key;
      }
    }
    return null;
  }

  String relativePathForRoot(int rootID, String path) {
    final root = _rootPaths[rootID];
    if (root == null) {
      throw StateError('Root $rootID is not open');
    }
    final normalized = _normalizePath(path);
    if (normalized == root) {
      return '';
    }
    if (!normalized.startsWith('$root/')) {
      return normalized;
    }
    return normalized.substring(root.length + 1);
  }

  String absolutePathForRoot(int rootID, String relativePath) {
    final root = _rootPaths[rootID];
    if (root == null) {
      throw StateError('Root $rootID is not open');
    }
    if (relativePath.isEmpty) {
      return root;
    }
    return '$root/$relativePath';
  }

  Uint8List decryptFileToData(String path, String tempKeyID) {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    return Uint8List.fromList(_native.secQuickReadFile(rootID, relativePath));
  }

  Future<void> writeFileBySession(
      String path, String tempKeyID, List<int> data) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    await writeFile(rootID, relativePath, Uint8List.fromList(data));
  }

  Future<void> deleteFileBySession(String path, String tempKeyID) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    await deleteFile(rootID, relativePath);
  }

  Future<bool> fileExistsBySession(String path, String tempKeyID) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    return fileExists(rootID, relativePath);
  }

  Future<void> renameBySession(
    String oldPath,
    String newPath,
    String tempKeyID,
  ) async {
    final rootID = int.parse(tempKeyID);
    final oldRelativePath = relativePathForRoot(rootID, oldPath);
    final newRelativePath = relativePathForRoot(rootID, newPath);
    await Future.microtask(
      () => _native.secRename(rootID, oldRelativePath, newRelativePath),
    );
  }

  Future<void> copyBySession({
    required String sourcePath,
    required String sourceSessionID,
    required String destinationPath,
    required String destinationSessionID,
    bool overwrite = false,
  }) async {
    final sourceRootID = int.parse(sourceSessionID);
    final destinationRootID = int.parse(destinationSessionID);
    final sourceRelativePath = relativePathForRoot(sourceRootID, sourcePath);
    final destinationRelativePath =
        relativePathForRoot(destinationRootID, destinationPath);
    await _native.secCopyEntryInBackground(
      sourceRootID,
      sourceRelativePath,
      destinationRootID,
      destinationRelativePath,
      overwrite: overwrite,
    );
  }

  Future<void> createEmptyFileBySession(
    String path,
    String tempKeyID,
  ) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    await Future.microtask(
      () => _native.secCreateEmptyFile(rootID, relativePath),
    );
  }

  Future<void> createDirectoryBySession(
    String path,
    String tempKeyID,
  ) async {
    final rootID = int.parse(tempKeyID);
    final relativePath = relativePathForRoot(rootID, path);
    await Future.microtask(
      () => _native.secCreateDirectory(rootID, relativePath),
    );
  }

  String encryptDataBytes(List<int> data, String tempKeyID) {
    // Compatibility for restored widgets that still expect base64 bytes.
    // New code should call writeFile/readFile through rootID instead.
    return base64Encode(data);
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
    final modeInt =
        mode == FileMode.read ? 0 : (mode == FileMode.write ? 1 : 2);
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

String _normalizePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.length > 1 && normalized.endsWith('/')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
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

  /// Modification time in Unix seconds.
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
