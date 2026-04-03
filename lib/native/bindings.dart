import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ==================== FFI TYPE DEFINITIONS ====================

// GenerateEncryptionConfig: (password, keyStrengthMs, mutable, challengeId) -> string
typedef GenerateEncryptionConfigC = Pointer<Utf8> Function(
    Pointer<Utf8> password,
    Int32 keyStrengthMs,
    Int32 mutable,
    Pointer<Utf8> challengeId);
typedef GenerateEncryptionConfigDart = Pointer<Utf8> Function(
    Pointer<Utf8> password,
    int keyStrengthMs,
    int mutable,
    Pointer<Utf8> challengeId);

// LoadCryptionConfig: (dirPath) -> string
typedef LoadCryptionConfigC = Pointer<Utf8> Function(Pointer<Utf8> dirPath);
typedef LoadCryptionConfigDart = Pointer<Utf8> Function(Pointer<Utf8> dirPath);

// FindCryptionRoot: (path) -> string
typedef FindCryptionRootC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef FindCryptionRootDart = Pointer<Utf8> Function(Pointer<Utf8> path);

// CreateEncryptedDirectory: (dirPath, configJSON) -> string
typedef CreateEncryptedDirectoryC = Pointer<Utf8> Function(
    Pointer<Utf8> dirPath, Pointer<Utf8> configJSON);
typedef CreateEncryptedDirectoryDart = Pointer<Utf8> Function(
    Pointer<Utf8> dirPath, Pointer<Utf8> configJSON);

// FreeCString: (s) -> void
typedef FreeCStringC = Void Function(Pointer<Utf8> s);
typedef FreeCStringDart = void Function(Pointer<Utf8> s);

// ClearSecureMemory: (dataBase64) -> string
typedef ClearSecureMemoryC = Pointer<Utf8> Function(Pointer<Utf8> dataBase64);
typedef ClearSecureMemoryDart = Pointer<Utf8> Function(Pointer<Utf8> dataBase64);

// ==================== SEC ROOT SERIES ====================

// sec_root_open: (rootPath, password, ttlSeconds) -> string
typedef SecRootOpenC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Int32 ttlSeconds);
typedef SecRootOpenDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, int ttlSeconds);

// sec_root_close: (sessionID) -> string
typedef SecRootCloseC = Pointer<Utf8> Function(Int64 sessionID);
typedef SecRootCloseDart = Pointer<Utf8> Function(int sessionID);

// sec_root_get_info: (sessionID) -> string
typedef SecRootGetInfoC = Pointer<Utf8> Function(Int64 sessionID);
typedef SecRootGetInfoDart = Pointer<Utf8> Function(int sessionID);

// ==================== SEC FILE SERIES ====================

// sec_fopen: (sessionID, filePath, mode) -> string
typedef SecFopenC = Pointer<Utf8> Function(
    Int64 sessionID, Pointer<Utf8> filePath, Pointer<Utf8> mode);
typedef SecFopenDart = Pointer<Utf8> Function(
    int sessionID, Pointer<Utf8> filePath, Pointer<Utf8> mode);

// sec_fread: (fileHandle, size) -> string
typedef SecFreadC = Pointer<Utf8> Function(Int64 fileHandle, Int32 size);
typedef SecFreadDart = Pointer<Utf8> Function(int fileHandle, int size);

// sec_fwrite: (fileHandle, dataBase64) -> string
typedef SecFwriteC = Pointer<Utf8> Function(
    Int64 fileHandle, Pointer<Utf8> dataBase64);
typedef SecFwriteDart = Pointer<Utf8> Function(
    int fileHandle, Pointer<Utf8> dataBase64);

// sec_fclose: (fileHandle) -> string
typedef SecFcloseC = Pointer<Utf8> Function(Int64 fileHandle);
typedef SecFcloseDart = Pointer<Utf8> Function(int fileHandle);

// sec_fseek: (fileHandle, offset, whence) -> string
typedef SecFseekC = Pointer<Utf8> Function(
    Int64 fileHandle, Int64 offset, Int32 whence);
typedef SecFseekDart = Pointer<Utf8> Function(
    int fileHandle, int offset, int whence);

// sec_ftell: (fileHandle) -> string
typedef SecFtellC = Pointer<Utf8> Function(Int64 fileHandle);
typedef SecFtellDart = Pointer<Utf8> Function(int fileHandle);

// sec_fstat: (fileHandle) -> string
typedef SecFstatC = Pointer<Utf8> Function(Int64 fileHandle);
typedef SecFstatDart = Pointer<Utf8> Function(int fileHandle);

// sec_fstat_info: (sessionID, filePath) -> string
typedef SecFstatInfoC = Pointer<Utf8> Function(
    Int64 sessionID, Pointer<Utf8> filePath);
typedef SecFstatInfoDart = Pointer<Utf8> Function(
    int sessionID, Pointer<Utf8> filePath);

// sec_readfile: (sessionID, filePath) -> string
typedef SecReadfileC = Pointer<Utf8> Function(
    Int64 sessionID, Pointer<Utf8> filePath);
typedef SecReadfileDart = Pointer<Utf8> Function(
    int sessionID, Pointer<Utf8> filePath);

// sec_writefile: (sessionID, filePath, dataBase64) -> string
typedef SecWritefileC = Pointer<Utf8> Function(
    Int64 sessionID, Pointer<Utf8> filePath, Pointer<Utf8> dataBase64);
typedef SecWritefileDart = Pointer<Utf8> Function(
    int sessionID, Pointer<Utf8> filePath, Pointer<Utf8> dataBase64);

// ==================== SEC DIR WALK SERIES ====================

// sec_dir_walk: (sessionID, dirPath) -> string
typedef SecDirWalkC = Pointer<Utf8> Function(
    Int64 sessionID, Pointer<Utf8> dirPath);
typedef SecDirWalkDart = Pointer<Utf8> Function(
    int sessionID, Pointer<Utf8> dirPath);

// sec_dir_walk_next: (walkerID) -> string
typedef SecDirWalkNextC = Pointer<Utf8> Function(Int64 walkerID);
typedef SecDirWalkNextDart = Pointer<Utf8> Function(int walkerID);

// sec_dir_walk_close: (walkerID) -> string
typedef SecDirWalkCloseC = Pointer<Utf8> Function(Int64 walkerID);
typedef SecDirWalkCloseDart = Pointer<Utf8> Function(int walkerID);

// ==================== NATIVE BINDINGS ====================

class NativeBindings {
  final DynamicLibrary _lib;

  NativeBindings._(this._lib) {
    generateEncryptionConfig = _lib.lookupFunction<GenerateEncryptionConfigC,
        GenerateEncryptionConfigDart>('GenerateEncryptionConfig');
    loadCryptionConfig =
        _lib.lookupFunction<LoadCryptionConfigC, LoadCryptionConfigDart>(
            'LoadCryptionConfig');
    findCryptionRoot =
        _lib.lookupFunction<FindCryptionRootC, FindCryptionRootDart>(
            'FindCryptionRoot');
    createEncryptedDirectory = _lib.lookupFunction<CreateEncryptedDirectoryC,
        CreateEncryptedDirectoryDart>('CreateEncryptedDirectory');
    freeCString =
        _lib.lookupFunction<FreeCStringC, FreeCStringDart>('FreeCString');
    clearSecureMemory =
        _lib.lookupFunction<ClearSecureMemoryC, ClearSecureMemoryDart>(
            'ClearSecureMemory');

    // SEC SERIES
    secRootOpen =
        _lib.lookupFunction<SecRootOpenC, SecRootOpenDart>('sec_root_open');
    secRootClose =
        _lib.lookupFunction<SecRootCloseC, SecRootCloseDart>('sec_root_close');
    secRootGetInfo =
        _lib.lookupFunction<SecRootGetInfoC, SecRootGetInfoDart>('sec_root_get_info');
    secFopen =
        _lib.lookupFunction<SecFopenC, SecFopenDart>('sec_fopen');
    secFread =
        _lib.lookupFunction<SecFreadC, SecFreadDart>('sec_fread');
    secFwrite =
        _lib.lookupFunction<SecFwriteC, SecFwriteDart>('sec_fwrite');
    secFclose =
        _lib.lookupFunction<SecFcloseC, SecFcloseDart>('sec_fclose');
    secFseek =
        _lib.lookupFunction<SecFseekC, SecFseekDart>('sec_fseek');
    secFtell =
        _lib.lookupFunction<SecFtellC, SecFtellDart>('sec_ftell');
    secFstat =
        _lib.lookupFunction<SecFstatC, SecFstatDart>('sec_fstat');
    secFstatInfo =
        _lib.lookupFunction<SecFstatInfoC, SecFstatInfoDart>('sec_fstat_info');
    secReadfile =
        _lib.lookupFunction<SecReadfileC, SecReadfileDart>('sec_readfile');
    secWritefile =
        _lib.lookupFunction<SecWritefileC, SecWritefileDart>('sec_writefile');
    secDirWalk =
        _lib.lookupFunction<SecDirWalkC, SecDirWalkDart>('sec_dir_walk');
    secDirWalkNext =
        _lib.lookupFunction<SecDirWalkNextC, SecDirWalkNextDart>('sec_dir_walk_next');
    secDirWalkClose =
        _lib.lookupFunction<SecDirWalkCloseC, SecDirWalkCloseDart>('sec_dir_walk_close');
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
  late final GenerateEncryptionConfigDart generateEncryptionConfig;
  late final LoadCryptionConfigDart loadCryptionConfig;
  late final FindCryptionRootDart findCryptionRoot;
  late final CreateEncryptedDirectoryDart createEncryptedDirectory;
  late final FreeCStringDart freeCString;
  late final ClearSecureMemoryDart clearSecureMemory;

  // SEC SERIES
  late final SecRootOpenDart secRootOpen;
  late final SecRootCloseDart secRootClose;
  late final SecRootGetInfoDart secRootGetInfo;
  late final SecFopenDart secFopen;
  late final SecFreadDart secFread;
  late final SecFwriteDart secFwrite;
  late final SecFcloseDart secFclose;
  late final SecFseekDart secFseek;
  late final SecFtellDart secFtell;
  late final SecFstatDart secFstat;
  late final SecFstatInfoDart secFstatInfo;
  late final SecReadfileDart secReadfile;
  late final SecWritefileDart secWritefile;
  late final SecDirWalkDart secDirWalk;
  late final SecDirWalkNextDart secDirWalkNext;
  late final SecDirWalkCloseDart secDirWalkClose;
}
