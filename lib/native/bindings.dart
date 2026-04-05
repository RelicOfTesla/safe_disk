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

// sec_file_open: (rootID, path, mode) -> JSON string
typedef SecFileOpenC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path, Int32 mode);
typedef SecFileOpenDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path, int mode);

// sec_file_close: (fileID) -> JSON string
typedef SecFileCloseC = Pointer<Utf8> Function(Int64 fileID);
typedef SecFileCloseDart = Pointer<Utf8> Function(int fileID);

// sec_file_read: (fileID, size) -> JSON string
typedef SecFileReadC = Pointer<Utf8> Function(Int64 fileID, Int32 size);
typedef SecFileReadDart = Pointer<Utf8> Function(int fileID, int size);

// sec_file_write: (fileID, data, size) -> JSON string
typedef SecFileWriteC = Pointer<Utf8> Function(Int64 fileID, Pointer<Utf8> data, Int32 size);
typedef SecFileWriteDart = Pointer<Utf8> Function(int fileID, Pointer<Utf8> data, int size);

// sec_file_seek: (fileID, offset, whence) -> JSON string
typedef SecFileSeekC = Pointer<Utf8> Function(Int64 fileID, Int64 offset, Int32 whence);
typedef SecFileSeekDart = Pointer<Utf8> Function(int fileID, int offset, int whence);

// sec_file_truncate: (fileID, size) -> JSON string
typedef SecFileTruncateC = Pointer<Utf8> Function(Int64 fileID, Int64 size);
typedef SecFileTruncateDart = Pointer<Utf8> Function(int fileID, int size);

// sec_file_delete: (rootID, path) -> JSON string
typedef SecFileDeleteC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecFileDeleteDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_file_exists: (rootID, path) -> JSON string
typedef SecFileExistsC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecFileExistsDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_mkdir_all: (rootID, path) -> JSON string
typedef SecMkdirAllC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecMkdirAllDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_read_dir: (rootID, path) -> JSON string
typedef SecReadDirC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecReadDirDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_quick_read_file: (rootID, path) -> JSON string
typedef SecQuickReadFileC = Pointer<Utf8> Function(Int64 rootID, Pointer<Utf8> path);
typedef SecQuickReadFileDart = Pointer<Utf8> Function(int rootID, Pointer<Utf8> path);

// sec_quick_write_file: (rootID, path, data, size) -> JSON string
typedef SecQuickWriteFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path, Pointer<Utf8> data, Int32 size);
typedef SecQuickWriteFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path, Pointer<Utf8> data, int size);

// sec_free_string: (s) -> void
typedef SecFreeStringC = Void Function(Pointer<Utf8> s);
typedef SecFreeStringDart = void Function(Pointer<Utf8> s);

// ==================== Native Bindings Class ====================

class NativeBindings {
  static NativeBindings? _instance;
  static DynamicLibrary? _lib;

  late final SecRootOpenDart secRootOpen;
  late final SecRootCloseDart secRootClose;
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

  NativeBindings._() {
    _lib = _openLibrary();
    _bindFunctions();
  }

  static NativeBindings get instance {
    _instance ??= NativeBindings._();
    return _instance!;
  }

  static DynamicLibrary _openLibrary() {
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
    secRootOpen = _lib!.lookupFunction<SecRootOpenC, SecRootOpenDart>('sec_root_open');
    secRootClose = _lib!.lookupFunction<SecRootCloseC, SecRootCloseDart>('sec_root_close');
    secFileOpen = _lib!.lookupFunction<SecFileOpenC, SecFileOpenDart>('sec_file_open');
    secFileClose = _lib!.lookupFunction<SecFileCloseC, SecFileCloseDart>('sec_file_close');
    secFileRead = _lib!.lookupFunction<SecFileReadC, SecFileReadDart>('sec_file_read');
    secFileWrite = _lib!.lookupFunction<SecFileWriteC, SecFileWriteDart>('sec_file_write');
    secFileSeek = _lib!.lookupFunction<SecFileSeekC, SecFileSeekDart>('sec_file_seek');
    secFileTruncate = _lib!.lookupFunction<SecFileTruncateC, SecFileTruncateDart>('sec_file_truncate');
    secFileDelete = _lib!.lookupFunction<SecFileDeleteC, SecFileDeleteDart>('sec_file_delete');
    secFileExists = _lib!.lookupFunction<SecFileExistsC, SecFileExistsDart>('sec_file_exists');
    secMkdirAll = _lib!.lookupFunction<SecMkdirAllC, SecMkdirAllDart>('sec_mkdir_all');
    secReadDir = _lib!.lookupFunction<SecReadDirC, SecReadDirDart>('sec_read_dir');
    secQuickReadFile = _lib!.lookupFunction<SecQuickReadFileC, SecQuickReadFileDart>('sec_quick_read_file');
    secQuickWriteFile = _lib!.lookupFunction<SecQuickWriteFileC, SecQuickWriteFileDart>('sec_quick_write_file');
    secFreeString = _lib!.lookupFunction<SecFreeStringC, SecFreeStringDart>('sec_free_string');
  }
}
