import 'dart:io';
import '../models/cryption_config.dart';
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
    if (size! < 1024 * 1024 * 1024) return '${(size! / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(size! / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

class FileService {
  final CryptoService _cryptoService;
  
  FileService(this._cryptoService);
  
  /// Lists files and subdirectories in a directory (non-recursive)
  Future<List<FileSystemNode>> listCurrentDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    
    final nodes = <FileSystemNode>[];
    await for (final entity in dir.list()) {
      final name = entity.path.split('/').last;
      if (name == '_cryption.json') continue; // Skip config file
      
      final stat = await entity.stat();
      
      if (entity is Directory) {
        // Count items in subdirectory
        int itemCount = 0;
        try {
          await for (final _ in entity.list()) {
            itemCount++;
          }
        } catch (_) {}
        
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
  
  /// Recursively scans a directory tree
  Future<FileSystemNode> scanDirectoryTree(String dirPath, {int maxDepth = 10}) async {
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
  
  /// Decrypts a file to a temporary location
  Future<String> decryptFile(FileSystemNode file, String keyBase64) async {
    if (file.isDirectory) {
      throw Exception('Cannot decrypt a directory');
    }
    
    final inputFile = File(file.path);
    final encryptedData = await inputFile.readAsBytes();
    
    final decryptedData = await _cryptoService.decrypt(encryptedData, keyBase64);
    
    // Create temp file
    final tempDir = await Directory.systemTemp.createTemp('safedisk_');
    final tempFile = File('${tempDir.path}/${file.name}');
    await tempFile.writeAsBytes(decryptedData);
    
    return tempFile.path;
  }
  
  /// Encrypts a file and saves to encrypted directory
  Future<void> encryptFile(String inputPath, String outputDir, String keyBase64) async {
    final inputFile = File(inputPath);
    final plaintext = await inputFile.readAsBytes();
    
    final encrypted = await _cryptoService.encrypt(plaintext, keyBase64);
    
    final name = inputPath.split('/').last;
    final outputFile = File('$outputDir/$name');
    await outputFile.writeAsBytes(encrypted);
  }
  
  /// Exports decrypted file to a user-selected location
  Future<void> exportFile(FileSystemNode file, String outputPath, String keyBase64) async {
    if (file.isDirectory) {
      throw Exception('Cannot export a directory');
    }
    
    final inputFile = File(file.path);
    final encryptedData = await inputFile.readAsBytes();
    
    final decryptedData = await _cryptoService.decrypt(encryptedData, keyBase64);
    
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(decryptedData);
  }
  
  /// Creates a new subdirectory
  Future<FileSystemNode> createDirectory(String parentPath, String dirName) async {
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
