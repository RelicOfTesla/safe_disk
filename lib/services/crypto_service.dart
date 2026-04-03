import 'dart:convert';
import 'dart:typed_data';
import '../native/native_lib.dart';
import '../models/cryption_config.dart';
import '../models/ffi_results.dart';

/// Crypto service for Safe Disk encryption operations
///
/// This service provides encryption operations using the native library.
/// All key derivation and management is handled by the backend (Go FFI).
///
/// **New Architecture (sec_* series)**:
/// - **Session-based**: Use `openSession` to create a session, `closeSession` to close it
/// - **Stateful**: The backend holds session state in memory
/// - **Simpler**: One call (`openSession`) replaces `verifyPassword` + `createSession`
///
/// **Usage (NEW - Recommended)**:
/// ```dart
/// // Step 1: Open session (verifies password and creates session)
/// final session = cryptoService.openSession(rootPath, password);
/// // NOTE: Caller should store sessionID (e.g., in a Map, State, or Provider)
///
/// // Step 2: Use sessionID for file operations (via SecFileService)
/// final data = secFileService.readFile(session.sessionID, 'file.txt');
/// secFileService.writeFile(session.sessionID, 'file.txt', data);
///
/// // Step 3: Close session when done
/// cryptoService.closeSession(session.sessionID);
/// ```
///
/// **Legacy Usage (Deprecated)**:
/// ```dart
/// // Step 1: Verify password
/// final result = cryptoService.verifyPassword(password, configJSON);
///
/// // Step 2: Create session and get tempKeyID
/// final tempKeyID = cryptoService.createSession(password, configJSON);
///
/// // Step 3: Use tempKeyID for encryption/decryption
/// final encrypted = cryptoService.encryptData(data, tempKeyID);
/// ```
class CryptoService {
  final NativeLib _native = NativeLib.instance;

  // ==================== NEW SESSION MANAGEMENT (sec_* series) ====================

  /// Opens an encrypted root directory and creates a session.
  ///
  /// This replaces the old `verifyPassword` + `createSession` pattern.
  /// One call verifies the password AND creates a session.
  ///
  /// [rootPath] - path to the encrypted root directory (containing _cryption.json)
  /// [password] - user password
  /// [ttlSeconds] - session TTL in seconds (0 = default 3600s = 1 hour)
  ///
  /// Returns: SecSession with sessionID and rootPath
  /// Throws: Exception if password is incorrect or directory is invalid
  SecSession openSession(String rootPath, String password, {int ttlSeconds = 0}) {
    final resultStr = _native.secRootOpen(rootPath, password, ttlSeconds: ttlSeconds);
    final result = SecRootOpenResult.fromJson(resultStr);
    return result.sessionOrThrow;
  }

  /// Closes a root session and releases resources.
  ///
  /// [sessionID] - session ID from openSession
  ///
  /// Throws: Exception if session ID is invalid
  void closeSession(int sessionID) {
    final resultStr = _native.secRootClose(sessionID);
    final result = FFIResult.fromJson(resultStr);
    if (!result.success) {
      throw Exception(result.error ?? 'Failed to close session');
    }
  }

  /// Gets information about a root session.
  ///
  /// [sessionID] - session ID from openSession
  ///
  /// Returns: SecSessionInfo with rootPath and config
  /// Throws: Exception if session ID is invalid
  SecSessionInfo getSessionInfo(int sessionID) {
    final resultStr = _native.secRootGetInfo(sessionID);
    final result = SecRootInfoResult.fromJson(resultStr);
    return result.infoOrThrow;
  }

  // ==================== LEGACY SESSION MANAGEMENT (Deprecated - Removed) ====================
  // The following methods have been removed. Use openSession() instead.
  // - createSession: use openSession()
  // - verifyPassword: use openSession() which validates password automatically

  // ==================== PASSWORD VERIFICATION ====================
  // Password verification is now done automatically in openSession()
  // If you need to verify password without creating a session, use openSession() and closeSession()

  // ==================== DATA ENCRYPTION/DECRYPTION ====================
  // Data encryption/decryption should be done through SecFileService
  // Use secReadfile() and secWritefile() instead

  // ==================== FILE ENCRYPTION/DECRYPTION ====================
  // File encryption/decryption should be done through SecFileService
  // Use secFopen(), secFread(), secFwrite(), secFclose() instead

  // ==================== STREAMING FILE OPERATIONS ====================
  // Streaming operations should be done through SecFileService
  // The sec_* series handles large files automatically

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
    final resultStr = _native.findCryptionRoot(startPath);
    final result = FindRootResult.fromJson(resultStr);
    return result.rootPath ?? '';
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
    // Parse the FFI response to extract the actual config
    final response = jsonDecode(configJSON) as Map<String, dynamic>;
    
    // Check if the response has the expected structure
    if (response.containsKey('config')) {
      // New format: {"success": true, "code": 0, "config": {...}}
      return CryptionConfig.fromJson(response['config'] as Map<String, dynamic>);
    } else {
      // Fallback: assume the entire response is the config (for backward compatibility)
      return CryptionConfig.fromJson(response);
    }
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
