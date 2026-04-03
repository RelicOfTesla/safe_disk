import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../native/native_lib.dart';
import '../models/ffi_results.dart';

/// Represents a file or directory node in the encrypted file system
class FileSystemNode {
  final String name;
  final String path;
  final bool isDirectory;
  final DateTime? modifiedTime;
  final int? size;
  final List<FileSystemNode>? children;

  FileSystemNode({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.modifiedTime,
    this.size,
    this.children,
  });

  // Helper to get file extension
  String? get extension {
    if (isDirectory) return null;
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : null;
  }

  // Helper to format size
  String get formattedSize {
    if (isDirectory || size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size! / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  // Convert to Map for Isolate communication
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'modifiedTime': modifiedTime?.toIso8601String(),
      'size': size,
      'children': children?.map((c) => c.toMap()).toList(),
    };
  }

  // Create from Map for Isolate communication
  factory FileSystemNode.fromMap(Map<String, dynamic> map) {
    return FileSystemNode(
      name: map['name'] as String,
      path: map['path'] as String,
      isDirectory: map['isDirectory'] as bool,
      modifiedTime: map['modifiedTime'] != null
          ? DateTime.parse(map['modifiedTime'] as String)
          : null,
      size: map['size'] as int?,
      children: (map['children'] as List<dynamic>?)
          ?.map((c) => FileSystemNode.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Parameters for directory listing (for Isolate communication)
class _ListDirectoryParams {
  final String dirPath;
  final int offset;
  final int? limit;

  _ListDirectoryParams({
    required this.dirPath,
    this.offset = 0,
    this.limit,
  });

  Map<String, dynamic> toMap() {
    return {
      'dirPath': dirPath,
      'offset': offset,
      'limit': limit,
    };
  }

  factory _ListDirectoryParams.fromMap(Map<String, dynamic> map) {
    return _ListDirectoryParams(
      dirPath: map['dirPath'] as String,
      offset: map['offset'] as int? ?? 0,
      limit: map['limit'] as int?,
    );
  }
}

/// Result of directory listing (for Isolate communication)
class _ListDirectoryResult {
  final List<Map<String, dynamic>> nodes;
  final int totalCount;
  final bool hasMore;

  _ListDirectoryResult({
    required this.nodes,
    required this.totalCount,
    required this.hasMore,
  });

  Map<String, dynamic> toMap() {
    return {
      'nodes': nodes,
      'totalCount': totalCount,
      'hasMore': hasMore,
    };
  }
}

/// Background function to list directory (runs in Isolate)
Future<_ListDirectoryResult> _listDirectoryInBackground(
    Map<String, dynamic> paramsMap) async {
  final params = _ListDirectoryParams.fromMap(paramsMap);
  final dir = Directory(params.dirPath);

  if (!await dir.exists()) {
    return _ListDirectoryResult(nodes: [], totalCount: 0, hasMore: false);
  }

  // Collect all entities first (we need to sort and count)
  final allEntities = <FileSystemEntity>[];
  await for (final entity in dir.list()) {
    final name = entity.path.split('/').last;
    if (name == '_cryption.json') continue; // Skip config file
    allEntities.add(entity);
  }

  // Sort entities: directories first, then files, both alphabetically
  allEntities.sort((a, b) {
    final aIsDir = a is Directory;
    final bIsDir = b is Directory;
    if (aIsDir != bIsDir) {
      return aIsDir ? -1 : 1;
    }
    final aName = a.path.split('/').last.toLowerCase();
    final bName = b.path.split('/').last.toLowerCase();
    return aName.compareTo(bName);
  });

  final totalCount = allEntities.length;

  // Apply pagination
  final offset = params.offset;
  final limit = params.limit;
  final endIndex = limit != null ? offset + limit : totalCount;
  final paginatedEntities = allEntities.sublist(
    offset.clamp(0, totalCount),
    endIndex.clamp(0, totalCount),
  );

  // Build nodes
  final nodes = <Map<String, dynamic>>[];
  for (final entity in paginatedEntities) {
    final name = entity.path.split('/').last;
    final stat = await entity.stat();

    if (entity is Directory) {
      nodes.add(FileSystemNode(
        name: name,
        path: entity.path,
        isDirectory: true,
        modifiedTime: stat.modified,
        children: [], // Empty list means "not loaded yet"
      ).toMap());
    } else if (entity is File) {
      nodes.add(FileSystemNode(
        name: name,
        path: entity.path,
        isDirectory: false,
        modifiedTime: stat.modified,
        size: stat.size,
      ).toMap());
    }
  }

  final hasMore = limit != null && (offset + limit) < totalCount;

  return _ListDirectoryResult(
    nodes: nodes,
    totalCount: totalCount,
    hasMore: hasMore,
  );
}

class FileService {
  /// Lists files and subdirectories in a directory (non-recursive) with pagination
  /// Uses Isolate to avoid blocking the main thread for large directories
  Future<List<FileSystemNode>> listCurrentDirectory(
    String dirPath, {
    int offset = 0,
    int? limit,
  }) async {
    try {
      // Use Isolate.run for background processing
      final params = _ListDirectoryParams(
        dirPath: dirPath,
        offset: offset,
        limit: limit,
      );

      final result = await Isolate.run(
        () => _listDirectoryInBackground(params.toMap()),
      );

      return result.nodes.map((n) => FileSystemNode.fromMap(n)).toList();
    } catch (e) {
      // Fallback to synchronous listing if Isolate fails
      print('Isolate listing failed, falling back to sync: $e');
      return await _listCurrentDirectorySync(dirPath,
          offset: offset, limit: limit);
    }
  }

  /// Synchronous fallback for directory listing (used if Isolate fails)
  Future<List<FileSystemNode>> _listCurrentDirectorySync(
    String dirPath, {
    int offset = 0,
    int? limit,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final nodes = <FileSystemNode>[];
    var index = 0;

    await for (final entity in dir.list()) {
      final name = entity.path.split('/').last;
      if (name == '_cryption.json') continue; // Skip config file

      // Apply pagination during iteration
      if (index < offset) {
        index++;
        continue;
      }
      if (limit != null && nodes.length >= limit) {
        break;
      }

      final stat = await entity.stat();

      if (entity is Directory) {
        nodes.add(FileSystemNode(
          name: name,
          path: entity.path,
          isDirectory: true,
          modifiedTime: stat.modified,
          children: [], // Empty list means "not loaded yet"
        ));
      } else if (entity is File) {
        nodes.add(FileSystemNode(
          name: name,
          path: entity.path,
          isDirectory: false,
          modifiedTime: stat.modified,
          size: stat.size,
        ));
      }
      index++;
    }

    // Sort: directories first, then files, both alphabetically
    nodes.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return nodes;
  }

  /// Gets the total count of items in a directory (without loading all items)
  Future<int> getDirectoryItemCount(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;

    var count = 0;
    await for (final entity in dir.list()) {
      final name = entity.path.split('/').last;
      if (name == '_cryption.json') continue; // Skip config file
      count++;
    }
    return count;
  }

  /// Recursively scans a directory tree
  Future<FileSystemNode> scanDirectoryTree(String dirPath,
      {int maxDepth = 10}) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw Exception('Directory does not exist: $dirPath');
    }

    return _scanNode(dirPath, 0, maxDepth);
  }

  Future<FileSystemNode> _scanNode(String path, int depth, int maxDepth) async {
    final name = path.split('/').last;
    final dir = Directory(path);
    final stat = await dir.stat();

    if (depth >= maxDepth) {
      // Max depth reached, return without children
      return FileSystemNode(
        name: name,
        path: path,
        isDirectory: true,
        modifiedTime: stat.modified,
        children: [], // Not loaded due to max depth
      );
    }

    final children = <FileSystemNode>[];
    await for (final entity in dir.list()) {
      final childName = entity.path.split('/').last;
      if (childName == '_cryption.json') continue;

      if (entity is Directory) {
        children.add(await _scanNode(entity.path, depth + 1, maxDepth));
      } else if (entity is File) {
        final childStat = await entity.stat();
        children.add(FileSystemNode(
          name: childName,
          path: entity.path,
          isDirectory: false,
          modifiedTime: childStat.modified,
          size: childStat.size,
        ));
      }
    }

    // Sort children
    children.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return FileSystemNode(
      name: name,
      path: path,
      isDirectory: true,
      modifiedTime: stat.modified,
      children: children,
    );
  }

  /// Gets the parent directory path
  String? getParentDirectory(String dirPath) {
    final parts = dirPath.split('/');
    if (parts.length <= 1) return null;
    parts.removeLast();
    return parts.join('/');
  }

  /// Large file threshold (100 MB)
  static const int largeFileThreshold = 100 * 1024 * 1024;

  /// Checks if a file is considered large
  bool isLargeFile(FileSystemNode file) {
    return file.size != null && file.size! > largeFileThreshold;
  }

  /// Creates a new subdirectory
  Future<FileSystemNode> createDirectory(
      String parentPath, String dirName) async {
    final newDir = Directory('$parentPath/$dirName');
    await newDir.create(recursive: true);

    return FileSystemNode(
      name: dirName,
      path: newDir.path,
      isDirectory: true,
      modifiedTime: DateTime.now(),
      children: [],
    );
  }

  /// Deletes a file or directory
  Future<void> deleteNode(FileSystemNode node) async {
    if (node.isDirectory) {
      final dir = Directory(node.path);
      await dir.delete(recursive: true);
    } else {
      final file = File(node.path);
      await file.delete();
    }
  }

  // ==================== SEC SERIES FILE OPERATIONS (NEW) ====================
  //
  // The sec_* series provides a cleaner, session-based API for encrypted file operations.
  // Key differences from the old interface:
  // - Uses sessionID (int) instead of tempKeyID (string)
  // - Uses relative paths within the root directory instead of absolute paths
  // - File operations are more like C stdio (fopen, fread, fwrite, fclose)
  //
  // Migration guide:
  // - decryptFileToBytes(file, tempKeyID) → secReadFile(sessionID, relativePath)
  // - encryptFile(inputPath, outputDir, tempKeyID) → secWriteFile(sessionID, relativePath, data)
  // - exportFile(file, outputPath, tempKeyID) → secReadFile(sessionID, relativePath) then save to outputPath
  //

  /// Reads an entire encrypted file at once using the sec_* series interface.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the file within the root directory
  ///
  /// Returns: decrypted data as Uint8List
  /// Throws: Exception if read fails
  Uint8List secReadFile(int sessionID, String relativePath) {
    final native = NativeLib.instance;
    final resultStr = native.secReadfile(sessionID, relativePath);
    final result = SecReadfileResult.fromJson(resultStr);
    return result.dataOrThrow;
  }

  /// Writes an entire encrypted file at once using the sec_* series interface.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the file within the root directory
  /// [data] - data to write (will be encrypted)
  ///
  /// Throws: Exception if write fails
  void secWriteFile(int sessionID, String relativePath, Uint8List data) {
    final native = NativeLib.instance;
    final dataBase64 = base64Encode(data);
    final resultStr = native.secWritefile(sessionID, relativePath, dataBase64);
    final result = FFIResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to write file');
    }
  }

  /// Opens an encrypted file for reading or writing using the sec_* series interface.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the file within the root directory
  /// [mode] - open mode: "r" (read), "w" (write), "a" (append)
  ///
  /// Returns: SecFileHandle for subsequent operations
  /// Throws: Exception if open fails
  SecFileHandle secOpenFile(int sessionID, String relativePath, String mode) {
    final native = NativeLib.instance;
    final resultStr = native.secFopen(sessionID, relativePath, mode);
    final result = SecFopenResult.fromJson(resultStr);
    return SecFileHandle(
      handle: result.fileHandleOrThrow,
      size: result.size ?? 0,
      sessionID: sessionID,
      native: native,
    );
  }

  /// Gets file information without opening the file.
  ///
  /// [sessionID] - session ID from CryptoService.openSession
  /// [relativePath] - relative path to the file within the root directory
  ///
  /// Returns: SecFileInfo with exists, size, isChunked, modTime
  SecFileInfo secGetFileInfo(int sessionID, String relativePath) {
    final native = NativeLib.instance;
    final resultStr = native.secFstatInfo(sessionID, relativePath);
    final result = SecFstatInfoResult.fromJson(resultStr);
    return SecFileInfo(
      exists: result.exists ?? false,
      size: result.size ?? 0,
      isChunked: result.isChunked ?? false,
      modTime: result.modTime != null
          ? DateTime.fromMillisecondsSinceEpoch(result.modTime! * 1000)
          : null,
    );
  }
}

/// Represents an open file handle for sec_* series operations
///
/// Use this class to read, write, and close files opened with secOpenFile.
/// The file is automatically encrypted/decrypted transparently.
class SecFileHandle {
  final int handle;
  final int size;
  final int sessionID;
  final NativeLib _native;

  bool _closed = false;

  SecFileHandle({
    required this.handle,
    required this.size,
    required this.sessionID,
    required NativeLib native,
  }) : _native = native;

  /// Whether the file has been closed
  bool get isClosed => _closed;

  /// Reads data from the file.
  ///
  /// [size] - number of bytes to read (0 = read all)
  ///
  /// Returns: decrypted data as Uint8List
  /// Throws: Exception if read fails or file is closed
  Uint8List read({int size = 0}) {
    if (_closed) {
      throw Exception('File is closed');
    }

    final resultStr = _native.secFread(handle, size: size);
    final result = SecFreadResult.fromJson(resultStr);
    return result.dataOrThrow;
  }

  /// Writes data to the file.
  ///
  /// [data] - data to write (will be encrypted)
  ///
  /// Returns: number of bytes written
  /// Throws: Exception if write fails or file is closed
  int write(Uint8List data) {
    if (_closed) {
      throw Exception('File is closed');
    }

    final dataBase64 = base64Encode(data);
    final resultStr = _native.secFwrite(handle, dataBase64);
    final result = SecFwriteResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Write failed');
    }
    return result.bytesWritten ?? 0;
  }

  /// Sets the file position.
  ///
  /// [offset] - offset from origin
  /// [whence] - 0 = SEEK_SET (start), 1 = SEEK_CUR (current), 2 = SEEK_END (end)
  ///
  /// Returns: new position
  /// Throws: Exception if seek fails or file is closed
  int seek(int offset, {int whence = 0}) {
    if (_closed) {
      throw Exception('File is closed');
    }

    final resultStr = _native.secFseek(handle, offset, whence: whence);
    final result = FFIResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Seek failed');
    }
    // The result contains 'position' field
    final json = jsonDecode(resultStr) as Map<String, dynamic>;
    return json['position'] as int? ?? 0;
  }

  /// Returns the current file position.
  ///
  /// Throws: Exception if file is closed
  int tell() {
    if (_closed) {
      throw Exception('File is closed');
    }

    final resultStr = _native.secFtell(handle);
    final result = FFIResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Tell failed');
    }
    // The result contains 'position' field
    final json = jsonDecode(resultStr) as Map<String, dynamic>;
    return json['position'] as int? ?? 0;
  }

  /// Returns the file size.
  ///
  /// Throws: Exception if file is closed
  int stat() {
    if (_closed) {
      throw Exception('File is closed');
    }

    final resultStr = _native.secFstat(handle);
    final result = SecFstatResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Stat failed');
    }
    return result.size ?? 0;
  }

  /// Closes the file and writes changes if modified.
  ///
  /// After calling this method, the handle can no longer be used.
  void close() {
    if (_closed) return;

    final resultStr = _native.secFclose(handle);
    final result = FFIResult.fromJson(resultStr);
    _closed = true;

    if (!result.success) {
      throw Exception(result.error ?? 'Close failed');
    }
  }
}

/// File information from sec_fstat_info
class SecFileInfo {
  final bool exists;
  final int size;
  final bool isChunked;
  final DateTime? modTime;

  SecFileInfo({
    required this.exists,
    required this.size,
    required this.isChunked,
    this.modTime,
  });
}
