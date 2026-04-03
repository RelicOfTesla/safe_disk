import 'dart:ffi';
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
  String makeTemporaryKeyID(String inputPass, String configJSON, {int ttlSeconds = 0}) {
    final inputPassPtr = inputPass.toNativeUtf8();
    final configJSONPtr = configJSON.toNativeUtf8();
    
    try {
      final resultPtr = _bindings.makeTemporaryKeyID(inputPassPtr, configJSONPtr, ttlSeconds);
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
  String encryptFileChunked(String srcPath, String toPath, String tempKeyID, {int chunkSizeKB = 0}) {
    final srcPtr = srcPath.toNativeUtf8();
    final toPtr = toPath.toNativeUtf8();
    final keyIDPtr = tempKeyID.toNativeUtf8();
    
    try {
      final resultPtr = _bindings.encryptFileChunked(srcPtr, toPtr, keyIDPtr, chunkSizeKB);
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
  String generateEncryptionConfig(String password, int keyStrengthMs, bool mutable, String challengeId) {
    final passwordPtr = password.toNativeUtf8();
    final challengeIdPtr = challengeId.toNativeUtf8();
    
    try {
      final resultPtr = _bindings.generateEncryptionConfig(passwordPtr, keyStrengthMs, mutable ? 1 : 0, challengeIdPtr);
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
      final resultPtr = _bindings.createEncryptedDirectory(dirPathPtr, configJSONPtr);
      final result = resultPtr.toDartString();
      return result;
    } finally {
      calloc.free(dirPathPtr);
      calloc.free(configJSONPtr);
    }
  }
}
