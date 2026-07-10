import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ==================== FFI TYPE DEFINITIONS ====================
// Based on ffi_sec_fs/exports.go

// sec_root_open: (rootPath, password, configJSON) -> JSON string
typedef SecRootOpenC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> configJSON);
typedef SecRootOpenDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> configJSON);

// sec_root_close: (rootID) -> JSON string
typedef SecRootCloseC = Pointer<Utf8> Function(Int64 rootID);
typedef SecRootCloseDart = Pointer<Utf8> Function(int rootID);

// sec_create_root_config: (rootPath, password, optionsJSON) -> JSON string
typedef SecCreateRootConfigC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> optionsJSON);
typedef SecCreateRootConfigDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> optionsJSON);

// sec_file_open: (rootID, path, mode) -> JSON string
typedef SecFileOpenC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path, Int32 mode);
typedef SecFileOpenDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path, int mode);

// sec_file_close: (fileID) -> JSON string
typedef SecFileCloseC = Pointer<Utf8> Function(Int64 fileID);
typedef SecFileCloseDart = Pointer<Utf8> Function(int fileID);

// sec_file_read: (fileID, size) -> JSON string
typedef SecFileReadC = Pointer<Utf8> Function(Int64 fileID, Int32 size);
typedef SecFileReadDart = Pointer<Utf8> Function(int fileID, int size);

// sec_file_write: (fileID, data, size) -> JSON string
typedef SecFileWriteC = Pointer<Utf8> Function(
    Int64 fileID, Pointer<Utf8> data, Int32 size);
typedef SecFileWriteDart = Pointer<Utf8> Function(
    int fileID, Pointer<Utf8> data, int size);

// sec_file_seek: (fileID, offset, whence) -> JSON string
typedef SecFileSeekC = Pointer<Utf8> Function(
    Int64 fileID, Int64 offset, Int32 whence);
typedef SecFileSeekDart = Pointer<Utf8> Function(
    int fileID, int offset, int whence);

// sec_file_truncate: (fileID, size) -> JSON string
typedef SecFileTruncateC = Pointer<Utf8> Function(Int64 fileID, Int64 size);
typedef SecFileTruncateDart = Pointer<Utf8> Function(int fileID, int size);

// sec_file_delete: (rootID, path) -> JSON string
typedef SecFileDeleteC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecFileDeleteDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);

// sec_file_exists: (rootID, path) -> JSON string
typedef SecFileExistsC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecFileExistsDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);

// sec_mkdir_all: (rootID, path) -> JSON string
typedef SecMkdirAllC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecMkdirAllDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);

// sec_read_dir: (rootID, path) -> JSON string
typedef SecReadDirC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecReadDirDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_quick_read_file: (rootID, path) -> JSON string
typedef SecQuickReadFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecQuickReadFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);

// sec_quick_write_file: (rootID, path, data, size) -> JSON string
typedef SecQuickWriteFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path, Pointer<Utf8> data, Int32 size);
typedef SecQuickWriteFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path, Pointer<Utf8> data, int size);

// sec_free_string: (s) -> void
typedef SecFreeStringC = Void Function(Pointer<Utf8> s);
typedef SecFreeStringDart = void Function(Pointer<Utf8> s);

// sec_clear_secure_memory: (data, size) -> JSON string
typedef SecClearSecureMemoryC = Pointer<Utf8> Function(
    Pointer<Uint8> data, Int32 size);
typedef SecClearSecureMemoryDart = Pointer<Utf8> Function(
    Pointer<Uint8> data, int size);

// transfer v3 operations
typedef SecTransferV3ListUnfinishedC = Pointer<Utf8> Function(Int64 rootID);
typedef SecTransferV3ListUnfinishedDart = Pointer<Utf8> Function(int rootID);

typedef SecTransferV3CleanUnfinishedC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> opID);
typedef SecTransferV3CleanUnfinishedDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> opID);

typedef SecTransferV3RecoverConvertC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath);
typedef SecTransferV3RecoverConvertDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath);

typedef SecTransferV3ConvertRootC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> kind);
typedef SecTransferV3ConvertRootDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> kind);

typedef SecTransferV3ImportFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);
typedef SecTransferV3ImportFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);

typedef SecTransferV3ImportDirectoryC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);
typedef SecTransferV3ImportDirectoryDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);

typedef SecTransferV3ExportFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);
typedef SecTransferV3ExportFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);

typedef SecTransferV3ExportDirectoryC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);
typedef SecTransferV3ExportDirectoryDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath);

typedef NativeProgressCallbackC = Void Function(
    Pointer<Utf8> currentFile,
    Int32 filesCompleted,
    Int32 filesTotal,
    Int32 isComplete,
    Pointer<Utf8> errorMessage);

typedef NativeProgressCallbackDart = void Function(
    Pointer<Utf8> currentFile,
    int filesCompleted,
    int filesTotal,
    int isComplete,
    Pointer<Utf8> errorMessage);

typedef SecTransferV3WithCallbackC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID,
    Int64 rootID,
    Pointer<Utf8> srcPath,
    Pointer<Utf8> destPath,
    Pointer<NativeFunction<NativeProgressCallbackC>> callback);
typedef SecTransferV3WithCallbackDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID,
    int rootID,
    Pointer<Utf8> srcPath,
    Pointer<Utf8> destPath,
    Pointer<NativeFunction<NativeProgressCallbackC>> callback);

typedef SecTransferV3CancelC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);
typedef SecTransferV3CancelDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);

// ==================== Native Bindings Class ====================

class NativeBindings {
  static NativeBindings? _instance;
  static DynamicLibrary? _lib;

  late final SecRootOpenDart secRootOpen;
  late final SecRootCloseDart secRootClose;
  late final SecCreateRootConfigDart secCreateRootConfig;
  late final SecFileOpenDart secFileOpen;
  late final SecFileCloseDart secFileClose;
  late final SecFileReadDart secFileRead;
  late final SecFileWriteDart secFileWrite;
  late final SecFileSeekDart secFileSeek;
  late final SecFileTruncateDart secFileTruncate;
  late final SecFileDeleteDart secFileDelete;
  late final SecFileExistsDart secFileExists;
  late final SecMkdirAllDart secMkdirAll;
  late final SecReadDirDart secReadDir;
  late final SecQuickReadFileDart secQuickReadFile;
  late final SecQuickWriteFileDart secQuickWriteFile;
  late final SecFreeStringDart secFreeString;
  late final SecClearSecureMemoryDart secClearSecureMemory;
  late final SecTransferV3ListUnfinishedDart secTransferV3ListUnfinished;
  late final SecTransferV3CleanUnfinishedDart secTransferV3CleanUnfinished;
  late final SecTransferV3RecoverConvertDart secTransferV3RecoverConvert;
  late final SecTransferV3ConvertRootDart secTransferV3ConvertRoot;
  late final SecTransferV3ImportFileDart secTransferV3ImportFile;
  late final SecTransferV3ImportDirectoryDart secTransferV3ImportDirectory;
  late final SecTransferV3ExportFileDart secTransferV3ExportFile;
  late final SecTransferV3ExportDirectoryDart secTransferV3ExportDirectory;
  late final SecTransferV3WithCallbackDart secTransferV3ImportFileWithCallback;
  late final SecTransferV3WithCallbackDart
      secTransferV3ImportDirectoryWithCallback;
  late final SecTransferV3WithCallbackDart secTransferV3ExportFileWithCallback;
  late final SecTransferV3WithCallbackDart
      secTransferV3ExportDirectoryWithCallback;
  late final SecTransferV3CancelDart secTransferV3Cancel;

  NativeBindings._() {
    _lib = _openLibrary();
    _bindFunctions();
  }

  static NativeBindings get instance {
    _instance ??= NativeBindings._();
    return _instance!;
  }

  static DynamicLibrary _openLibrary() {
    final overridePath = Platform.environment['SAFE_DISK_FFI_LIBRARY'];
    if (overridePath != null && overridePath.isNotEmpty) {
      return DynamicLibrary.open(overridePath);
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('libffi_sec_fs.so');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libffi_sec_fs.dylib');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('ffi_sec_fs.dll');
    }
    throw UnsupportedError('Unsupported platform');
  }

  void _bindFunctions() {
    secRootOpen =
        _lib!.lookupFunction<SecRootOpenC, SecRootOpenDart>('sec_root_open');
    secRootClose =
        _lib!.lookupFunction<SecRootCloseC, SecRootCloseDart>('sec_root_close');
    secCreateRootConfig = _lib!
        .lookupFunction<SecCreateRootConfigC, SecCreateRootConfigDart>(
            'sec_create_root_config');
    secFileOpen =
        _lib!.lookupFunction<SecFileOpenC, SecFileOpenDart>('sec_file_open');
    secFileClose =
        _lib!.lookupFunction<SecFileCloseC, SecFileCloseDart>('sec_file_close');
    secFileRead =
        _lib!.lookupFunction<SecFileReadC, SecFileReadDart>('sec_file_read');
    secFileWrite =
        _lib!.lookupFunction<SecFileWriteC, SecFileWriteDart>('sec_file_write');
    secFileSeek =
        _lib!.lookupFunction<SecFileSeekC, SecFileSeekDart>('sec_file_seek');
    secFileTruncate = _lib!
        .lookupFunction<SecFileTruncateC, SecFileTruncateDart>(
            'sec_file_truncate');
    secFileDelete = _lib!
        .lookupFunction<SecFileDeleteC, SecFileDeleteDart>('sec_file_delete');
    secFileExists = _lib!
        .lookupFunction<SecFileExistsC, SecFileExistsDart>('sec_file_exists');
    secMkdirAll =
        _lib!.lookupFunction<SecMkdirAllC, SecMkdirAllDart>('sec_mkdir_all');
    secReadDir =
        _lib!.lookupFunction<SecReadDirC, SecReadDirDart>('sec_read_dir');
    secQuickReadFile = _lib!
        .lookupFunction<SecQuickReadFileC, SecQuickReadFileDart>(
            'sec_quick_read_file');
    secQuickWriteFile = _lib!
        .lookupFunction<SecQuickWriteFileC, SecQuickWriteFileDart>(
            'sec_quick_write_file');
    secFreeString = _lib!
        .lookupFunction<SecFreeStringC, SecFreeStringDart>('sec_free_string');
    secClearSecureMemory = _lib!
        .lookupFunction<SecClearSecureMemoryC, SecClearSecureMemoryDart>(
            'sec_clear_secure_memory');
    secTransferV3ListUnfinished = _lib!.lookupFunction<
        SecTransferV3ListUnfinishedC,
        SecTransferV3ListUnfinishedDart>('sec_transfer_v3_list_unfinished');
    secTransferV3CleanUnfinished = _lib!.lookupFunction<
        SecTransferV3CleanUnfinishedC,
        SecTransferV3CleanUnfinishedDart>('sec_transfer_v3_clean_unfinished');
    secTransferV3RecoverConvert = _lib!.lookupFunction<
        SecTransferV3RecoverConvertC,
        SecTransferV3RecoverConvertDart>('sec_transfer_v3_recover_convert');
    secTransferV3ConvertRoot = _lib!.lookupFunction<SecTransferV3ConvertRootC,
        SecTransferV3ConvertRootDart>('sec_transfer_v3_convert_root');
    secTransferV3ImportFile = _lib!
        .lookupFunction<SecTransferV3ImportFileC, SecTransferV3ImportFileDart>(
            'sec_transfer_v3_import_file');
    secTransferV3ImportDirectory = _lib!.lookupFunction<
        SecTransferV3ImportDirectoryC,
        SecTransferV3ImportDirectoryDart>('sec_transfer_v3_import_directory');
    secTransferV3ExportFile = _lib!
        .lookupFunction<SecTransferV3ExportFileC, SecTransferV3ExportFileDart>(
            'sec_transfer_v3_export_file');
    secTransferV3ExportDirectory = _lib!.lookupFunction<
        SecTransferV3ExportDirectoryC,
        SecTransferV3ExportDirectoryDart>('sec_transfer_v3_export_directory');
    secTransferV3ImportFileWithCallback = _lib!.lookupFunction<
            SecTransferV3WithCallbackC, SecTransferV3WithCallbackDart>(
        'sec_transfer_v3_import_file_with_callback');
    secTransferV3ImportDirectoryWithCallback = _lib!.lookupFunction<
            SecTransferV3WithCallbackC, SecTransferV3WithCallbackDart>(
        'sec_transfer_v3_import_directory_with_callback');
    secTransferV3ExportFileWithCallback = _lib!.lookupFunction<
            SecTransferV3WithCallbackC, SecTransferV3WithCallbackDart>(
        'sec_transfer_v3_export_file_with_callback');
    secTransferV3ExportDirectoryWithCallback = _lib!.lookupFunction<
            SecTransferV3WithCallbackC, SecTransferV3WithCallbackDart>(
        'sec_transfer_v3_export_directory_with_callback');
    secTransferV3Cancel = _lib!
        .lookupFunction<SecTransferV3CancelC, SecTransferV3CancelDart>(
            'sec_transfer_v3_cancel');
  }
}
