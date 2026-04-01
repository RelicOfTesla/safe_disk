import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// C function signatures
typedef DeriveKeyC = Pointer<Utf8> Function(Pointer<Utf8> inputPass, Int32 iterN);
typedef DeriveKeyDart = Pointer<Utf8> Function(Pointer<Utf8> inputPass, int iterN);

typedef VerifyPasswordC = Int32 Function(Pointer<Utf8> checkBase64, Pointer<Utf8> inputPass, Int32 iterN);
typedef VerifyPasswordDart = int Function(Pointer<Utf8> checkBase64, Pointer<Utf8> inputPass, int iterN);

typedef EncryptDataC = Pointer<Utf8> Function(Pointer<Utf8> plaintextBase64, Pointer<Utf8> keyBase64);
typedef EncryptDataDart = Pointer<Utf8> Function(Pointer<Utf8> plaintextBase64, Pointer<Utf8> keyBase64);

typedef DecryptDataC = Pointer<Utf8> Function(Pointer<Utf8> ciphertextBase64, Pointer<Utf8> keyBase64);
typedef DecryptDataDart = Pointer<Utf8> Function(Pointer<Utf8> ciphertextBase64, Pointer<Utf8> keyBase64);

typedef LoadCryptionConfigC = Pointer<Utf8> Function(Pointer<Utf8> dirPath);
typedef LoadCryptionConfigDart = Pointer<Utf8> Function(Pointer<Utf8> dirPath);

typedef GenerateRandomKeyC = Pointer<Utf8> Function();
typedef GenerateRandomKeyDart = Pointer<Utf8> Function();

typedef EncryptFileKeyC = Pointer<Utf8> Function(Pointer<Utf8> fileKeyBase64, Pointer<Utf8> inputPass, Int32 iterN);
typedef EncryptFileKeyDart = Pointer<Utf8> Function(Pointer<Utf8> fileKeyBase64, Pointer<Utf8> inputPass, int iterN);

typedef DecryptFileKeyC = Pointer<Utf8> Function(Pointer<Utf8> encryptedKeyBase64, Pointer<Utf8> inputPass, Int32 iterN);
typedef DecryptFileKeyDart = Pointer<Utf8> Function(Pointer<Utf8> encryptedKeyBase64, Pointer<Utf8> inputPass, int iterN);

class NativeBindings {
  final DynamicLibrary _lib;
  
  late final DeriveKeyDart deriveKey;
  late final VerifyPasswordDart verifyPassword;
  late final EncryptDataDart encryptData;
  late final DecryptDataDart decryptData;
  late final LoadCryptionConfigDart loadCryptionConfig;
  late final GenerateRandomKeyDart generateRandomKey;
  late final EncryptFileKeyDart encryptFileKey;
  late final DecryptFileKeyDart decryptFileKey;
  
  NativeBindings._(this._lib) {
    deriveKey = _lib.lookupFunction<DeriveKeyC, DeriveKeyDart>('DeriveKey');
    verifyPassword = _lib.lookupFunction<VerifyPasswordC, VerifyPasswordDart>('VerifyPassword');
    encryptData = _lib.lookupFunction<EncryptDataC, EncryptDataDart>('EncryptData');
    decryptData = _lib.lookupFunction<DecryptDataC, DecryptDataDart>('DecryptData');
    loadCryptionConfig = _lib.lookupFunction<LoadCryptionConfigC, LoadCryptionConfigDart>('LoadCryptionConfig');
    generateRandomKey = _lib.lookupFunction<GenerateRandomKeyC, GenerateRandomKeyDart>('GenerateRandomKey');
    encryptFileKey = _lib.lookupFunction<EncryptFileKeyC, EncryptFileKeyDart>('EncryptFileKey');
    decryptFileKey = _lib.lookupFunction<DecryptFileKeyC, DecryptFileKeyDart>('DecryptFileKey');
  }
  
  static NativeBindings? _instance;
  
  static NativeBindings get instance {
    _instance ??= NativeBindings._(_openLibrary());
    return _instance!;
  }
  
  static DynamicLibrary _openLibrary() {
    if (Platform.isLinux) {
      return DynamicLibrary.open('libsafedisk_native.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('safedisk_native.dll');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libsafedisk_native.dylib');
    }
    throw UnsupportedError('Unsupported platform');
  }
}
