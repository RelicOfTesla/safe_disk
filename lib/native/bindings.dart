import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ==================== FFI TYPE DEFINITIONS ====================

// VerifyPassword: (inputPass, configJSON) -> int
typedef VerifyPasswordC = Int32 Function(Pointer<Utf8> inputPass, Pointer<Utf8> configJSON);
typedef VerifyPasswordDart = int Function(Pointer<Utf8> inputPass, Pointer<Utf8> configJSON);

// MakeTemporaryKeyID: (inputPass, configJSON, ttlSeconds) -> string
typedef MakeTemporaryKeyIDC = Pointer<Utf8> Function(Pointer<Utf8> inputPass, Pointer<Utf8> configJSON, Int32 ttlSeconds);
typedef MakeTemporaryKeyIDDart = Pointer<Utf8> Function(Pointer<Utf8> inputPass, Pointer<Utf8> configJSON, int ttlSeconds);

// EncryptData: (dataBase64, tempKeyID) -> string
typedef EncryptDataC = Pointer<Utf8> Function(Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);
typedef EncryptDataDart = Pointer<Utf8> Function(Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);

// DecryptData: (dataBase64, tempKeyID) -> string
typedef DecryptDataC = Pointer<Utf8> Function(Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);
typedef DecryptDataDart = Pointer<Utf8> Function(Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);

// EncryptFile: (srcPath, toPath, tempKeyID) -> string
typedef EncryptFileC = Pointer<Utf8> Function(Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);
typedef EncryptFileDart = Pointer<Utf8> Function(Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);

// DecryptFileToData: (path, tempKeyID) -> string
typedef DecryptFileToDataC = Pointer<Utf8> Function(Pointer<Utf8> path, Pointer<Utf8> tempKeyID);
typedef DecryptFileToDataDart = Pointer<Utf8> Function(Pointer<Utf8> path, Pointer<Utf8> tempKeyID);

// GenerateEncryptionConfig: (password, keyStrengthMs, mutable, challengeId) -> string
typedef GenerateEncryptionConfigC = Pointer<Utf8> Function(Pointer<Utf8> password, Int32 keyStrengthMs, Int32 mutable, Pointer<Utf8> challengeId);
typedef GenerateEncryptionConfigDart = Pointer<Utf8> Function(Pointer<Utf8> password, int keyStrengthMs, int mutable, Pointer<Utf8> challengeId);

// LoadCryptionConfig: (dirPath) -> string
typedef LoadCryptionConfigC = Pointer<Utf8> Function(Pointer<Utf8> dirPath);
typedef LoadCryptionConfigDart = Pointer<Utf8> Function(Pointer<Utf8> dirPath);

// FindCryptionRoot: (path) -> string
typedef FindCryptionRootC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef FindCryptionRootDart = Pointer<Utf8> Function(Pointer<Utf8> path);

// CreateEncryptedDirectory: (dirPath, configJSON) -> string
typedef CreateEncryptedDirectoryC = Pointer<Utf8> Function(Pointer<Utf8> dirPath, Pointer<Utf8> configJSON);
typedef CreateEncryptedDirectoryDart = Pointer<Utf8> Function(Pointer<Utf8> dirPath, Pointer<Utf8> configJSON);

// FreeCString: (s) -> void
typedef FreeCStringC = Void Function(Pointer<Utf8> s);
typedef FreeCStringDart = void Function(Pointer<Utf8> s);

// ==================== NATIVE BINDINGS ====================

class NativeBindings {
  final DynamicLibrary _lib;
  
  NativeBindings._(this._lib) {
    verifyPassword = _lib.lookupFunction<VerifyPasswordC, VerifyPasswordDart>('VerifyPassword');
    makeTemporaryKeyID = _lib.lookupFunction<MakeTemporaryKeyIDC, MakeTemporaryKeyIDDart>('MakeTemporaryKeyID');
    encryptData = _lib.lookupFunction<EncryptDataC, EncryptDataDart>('EncryptData');
    decryptData = _lib.lookupFunction<DecryptDataC, DecryptDataDart>('DecryptData');
    encryptFile = _lib.lookupFunction<EncryptFileC, EncryptFileDart>('EncryptFile');
    decryptFileToData = _lib.lookupFunction<DecryptFileToDataC, DecryptFileToDataDart>('DecryptFileToData');
    generateEncryptionConfig = _lib.lookupFunction<GenerateEncryptionConfigC, GenerateEncryptionConfigDart>('GenerateEncryptionConfig');
    loadCryptionConfig = _lib.lookupFunction<LoadCryptionConfigC, LoadCryptionConfigDart>('LoadCryptionConfig');
    findCryptionRoot = _lib.lookupFunction<FindCryptionRootC, FindCryptionRootDart>('FindCryptionRoot');
    createEncryptedDirectory = _lib.lookupFunction<CreateEncryptedDirectoryC, CreateEncryptedDirectoryDart>('CreateEncryptedDirectory');
    freeCString = _lib.lookupFunction<FreeCStringC, FreeCStringDart>('FreeCString');
  }
  
  static NativeBindings? _instance;
  
  static NativeBindings get instance {
    _instance ??= NativeBindings._(_openLibrary());
    return _instance!;
  }
  
  static DynamicLibrary _openLibrary() {
    // Try multiple paths
    final paths = [
      '/home/john/Desktop/dev/safe_disk/linux/libsafedisk_native.so',
      './linux/libsafedisk_native.so',
      'libsafedisk_native.so',
    ];
    
    for (final path in paths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          print('Loading native library from: $path');
          return DynamicLibrary.open(path);
        }
      } catch (e) {
        // Try next path
      }
    }
    
    throw Exception('Could not find native library. Tried: $paths');
  }
  
  // Function bindings
  late final VerifyPasswordDart verifyPassword;
  late final MakeTemporaryKeyIDDart makeTemporaryKeyID;
  late final EncryptDataDart encryptData;
  late final DecryptDataDart decryptData;
  late final EncryptFileDart encryptFile;
  late final DecryptFileToDataDart decryptFileToData;
  late final GenerateEncryptionConfigDart generateEncryptionConfig;
  late final LoadCryptionConfigDart loadCryptionConfig;
  late final FindCryptionRootDart findCryptionRoot;
  late final CreateEncryptedDirectoryDart createEncryptedDirectory;
  late final FreeCStringDart freeCString;
}
