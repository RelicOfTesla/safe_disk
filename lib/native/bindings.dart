import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

enum NativeLibraryFailureStage { load, bind, unknown }

class NativeLibraryException implements Exception {
  const NativeLibraryException(this.stage, this.cause);

  final NativeLibraryFailureStage stage;
  final Object cause;

  String get operation => switch (stage) {
        NativeLibraryFailureStage.load => 'native-library/load',
        NativeLibraryFailureStage.bind => 'native-library/bind',
        NativeLibraryFailureStage.unknown => 'native-library/initialize',
      };

  @override
  String toString() => 'NativeLibraryException($operation): $cause';
}

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

// sec_webdav_open: (rootID, exposedPath, displayName) -> JSON string
typedef SecWebDavOpenC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> exposedPath, Pointer<Utf8> displayName);
typedef SecWebDavOpenDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> exposedPath, Pointer<Utf8> displayName);

// sec_webdav_open_with_options: (rootID, exposedPath, displayName, optionsJSON) -> JSON string
typedef SecWebDavOpenWithOptionsC = Pointer<Utf8> Function(
    Int64 rootID,
    Pointer<Utf8> exposedPath,
    Pointer<Utf8> displayName,
    Pointer<Utf8> optionsJSON);
typedef SecWebDavOpenWithOptionsDart = Pointer<Utf8> Function(
    int rootID,
    Pointer<Utf8> exposedPath,
    Pointer<Utf8> displayName,
    Pointer<Utf8> optionsJSON);

// sec_webdav_close: (sessionID) -> JSON string
typedef SecWebDavCloseC = Pointer<Utf8> Function(Pointer<Utf8> sessionID);
typedef SecWebDavCloseDart = Pointer<Utf8> Function(Pointer<Utf8> sessionID);

// sec_webdav_reveal: (sessionID) -> JSON string
typedef SecWebDavRevealC = Pointer<Utf8> Function(Pointer<Utf8> sessionID);
typedef SecWebDavRevealDart = Pointer<Utf8> Function(Pointer<Utf8> sessionID);

// sec_webdav_list: (rootID) -> JSON string
typedef SecWebDavListC = Pointer<Utf8> Function(Int64 rootID);
typedef SecWebDavListDart = Pointer<Utf8> Function(int rootID);

// sec_webdav_mount: (sessionID) -> JSON string
typedef SecWebDavMountC = Pointer<Utf8> Function(Pointer<Utf8> sessionID);
typedef SecWebDavMountDart = Pointer<Utf8> Function(Pointer<Utf8> sessionID);

// sec_webdav_unmount: (sessionID) -> JSON string
typedef SecWebDavUnmountC = Pointer<Utf8> Function(Pointer<Utf8> sessionID);
typedef SecWebDavUnmountDart = Pointer<Utf8> Function(Pointer<Utf8> sessionID);

// sec_webdav_mount_start: (operationID, sessionID) -> JSON string
typedef SecWebDavMountStartC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID, Pointer<Utf8> sessionID);
typedef SecWebDavMountStartDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID, Pointer<Utf8> sessionID);

// sec_webdav_unmount_start: (operationID, sessionID) -> JSON string
typedef SecWebDavUnmountStartC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID, Pointer<Utf8> sessionID);
typedef SecWebDavUnmountStartDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID, Pointer<Utf8> sessionID);

// sec_webdav_operation_poll: (operationID) -> JSON string
typedef SecWebDavOperationPollC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);
typedef SecWebDavOperationPollDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);

// sec_webdav_operation_cancel: (operationID) -> JSON string
typedef SecWebDavOperationCancelC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);
typedef SecWebDavOperationCancelDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID);

// sec_webdav_export_cert_pem: () -> JSON string
typedef SecWebDavExportCertPEMC = Pointer<Utf8> Function();
typedef SecWebDavExportCertPEMDart = Pointer<Utf8> Function();
 
// sec_webdav_export_ca_cert_pem: () -> JSON string
typedef SecWebDavExportCACertPEMC = Pointer<Utf8> Function();
typedef SecWebDavExportCACertPEMDart = Pointer<Utf8> Function();

// sec_create_root_config: (rootPath, password, optionsJSON) -> JSON string
typedef SecCreateRootConfigC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> optionsJSON);
typedef SecCreateRootConfigDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> optionsJSON);

// sec_root_change_password: (rootPath, oldPassword, newPassword) -> JSON
typedef SecRootChangePasswordC = Pointer<Utf8> Function(Pointer<Utf8> rootPath,
    Pointer<Utf8> oldPassword, Pointer<Utf8> newPassword);
typedef SecRootChangePasswordDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath,
    Pointer<Utf8> oldPassword,
    Pointer<Utf8> newPassword);

// sec_root_read_password_hint: (rootPath) -> JSON
typedef SecRootReadPasswordHintC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath);
typedef SecRootReadPasswordHintDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath);

// sec_root_update_password_hint: (rootPath, password, hint) -> JSON
typedef SecRootUpdatePasswordHintC = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> hint);
typedef SecRootUpdatePasswordHintDart = Pointer<Utf8> Function(
    Pointer<Utf8> rootPath, Pointer<Utf8> password, Pointer<Utf8> hint);

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

// sec_directory_delete_tree: (rootID, path) -> JSON string
typedef SecDirectoryDeleteTreeC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecDirectoryDeleteTreeDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);

// sec_rename: (rootID, oldPath, newPath) -> JSON string
typedef SecRenameC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> oldPath, Pointer<Utf8> newPath);
typedef SecRenameDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> oldPath, Pointer<Utf8> newPath);

// sec_copy_entry: (srcRootID, srcPath, dstRootID, dstPath, overwrite) -> JSON
typedef SecCopyEntryC = Pointer<Utf8> Function(
    Int64 srcRootID,
    Pointer<Utf8> srcPath,
    Int64 dstRootID,
    Pointer<Utf8> dstPath,
    Int32 overwrite);
typedef SecCopyEntryDart = Pointer<Utf8> Function(int srcRootID,
    Pointer<Utf8> srcPath, int dstRootID, Pointer<Utf8> dstPath, int overwrite);

typedef SecCreateEntryC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecCreateEntryDart = Pointer<Utf8> Function(
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

typedef SecDirCursorOpenC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> path);
typedef SecDirCursorOpenDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> path);
typedef SecDirCursorReadPageC = Pointer<Utf8> Function(
    Int64 cursorID, Int32 limit);
typedef SecDirCursorReadPageDart = Pointer<Utf8> Function(
    int cursorID, int limit);
typedef SecDirCursorCloseC = Pointer<Utf8> Function(Int64 cursorID);
typedef SecDirCursorCloseDart = Pointer<Utf8> Function(int cursorID);

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

typedef SecTransferV3ImportFileC = Pointer<Utf8> Function(Int64 rootID,
    Pointer<Utf8> srcPath, Pointer<Utf8> destPath, Int32 overwrite,
    Pointer<Utf8> durability);
typedef SecTransferV3ImportFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath, int overwrite,
    Pointer<Utf8> durability);

typedef SecTransferV3ImportDirectoryC = Pointer<Utf8> Function(Int64 rootID,
    Pointer<Utf8> srcPath, Pointer<Utf8> destPath, Int32 overwrite,
    Pointer<Utf8> durability);
typedef SecTransferV3ImportDirectoryDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath, int overwrite,
    Pointer<Utf8> durability);

typedef SecTransferV3ExportFileC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath,
    Pointer<Utf8> durability);
typedef SecTransferV3ExportFileDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath,
    Pointer<Utf8> durability);

typedef SecTransferV3ExportDirectoryC = Pointer<Utf8> Function(
    Int64 rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath,
    Pointer<Utf8> durability);
typedef SecTransferV3ExportDirectoryDart = Pointer<Utf8> Function(
    int rootID, Pointer<Utf8> srcPath, Pointer<Utf8> destPath,
    Pointer<Utf8> durability);

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
    Pointer<Utf8> durability,
    Pointer<NativeFunction<NativeProgressCallbackC>> callback);
typedef SecTransferV3WithCallbackDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID,
    int rootID,
    Pointer<Utf8> srcPath,
    Pointer<Utf8> destPath,
    Pointer<Utf8> durability,
    Pointer<NativeFunction<NativeProgressCallbackC>> callback);

typedef SecTransferV3ImportWithCallbackC = Pointer<Utf8> Function(
    Pointer<Utf8> operationID,
    Int64 rootID,
    Pointer<Utf8> srcPath,
    Pointer<Utf8> destPath,
    Int32 overwrite,
    Pointer<Utf8> durability,
    Pointer<NativeFunction<NativeProgressCallbackC>> callback);
typedef SecTransferV3ImportWithCallbackDart = Pointer<Utf8> Function(
    Pointer<Utf8> operationID,
    int rootID,
    Pointer<Utf8> srcPath,
    Pointer<Utf8> destPath,
    int overwrite,
    Pointer<Utf8> durability,
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
  late final SecWebDavOpenDart secWebDavOpen;
  late final SecWebDavOpenWithOptionsDart secWebDavOpenWithOptions;
  late final SecWebDavCloseDart secWebDavClose;
  late final SecWebDavRevealDart secWebDavReveal;
  late final SecWebDavListDart secWebDavList;
  late final SecWebDavMountDart secWebDavMount;
  late final SecWebDavUnmountDart secWebDavUnmount;
  late final SecWebDavMountStartDart secWebDavMountStart;
  late final SecWebDavUnmountStartDart secWebDavUnmountStart;
  late final SecWebDavOperationPollDart secWebDavOperationPoll;
  late final SecWebDavOperationCancelDart secWebDavOperationCancel;
  late final SecWebDavExportCertPEMDart secWebDavExportCertPEM;
  late final SecWebDavExportCACertPEMDart secWebDavExportCACertPEM;
  late final SecCreateRootConfigDart secCreateRootConfig;
  late final SecRootChangePasswordDart secRootChangePassword;
  late final SecRootReadPasswordHintDart secRootReadPasswordHint;
  late final SecRootUpdatePasswordHintDart secRootUpdatePasswordHint;
  late final SecFileOpenDart secFileOpen;
  late final SecFileCloseDart secFileClose;
  late final SecFileReadDart secFileRead;
  late final SecFileWriteDart secFileWrite;
  late final SecFileSeekDart secFileSeek;
  late final SecFileTruncateDart secFileTruncate;
  late final SecFileDeleteDart secFileDelete;
  late final SecDirectoryDeleteTreeDart secDirectoryDeleteTree;
  late final SecRenameDart secRename;
  late final SecCopyEntryDart secCopyEntry;
  late final SecCreateEntryDart secCreateEmptyFile;
  late final SecCreateEntryDart secCreateDirectory;
  late final SecFileExistsDart secFileExists;
  late final SecMkdirAllDart secMkdirAll;
  late final SecReadDirDart secReadDir;
  late final SecDirCursorOpenDart secDirCursorOpen;
  late final SecDirCursorReadPageDart secDirCursorReadPage;
  late final SecDirCursorCloseDart secDirCursorClose;
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
  late final SecTransferV3ImportWithCallbackDart
      secTransferV3ImportFileWithCallback;
  late final SecTransferV3ImportWithCallbackDart
      secTransferV3ImportDirectoryWithCallback;
  late final SecTransferV3WithCallbackDart secTransferV3ExportFileWithCallback;
  late final SecTransferV3WithCallbackDart
      secTransferV3ExportDirectoryWithCallback;
  late final SecTransferV3CancelDart secTransferV3Cancel;

  NativeBindings._() {
    try {
      _lib = _openLibrary();
    } on NativeLibraryException {
      rethrow;
    } on Object catch (error) {
      throw NativeLibraryException(NativeLibraryFailureStage.load, error);
    }
    try {
      _bindFunctions();
    } on NativeLibraryException {
      rethrow;
    } on Object catch (error) {
      throw NativeLibraryException(NativeLibraryFailureStage.bind, error);
    }
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
      final libraryPath = File(Platform.resolvedExecutable)
          .parent
          .uri
          .resolve('ffi_sec_fs.dll')
          .toFilePath();
      if (!File(libraryPath).existsSync()) {
        throw StateError('native-library-bundle-missing');
      }
      return DynamicLibrary.open(libraryPath);
    }
    throw UnsupportedError('native-library-platform-unsupported');
  }

  void _bindFunctions() {
    secRootOpen =
        _lib!.lookupFunction<SecRootOpenC, SecRootOpenDart>('sec_root_open');
    secRootClose =
        _lib!.lookupFunction<SecRootCloseC, SecRootCloseDart>('sec_root_close');
    secWebDavOpen = _lib!
        .lookupFunction<SecWebDavOpenC, SecWebDavOpenDart>('sec_webdav_open');
    secWebDavOpenWithOptions = _lib!.lookupFunction<SecWebDavOpenWithOptionsC,
        SecWebDavOpenWithOptionsDart>('sec_webdav_open_with_options');
    secWebDavClose = _lib!.lookupFunction<SecWebDavCloseC, SecWebDavCloseDart>(
        'sec_webdav_close');
    secWebDavReveal = _lib!
        .lookupFunction<SecWebDavRevealC, SecWebDavRevealDart>(
            'sec_webdav_reveal');
    secWebDavList = _lib!
        .lookupFunction<SecWebDavListC, SecWebDavListDart>('sec_webdav_list');
    secWebDavMount = _lib!.lookupFunction<SecWebDavMountC, SecWebDavMountDart>(
        'sec_webdav_mount');
    secWebDavUnmount = _lib!
        .lookupFunction<SecWebDavUnmountC, SecWebDavUnmountDart>(
            'sec_webdav_unmount');
    secWebDavMountStart = _lib!
        .lookupFunction<SecWebDavMountStartC, SecWebDavMountStartDart>(
            'sec_webdav_mount_start');
    secWebDavUnmountStart = _lib!
        .lookupFunction<SecWebDavUnmountStartC, SecWebDavUnmountStartDart>(
            'sec_webdav_unmount_start');
    secWebDavOperationPoll = _lib!
        .lookupFunction<SecWebDavOperationPollC, SecWebDavOperationPollDart>(
            'sec_webdav_operation_poll');
    secWebDavOperationCancel = _lib!.lookupFunction<SecWebDavOperationCancelC,
        SecWebDavOperationCancelDart>('sec_webdav_operation_cancel');
    secWebDavExportCertPEM = _lib!.lookupFunction<SecWebDavExportCertPEMC,
        SecWebDavExportCertPEMDart>('sec_webdav_export_cert_pem');
    secCreateRootConfig = _lib!
        .lookupFunction<SecCreateRootConfigC, SecCreateRootConfigDart>(
            'sec_create_root_config');
    secRootChangePassword = _lib!
        .lookupFunction<SecRootChangePasswordC, SecRootChangePasswordDart>(
            'sec_root_change_password');
    secRootReadPasswordHint = _lib!
        .lookupFunction<SecRootReadPasswordHintC, SecRootReadPasswordHintDart>(
            'sec_root_read_password_hint');
    secRootUpdatePasswordHint = _lib!.lookupFunction<SecRootUpdatePasswordHintC,
        SecRootUpdatePasswordHintDart>('sec_root_update_password_hint');
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
    secDirectoryDeleteTree = _lib!
        .lookupFunction<SecDirectoryDeleteTreeC, SecDirectoryDeleteTreeDart>(
            'sec_directory_delete_tree');
    secRename = _lib!.lookupFunction<SecRenameC, SecRenameDart>('sec_rename');
    secCopyEntry =
        _lib!.lookupFunction<SecCopyEntryC, SecCopyEntryDart>('sec_copy_entry');
    secCreateEmptyFile = _lib!
        .lookupFunction<SecCreateEntryC, SecCreateEntryDart>(
            'sec_create_empty_file');
    secCreateDirectory = _lib!
        .lookupFunction<SecCreateEntryC, SecCreateEntryDart>(
            'sec_create_directory');
    secFileExists = _lib!
        .lookupFunction<SecFileExistsC, SecFileExistsDart>('sec_file_exists');
    secMkdirAll =
        _lib!.lookupFunction<SecMkdirAllC, SecMkdirAllDart>('sec_mkdir_all');
    secReadDir =
        _lib!.lookupFunction<SecReadDirC, SecReadDirDart>('sec_read_dir');
    secDirCursorOpen = _lib!
        .lookupFunction<SecDirCursorOpenC, SecDirCursorOpenDart>(
            'sec_dir_cursor_open');
    secDirCursorReadPage = _lib!
        .lookupFunction<SecDirCursorReadPageC, SecDirCursorReadPageDart>(
            'sec_dir_cursor_read_page');
    secDirCursorClose = _lib!
        .lookupFunction<SecDirCursorCloseC, SecDirCursorCloseDart>(
            'sec_dir_cursor_close');
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
            SecTransferV3ImportWithCallbackC,
            SecTransferV3ImportWithCallbackDart>(
        'sec_transfer_v3_import_file_with_callback');
    secTransferV3ImportDirectoryWithCallback = _lib!.lookupFunction<
            SecTransferV3ImportWithCallbackC,
            SecTransferV3ImportWithCallbackDart>(
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
