import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

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
      throw Exception(data['error'] ?? '$operation failed');
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
    final dataStr = base64Encode(data);
    final dataPtr = dataStr.toNativeUtf8();

    try {
      final resultPtr = _bindings.secFileWrite(fileID, dataPtr, data.length);
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

      final entries = data['data']['entries'] as List;
      return entries.cast<Map<String, dynamic>>();
    } finally {
      calloc.free(pathPtr);
    }
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
    final dataStr = base64Encode(data);
    final dataPtr = dataStr.toNativeUtf8();

    try {
      final resultPtr =
          _bindings.secQuickWriteFile(rootID, pathPtr, dataPtr, data.length);
      final result = _ptrToString(resultPtr);
      final resultData = _parseJson(result);
      _checkResult(resultData, 'secQuickWriteFile');
    } finally {
      calloc.free(pathPtr);
      calloc.free(dataPtr);
    }
  }

  // ==================== Transfer V3 Operations ====================

  List<Map<String, dynamic>> secTransferV3ListUnfinished(int rootID) {
    final resultPtr = _bindings.secTransferV3ListUnfinished(rootID);
    final result = _ptrToString(resultPtr);
    final data = _parseJson(result);
    _checkResult(data, 'secTransferV3ListUnfinished');
    final markers = data['data']['markers'] as List;
    return markers.cast<Map<String, dynamic>>();
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

  void secTransferV3ImportFile(int rootID, String srcPath, String destPath) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr =
          _bindings.secTransferV3ImportFile(rootID, srcPathPtr, destPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ImportFile');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
  }

  void secTransferV3ImportDirectory(
      int rootID, String srcPath, String destPath) {
    final srcPathPtr = srcPath.toNativeUtf8();
    final destPathPtr = destPath.toNativeUtf8();
    try {
      final resultPtr = _bindings.secTransferV3ImportDirectory(
          rootID, srcPathPtr, destPathPtr);
      final result = _ptrToString(resultPtr);
      final data = _parseJson(result);
      _checkResult(data, 'secTransferV3ImportDirectory');
    } finally {
      calloc.free(srcPathPtr);
      calloc.free(destPathPtr);
    }
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
}
