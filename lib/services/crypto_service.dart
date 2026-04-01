import 'dart:io';
import '../native/native_lib.dart';
import '../models/cryption_config.dart';

class CryptoService {
  final NativeLib _native = NativeLib.instance;
  
  final Map<String, String> _keyCache = {}; // path -> keyBase64
  
  /// Derives a key from password (for mutable=false mode)
  String deriveKey(String password, int iterN) {
    return _native.deriveKey(password, iterN);
  }
  
  /// Gets the file encryption key
  /// For mutable=false: derives from password
  /// For mutable=true: decrypts from encrypted key
  Future<String> getFileKey(EncryptedDirectory dir, String password) async {
    if (!dir.config.mutable) {
      // Immutable mode: derive from password
      return deriveKey(password, dir.config.iterN);
    }
    
    // Mutable mode: decrypt file key
    if (dir.config.encryptedKey == null) {
      throw Exception('Mutable mode but no encrypted key found');
    }
    
    // Decrypt the file key using password
    return _native.decryptFileKey(
      dir.config.encryptedKey!,
      password,
      dir.config.iterN,
    );
  }
  
  /// Verifies password for an encrypted directory
  Future<bool> verifyPassword(EncryptedDirectory dir, String password) async {
    final isValid = _native.verifyPassword(dir.config.check, password, dir.config.iterN);
    
    if (isValid) {
      // Get the actual file encryption key
      final fileKey = await getFileKey(dir, password);
      _keyCache[dir.path] = fileKey;
    }
    
    return isValid;
  }
  
  /// Gets cached key for a directory (returns null if not verified yet)
  String? getCachedKey(String dirPath) => _keyCache[dirPath];
  
  /// Encrypts data
  Future<List<int>> encrypt(List<int> plaintext, String keyBase64) async {
    final ciphertextBase64 = _native.encryptData(plaintext, keyBase64);
    return _native.decryptData(ciphertextBase64, keyBase64); // Decode base64
  }
  
  /// Decrypts data
  Future<List<int>> decrypt(List<int> ciphertext, String keyBase64) async {
    return _native.decryptData(
      _native.encryptData(ciphertext, keyBase64), // Encode base64
      keyBase64,
    );
  }
  
  /// Loads _cryption.json from a directory
  Future<CryptionConfig?> loadConfig(String dirPath) async {
    final json = _native.loadCryptionConfig(dirPath);
    if (json == null) return null;
    return CryptionConfig.fromJson(json);
  }
  
  /// Checks if a directory is an encrypted directory (has _cryption.json)
  /// Returns true if _cryption.json exists in this directory or any parent
  Future<bool> isEncryptedDirectory(String dirPath) async {
    final root = await findEncryptedRoot(dirPath);
    return root != null;
  }
  
  /// Finds the root of an encrypted directory
  /// Searches upward from dirPath until _cryption.json is found or reaching filesystem root
  /// Returns the path of the encrypted root, or null if not found
  Future<String?> findEncryptedRoot(String dirPath) async {
    var path = dirPath;
    
    while (path.isNotEmpty && path != '/' && path != '.' && path != '..') {
      final file = File('$path/_cryption.json');
      if (await file.exists()) {
        return path;
      }
      
      // Move to parent directory
      final parent = File(path).parent.path;
      if (parent == path) break; // Reached root
      path = parent;
    }
    
    return null;
  }
  
  /// Loads config from an encrypted directory
  /// Automatically finds the encrypted root if dirPath is a subdirectory
  Future<CryptionConfig?> loadConfigFromPath(String dirPath) async {
    final root = await findEncryptedRoot(dirPath);
    if (root == null) return null;
    return await loadConfig(root);
  }
  
  /// Clears key cache
  void clearCache() {
    _keyCache.clear();
  }
  
  /// Clears key for a specific directory
  void clearKeyFor(String dirPath) {
    _keyCache.remove(dirPath);
  }
}
