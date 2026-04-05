import 'dart:io';
import 'dart:typed_data';

import 'crypto_service.dart';

/// Represents a file or directory node in the encrypted file system.
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

  /// Helper to get file extension.
  String? get extension {
    if (isDirectory) return null;
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : null;
  }

  /// Helper to format size.
  String get formattedSize {
    if (isDirectory || size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(size! / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// Convert to Map for serialization.
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

  /// Create from Map for deserialization.
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

/// Service for file operations in secure storage.
///
/// **Architecture (V2)**:
/// - Uses rootID-based operations
/// - Delegates to CryptoService for file I/O
/// - Provides file type detection and helper methods
class FileService {
  final CryptoService _cryptoService;

  FileService({CryptoService? cryptoService})
      : _cryptoService = cryptoService ?? CryptoService();

  // ==================== File Read/Write ====================

  /// Reads a file from secure storage.
  Future<Uint8List> readFile(int rootID, String path) async {
    return _cryptoService.readFile(rootID, path);
  }

  /// Reads a file as string.
  Future<String> readTextFile(int rootID, String path) async {
    return _cryptoService.readTextFile(rootID, path);
  }

  /// Writes data to a file in secure storage.
  Future<void> writeFile(int rootID, String path, Uint8List data) async {
    return _cryptoService.writeFile(rootID, path, data);
  }

  /// Writes a string to a file.
  Future<void> writeTextFile(int rootID, String path, String content) async {
    return _cryptoService.writeTextFile(rootID, path, content);
  }

  /// Deletes a file from secure storage.
  Future<void> deleteFile(int rootID, String path) async {
    return _cryptoService.deleteFile(rootID, path);
  }

  /// Checks if a file exists in secure storage.
  Future<bool> fileExists(int rootID, String path) async {
    return _cryptoService.fileExists(rootID, path);
  }

  // ==================== File Type Detection ====================

  /// Checks if a file is an image based on extension.
  bool isImage(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext);
  }

  /// Checks if a file is a text file based on extension.
  bool isTextFile(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['txt', 'md', 'json', 'xml', 'yaml', 'yml', 'csv'].contains(ext);
  }

  /// Checks if a file is a video based on extension.
  bool isVideo(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'].contains(ext);
  }

  /// Checks if a file is an audio based on extension.
  bool isAudio(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'].contains(ext);
  }

  /// Checks if a file is a document based on extension.
  bool isDocument(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext);
  }

  // ==================== Directory Operations ====================

  /// Creates a directory in secure storage.
  Future<void> createDir(int rootID, String path) async {
    return _cryptoService.createDir(rootID, path);
  }

  /// Lists directory entries.
  Future<List<DirEntry>> listDir(int rootID, String path) async {
    return _cryptoService.listDir(rootID, path);
  }
}
