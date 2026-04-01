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
