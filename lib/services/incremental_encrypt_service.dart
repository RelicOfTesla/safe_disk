import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../native/native_lib.dart';
import '../models/ffi_results.dart';

/// Progress callback type for incremental encryption operations
/// currentBytes: bytes processed so far
/// totalBytes: total bytes to process
/// percent: completion percentage (0-100)
typedef ProgressCallback = void Function(
    int currentBytes, int totalBytes, int percent);

/// Error callback type for incremental encryption operations
typedef ErrorCallback = void Function(String error);

/// Incremental encryptor for streaming file encryption
///
/// This class provides memory-efficient encryption for large files by processing
/// data in chunks. The encryption is performed incrementally, allowing progress
/// tracking and cancellation.
///
/// Usage:
/// ```dart
/// final encryptor = IncrementalEncryptor(
///   dstPath: '/path/to/output.enc',
///   keyBase64: 'base64-encoded-32-byte-key',
///   chunkSizeKB: 64, // Optional, default 64KB
///   onProgress: (current, total, percent) {
///     print('Progress: $percent%');
///   },
///   onError: (error) {
///     print('Error: $error');
///   },
/// );
///
/// // Add data in chunks
/// await encryptor.addBlock(dataChunk1);
/// await encryptor.addBlock(dataChunk2);
///
/// // Finalize encryption
/// await encryptor.finalize();
///
/// // Or close without finalizing (aborts encryption)
/// await encryptor.close();
/// ```
class IncrementalEncryptor {
  final String dstPath;
  final String keyBase64;
  final int chunkSizeKB;
  final ProgressCallback? onProgress;
  final ErrorCallback? onError;

  NativeLib? _native;

  int? _handleID;
  bool _isFinalized = false;
  bool _isClosed = false;
  int _totalBytesWritten = 0;

  /// Creates a new incremental encryptor
  IncrementalEncryptor({
    required this.dstPath,
    required this.keyBase64,
    this.chunkSizeKB = 64,
    this.onProgress,
    this.onError,
  });

  /// Lazily initializes and returns the native library
  NativeLib get _nativeLib {
    _native ??= NativeLib.instance;
    return _native!;
  }

  /// Initializes the encryptor and creates the output file
  /// Returns true if successful, false otherwise
  Future<bool> initialize() async {
    if (_handleID != null) {
      return true; // Already initialized
    }

    try {
      final resultStr = _nativeLib.incrementalEncryptorCreate(
        dstPath,
        keyBase64,
        chunkSizeKB,
      );
      final result = IncrementalEncryptorResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to create encryptor');
        return false;
      }

      _handleID = result.handleIDOrThrow;
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Adds a block of data to be encrypted
  /// data: the data block to encrypt
  /// Returns true if successful, false otherwise
  Future<bool> addBlock(Uint8List data) async {
    if (_isFinalized || _isClosed) {
      onError?.call('Encryptor is already finalized or closed');
      return false;
    }

    if (_handleID == null) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      final dataBase64 = base64Encode(data);
      final resultStr =
          _nativeLib.incrementalEncryptorAddBlock(_handleID!, dataBase64);
      final result = FFIResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to add block');
        return false;
      }

      _totalBytesWritten += data.length;

      // Progress is tracked by total bytes written
      // Note: We don't know total size ahead of time for streaming encryption
      onProgress?.call(_totalBytesWritten, 0, 0);

      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Adds a string as a block (convenience method)
  /// text: the text to encrypt
  /// encoding: text encoding (default UTF-8)
  /// Returns true if successful, false otherwise
  Future<bool> addTextBlock(String text, {Encoding encoding = utf8}) async {
    return addBlock(Uint8List.fromList(encoding.encode(text)));
  }

  /// Finalizes the encryption and writes the file
  /// Returns true if successful, false otherwise
  Future<bool> finalize() async {
    if (_isFinalized) {
      return true; // Already finalized
    }

    if (_isClosed) {
      onError?.call('Encryptor is already closed');
      return false;
    }

    if (_handleID == null) {
      onError?.call('Encryptor was not initialized');
      return false;
    }

    try {
      final resultStr = _nativeLib.incrementalEncryptorFinalize(_handleID!);
      final result = FFIResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to finalize encryption');
        return false;
      }

      _isFinalized = true;
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Closes the encryptor without finalizing (aborts encryption)
  Future<void> close() async {
    if (_isClosed) {
      return; // Already closed
    }

    if (_handleID != null && !_isFinalized) {
      try {
        _nativeLib.incrementalEncryptorClose(_handleID!);
      } catch (e) {
        // Ignore errors on close
      }
    }

    _isClosed = true;
    _handleID = null;
  }

  /// Returns true if the encryptor is finalized
  bool get isFinalized => _isFinalized;

  /// Returns true if the encryptor is closed
  bool get isClosed => _isClosed;

  /// Returns the total bytes written so far
  int get totalBytesWritten => _totalBytesWritten;
}

/// Incremental decryptor for streaming file decryption
///
/// This class provides memory-efficient decryption for incrementally encrypted files.
/// Supports random access to specific blocks, byte ranges, and integrity verification.
///
/// Usage:
/// ```dart
/// final decryptor = IncrementalDecryptor(
///   srcPath: '/path/to/file.enc',
///   keyBase64: 'base64-encoded-32-byte-key',
///   onProgress: (current, total, percent) {
///     print('Progress: $percent%');
///   },
///   onError: (error) {
///     print('Error: $error');
///   },
/// );
///
/// if (await decryptor.open()) {
///   // Decrypt specific block
///   final block0 = await decryptor.decryptBlock(0);
///
///   // Decrypt byte range
///   final range = await decryptor.decryptRange(100, 500);
///
///   // Decrypt all
///   final all = await decryptor.decryptAll();
///
///   // Verify integrity
///   final isValid = await decryptor.verifyIntegrity();
///
///   // Close when done
///   await decryptor.close();
/// }
/// ```
class IncrementalDecryptor {
  final String srcPath;
  final String keyBase64;
  final ProgressCallback? onProgress;
  final ErrorCallback? onError;

  NativeLib? _native;

  int? _handleID;
  bool _isOpen = false;
  bool _isClosed = false;
  int _chunkCount = 0;
  int _totalSize = 0;

  /// Creates a new incremental decryptor
  IncrementalDecryptor({
    required this.srcPath,
    required this.keyBase64,
    this.onProgress,
    this.onError,
  });

  /// Lazily initializes and returns the native library
  NativeLib get _nativeLib {
    _native ??= NativeLib.instance;
    return _native!;
  }

  /// Opens the encrypted file for decryption
  /// Returns true if successful, false otherwise
  Future<bool> open() async {
    if (_isOpen) {
      return true; // Already open
    }

    if (_isClosed) {
      onError?.call('Decryptor is already closed');
      return false;
    }

    try {
      final resultStr = _nativeLib.incrementalDecryptorOpen(srcPath, keyBase64);
      final result = IncrementalDecryptorResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to open decryptor');
        return false;
      }

      _handleID = result.handleIDOrThrow;
      _chunkCount = result.chunkCount ?? 0;
      _totalSize = result.totalSize ?? 0;
      _isOpen = true;
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Ensures the decryptor is open before operations
  void _ensureOpen() {
    if (!_isOpen || _handleID == null) {
      throw StateError('Decryptor is not open. Call open() first.');
    }
    if (_isClosed) {
      throw StateError('Decryptor is closed.');
    }
  }

  /// Decrypts a specific block by index
  /// blockIndex: 0-based block index
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptBlock(int blockIndex) async {
    _ensureOpen();

    try {
      final resultStr =
          _nativeLib.incrementalDecryptorDecryptBlock(_handleID!, blockIndex);
      final result = IncrementalBlockResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to decrypt block $blockIndex');
        return null;
      }

      _reportProgress(blockIndex + 1, _chunkCount);
      return result.dataOrThrow;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Decrypts a range of bytes from the file
  /// offset: byte offset in the plaintext
  /// length: number of bytes to decrypt
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptRange(int offset, int length) async {
    _ensureOpen();

    try {
      final resultStr = _nativeLib.incrementalDecryptorDecryptRange(
          _handleID!, offset, length);
      final result = IncrementalBlockResult.fromJson(resultStr);

      if (!result.success) {
        onError
            ?.call(result.error ?? 'Failed to decrypt range $offset-$length');
        return null;
      }

      return result.dataOrThrow;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Decrypts the entire file
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptAll() async {
    _ensureOpen();

    try {
      final resultStr = _nativeLib.incrementalDecryptorDecryptAll(_handleID!);
      final result = IncrementalBlockResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to decrypt all');
        return null;
      }

      _reportProgress(_chunkCount, _chunkCount);
      return result.dataOrThrow;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Decrypts the entire file as a string
  /// encoding: text encoding (default UTF-8)
  /// Returns the decrypted string, or null on error
  Future<String?> decryptAllAsString({Encoding encoding = utf8}) async {
    final data = await decryptAll();
    if (data == null) return null;
    return encoding.decode(data);
  }

  /// Verifies the integrity of a specific block
  /// blockIndex: 0-based block index
  /// Returns true if the block is valid, false otherwise
  Future<bool> verifyBlockIntegrity(int blockIndex) async {
    _ensureOpen();

    try {
      final resultStr = _nativeLib.incrementalDecryptorVerifyBlockIntegrity(
          _handleID!, blockIndex);
      final result = FFIResult.fromJson(resultStr);
      return result.success;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Verifies the integrity of the entire file
  /// Returns true if the file is valid, false otherwise
  Future<bool> verifyIntegrity() async {
    _ensureOpen();

    try {
      final resultStr =
          _nativeLib.incrementalDecryptorVerifyIntegrity(_handleID!);
      final result = FFIResult.fromJson(resultStr);
      return result.success;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Returns information about a specific block
  /// blockIndex: 0-based block index
  /// Returns the block info, or null on error
  Future<IncrementalBlockInfo?> getBlockInfo(int blockIndex) async {
    _ensureOpen();

    try {
      final resultStr =
          _nativeLib.incrementalDecryptorGetBlockInfo(_handleID!, blockIndex);
      final result = IncrementalBlockInfoResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to get block info');
        return null;
      }

      return result.blockInfo;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Returns information about all blocks
  /// Returns a list of block info, or null on error
  Future<List<IncrementalBlockInfo>?> getAllBlockInfo() async {
    _ensureOpen();

    try {
      final resultStr =
          _nativeLib.incrementalDecryptorGetAllBlockInfo(_handleID!);
      final result = IncrementalAllBlockInfoResult.fromJson(resultStr);

      if (!result.success) {
        onError?.call(result.error ?? 'Failed to get all block info');
        return null;
      }

      return result.blockInfos;
    } catch (e) {
      onError?.call(e.toString());
      return null;
    }
  }

  /// Closes the decryptor and releases resources
  Future<void> close() async {
    if (_isClosed) {
      return; // Already closed
    }

    if (_handleID != null) {
      try {
        _nativeLib.incrementalDecryptorClose(_handleID!);
      } catch (e) {
        // Ignore errors on close
      }
    }

    _isClosed = true;
    _isOpen = false;
    _handleID = null;
  }

  /// Reports progress to the callback
  void _reportProgress(int current, int total) {
    if (onProgress != null && total > 0) {
      final percent = ((current / total) * 100).round();
      onProgress!(current, total, percent);
    }
  }

  /// Returns true if the decryptor is open
  bool get isOpen => _isOpen;

  /// Returns true if the decryptor is closed
  bool get isClosed => _isClosed;

  /// Returns the number of chunks in the file
  int get chunkCount => _chunkCount;

  /// Returns the total size of the decrypted file
  int get totalSize => _totalSize;
}

/// Service for incremental encryption and decryption operations
///
/// This service provides high-level methods for working with incrementally
/// encrypted files. It supports:
/// - Streaming encryption of large files
/// - Random access decryption
/// - Integrity verification
/// - Progress tracking
///
/// Usage:
/// ```dart
/// final service = IncrementalEncryptService();
///
/// // Encrypt a file incrementally
/// await service.encryptFileIncremental(
///   srcPath: '/path/to/large/file.txt',
///   dstPath: '/path/to/output.enc',
///   keyBase64: 'base64-encoded-key',
///   onProgress: (current, total, percent) {
///     print('Encrypting: $percent%');
///   },
/// );
///
/// // Decrypt a file incrementally
/// await service.decryptFileIncremental(
///   srcPath: '/path/to/output.enc',
///   dstPath: '/path/to/decrypted.txt',
///   keyBase64: 'base64-encoded-key',
///   onProgress: (current, total, percent) {
///     print('Decrypting: $percent%');
///   },
/// );
/// ```
class IncrementalEncryptService {
  NativeLib? _native;

  static IncrementalEncryptService? _instance;

  static IncrementalEncryptService get instance {
    _instance ??= IncrementalEncryptService._();
    return _instance!;
  }

  IncrementalEncryptService._();

  /// Lazily initializes and returns the native library
  NativeLib get _nativeLib {
    _native ??= NativeLib.instance;
    return _native!;
  }

  /// Default chunk size in KB (64 KB)
  static const int defaultChunkSizeKB = 64;

  /// Creates an incremental encryptor
  /// dstPath: destination file path for the encrypted file
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns the encryptor instance
  IncrementalEncryptor createEncryptor({
    required String dstPath,
    required String keyBase64,
    int chunkSizeKB = defaultChunkSizeKB,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) {
    return IncrementalEncryptor(
      dstPath: dstPath,
      keyBase64: keyBase64,
      chunkSizeKB: chunkSizeKB,
      onProgress: onProgress,
      onError: onError,
    );
  }

  /// Opens an incremental decryptor
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns the decryptor instance, or null on error
  Future<IncrementalDecryptor?> openDecryptor({
    required String srcPath,
    required String keyBase64,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    final decryptor = IncrementalDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onProgress: onProgress,
      onError: onError,
    );

    if (await decryptor.open()) {
      return decryptor;
    }
    return null;
  }

  /// Checks if a file is in incremental encrypted format
  /// path: file path to check
  /// Returns true if incremental, false otherwise
  bool isIncrementalFile(String path) {
    try {
      final resultStr = _nativeLib.isIncrementalFile(path);
      final result = IsIncrementalResult.fromJson(resultStr);
      return result.isIncrementalOrThrow;
    } catch (e) {
      return false;
    }
  }

  /// Gets metadata about an incremental encrypted file
  /// path: file path
  /// Returns the file info, or null on error
  Future<IncrementalFileHeader?> getFileInfo(String path) async {
    try {
      final resultStr = _nativeLib.getIncrementalFileInfo(path);
      final result = IncrementalFileInfoResult.fromJson(resultStr);

      if (!result.success) {
        return null;
      }

      return result.header;
    } catch (e) {
      return null;
    }
  }

  /// Encrypts a file incrementally (streaming)
  /// srcPath: source file path
  /// dstPath: destination encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns true if successful, false otherwise
  ///
  /// Note: This method reads the file in chunks and encrypts each chunk,
  /// making it memory-efficient for large files.
  Future<bool> encryptFileIncremental({
    required String srcPath,
    required String dstPath,
    required String keyBase64,
    int chunkSizeKB = defaultChunkSizeKB,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    final srcFile = File(srcPath);
    if (!await srcFile.exists()) {
      onError?.call('Source file does not exist: $srcPath');
      return false;
    }

    try {
      final fileSize = await srcFile.length();
      final chunkSize = chunkSizeKB * 1024;

      final encryptor = createEncryptor(
        dstPath: dstPath,
        keyBase64: keyBase64,
        chunkSizeKB: chunkSizeKB,
        onError: onError,
      );

      if (!await encryptor.initialize()) {
        return false;
      }

      final raf = await srcFile.open(mode: FileMode.read);
      try {
        var bytesProcessed = 0;
        final buffer = Uint8List(chunkSize);

        while (bytesProcessed < fileSize) {
          final bytesRead = await raf.readInto(buffer);
          if (bytesRead == 0) break;

          final chunk = buffer.sublist(0, bytesRead);
          if (!await encryptor.addBlock(chunk)) {
            await encryptor.close();
            return false;
          }

          bytesProcessed += bytesRead;
          _reportProgress(bytesProcessed, fileSize, onProgress);
        }
      } finally {
        await raf.close();
      }

      final success = await encryptor.finalize();
      return success;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Decrypts a file incrementally (streaming)
  /// srcPath: source encrypted file path
  /// dstPath: destination decrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns true if successful, false otherwise
  ///
  /// Note: This method decrypts all blocks and writes them to the output file.
  /// For random access decryption, use openDecryptor() instead.
  Future<bool> decryptFileIncremental({
    required String srcPath,
    required String dstPath,
    required String keyBase64,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    final decryptor = await openDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onProgress: onProgress,
      onError: onError,
    );

    if (decryptor == null) {
      return false;
    }

    try {
      final allData = await decryptor.decryptAll();
      if (allData == null) {
        return false;
      }

      final dstFile = File(dstPath);
      await dstFile.parent.create(recursive: true);
      await dstFile.writeAsBytes(allData);
      return true;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    } finally {
      await decryptor.close();
    }
  }

  /// Decrypts a specific block from an encrypted file
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// blockIndex: 0-based block index
  /// onError: optional error callback
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptBlock({
    required String srcPath,
    required String keyBase64,
    required int blockIndex,
    ErrorCallback? onError,
  }) async {
    final decryptor = await openDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onError: onError,
    );

    if (decryptor == null) {
      return null;
    }

    try {
      return await decryptor.decryptBlock(blockIndex);
    } finally {
      await decryptor.close();
    }
  }

  /// Decrypts a byte range from an encrypted file
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// offset: byte offset in the plaintext
  /// length: number of bytes to decrypt
  /// onError: optional error callback
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptRange({
    required String srcPath,
    required String keyBase64,
    required int offset,
    required int length,
    ErrorCallback? onError,
  }) async {
    final decryptor = await openDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onError: onError,
    );

    if (decryptor == null) {
      return null;
    }

    try {
      return await decryptor.decryptRange(offset, length);
    } finally {
      await decryptor.close();
    }
  }

  /// Verifies the integrity of an encrypted file
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// onError: optional error callback
  /// Returns true if valid, false otherwise
  Future<bool> verifyIntegrity({
    required String srcPath,
    required String keyBase64,
    ErrorCallback? onError,
  }) async {
    final decryptor = await openDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onError: onError,
    );

    if (decryptor == null) {
      return false;
    }

    try {
      return await decryptor.verifyIntegrity();
    } finally {
      await decryptor.close();
    }
  }

  /// Encrypts data incrementally (in-memory)
  /// data: data to encrypt
  /// dstPath: destination encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns true if successful, false otherwise
  Future<bool> encryptDataIncremental({
    required Uint8List data,
    required String dstPath,
    required String keyBase64,
    int chunkSizeKB = defaultChunkSizeKB,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    try {
      final chunkSize = chunkSizeKB * 1024;

      final encryptor = createEncryptor(
        dstPath: dstPath,
        keyBase64: keyBase64,
        chunkSizeKB: chunkSizeKB,
        onError: onError,
      );

      if (!await encryptor.initialize()) {
        return false;
      }

      var offset = 0;
      while (offset < data.length) {
        final end = (offset + chunkSize < data.length)
            ? offset + chunkSize
            : data.length;
        final chunk = data.sublist(offset, end);

        if (!await encryptor.addBlock(chunk)) {
          await encryptor.close();
          return false;
        }

        offset = end;
        _reportProgress(offset, data.length, onProgress);
      }

      final success = await encryptor.finalize();
      return success;
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  /// Encrypts a string incrementally (in-memory)
  /// text: text to encrypt
  /// dstPath: destination encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// encoding: text encoding (default UTF-8)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns true if successful, false otherwise
  Future<bool> encryptTextIncremental({
    required String text,
    required String dstPath,
    required String keyBase64,
    int chunkSizeKB = defaultChunkSizeKB,
    Encoding encoding = utf8,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    return encryptDataIncremental(
      data: Uint8List.fromList(encoding.encode(text)),
      dstPath: dstPath,
      keyBase64: keyBase64,
      chunkSizeKB: chunkSizeKB,
      onProgress: onProgress,
      onError: onError,
    );
  }

  /// Decrypts all data from an encrypted file
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns the decrypted data, or null on error
  Future<Uint8List?> decryptAllData({
    required String srcPath,
    required String keyBase64,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    final decryptor = await openDecryptor(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onProgress: onProgress,
      onError: onError,
    );

    if (decryptor == null) {
      return null;
    }

    try {
      return await decryptor.decryptAll();
    } finally {
      await decryptor.close();
    }
  }

  /// Decrypts all data from an encrypted file as a string
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// encoding: text encoding (default UTF-8)
  /// onProgress: optional progress callback
  /// onError: optional error callback
  /// Returns the decrypted string, or null on error
  Future<String?> decryptAllAsString({
    required String srcPath,
    required String keyBase64,
    Encoding encoding = utf8,
    ProgressCallback? onProgress,
    ErrorCallback? onError,
  }) async {
    final data = await decryptAllData(
      srcPath: srcPath,
      keyBase64: keyBase64,
      onProgress: onProgress,
      onError: onError,
    );

    if (data == null) return null;
    return encoding.decode(data);
  }

  /// Reports progress to the callback
  void _reportProgress(int current, int total, ProgressCallback? onProgress) {
    if (onProgress != null && total > 0) {
      final percent = ((current / total) * 100).round();
      onProgress(current, total, percent);
    }
  }
}
