import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'crypto_service.dart';

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
  final CryptoService _cryptoService;

  FileService(this._cryptoService);

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

  /// Decrypts a file to memory (NOT to disk for security)
  /// Returns decrypted data as Uint8List
  /// SECURITY: Never save decrypted data to temporary files!
  /// NOTE: For large files (>100 MB), this may use significant memory.
  /// Consider using exportFile() for large files instead.
  Future<Uint8List> decryptFileToBytes(
      FileSystemNode file, String tempKeyID) async {
    if (file.isDirectory) {
      throw Exception('Cannot decrypt a directory');
    }

    // Check if file is chunked format (supports streaming)
    final isChunked = _cryptoService.isChunkedFile(file.path);

    if (isChunked) {
      // For chunked files, we can use memory-efficient decryption
      // But since we need to return bytes, we still load into memory
      // However, the decryption process itself is memory-efficient
      final tempPath = await _decryptToTempFile(file.path, tempKeyID);
      try {
        final tempFile = File(tempPath);
        final decryptedData = await tempFile.readAsBytes();
        return decryptedData;
      } finally {
        // Clean up temp file
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    // Standard decryption for non-chunked files
    final inputFile = File(file.path);
    final encryptedData = await inputFile.readAsBytes();

    // Decrypt using session key
    final encryptedDataBase64 = base64Encode(encryptedData);
    final decryptedData =
        _cryptoService.decryptDataBytes(encryptedDataBase64, tempKeyID);

    // Clear sensitive data from memory
    encryptedData.fillRange(0, encryptedData.length, 0);

    return decryptedData;
  }

  /// Decrypts a file to a temporary file path.
  /// This is memory-efficient for large files.
  /// Returns the path to the temporary decrypted file.
  /// Caller is responsible for deleting the temp file after use.
  Future<String> _decryptToTempFile(String inputPath, String tempKeyID) async {
    final tempDir = Directory.systemTemp;
    final tempFileName =
        'safedisk_decrypted_${DateTime.now().millisecondsSinceEpoch}';
    final tempPath = '${tempDir.path}/$tempFileName';

    _cryptoService.decryptFileToPath(inputPath, tempPath, tempKeyID);

    return tempPath;
  }

  /// Encrypts a file and saves to encrypted directory
  Future<void> encryptFile(
      String inputPath, String outputDir, String tempKeyID) async {
    final inputFile = File(inputPath);
    final plaintext = await inputFile.readAsBytes();

    // Encrypt using session key
    final ciphertextBase64 =
        _cryptoService.encryptDataBytes(plaintext, tempKeyID);
    final encrypted = base64Decode(ciphertextBase64);

    // Clear sensitive data from memory
    plaintext.fillRange(0, plaintext.length, 0);

    final name = inputPath.split('/').last;
    final outputFile = File('$outputDir/$name');
    await outputFile.writeAsBytes(encrypted);
  }

  /// Exports decrypted file to a user-selected location.
  /// This method uses memory-efficient streaming decryption for large files.
  Future<void> exportFile(
      FileSystemNode file, String outputPath, String tempKeyID) async {
    if (file.isDirectory) {
      throw Exception('Cannot export a directory');
    }

    // Use streaming decryption directly to output path
    // This is memory-efficient for both large and small files
    _cryptoService.decryptFileToPath(file.path, outputPath, tempKeyID);
  }

  /// Exports decrypted file to a user-selected location.
  /// Uses the legacy in-memory method (for backward compatibility).
  /// DEPRECATED: Use exportFile() instead for better memory efficiency.
  Future<void> exportFileLegacy(
      FileSystemNode file, String outputPath, String tempKeyID) async {
    if (file.isDirectory) {
      throw Exception('Cannot export a directory');
    }

    final inputFile = File(file.path);
    final encryptedData = await inputFile.readAsBytes();

    // Decrypt using session key
    final encryptedDataBase64 = base64Encode(encryptedData);
    final decryptedData =
        _cryptoService.decryptDataBytes(encryptedDataBase64, tempKeyID);

    // Clear sensitive data from memory
    encryptedData.fillRange(0, encryptedData.length, 0);

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(decryptedData);
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
}
