import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

class DirectoryCursorPage {
  const DirectoryCursorPage({required this.entries, required this.done});

  final List<Map<String, dynamic>> entries;
  final bool done;
}

class NativeOperationException implements Exception {
  const NativeOperationException(this.operation, this.message, {this.code});

  final String operation;
  final String message;
  final int? code;

  @override
  String toString() => code == null
      ? 'NativeOperationException($operation): $message'
      : 'NativeOperationException($operation, code=$code): $message';
}

abstract final class NativeErrorCode {
  static const invalidPassword = 1001;
  static const passwordVerifierAbsent = 1002;
  static const invalidConfig = 1101;
  static const rootSessionNotFound = 1201;
  static const transferMarkerCorrupt = 1202;
  static const transferV3Unavailable = 1203;
}

/// Native library wrapper for Safe Disk FFI operations.
///
/// Architecture:
/// - Root-based operations: Open a root directory, get a rootID
/// - File operations: Use rootID to open/read/write files
/// - ID mapping managed by Go backend (ffi_comm.Store)
/// - Transfer V3 exposes synchronous import/export plus unfinished markers
///
/// Usage:
/// ```dart
/// // 1. Open root
/// final rootID = NativeLib.instance.secRootOpen('/path/to/root', 'password', '{}');
///
/// // 2. Read file
/// final data = NativeLib.instance.secQuickReadFile(rootID, 'path/to/file.txt');
///
/// // 3. Write file
/// NativeLib.instance.secQuickWriteFile(rootID, 'path/to/file.txt', data);
///
/// // 4. Close root
/// NativeLib.instance.secRootClose(rootID);
/// ```
class NativeLib {
  final NativeBindings _bindings = NativeBindings.instance;

  static NativeLib? _instance;

  static NativeLib get instance {
    _instance ??= NativeLib._();
    return _instance!;
  }

  NativeLib._();

  /// Forces dynamic-library loading and symbol binding before user actions.
  static void ensureAvailable() {
    NativeBindings.instance;
  }

  // ==================== Helper Methods ====================

  /// Converts FFI result pointer to Dart string and frees the pointer.
  String _ptrToString(Pointer<Utf8> ptr) {
    try {
      return ptr.toDartString();
    } finally {
      _bindings.secFreeString(ptr);
    }
  }

  /// Parses JSON string to Map.
  Map<String, dynamic> _parseJson(String jsonStr) {
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Checks result and throws on error.
  void _checkResult(Map<String, dynamic> data, String operation) {
    if (data['success'] != true) {
      throw NativeOperationException(
        operation,
        data['error']?.toString() ?? '$operation failed',
        code: data['code'] as int?,
      );
    }
  }

  // ==================== Root Operations ====================

  /// Opens a secure root directory.
  ///
  /// Returns rootID on success, throws on error.
  int secRootOpen(String rootPath, String password, String configJSON) {
    final rootPathPtr = rootPath.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();
    final configJSONPtr = configJSON.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.secRootOpen(rootPathPtr, passwordPtr, configJSONPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secRootOpen');
      return data['data']['root_id'] as int;
    } finally {
      calloc.free(rootPathPtr);
      calloc.free(passwordPtr);
      calloc.free(configJSONPtr);
    }
  }

  /// Closes a secure root directory.
  void secRootClose(int rootID) {
    final resultPtr = _bindings.secRootClose(rootID);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secRootClose');
  }

  /// Creates a secure root configuration.
  void secCreateRootConfig(
      String rootPath, String password, String optionsJSON) {
    final rootPathPtr = rootPath.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();
    final optionsJSONPtr = optionsJSON.toNativeUtf8();

    try {
      final resultPtr = _bindings.secCreateRootConfig(
          rootPathPtr, passwordPtr, optionsJSONPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secCreateRootConfig');
    } finally {
      calloc.free(rootPathPtr);
      calloc.free(passwordPtr);
      calloc.free(optionsJSONPtr);
    }
  }

  /// Changes a password-changeable root's password without rewriting files.
  void secRootChangePassword(
    String rootPath,
    String oldPassword,
    String newPassword,
  ) {
    final rootPathPtr = rootPath.toNativeUtf8();
    final oldPasswordPtr = oldPassword.toNativeUtf8();
    final newPasswordPtr = newPassword.toNativeUtf8();

    try {
      final resultPtr = _bindings.secRootChangePassword(
        rootPathPtr,
        oldPasswordPtr,
        newPasswordPtr,
      );
      final data = _parseJson(_ptrToString(resultPtr));
      _checkResult(data, 'secRootChangePassword');
    } finally {
      calloc.free(rootPathPtr);
      calloc.free(oldPasswordPtr);
      calloc.free(newPasswordPtr);
    }
  }

  // ==================== File Operations ====================

  /// Opens a file within a secure root.
  ///
  /// Mode: 0=read, 1=write, 2=readwrite
  int secFileOpen(int rootID, String path, int mode) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFileOpen(rootID, pathPtr, mode);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secFileOpen');
      return data['data']['file_id'] as int;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Closes a file.
  void secFileClose(int fileID) {
    final resultPtr = _bindings.secFileClose(fileID);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secFileClose');
  }

  /// Reads data from a file.
  List<int> secFileRead(int fileID, int size) {
    final resultPtr = _bindings.secFileRead(fileID, size);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secFileRead');

    // Data is base64 encoded in JSON
    final base64Data = data['data']['data'] as String;
    return base64Decode(base64Data);
  }

  /// Writes data to a file.
  void secFileWrite(int fileID, List<int> data) {
    final dataPtr = _bytesToNative(data);

    try {
      final resultPtr =
          _bindings.secFileWrite(fileID, dataPtr.cast<Utf8>(), data.length);
      final result = _ptrToString(resultPtr);
      final resultData = _parseJson(result);
      _checkResult(resultData, 'secFileWrite');
    } finally {
      calloc.free(dataPtr);
    }
  }

  /// Seeks in a file.
  ///
  /// Whence: 0=SEEK_SET, 1=SEEK_CUR, 2=SEEK_END
  int secFileSeek(int fileID, int offset, int whence) {
    final resultPtr = _bindings.secFileSeek(fileID, offset, whence);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secFileSeek');
    return data['data']['position'] as int;
  }

  /// Truncates a file.
  void secFileTruncate(int fileID, int size) {
    final resultPtr = _bindings.secFileTruncate(fileID, size);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secFileTruncate');
  }

  /// Deletes a file.
  void secFileDelete(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFileDelete(rootID, pathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secFileDelete');
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Atomically renames a file or directory without replacing a target.
  void secRename(int rootID, String oldPath, String newPath) {
    final oldPathPtr = oldPath.toNativeUtf8();
    final newPathPtr = newPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secRename(rootID, oldPathPtr, newPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secRename');
    } finally {
      calloc.free(oldPathPtr);
      calloc.free(newPathPtr);
    }
  }

  /// Copies and re-encrypts one logical entry between open roots.
  void secCopyEntry(
    int srcRootID,
    String srcPath,
    int dstRootID,
    String dstPath, {
    bool overwrite = false,
  }) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final dstPathPtr = dstPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secCopyEntry(
        srcRootID,
        srcPathPtr,
        dstRootID,
        dstPathPtr,
        overwrite ? 1 : 0,
      );
      final data = _parseJson(_ptrToString(resultPtr));
      _checkResult(data, 'secCopyEntry');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(dstPathPtr);
    }
  }

  Future<void> secCopyEntryInBackground(
    int srcRootID,
    String srcPath,
    int dstRootID,
    String dstPath, {
    bool overwrite = false,
  }) {
    return Isolate.run(() {
      NativeLib.instance.secCopyEntry(
        srcRootID,
        srcPath,
        dstRootID,
        dstPath,
        overwrite: overwrite,
      );
    }, debugName: 'safe-disk-copy-entry');
  }

  void secCreateEmptyFile(int rootID, String path) {
    _runCreateEntry(
        _bindings.secCreateEmptyFile, rootID, path, 'secCreateEmptyFile');
  }

  void secCreateDirectory(int rootID, String path) {
    _runCreateEntry(
        _bindings.secCreateDirectory, rootID, path, 'secCreateDirectory');
  }

  void _runCreateEntry(
    SecCreateEntryDart nativeFunction,
    int rootID,
    String path,
    String operation,
  ) {
    final pathPtr = path.toNativeUtf8();
    try {
      final data = _parseJson(_ptrToString(nativeFunction(rootID, pathPtr)));
      _checkResult(data, operation);
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Checks if a file exists.
  bool secFileExists(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFileExists(rootID, pathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      if (data['success'] != true) {
        return false;
      }
      return data['data']['exists'] as bool;
    } finally {
      calloc.free(pathPtr);
    }
  }

  // ==================== Directory Operations ====================

  /// Creates a directory.
  void secMkdirAll(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secMkdirAll(rootID, pathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secMkdirAll');
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Reads directory entries.
  List<Map<String, dynamic>> secReadDir(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secReadDir(rootID, pathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secReadDir');

      final entries = data['data']['entries'] as List? ?? const [];
      return entries.cast<Map<String, dynamic>>();
    } finally {
      calloc.free(pathPtr);
    }
  }

  int secOpenDirCursor(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      final data =
          _parseJson(_ptrToString(_bindings.secDirCursorOpen(rootID, pathPtr)));
      _checkResult(data, 'secOpenDirCursor');
      return data['data']['cursor_id'] as int;
    } finally {
      calloc.free(pathPtr);
    }
  }

  DirectoryCursorPage secReadDirCursorPage(int cursorID, int limit) {
    final data = _parseJson(
        _ptrToString(_bindings.secDirCursorReadPage(cursorID, limit)));
    _checkResult(data, 'secReadDirCursorPage');
    final page = data['data'] as Map<String, dynamic>;
    return DirectoryCursorPage(
      entries:
          (page['entries'] as List? ?? const []).cast<Map<String, dynamic>>(),
      done: page['done'] as bool,
    );
  }

  void secCloseDirCursor(int cursorID) {
    final data =
        _parseJson(_ptrToString(_bindings.secDirCursorClose(cursorID)));
    _checkResult(data, 'secCloseDirCursor');
  }

  // ==================== Quick Operations ====================

  /// Quick reads a file (open + read + close).
  List<int> secQuickReadFile(int rootID, String path) {
    final pathPtr = path.toNativeUtf8();

    try {
      final resultPtr = _bindings.secQuickReadFile(rootID, pathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secQuickReadFile');

      final base64Data = data['data']['data'] as String;
      return base64Decode(base64Data);
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Quick writes a file (open + write + close).
  void secQuickWriteFile(int rootID, String path, List<int> data) {
    final pathPtr = path.toNativeUtf8();
    final dataPtr = _bytesToNative(data);

    try {
      final resultPtr = _bindings.secQuickWriteFile(
          rootID, pathPtr, dataPtr.cast<Utf8>(), data.length);
      final result = _ptrToString(resultPtr);
      final resultData = _parseJson(result);
      _checkResult(resultData, 'secQuickWriteFile');
    } finally {
      calloc.free(pathPtr);
      calloc.free(dataPtr);
    }
  }

  Pointer<Uint8> _bytesToNative(List<int> data) {
    final ptr = calloc<Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, Uint8List.fromList(data));
    return ptr;
  }

  // ==================== Utility Operations ====================

  /// Clears a mutable byte buffer and its temporary native copy.
  void clearSecureBytes(Uint8List data) {
    final dataPtr = _bytesToNative(data);

    try {
      final resultPtr = _bindings.secClearSecureMemory(dataPtr, data.length);
      final result = _ptrToString(resultPtr);
      final resultData = _parseJson(result);
      _checkResult(resultData, 'clearSecureBytes');
    } finally {
      calloc.free(dataPtr);
      data.fillRange(0, data.length, 0);
    }
  }

  /// Best-effort clear for string content by clearing a UTF-8 byte copy.
  void clearSecureMemory(String text) {
    if (text.isEmpty) {
      return;
    }
    clearSecureBytes(Uint8List.fromList(utf8.encode(text)));
  }

  // ==================== Transfer V3 Operations ====================

  List<Map<String, dynamic>> secTransferV3ListUnfinished(int rootID) {
    final resultPtr = _bindings.secTransferV3ListUnfinished(rootID);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secTransferV3ListUnfinished');
    final responseData = data['data'];
    if (responseData is! Map) {
      throw StateError('secTransferV3ListUnfinished returned invalid data');
    }
    final markers = responseData['markers'];
    if (markers is! List) {
      throw StateError('secTransferV3ListUnfinished returned invalid markers');
    }
    return markers.map((marker) {
      if (marker is! Map) {
        throw StateError('secTransferV3ListUnfinished returned invalid marker');
      }
      return Map<String, dynamic>.from(marker);
    }).toList(growable: false);
  }

  void secTransferV3CleanUnfinished(int rootID, String opID) {
    final opIDPtr = opID.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3CleanUnfinished(rootID, opIDPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3CleanUnfinished');
    } finally {
      calloc.free(opIDPtr);
    }
  }

  Map<String, dynamic> secTransferV3RecoverConvert(String rootPath) {
    final rootPathPtr = rootPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3RecoverConvert(rootPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3RecoverConvert');
      return data['data'] as Map<String, dynamic>;
    } finally {
      calloc.free(rootPathPtr);
    }
  }

  void secTransferV3ConvertRoot(String rootPath, String password, String kind) {
    final rootPathPtr = rootPath.toNativeUtf8();
    final passwordPtr = password.toNativeUtf8();
    final kindPtr = kind.toNativeUtf8();
    try {
      final resultPtr =
          _bindings.secTransferV3ConvertRoot(rootPathPtr, passwordPtr, kindPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ConvertRoot');
    } finally {
      calloc.free(rootPathPtr);
      calloc.free(passwordPtr);
      calloc.free(kindPtr);
    }
  }

  void secTransferV3ImportFile(
    int rootID,
    String srcPath,
    String destPath, {
    bool overwrite = false,
  }) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3ImportFile(
        rootID,
        srcPathPtr,
        destPathPtr,
        overwrite ? 1 : 0,
      );
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ImportFile');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  Future<void> secTransferV3ImportFileWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    void Function(TransferProgressEvent progress) onProgress, {
    bool overwrite = false,
    TransferCancellationToken? cancellationToken,
  }) {
    return _runTransferInBackground(
      kind: _TransferWorkerKind.importFile,
      rootID: rootID,
      srcPath: srcPath,
      destPath: destPath,
      operation: 'secTransferV3ImportFileWithProgress',
      overwrite: overwrite,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  void secTransferV3ImportDirectory(
    int rootID,
    String srcPath,
    String destPath, {
    bool overwrite = false,
  }) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3ImportDirectory(
        rootID,
        srcPathPtr,
        destPathPtr,
        overwrite ? 1 : 0,
      );
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ImportDirectory');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  Future<void> secTransferV3ImportDirectoryWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    void Function(TransferProgressEvent progress) onProgress, {
    bool overwrite = false,
    TransferCancellationToken? cancellationToken,
  }) {
    return _runTransferInBackground(
      kind: _TransferWorkerKind.importDirectory,
      rootID: rootID,
      srcPath: srcPath,
      destPath: destPath,
      operation: 'secTransferV3ImportDirectoryWithProgress',
      overwrite: overwrite,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  void secTransferV3ExportFile(int rootID, String srcPath, String destPath) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr =
          _bindings.secTransferV3ExportFile(rootID, srcPathPtr, destPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ExportFile');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  Future<void> secTransferV3ExportFileWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    void Function(TransferProgressEvent progress) onProgress, {
    TransferCancellationToken? cancellationToken,
  }) {
    return _runTransferInBackground(
      kind: _TransferWorkerKind.exportFile,
      rootID: rootID,
      srcPath: srcPath,
      destPath: destPath,
      operation: 'secTransferV3ExportFileWithProgress',
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  void secTransferV3ExportDirectory(
      int rootID, String srcPath, String destPath) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3ExportDirectory(
          rootID, srcPathPtr, destPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ExportDirectory');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  Future<void> secTransferV3ExportDirectoryWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    void Function(TransferProgressEvent progress) onProgress, {
    TransferCancellationToken? cancellationToken,
  }) {
    return _runTransferInBackground(
      kind: _TransferWorkerKind.exportDirectory,
      rootID: rootID,
      srcPath: srcPath,
      destPath: destPath,
      operation: 'secTransferV3ExportDirectoryWithProgress',
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  Future<void> _runTransferInBackground({
    required String kind,
    required int rootID,
    required String srcPath,
    required String destPath,
    required String operation,
    required void Function(TransferProgressEvent progress) onProgress,
    bool overwrite = false,
    TransferCancellationToken? cancellationToken,
  }) async {
    final messages = ReceivePort();
    final operationID = _newTransferOperationID();
    cancellationToken?._bind(operationID);
    Object? callbackError;
    StackTrace? callbackStackTrace;

    try {
      await Isolate.spawn<Map<String, Object>>(
        _transferWorkerMain,
        <String, Object>{
          'sendPort': messages.sendPort,
          'kind': kind,
          'rootID': rootID,
          'srcPath': srcPath,
          'destPath': destPath,
          'operation': operation,
          'operationID': operationID,
          'overwrite': overwrite,
        },
        onExit: messages.sendPort,
        debugName: 'safe-disk-transfer-$kind',
      );

      await for (final message in messages) {
        if (message == null) {
          throw StateError('$operation worker exited without a result');
        }

        final event = message as Map<Object?, Object?>;
        switch (event['type']) {
          case 'progress':
            final progress = TransferProgressEvent.fromMessage(
              event['progress']! as Map<Object?, Object?>,
            );
            if (progress.isComplete) {
              cancellationToken?._markComplete();
            } else {
              cancellationToken?._markActive();
            }
            if (callbackError == null) {
              try {
                onProgress(progress);
              } catch (error, stackTrace) {
                // Keep the worker callback alive until native code returns.
                callbackError = error;
                callbackStackTrace = stackTrace;
              }
            }
          case 'complete':
            if (callbackError != null) {
              Error.throwWithStackTrace(callbackError, callbackStackTrace!);
            }
            return;
          case 'error':
            throw StateError(event['error']! as String);
          default:
            throw StateError('$operation worker sent an unknown event');
        }
      }
    } finally {
      cancellationToken?._markComplete();
      messages.close();
    }
  }

  void _runTransferWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    String operationID,
    SecTransferV3WithCallbackDart nativeFunction,
    String operation,
    void Function(TransferProgressEvent progress) onProgress,
  ) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    final operationIDPtr = operationID.toNativeUtf8();
    late final NativeCallable<NativeProgressCallbackC> callback;
    callback = NativeCallable<NativeProgressCallbackC>.isolateLocal(
      (
        Pointer<Utf8> currentFile,
        int filesCompleted,
        int filesTotal,
        int isComplete,
        Pointer<Utf8> errorMessage,
      ) {
        onProgress(TransferProgressEvent(
          currentFile: currentFile == nullptr ? '' : currentFile.toDartString(),
          completedFiles: filesCompleted,
          totalFiles: filesTotal,
          isComplete: isComplete != 0,
          errorMessage:
              errorMessage == nullptr ? null : errorMessage.toDartString(),
        ));
      },
    );

    try {
      final resultPtr = nativeFunction(operationIDPtr, rootID, srcPathPtr,
          destPathPtr, callback.nativeFunction);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, operation);
    } finally {
      callback.close();
      calloc.free(operationIDPtr);
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  void _runImportTransferWithProgress(
    int rootID,
    String srcPath,
    String destPath,
    String operationID,
    bool overwrite,
    SecTransferV3ImportWithCallbackDart nativeFunction,
    String operation,
    void Function(TransferProgressEvent progress) onProgress,
  ) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    final operationIDPtr = operationID.toNativeUtf8();
    late final NativeCallable<NativeProgressCallbackC> callback;
    callback = NativeCallable<NativeProgressCallbackC>.isolateLocal(
      (
        Pointer<Utf8> currentFile,
        int filesCompleted,
        int filesTotal,
        int isComplete,
        Pointer<Utf8> errorMessage,
      ) {
        onProgress(TransferProgressEvent(
          currentFile: currentFile == nullptr ? '' : currentFile.toDartString(),
          completedFiles: filesCompleted,
          totalFiles: filesTotal,
          isComplete: isComplete != 0,
          errorMessage:
              errorMessage == nullptr ? null : errorMessage.toDartString(),
        ));
      },
    );

    try {
      final resultPtr = nativeFunction(
        operationIDPtr,
        rootID,
        srcPathPtr,
        destPathPtr,
        overwrite ? 1 : 0,
        callback.nativeFunction,
      );
      final data = _parseJson(_ptrToString(resultPtr));
      _checkResult(data, operation);
    } finally {
      callback.close();
      calloc.free(operationIDPtr);
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  bool secTransferV3Cancel(String operationID) {
    final operationIDPtr = operationID.toNativeUtf8();
    try {
      final result =
          _ptrToString(_bindings.secTransferV3Cancel(operationIDPtr));
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3Cancel');
      return data['data']['active'] as bool;
    } finally {
      calloc.free(operationIDPtr);
    }
  }
}

abstract final class _TransferWorkerKind {
  static const importFile = 'import-file';
  static const importDirectory = 'import-directory';
  static const exportFile = 'export-file';
  static const exportDirectory = 'export-directory';
}

void _transferWorkerMain(Map<String, Object> request) {
  final sendPort = request['sendPort']! as SendPort;
  final kind = request['kind']! as String;
  final rootID = request['rootID']! as int;
  final srcPath = request['srcPath']! as String;
  final destPath = request['destPath']! as String;
  final operation = request['operation']! as String;
  final operationID = request['operationID']! as String;
  final overwrite = request['overwrite']! as bool;
  final native = NativeLib.instance;

  void report(TransferProgressEvent progress) {
    sendPort.send(<String, Object>{
      'type': 'progress',
      'progress': progress.toMessage(),
    });
  }

  try {
    switch (kind) {
      case _TransferWorkerKind.importFile:
        native._runImportTransferWithProgress(
            rootID,
            srcPath,
            destPath,
            operationID,
            overwrite,
            native._bindings.secTransferV3ImportFileWithCallback,
            operation,
            report);
      case _TransferWorkerKind.importDirectory:
        native._runImportTransferWithProgress(
            rootID,
            srcPath,
            destPath,
            operationID,
            overwrite,
            native._bindings.secTransferV3ImportDirectoryWithCallback,
            operation,
            report);
      case _TransferWorkerKind.exportFile:
        native._runTransferWithProgress(
            rootID,
            srcPath,
            destPath,
            operationID,
            native._bindings.secTransferV3ExportFileWithCallback,
            operation,
            report);
      case _TransferWorkerKind.exportDirectory:
        native._runTransferWithProgress(
            rootID,
            srcPath,
            destPath,
            operationID,
            native._bindings.secTransferV3ExportDirectoryWithCallback,
            operation,
            report);
      default:
        throw ArgumentError.value(kind, 'kind', 'unsupported transfer kind');
    }
    Isolate.exit(sendPort, const <String, Object>{'type': 'complete'});
  } catch (error) {
    Isolate.exit(sendPort, <String, Object>{
      'type': 'error',
      'error': error.toString(),
    });
  }
}

String _newTransferOperationID() {
  final random = Random.secure();
  final randomPart = List.generate(
    4,
    (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
  ).join();
  return 'dart-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
}

class TransferCancellationToken {
  String? _operationID;
  bool _active = false;
  bool _complete = false;
  bool _cancelRequested = false;

  bool get isActive => _active && !_complete;
  bool get isComplete => _complete;
  bool get isCancelled => _cancelRequested;

  bool cancel() {
    final operationID = _operationID;
    if (!isActive || operationID == null) return false;
    final accepted = NativeLib.instance.secTransferV3Cancel(operationID);
    _cancelRequested = _cancelRequested || accepted;
    return accepted;
  }

  void _bind(String operationID) {
    if (_operationID != null) {
      throw StateError('TransferCancellationToken cannot be reused');
    }
    _operationID = operationID;
  }

  void _markActive() => _active = true;

  void _markComplete() {
    _active = false;
    _complete = true;
  }
}

class TransferProgressEvent {
  final String currentFile;
  final int completedFiles;
  final int totalFiles;
  final bool isComplete;
  final String? errorMessage;

  const TransferProgressEvent({
    required this.currentFile,
    required this.completedFiles,
    required this.totalFiles,
    required this.isComplete,
    this.errorMessage,
  });

  factory TransferProgressEvent.fromMessage(Map<Object?, Object?> message) {
    return TransferProgressEvent(
      currentFile: message['currentFile']! as String,
      completedFiles: message['completedFiles']! as int,
      totalFiles: message['totalFiles']! as int,
      isComplete: message['isComplete']! as bool,
      errorMessage: message['errorMessage'] as String?,
    );
  }

  Map<String, Object?> toMessage() => <String, Object?>{
        'currentFile': currentFile,
        'completedFiles': completedFiles,
        'totalFiles': totalFiles,
        'isComplete': isComplete,
        'errorMessage': errorMessage,
      };

  int get percent {
    if (totalFiles <= 0) {
      return isComplete ? 100 : 0;
    }
    return ((completedFiles / totalFiles) * 100).round().clamp(0, 100);
  }
}
