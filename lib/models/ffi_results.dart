import 'dart:convert';
import 'dart:typed_data';

/// Base class for FFI operation results
class FFIResult {
  final bool success;
  final String? error;
  
  FFIResult({required this.success, this.error});
  
  factory FFIResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FFIResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

/// Result for data encryption/decryption operations
class DataResult extends FFIResult {
  final Uint8List? data;
  
  DataResult({required bool success, String? error, this.data})
      : super(success: success, error: error);
  
  factory DataResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final success = json['success'] as bool? ?? false;
    
    Uint8List? data;
    if (success && json['data'] != null) {
      data = base64Decode(json['data'] as String);
    }
    
    return DataResult(
      success: success,
      error: json['error'] as String?,
      data: data,
    );
  }
  
  /// Returns the data or throws an exception if failed
  Uint8List get dataOrThrow {
    if (!success) {
      throw Exception(error ?? 'Operation failed');
    }
    if (data == null) {
      throw Exception('No data returned');
    }
    return data!;
  }
}

/// Result for file encryption operations
class FileResult extends FFIResult {
  final String? path;
  
  FileResult({required bool success, String? error, this.path})
      : super(success: success, error: error);
  
  factory FileResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FileResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      path: json['path'] as String?,
    );
  }
  
  /// Throws an exception if operation failed
  void throwOnError() {
    if (!success) {
      throw Exception(error ?? 'Operation failed');
    }
  }
}

/// Result for session creation operations
class SessionResult extends FFIResult {
  final String? tempKeyID;
  
  SessionResult({required bool success, String? error, this.tempKeyID})
      : super(success: success, error: error);
  
  factory SessionResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SessionResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      tempKeyID: json['tempKeyID'] as String?,
    );
  }
  
  /// Returns the temp key ID or throws an exception if failed
  String get tempKeyIDOrThrow {
    if (!success) {
      throw Exception(error ?? 'Session creation failed');
    }
    if (tempKeyID == null) {
      throw Exception('No temporary key ID returned');
    }
    return tempKeyID!;
  }
}

/// Result for config loading operations
class ConfigResult extends FFIResult {
  final Map<String, dynamic>? config;
  
  ConfigResult({required bool success, String? error, this.config})
      : super(success: success, error: error);
  
  factory ConfigResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ConfigResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      config: json['config'] as Map<String, dynamic>?,
    );
  }
  
  /// Returns the config or throws an exception if failed
  Map<String, dynamic> get configOrThrow {
    if (!success) {
      throw Exception(error ?? 'Config loading failed');
    }
    if (config == null) {
      throw Exception('No config returned');
    }
    return config!;
  }
}

/// Result for directory finding operations
class FindRootResult extends FFIResult {
  final String? rootPath;
  
  FindRootResult({required bool success, String? error, this.rootPath})
      : super(success: success, error: error);
  
  factory FindRootResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FindRootResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      rootPath: json['rootPath'] as String?,
    );
  }
}

/// Result for checking if a file is chunked
class IsChunkedResult extends FFIResult {
  final bool? isChunked;
  
  IsChunkedResult({required bool success, String? error, this.isChunked})
      : super(success: success, error: error);
  
  factory IsChunkedResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return IsChunkedResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      isChunked: json['isChunked'] as bool?,
    );
  }
  
  /// Returns isChunked or throws an exception if failed
  bool get isChunkedOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to check file format');
    }
    return isChunked ?? false;
  }
}

/// File information result
/// Contains size, isChunked, and recommendedMethod
/// This class is returned by getEncryptedFileInfo
/// Fields:
/// - success: whether the operation was successful
/// - size: file size in bytes
/// - isChunked: whether the file is in chunked format
/// - recommendedMethod: recommended decryption method
/// Note: size and isChunked may be null on error
/// Note: recommendedMethod may be null on error
class FileInfo extends FFIResult {
  final int? size;
  final bool? isChunked;
  final String? recommendedMethod;
  
  FileInfo({
    required bool success,
    String? error,
    this.size,
    this.isChunked,
    this.recommendedMethod,
  }) : super(success: success, error: error);
  
  factory FileInfo.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FileInfo(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      size: json['size'] as int?,
      isChunked: json['isChunked'] as bool?,
      recommendedMethod: json['recommendedMethod'] as String?,
    );
  }
}
