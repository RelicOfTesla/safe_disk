import 'dart:convert';
import 'dart:typed_data';
import '../native/native_lib.dart';
import '../models/cryption_config.dart';
import '../models/ffi_results.dart';

/// Crypto service for Safe Disk encryption operations
///
/// This service provides stateless encryption operations using the native library.
/// All key derivation and management is handled by the backend (Go FFI).
///
/// **Architecture Design**:
/// - **Stateless**: No internal state management
/// - **Explicit key ID**: All operations require explicit tempKeyID parameter
/// - **External management**: Caller is responsible for managing tempKeyID
/// - **Flexible**: Supports any key management strategy (single directory, multi-directory, subdirectories, etc.)
///
/// **Usage**:
/// ```dart
/// // Step 1: Verify password
/// final result = cryptoService.verifyPassword(password, configJSON);
/// if (!result.success) {
///   print('Password incorrect: ${result.error}');
///   return;
/// }
///
/// // Step 2: Create session and get tempKeyID
/// final tempKeyID = cryptoService.createSession(password, configJSON);
/// // NOTE: Caller should store tempKeyID (e.g., in a Map, State, or Provider)
///
/// // Step 3: Use tempKeyID for encryption/decryption
/// final encrypted = cryptoService.encryptData(data, tempKeyID);
/// final decrypted = cryptoService.decryptData(encrypted, tempKeyID);
/// ```
class CryptoService {
  final NativeLib _native = NativeLib.instance;

  // ==================== SESSION MANAGEMENT ====================

  /// Creates a session and returns the temporary key ID
  /// The caller is responsible for storing and managing the key ID
  /// password: user password
  /// configJSON: config JSON string (from _cryption.json)
  /// Returns: temporary key ID (caller should store it)
  String createSession(String password, String configJSON) {
    final resultStr = _native.makeTemporaryKeyID(password, configJSON,
        ttlSeconds: 3600); // 1 hour TTL
    final result = SessionResult.fromJson(resultStr);
    return result.tempKeyIDOrThrow;
  }

  // ==================== PASSWORD VERIFICATION ====================

  /// Verifies if the password is correct
  /// inputPass: user input password
  /// configJSON: config JSON string (from _cryption.json)
  /// Returns: VerifyResult with success status and error message
  VerifyResult verifyPassword(String inputPass, String configJSON) {
    final success = _native.verifyPassword(inputPass, configJSON);
    if (success) {
      return VerifyResult(success: true);
    } else {
      return VerifyResult(
          success: false, error: 'Password verification failed');
    }
  }

  // ==================== DATA ENCRYPTION/DECRYPTION ====================

  /// Encrypts data with a temporary key ID
  /// data: plaintext data
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: encrypted data (base64)
  String encryptData(String data, String tempKeyID) {
    final dataBase64 = base64Encode(utf8.encode(data));
    final resultStr = _native.encryptData(dataBase64, tempKeyID);
    final result = DataResult.fromJson(resultStr);
    return base64Encode(result.dataOrThrow);
  }

  /// Encrypts binary data with a temporary key ID
  /// data: binary data
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: encrypted data (base64)
  String encryptDataBytes(Uint8List data, String tempKeyID) {
    final dataBase64 = base64Encode(data);
    final resultStr = _native.encryptData(dataBase64, tempKeyID);
    final result = DataResult.fromJson(resultStr);
    return base64Encode(result.dataOrThrow);
  }

  /// Decrypts data with a specific temp key ID (for async operations)
  /// encryptedDataBase64: encrypted data (base64)
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: decrypted data (string)
  String decryptData(String encryptedDataBase64, String tempKeyID) {
    final resultStr = _native.decryptData(encryptedDataBase64, tempKeyID);
    final result = DataResult.fromJson(resultStr);
    return utf8.decode(result.dataOrThrow);
  }

  /// Decrypts binary data with a temporary key ID (for async operations)
  /// encryptedDataBase64: encrypted data (base64)
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: decrypted data (bytes)
  Uint8List decryptDataBytes(String encryptedDataBase64, String tempKeyID) {
    final resultStr = _native.decryptData(encryptedDataBase64, tempKeyID);
    final result = DataResult.fromJson(resultStr);
    return result.dataOrThrow;
  }

  // ==================== FILE ENCRYPTION/DECRYPTION ====================

  /// Encrypts a file with a specific temp key ID (for async operations)
  /// srcPath: source file path
  /// toPath: destination file path
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: JSON result {"success": true} or throws exception
  Map<String, dynamic> encryptFile(
      String srcPath, String toPath, String tempKeyID) {
    final resultStr = _native.encryptFile(srcPath, toPath, tempKeyID);
    final result = FileResult.fromJson(resultStr);
    result.throwOnError();
    return {'success': true};
  }

  /// Decrypts a file with a specific temp key ID (for async operations)
  /// path: encrypted file path
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: decrypted data (bytes)
  Uint8List decryptFileToData(String path, String tempKeyID) {
    final resultStr = _native.decryptFileToData(path, tempKeyID);
    final result = DataResult.fromJson(resultStr);
    return result.dataOrThrow;
  }

  // ==================== STREAMING FILE OPERATIONS ====================

  /// Large file threshold (100 MB)
  static const int largeFileThreshold = 100 * 1024 * 1024;

  /// Decrypts an encrypted file directly to another file path.
  /// This is memory-efficient for large files - uses streaming decryption for chunked files.
  /// srcPath: source encrypted file path
  /// toPath: destination decrypted file path
  /// tempKeyID: temporary key ID (from createSession)
  /// Returns: {"success": true} or throws exception
  Map<String, dynamic> decryptFileToPath(
      String srcPath, String toPath, String tempKeyID) {
    final resultStr = _native.decryptFileToPath(srcPath, toPath, tempKeyID);
    final result = FileResult.fromJson(resultStr);
    result.throwOnError();
    return {'success': true};
  }

  /// Encrypts a file using chunked format (memory-efficient for large files).
  /// This format supports streaming decryption - only one chunk is loaded into memory at a time.
  /// srcPath: source file path
  /// toPath: destination encrypted file path
  /// tempKeyID: temporary key ID (from createSession)
  /// chunkSizeKB: chunk size in KB (0 = default 64 KB)
  /// Returns: {"success": true} or throws exception
  Map<String, dynamic> encryptFileChunked(
      String srcPath, String toPath, String tempKeyID,
      {int chunkSizeKB = 0}) {
    final resultStr = _native.encryptFileChunked(srcPath, toPath, tempKeyID,
        chunkSizeKB: chunkSizeKB);
    final result = FileResult.fromJson(resultStr);
    result.throwOnError();
    return {'success': true};
  }

  /// Checks if a file is in chunked encrypted format.
  /// path: file path to check
  /// Returns: true if chunked, false otherwise
  bool isChunkedFile(String path) {
    final resultStr = _native.isChunkedFile(path);
    final result = IsChunkedResult.fromJson(resultStr);
    return result.isChunkedOrThrow;
  }

  /// Gets information about an encrypted file.
  /// path: file path
  /// Returns: FileInfo with size, isChunked, recommendedMethod
  FileInfo getEncryptedFileInfo(String path) {
    final resultStr = _native.getEncryptedFileInfo(path);
    return FileInfo.fromJson(resultStr);
  }

  // ==================== CONFIG MANAGEMENT ====================

  /// Generates complete encryption configuration
  /// password: user password
  /// keyStrengthMs: target key derivation time in milliseconds (e.g., 1000 for 1 second)
  /// mutable: whether to use mutable mode (unique file key)
  /// challengeId: optional challenge ID (use empty string for default "safe_disk")
  /// Returns: JSON config string
  String generateEncryptionConfig(
      String password, int keyStrengthMs, bool mutable, String challengeId) {
    return _native.generateEncryptionConfig(
        password, keyStrengthMs, mutable, challengeId);
  }

  /// Loads config from an encrypted directory
  /// dirPath: directory path
  /// Returns: JSON config string
  String loadCryptionConfig(String dirPath) {
    return _native.loadCryptionConfig(dirPath);
  }

  /// Finds the encrypted root directory (searches upward like .git)
  /// startPath: starting path
  /// Returns: root directory path or empty string if not found
  String findCryptionRoot(String startPath) {
    return _native.findCryptionRoot(startPath);
  }

  /// Creates an encrypted directory
  /// dirPath: directory path
  /// configJSON: config JSON string
  /// Returns: JSON result {"success": true} or {"success": false, "error": "..."}
  Map<String, dynamic> createEncryptedDirectory(
      String dirPath, Map<String, dynamic> config) {
    final configJSON = jsonEncode(config);
    final resultStr = _native.createEncryptedDirectory(dirPath, configJSON);
    final result = FFIResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to create encrypted directory');
    }
    return {'success': true};
  }

  // ==================== LEGACY COMPATIBILITY ====================

  /// Loads config from an encrypted directory and returns CryptionConfig object
  /// This method is provided for backward compatibility
  CryptionConfig loadConfig(String dirPath) {
    final configJSON = loadCryptionConfig(dirPath);
    final configMap = jsonDecode(configJSON) as Map<String, dynamic>;
    return CryptionConfig.fromJson(configMap);
  }
}

/// Result of password verification
class VerifyResult {
  final bool success;
  final String? error;

  VerifyResult({required this.success, this.error});

  /// Throws an exception if verification failed
  void throwOnError() {
    if (!success) {
      throw Exception(error ?? 'Password verification failed');
    }
  }
}
