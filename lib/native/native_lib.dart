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

  // ==================== NEW FFI INTERFACE ====================

  /// Verifies if the password is correct
  /// inputPass: user input password
  /// configJSON: config JSON string (from _cryption.json)
  /// Returns: true if correct, false if incorrect
  bool verifyPassword(String inputPass, String configJSON) {
    final inputPassPtr = inputPass.toNativeUtf8();
    final configJSONPtr = configJSON.toNativeUtf8();

    try {
      final result = _bindings.verifyPassword(inputPassPtr, configJSONPtr);
      return result == 1;
    } finally {
      calloc.free(inputPassPtr);
      calloc.free(configJSONPtr);
    }
  }

  /// Generates a temporary key ID for session use
  /// inputPass: user input password
  /// configJSON: config JSON string (from _cryption.json)
  /// ttlSeconds: time-to-live in seconds (0 = default 3600s)
  /// Returns: temporary key ID (hex string) or empty string on error
  String makeTemporaryKeyID(String inputPass, String configJSON,
      {int ttlSeconds = 0}) {
    final inputPassPtr = inputPass.toNativeUtf8();
    final configJSONPtr = configJSON.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.makeTemporaryKeyID(inputPassPtr, configJSONPtr, ttlSeconds);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(inputPassPtr);
      calloc.free(configJSONPtr);
    }
  }

  /// Encrypts data with temporary key ID
  /// dataBase64: base64-encoded data to encrypt
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: base64-encoded encrypted data or empty string on error
  String encryptData(String dataBase64, String tempKeyID) {
    final dataPtr = dataBase64.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr = _bindings.encryptData(dataPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dataPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Decrypts data with temporary key ID
  /// dataBase64: base64-encoded encrypted data
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: base64-encoded decrypted data or empty string on error
  String decryptData(String dataBase64, String tempKeyID) {
    final dataPtr = dataBase64.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr = _bindings.decryptData(dataPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dataPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Encrypts a file with temporary key ID
  /// srcPath: source file path
  /// toPath: destination file path
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: JSON result {"success": true} or {"success": false, "error": "..."}
  String encryptFile(String srcPath, String toPath, String tempKeyID) {
    final srcPtr = srcPath.toNativeUtf8();
    final toPtr = toPath.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr = _bindings.encryptFile(srcPtr, toPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(toPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Decrypts a file with temporary key ID and returns the data
  /// path: encrypted file path
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: base64-encoded decrypted data or empty string on error
  String decryptFileToData(String path, String tempKeyID) {
    final pathPtr = path.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr = _bindings.decryptFileToData(pathPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
      calloc.free(keyIDPtr);
    }
  }

  // ==================== STREAMING FILE OPERATIONS ====================

  /// Decrypts an encrypted file directly to another file path.
  /// This is memory-efficient for large files - uses streaming decryption for chunked files.
  /// srcPath: source encrypted file path
  /// toPath: destination decrypted file path
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: JSON result {"success": true} or {"success": false, "error": "..."}
  String decryptFileToPath(String srcPath, String toPath, String tempKeyID) {
    final srcPtr = srcPath.toNativeUtf8();
    final toPtr = toPath.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr = _bindings.decryptFileToPath(srcPtr, toPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(toPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Encrypts a file using chunked format (memory-efficient for large files).
  /// This format supports streaming decryption - only one chunk is loaded into memory at a time.
  /// srcPath: source file path
  /// toPath: destination encrypted file path
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// Returns: JSON result {"success": true} or {"success": false, "error": "..."}
  String encryptFileChunked(String srcPath, String toPath, String tempKeyID,
      {int chunkSizeKB = 0}) {
    final srcPtr = srcPath.toNativeUtf8();
    final toPtr = toPath.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.encryptFileChunked(srcPtr, toPtr, keyIDPtr, chunkSizeKB);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(toPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Checks if a file is in chunked encrypted format.
  /// path: file path to check
  /// Returns: JSON result {"success": true, "isChunked": true/false}
  String isChunkedFile(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.isChunkedFile(pathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Gets information about an encrypted file.
  /// path: file path
  /// Returns: JSON result with file info (size, isChunked, recommendedMethod)
  String getEncryptedFileInfo(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.getEncryptedFileInfo(pathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }

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

  // ==================== ASYNC DIRECTORY OPERATIONS ====================

  /// Starts an async directory encryption job.
  /// srcDir: source directory path (plaintext files)
  /// dstDir: destination directory path (encrypted files)
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: JSON result {"success": true, "jobID": "..."} or error
  String encryptDirectoryAsync(String srcDir, String dstDir, String tempKeyID) {
    final srcPtr = srcDir.toNativeUtf8();
    final dstPtr = dstDir.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.encryptDirectoryAsync(srcPtr, dstPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Starts an async directory decryption job.
  /// srcDir: source directory path (encrypted files)
  /// dstDir: destination directory path (decrypted files)
  /// tempKeyID: temporary key ID (from makeTemporaryKeyID)
  /// Returns: JSON result {"success": true, "jobID": "..."} or error
  String decryptDirectoryAsync(String srcDir, String dstDir, String tempKeyID) {
    final srcPtr = srcDir.toNativeUtf8();
    final dstPtr = dstDir.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.decryptDirectoryAsync(srcPtr, dstPtr, keyIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPtr);
      calloc.free(dstPtr);
      calloc.free(keyIDPtr);
    }
  }

  /// Gets the progress of an async job.
  /// jobID: job ID (from encryptDirectoryAsync or decryptDirectoryAsync)
  /// Returns: JSON result {"success": true, "progress": {...}} or error
  String getJobProgress(String jobID) {
    final jobIDPtr = jobID.toNativeUtf8();

    try {
      final resultPtr = _bindings.getJobProgress(jobIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(jobIDPtr);
    }
  }

  /// Gets the status of an async job.
  /// jobID: job ID
  /// Returns: JSON result {"success": true, "status": "pending|running|completed|cancelled|failed"} or error
  String getJobStatus(String jobID) {
    final jobIDPtr = jobID.toNativeUtf8();

    try {
      final resultPtr = _bindings.getJobStatus(jobIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(jobIDPtr);
    }
  }

  /// Cancels an async job.
  /// jobID: job ID
  /// Returns: JSON result {"success": true} or error
  String cancelJob(String jobID) {
    final jobIDPtr = jobID.toNativeUtf8();

    try {
      final resultPtr = _bindings.cancelJob(jobIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(jobIDPtr);
    }
  }

  /// Deletes an async job.
  /// jobID: job ID
  /// Returns: JSON result {"success": true}
  String deleteJob(String jobID) {
    final jobIDPtr = jobID.toNativeUtf8();

    try {
      final resultPtr = _bindings.deleteJob(jobIDPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(jobIDPtr);
    }
  }

  // ==================== INCREMENTAL ENCRYPTION OPERATIONS ====================

  /// Creates a new incremental encryptor.
  /// dstPath: destination file path for the encrypted file
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// Returns: JSON result {"success": true, "handleID": ...} or error
  String incrementalEncryptorCreate(
      String dstPath, String keyBase64, int chunkSizeKB) {
    final dstPathPtr = dstPath.toNativeUtf8();
    final keyBase64Ptr = keyBase64.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.incrementalEncryptorCreate(dstPathPtr, keyBase64Ptr, chunkSizeKB);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dstPathPtr);
      calloc.free(keyBase64Ptr);
    }
  }

  /// Adds a block to the incremental encryptor.
  /// handleID: encryptor handle ID (from incrementalEncryptorCreate)
  /// dataBase64: base64-encoded block data
  /// Returns: JSON result {"success": true} or error
  String incrementalEncryptorAddBlock(int handleID, String dataBase64) {
    final dataBase64Ptr = dataBase64.toNativeUtf8();

    try {
      final resultPtr = _bindings.incrementalEncryptorAddBlock(handleID, dataBase64Ptr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dataBase64Ptr);
    }
  }

  /// Finalizes the incremental encryptor and writes the file.
  /// handleID: encryptor handle ID (from incrementalEncryptorCreate)
  /// Returns: JSON result {"success": true} or error
  String incrementalEncryptorFinalize(int handleID) {
    final resultPtr = _bindings.incrementalEncryptorFinalize(handleID);
    return resultPtr.toDartString();
  }

  /// Closes the incremental encryptor without finalizing.
  /// handleID: encryptor handle ID (from incrementalEncryptorCreate)
  /// Returns: JSON result {"success": true} or error
  String incrementalEncryptorClose(int handleID) {
    final resultPtr = _bindings.incrementalEncryptorClose(handleID);
    return resultPtr.toDartString();
  }

  /// Opens an incremental encrypted file for reading.
  /// srcPath: source encrypted file path
  /// keyBase64: base64-encoded 32-byte key (AES-256)
  /// Returns: JSON result {"success": true, "handleID": ..., "chunkCount": ..., "totalSize": ...} or error
  String incrementalDecryptorOpen(String srcPath, String keyBase64) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final keyBase64Ptr = keyBase64.toNativeUtf8();

    try {
      final resultPtr = _bindings.incrementalDecryptorOpen(srcPathPtr, keyBase64Ptr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(keyBase64Ptr);
    }
  }

  /// Decrypts a specific block by index.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// blockIndex: block index (0-based)
  /// Returns: JSON result {"success": true, "data": "...base64..."} or error
  String incrementalDecryptorDecryptBlock(int handleID, int blockIndex) {
    final resultPtr = _bindings.incrementalDecryptorDecryptBlock(handleID, blockIndex);
    return resultPtr.toDartString();
  }

  /// Decrypts a range of bytes from the file.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// offset: byte offset in the plaintext
  /// length: number of bytes to decrypt
  /// Returns: JSON result {"success": true, "data": "...base64..."} or error
  String incrementalDecryptorDecryptRange(int handleID, int offset, int length) {
    final resultPtr = _bindings.incrementalDecryptorDecryptRange(handleID, offset, length);
    return resultPtr.toDartString();
  }

  /// Decrypts the entire file.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// Returns: JSON result {"success": true, "data": "...base64..."} or error
  String incrementalDecryptorDecryptAll(int handleID) {
    final resultPtr = _bindings.incrementalDecryptorDecryptAll(handleID);
    return resultPtr.toDartString();
  }

  /// Verifies the integrity of a specific block.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// blockIndex: block index (0-based)
  /// Returns: JSON result {"success": true} or error
  String incrementalDecryptorVerifyBlockIntegrity(int handleID, int blockIndex) {
    final resultPtr = _bindings.incrementalDecryptorVerifyBlockIntegrity(handleID, blockIndex);
    return resultPtr.toDartString();
  }

  /// Verifies the integrity of the entire file.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// Returns: JSON result {"success": true} or error
  String incrementalDecryptorVerifyIntegrity(int handleID) {
    final resultPtr = _bindings.incrementalDecryptorVerifyIntegrity(handleID);
    return resultPtr.toDartString();
  }

  /// Returns information about a specific block.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// blockIndex: block index (0-based)
  /// Returns: JSON result {"success": true, "blockInfo": {...}} or error
  String incrementalDecryptorGetBlockInfo(int handleID, int blockIndex) {
    final resultPtr = _bindings.incrementalDecryptorGetBlockInfo(handleID, blockIndex);
    return resultPtr.toDartString();
  }

  /// Returns information about all blocks.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// Returns: JSON result {"success": true, "blockInfos": [...]} or error
  String incrementalDecryptorGetAllBlockInfo(int handleID) {
    final resultPtr = _bindings.incrementalDecryptorGetAllBlockInfo(handleID);
    return resultPtr.toDartString();
  }

  /// Closes the incremental decryptor.
  /// handleID: decryptor handle ID (from incrementalDecryptorOpen)
  /// Returns: JSON result {"success": true} or error
  String incrementalDecryptorClose(int handleID) {
    final resultPtr = _bindings.incrementalDecryptorClose(handleID);
    return resultPtr.toDartString();
  }

  /// Checks if a file is in incremental encrypted format.
  /// path: file path to check
  /// Returns: JSON result {"success": true, "isIncremental": true/false} or error
  String isIncrementalFile(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.isIncrementalFile(pathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Returns metadata about an incremental encrypted file.
  /// path: file path
  /// Returns: JSON result {"success": true, "header": {...}} or error
  String getIncrementalFileInfo(String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.getIncrementalFileInfo(pathPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(pathPtr);
    }
  }
}
