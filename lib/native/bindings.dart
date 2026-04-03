import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ==================== FFI TYPE DEFINITIONS ====================

// VerifyPassword: (inputPass, configJSON) -> int
typedef VerifyPasswordC = Int32 Function(
    Pointer<Utf8> inputPass, Pointer<Utf8> configJSON);
typedef VerifyPasswordDart = int Function(
    Pointer<Utf8> inputPass, Pointer<Utf8> configJSON);

// MakeTemporaryKeyID: (inputPass, configJSON, ttlSeconds) -> string
typedef MakeTemporaryKeyIDC = Pointer<Utf8> Function(
    Pointer<Utf8> inputPass, Pointer<Utf8> configJSON, Int32 ttlSeconds);
typedef MakeTemporaryKeyIDDart = Pointer<Utf8> Function(
    Pointer<Utf8> inputPass, Pointer<Utf8> configJSON, int ttlSeconds);

// EncryptData: (dataBase64, tempKeyID) -> string
typedef EncryptDataC = Pointer<Utf8> Function(
    Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);
typedef EncryptDataDart = Pointer<Utf8> Function(
    Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);

// DecryptData: (dataBase64, tempKeyID) -> string
typedef DecryptDataC = Pointer<Utf8> Function(
    Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);
typedef DecryptDataDart = Pointer<Utf8> Function(
    Pointer<Utf8> dataBase64, Pointer<Utf8> tempKeyID);

// EncryptFile: (srcPath, toPath, tempKeyID) -> string
typedef EncryptFileC = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);
typedef EncryptFileDart = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);

// DecryptFileToData: (path, tempKeyID) -> string
typedef DecryptFileToDataC = Pointer<Utf8> Function(
    Pointer<Utf8> path, Pointer<Utf8> tempKeyID);
typedef DecryptFileToDataDart = Pointer<Utf8> Function(
    Pointer<Utf8> path, Pointer<Utf8> tempKeyID);

// DecryptFileToPath: (srcPath, toPath, tempKeyID) -> string
typedef DecryptFileToPathC = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);
typedef DecryptFileToPathDart = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID);

// EncryptFileChunked: (srcPath, toPath, tempKeyID, chunkSizeKB) -> string
typedef EncryptFileChunkedC = Pointer<Utf8> Function(Pointer<Utf8> srcPath,
    Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID, Int32 chunkSizeKB);
typedef EncryptFileChunkedDart = Pointer<Utf8> Function(Pointer<Utf8> srcPath,
    Pointer<Utf8> toPath, Pointer<Utf8> tempKeyID, int chunkSizeKB);

// IsChunkedFile: (path) -> string
typedef IsChunkedFileC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef IsChunkedFileDart = Pointer<Utf8> Function(Pointer<Utf8> path);

// GetEncryptedFileInfo: (path) -> string
typedef GetEncryptedFileInfoC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef GetEncryptedFileInfoDart = Pointer<Utf8> Function(Pointer<Utf8> path);

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

// EncryptDirectoryAsync: (srcDir, dstDir, tempKeyID) -> string
typedef EncryptDirectoryAsyncC = Pointer<Utf8> Function(
    Pointer<Utf8> srcDir, Pointer<Utf8> dstDir, Pointer<Utf8> tempKeyID);
typedef EncryptDirectoryAsyncDart = Pointer<Utf8> Function(
    Pointer<Utf8> srcDir, Pointer<Utf8> dstDir, Pointer<Utf8> tempKeyID);

// DecryptDirectoryAsync: (srcDir, dstDir, tempKeyID) -> string
typedef DecryptDirectoryAsyncC = Pointer<Utf8> Function(
    Pointer<Utf8> srcDir, Pointer<Utf8> dstDir, Pointer<Utf8> tempKeyID);
typedef DecryptDirectoryAsyncDart = Pointer<Utf8> Function(
    Pointer<Utf8> srcDir, Pointer<Utf8> dstDir, Pointer<Utf8> tempKeyID);

// GetJobProgress: (jobID) -> string
typedef GetJobProgressC = Pointer<Utf8> Function(Pointer<Utf8> jobID);
typedef GetJobProgressDart = Pointer<Utf8> Function(Pointer<Utf8> jobID);

// GetJobStatus: (jobID) -> string
typedef GetJobStatusC = Pointer<Utf8> Function(Pointer<Utf8> jobID);
typedef GetJobStatusDart = Pointer<Utf8> Function(Pointer<Utf8> jobID);

// CancelJob: (jobID) -> string
typedef CancelJobC = Pointer<Utf8> Function(Pointer<Utf8> jobID);
typedef CancelJobDart = Pointer<Utf8> Function(Pointer<Utf8> jobID);

// DeleteJob: (jobID) -> string
typedef DeleteJobC = Pointer<Utf8> Function(Pointer<Utf8> jobID);
typedef DeleteJobDart = Pointer<Utf8> Function(Pointer<Utf8> jobID);

// ==================== INCREMENTAL ENCRYPTION OPERATIONS ====================

// IncrementalEncryptorCreate: (dstPath, keyBase64, chunkSizeKB) -> string
typedef IncrementalEncryptorCreateC = Pointer<Utf8> Function(
    Pointer<Utf8> dstPath, Pointer<Utf8> keyBase64, Int32 chunkSizeKB);
typedef IncrementalEncryptorCreateDart = Pointer<Utf8> Function(
    Pointer<Utf8> dstPath, Pointer<Utf8> keyBase64, int chunkSizeKB);

// IncrementalEncryptorAddBlock: (handleID, dataBase64) -> string
typedef IncrementalEncryptorAddBlockC = Pointer<Utf8> Function(
    Int64 handleID, Pointer<Utf8> dataBase64);
typedef IncrementalEncryptorAddBlockDart = Pointer<Utf8> Function(
    int handleID, Pointer<Utf8> dataBase64);

// IncrementalEncryptorFinalize: (handleID) -> string
typedef IncrementalEncryptorFinalizeC = Pointer<Utf8> Function(Int64 handleID);
typedef IncrementalEncryptorFinalizeDart = Pointer<Utf8> Function(int handleID);

// IncrementalEncryptorClose: (handleID) -> string
typedef IncrementalEncryptorCloseC = Pointer<Utf8> Function(Int64 handleID);
typedef IncrementalEncryptorCloseDart = Pointer<Utf8> Function(int handleID);

// IncrementalDecryptorOpen: (srcPath, keyBase64) -> string
typedef IncrementalDecryptorOpenC = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> keyBase64);
typedef IncrementalDecryptorOpenDart = Pointer<Utf8> Function(
    Pointer<Utf8> srcPath, Pointer<Utf8> keyBase64);

// IncrementalDecryptorDecryptBlock: (handleID, blockIndex) -> string
typedef IncrementalDecryptorDecryptBlockC = Pointer<Utf8> Function(
    Int64 handleID, Int32 blockIndex);
typedef IncrementalDecryptorDecryptBlockDart = Pointer<Utf8> Function(
    int handleID, int blockIndex);

// IncrementalDecryptorDecryptRange: (handleID, offset, length) -> string
typedef IncrementalDecryptorDecryptRangeC = Pointer<Utf8> Function(
    Int64 handleID, Int64 offset, Int32 length);
typedef IncrementalDecryptorDecryptRangeDart = Pointer<Utf8> Function(
    int handleID, int offset, int length);

// IncrementalDecryptorDecryptAll: (handleID) -> string
typedef IncrementalDecryptorDecryptAllC = Pointer<Utf8> Function(Int64 handleID);
typedef IncrementalDecryptorDecryptAllDart = Pointer<Utf8> Function(
    int handleID);

// IncrementalDecryptorVerifyBlockIntegrity: (handleID, blockIndex) -> string
typedef IncrementalDecryptorVerifyBlockIntegrityC = Pointer<Utf8> Function(
    Int64 handleID, Int32 blockIndex);
typedef IncrementalDecryptorVerifyBlockIntegrityDart = Pointer<Utf8> Function(
    int handleID, int blockIndex);

// IncrementalDecryptorVerifyIntegrity: (handleID) -> string
typedef IncrementalDecryptorVerifyIntegrityC = Pointer<Utf8> Function(
    Int64 handleID);
typedef IncrementalDecryptorVerifyIntegrityDart = Pointer<Utf8> Function(
    int handleID);

// IncrementalDecryptorGetBlockInfo: (handleID, blockIndex) -> string
typedef IncrementalDecryptorGetBlockInfoC = Pointer<Utf8> Function(
    Int64 handleID, Int32 blockIndex);
typedef IncrementalDecryptorGetBlockInfoDart = Pointer<Utf8> Function(
    int handleID, int blockIndex);

// IncrementalDecryptorGetAllBlockInfo: (handleID) -> string
typedef IncrementalDecryptorGetAllBlockInfoC = Pointer<Utf8> Function(
    Int64 handleID);
typedef IncrementalDecryptorGetAllBlockInfoDart = Pointer<Utf8> Function(
    int handleID);

// IncrementalDecryptorClose: (handleID) -> string
typedef IncrementalDecryptorCloseC = Pointer<Utf8> Function(Int64 handleID);
typedef IncrementalDecryptorCloseDart = Pointer<Utf8> Function(int handleID);

// IsIncrementalFile: (path) -> string
typedef IsIncrementalFileC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef IsIncrementalFileDart = Pointer<Utf8> Function(Pointer<Utf8> path);

// GetIncrementalFileInfo: (path) -> string
typedef GetIncrementalFileInfoC = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef GetIncrementalFileInfoDart = Pointer<Utf8> Function(Pointer<Utf8> path);

// ClearSecureMemory: (dataBase64) -> string
typedef ClearSecureMemoryC = Pointer<Utf8> Function(Pointer<Utf8> dataBase64);
typedef ClearSecureMemoryDart = Pointer<Utf8> Function(Pointer<Utf8> dataBase64);


// ==================== NATIVE BINDINGS ====================

class NativeBindings {
  final DynamicLibrary _lib;

  NativeBindings._(this._lib) {
    verifyPassword = _lib
        .lookupFunction<VerifyPasswordC, VerifyPasswordDart>('VerifyPassword');
    makeTemporaryKeyID =
        _lib.lookupFunction<MakeTemporaryKeyIDC, MakeTemporaryKeyIDDart>(
            'MakeTemporaryKeyID');
    encryptData =
        _lib.lookupFunction<EncryptDataC, EncryptDataDart>('EncryptData');
    decryptData =
        _lib.lookupFunction<DecryptDataC, DecryptDataDart>('DecryptData');
    encryptFile =
        _lib.lookupFunction<EncryptFileC, EncryptFileDart>('EncryptFile');
    decryptFileToData =
        _lib.lookupFunction<DecryptFileToDataC, DecryptFileToDataDart>(
            'DecryptFileToData');
    decryptFileToPath =
        _lib.lookupFunction<DecryptFileToPathC, DecryptFileToPathDart>(
            'DecryptFileToPath');
    encryptFileChunked =
        _lib.lookupFunction<EncryptFileChunkedC, EncryptFileChunkedDart>(
            'EncryptFileChunked');
    isChunkedFile =
        _lib.lookupFunction<IsChunkedFileC, IsChunkedFileDart>('IsChunkedFile');
    getEncryptedFileInfo =
        _lib.lookupFunction<GetEncryptedFileInfoC, GetEncryptedFileInfoDart>(
            'GetEncryptedFileInfo');
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
    encryptDirectoryAsync =
        _lib.lookupFunction<EncryptDirectoryAsyncC, EncryptDirectoryAsyncDart>(
            'EncryptDirectoryAsync');
    decryptDirectoryAsync =
        _lib.lookupFunction<DecryptDirectoryAsyncC, DecryptDirectoryAsyncDart>(
            'DecryptDirectoryAsync');
    getJobProgress =
        _lib.lookupFunction<GetJobProgressC, GetJobProgressDart>(
            'GetJobProgress');
    getJobStatus =
        _lib.lookupFunction<GetJobStatusC, GetJobStatusDart>('GetJobStatus');
    cancelJob =
        _lib.lookupFunction<CancelJobC, CancelJobDart>('CancelJob');
    deleteJob =
        _lib.lookupFunction<DeleteJobC, DeleteJobDart>('DeleteJob');

    // Incremental encryption operations
    incrementalEncryptorCreate = _lib.lookupFunction<
        IncrementalEncryptorCreateC,
        IncrementalEncryptorCreateDart>('IncrementalEncryptorCreate');
    incrementalEncryptorAddBlock = _lib.lookupFunction<
        IncrementalEncryptorAddBlockC,
        IncrementalEncryptorAddBlockDart>('IncrementalEncryptorAddBlock');
    incrementalEncryptorFinalize = _lib.lookupFunction<
        IncrementalEncryptorFinalizeC,
        IncrementalEncryptorFinalizeDart>('IncrementalEncryptorFinalize');
    incrementalEncryptorClose = _lib.lookupFunction<
        IncrementalEncryptorCloseC,
        IncrementalEncryptorCloseDart>('IncrementalEncryptorClose');
    incrementalDecryptorOpen = _lib.lookupFunction<
        IncrementalDecryptorOpenC,
        IncrementalDecryptorOpenDart>('IncrementalDecryptorOpen');
    incrementalDecryptorDecryptBlock = _lib.lookupFunction<
        IncrementalDecryptorDecryptBlockC,
        IncrementalDecryptorDecryptBlockDart>(
        'IncrementalDecryptorDecryptBlock');
    incrementalDecryptorDecryptRange = _lib.lookupFunction<
        IncrementalDecryptorDecryptRangeC,
        IncrementalDecryptorDecryptRangeDart>(
        'IncrementalDecryptorDecryptRange');
    incrementalDecryptorDecryptAll = _lib.lookupFunction<
        IncrementalDecryptorDecryptAllC,
        IncrementalDecryptorDecryptAllDart>('IncrementalDecryptorDecryptAll');
    incrementalDecryptorVerifyBlockIntegrity = _lib.lookupFunction<
        IncrementalDecryptorVerifyBlockIntegrityC,
        IncrementalDecryptorVerifyBlockIntegrityDart>(
        'IncrementalDecryptorVerifyBlockIntegrity');
    incrementalDecryptorVerifyIntegrity = _lib.lookupFunction<
        IncrementalDecryptorVerifyIntegrityC,
        IncrementalDecryptorVerifyIntegrityDart>(
        'IncrementalDecryptorVerifyIntegrity');
    incrementalDecryptorGetBlockInfo = _lib.lookupFunction<
        IncrementalDecryptorGetBlockInfoC,
        IncrementalDecryptorGetBlockInfoDart>(
        'IncrementalDecryptorGetBlockInfo');
    incrementalDecryptorGetAllBlockInfo = _lib.lookupFunction<
        IncrementalDecryptorGetAllBlockInfoC,
        IncrementalDecryptorGetAllBlockInfoDart>(
        'IncrementalDecryptorGetAllBlockInfo');
    incrementalDecryptorClose = _lib.lookupFunction<
        IncrementalDecryptorCloseC,
        IncrementalDecryptorCloseDart>('IncrementalDecryptorClose');
    isIncrementalFile =
        _lib.lookupFunction<IsIncrementalFileC, IsIncrementalFileDart>(
            'IsIncrementalFile');
    getIncrementalFileInfo = _lib.lookupFunction<GetIncrementalFileInfoC,
        GetIncrementalFileInfoDart>('GetIncrementalFileInfo');
    clearSecureMemory =
        _lib.lookupFunction<ClearSecureMemoryC, ClearSecureMemoryDart>(
            'ClearSecureMemory');
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
  late final DecryptFileToPathDart decryptFileToPath;
  late final EncryptFileChunkedDart encryptFileChunked;
  late final IsChunkedFileDart isChunkedFile;
  late final GetEncryptedFileInfoDart getEncryptedFileInfo;
  late final GenerateEncryptionConfigDart generateEncryptionConfig;
  late final LoadCryptionConfigDart loadCryptionConfig;
  late final FindCryptionRootDart findCryptionRoot;
  late final CreateEncryptedDirectoryDart createEncryptedDirectory;
  late final FreeCStringDart freeCString;
  late final EncryptDirectoryAsyncDart encryptDirectoryAsync;
  late final DecryptDirectoryAsyncDart decryptDirectoryAsync;
  late final GetJobProgressDart getJobProgress;
  late final GetJobStatusDart getJobStatus;
  late final CancelJobDart cancelJob;
  late final DeleteJobDart deleteJob;

  // Incremental encryption operations
  late final IncrementalEncryptorCreateDart incrementalEncryptorCreate;
  late final IncrementalEncryptorAddBlockDart incrementalEncryptorAddBlock;
  late final IncrementalEncryptorFinalizeDart incrementalEncryptorFinalize;
  late final IncrementalEncryptorCloseDart incrementalEncryptorClose;
  late final IncrementalDecryptorOpenDart incrementalDecryptorOpen;
  late final IncrementalDecryptorDecryptBlockDart incrementalDecryptorDecryptBlock;
  late final IncrementalDecryptorDecryptRangeDart incrementalDecryptorDecryptRange;
  late final IncrementalDecryptorDecryptAllDart incrementalDecryptorDecryptAll;
  late final IncrementalDecryptorVerifyBlockIntegrityDart incrementalDecryptorVerifyBlockIntegrity;
  late final IncrementalDecryptorVerifyIntegrityDart incrementalDecryptorVerifyIntegrity;
  late final IncrementalDecryptorGetBlockInfoDart incrementalDecryptorGetBlockInfo;
  late final IncrementalDecryptorGetAllBlockInfoDart incrementalDecryptorGetAllBlockInfo;
  late final IncrementalDecryptorCloseDart incrementalDecryptorClose;
  late final IsIncrementalFileDart isIncrementalFile;
  late final GetIncrementalFileInfoDart getIncrementalFileInfo;
  late final ClearSecureMemoryDart clearSecureMemory;
}
