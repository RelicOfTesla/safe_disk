import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'bindings.dart';

class NativeLib {
  final NativeBindings _bindings;
  
  NativeLib._() : _bindings = NativeBindings.instance;
  
  static NativeLib? _instance;
  
  static NativeLib get instance {
    _instance ??= NativeLib._();
    return _instance!;
  }
  
  /// Derives a 32-byte AES-256 key from password
  /// Returns base64-encoded key
  String deriveKey(String inputPass, int iterN) {
    final inputPassPtr = inputPass.toNativeUtf8();
    try {
      final resultPtr = _bindings.deriveKey(inputPassPtr, iterN);
      return resultPtr.toDartString();
    } finally {
      calloc.free(inputPassPtr);
    }
  }
  
  /// Verifies if the password is correct
  /// checkBase64: base64-encoded check value from _cryption.json
  /// Returns true if password is correct
  bool verifyPassword(String checkBase64, String inputPass, int iterN) {
    final checkPtr = checkBase64.toNativeUtf8();
    final inputPassPtr = inputPass.toNativeUtf8();
    try {
      final result = _bindings.verifyPassword(checkPtr, inputPassPtr, iterN);
      return result == 1;
    } finally {
      calloc.free(checkPtr);
      calloc.free(inputPassPtr);
    }
  }
  
  /// Encrypts data using AES-256-GCM
  /// plaintext: raw data (will be base64-encoded internally)
  /// keyBase64: base64-encoded 32-byte key
  /// Returns base64-encoded ciphertext: [IV(12)] + [Ciphertext] + [Tag(16)]
  String encryptData(List<int> plaintext, String keyBase64) {
    final plaintextBase64 = base64Encode(plaintext);
    final plaintextPtr = plaintextBase64.toNativeUtf8();
    final keyPtr = keyBase64.toNativeUtf8();
    try {
      final resultPtr = _bindings.encryptData(plaintextPtr, keyPtr);
      return resultPtr.toDartString();
    } finally {
      calloc.free(plaintextPtr);
      calloc.free(keyPtr);
    }
  }
  
  /// Decrypts data using AES-256-GCM
  /// ciphertextBase64: base64-encoded ciphertext: [IV(12)] + [Ciphertext] + [Tag(16)]
  /// keyBase64: base64-encoded 32-byte key
  /// Returns raw decrypted data
  List<int> decryptData(String ciphertextBase64, String keyBase64) {
    final ciphertextPtr = ciphertextBase64.toNativeUtf8();
    final keyPtr = keyBase64.toNativeUtf8();
    try {
      final resultPtr = _bindings.decryptData(ciphertextPtr, keyPtr);
      final resultBase64 = resultPtr.toDartString();
      return base64Decode(resultBase64);
    } finally {
      calloc.free(ciphertextPtr);
      calloc.free(keyPtr);
    }
  }
  
  /// Loads _cryption.json from a directory
  /// Returns parsed JSON as Map, or null if not found
  Map<String, dynamic>? loadCryptionConfig(String dirPath) {
    final dirPathPtr = dirPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.loadCryptionConfig(dirPathPtr);
      final result = resultPtr.toDartString();
      if (result.isEmpty) return null;
      return jsonDecode(result) as Map<String, dynamic>;
    } finally {
      calloc.free(dirPathPtr);
    }
  }
  
  /// Generates a random 32-byte key
  /// Returns base64-encoded key
  String generateRandomKey() {
    final resultPtr = _bindings.generateRandomKey();
    return resultPtr.toDartString();
  }
  
  /// Encrypts a file key with password (for mutable=true mode)
  /// fileKeyBase64: base64-encoded 32-byte file key
  /// Returns base64-encoded encrypted file key
  String encryptFileKey(String fileKeyBase64, String inputPass, int iterN) {
    final fileKeyPtr = fileKeyBase64.toNativeUtf8();
    final inputPassPtr = inputPass.toNativeUtf8();
    try {
      final resultPtr = _bindings.encryptFileKey(fileKeyPtr, inputPassPtr, iterN);
      return resultPtr.toDartString();
    } finally {
      calloc.free(fileKeyPtr);
      calloc.free(inputPassPtr);
    }
  }
  
  /// Decrypts a file key with password (for mutable=true mode)
  /// encryptedKeyBase64: base64-encoded encrypted file key
  /// Returns base64-encoded 32-byte file key
  String decryptFileKey(String encryptedKeyBase64, String inputPass, int iterN) {
    final encryptedKeyPtr = encryptedKeyBase64.toNativeUtf8();
    final inputPassPtr = inputPass.toNativeUtf8();
    try {
      final resultPtr = _bindings.decryptFileKey(encryptedKeyPtr, inputPassPtr, iterN);
      return resultPtr.toDartString();
    } finally {
      calloc.free(encryptedKeyPtr);
      calloc.free(inputPassPtr);
    }
  }
}
