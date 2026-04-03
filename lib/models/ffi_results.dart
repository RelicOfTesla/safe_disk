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

  DataResult({required super.success, super.error, this.data});

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

  FileResult({required super.success, super.error, this.path});

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

  SessionResult({required super.success, super.error, this.tempKeyID});

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

  ConfigResult({required super.success, super.error, this.config});

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

  FindRootResult({required super.success, super.error, this.rootPath});

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

  IsChunkedResult({required super.success, super.error, this.isChunked});

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
    required super.success,
    super.error,
    this.size,
    this.isChunked,
    this.recommendedMethod,
  });

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

/// Result for async job creation (encryptDirectoryAsync, decryptDirectoryAsync)
class JobResult extends FFIResult {
  final String? jobID;

  JobResult({required super.success, super.error, this.jobID});

  factory JobResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return JobResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      jobID: json['jobID'] as String?,
    );
  }

  /// Returns the job ID or throws an exception if failed
  String get jobIDOrThrow {
    if (!success) {
      throw Exception(error ?? 'Job creation failed');
    }
    if (jobID == null) {
      throw Exception('No job ID returned');
    }
    return jobID!;
  }
}

/// Job status enum
enum JobStatus {
  pending,
  running,
  completed,
  cancelled,
  failed,
  unknown;

  static JobStatus fromString(String status) {
    switch (status) {
      case 'pending':
        return JobStatus.pending;
      case 'running':
        return JobStatus.running;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      case 'failed':
        return JobStatus.failed;
      default:
        return JobStatus.unknown;
    }
  }
}

/// Result for getJobStatus operation
class JobStatusResult extends FFIResult {
  final JobStatus? status;

  JobStatusResult({required super.success, super.error, this.status});

  factory JobStatusResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    JobStatus? status;
    if (json['status'] != null) {
      status = JobStatus.fromString(json['status'] as String);
    }
    return JobStatusResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      status: status,
    );
  }
}

/// Progress information for async jobs
class JobProgress {
  final int totalFiles;
  final int processedFiles;
  final String currentFile;
  final int totalBytes;
  final int processedBytes;
  final int percent;
  final String status;
  final String? error;

  JobProgress({
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.currentFile = '',
    this.totalBytes = 0,
    this.processedBytes = 0,
    this.percent = 0,
    this.status = '',
    this.error,
  });

  factory JobProgress.fromJson(Map<String, dynamic> json) {
    return JobProgress(
      totalFiles: json['totalFiles'] as int? ?? 0,
      processedFiles: json['processedFiles'] as int? ?? 0,
      currentFile: json['currentFile'] as String? ?? '',
      totalBytes: json['totalBytes'] as int? ?? 0,
      processedBytes: json['processedBytes'] as int? ?? 0,
      percent: json['percent'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      error: json['error'] as String?,
    );
  }

  /// Returns true if the job is complete (completed, cancelled, or failed)
  bool get isComplete =>
      status == 'completed' || status == 'cancelled' || status == 'failed';

  /// Returns true if the job is running
  bool get isRunning => status == 'running';

  /// Returns true if the job failed
  bool get isFailed => status == 'failed';

  /// Returns true if the job was cancelled
  bool get isCancelled => status == 'cancelled';
}

/// Result for getJobProgress operation
class JobProgressResult extends FFIResult {
  final JobProgress? progress;

  JobProgressResult({required super.success, super.error, this.progress});

  factory JobProgressResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    JobProgress? progress;
    if (json['progress'] != null) {
      progress = JobProgress.fromJson(json['progress'] as Map<String, dynamic>);
    }
    return JobProgressResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      progress: progress,
    );
  }
}

// ==================== INCREMENTAL ENCRYPTION/DECRYPTION RESULTS ====================

/// Result for incrementalEncryptorCreate operation
class IncrementalEncryptorResult extends FFIResult {
  final int? handleID;

  IncrementalEncryptorResult({required super.success, super.error, this.handleID});

  factory IncrementalEncryptorResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return IncrementalEncryptorResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      handleID: json['handleID'] as int?,
    );
  }

  /// Returns the handle ID or throws an exception if failed
  int get handleIDOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to create incremental encryptor');
    }
    if (handleID == null) {
      throw Exception('No handle ID returned');
    }
    return handleID!;
  }
}

/// Result for incrementalDecryptorOpen operation
class IncrementalDecryptorResult extends FFIResult {
  final int? handleID;
  final int? chunkCount;
  final int? totalSize;

  IncrementalDecryptorResult({
    required super.success,
    super.error,
    this.handleID,
    this.chunkCount,
    this.totalSize,
  });

  factory IncrementalDecryptorResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return IncrementalDecryptorResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      handleID: json['handleID'] as int?,
      chunkCount: json['chunkCount'] as int?,
      totalSize: json['totalSize'] as int?,
    );
  }

  /// Returns the handle ID or throws an exception if failed
  int get handleIDOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to open incremental decryptor');
    }
    if (handleID == null) {
      throw Exception('No handle ID returned');
    }
    return handleID!;
  }
}

/// Result for incremental block decryption operations
class IncrementalBlockResult extends FFIResult {
  final Uint8List? data;

  IncrementalBlockResult({required super.success, super.error, this.data});

  factory IncrementalBlockResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final success = json['success'] as bool? ?? false;

    Uint8List? data;
    if (success && json['data'] != null) {
      data = base64Decode(json['data'] as String);
    }

    return IncrementalBlockResult(
      success: success,
      error: json['error'] as String?,
      data: data,
    );
  }

  /// Returns the data or throws an exception if failed
  Uint8List get dataOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to decrypt block');
    }
    if (data == null) {
      throw Exception('No data returned');
    }
    return data!;
  }
}

/// Block information for incremental encrypted files
class IncrementalBlockInfo {
  final int index;
  final int offset;
  final int size;
  final String hash;

  IncrementalBlockInfo({
    required this.index,
    required this.offset,
    required this.size,
    required this.hash,
  });

  factory IncrementalBlockInfo.fromJson(Map<String, dynamic> json) {
    return IncrementalBlockInfo(
      index: json['index'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      hash: json['hash'] as String? ?? '',
    );
  }
}

/// Result for incrementalDecryptorGetBlockInfo operation
class IncrementalBlockInfoResult extends FFIResult {
  final IncrementalBlockInfo? blockInfo;

  IncrementalBlockInfoResult({required super.success, super.error, this.blockInfo});

  factory IncrementalBlockInfoResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    IncrementalBlockInfo? blockInfo;
    if (json['blockInfo'] != null) {
      blockInfo = IncrementalBlockInfo.fromJson(
        json['blockInfo'] as Map<String, dynamic>,
      );
    }
    return IncrementalBlockInfoResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      blockInfo: blockInfo,
    );
  }
}

/// Result for incrementalDecryptorGetAllBlockInfo operation
class IncrementalAllBlockInfoResult extends FFIResult {
  final List<IncrementalBlockInfo>? blockInfos;

  IncrementalAllBlockInfoResult({required super.success, super.error, this.blockInfos});

  factory IncrementalAllBlockInfoResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    List<IncrementalBlockInfo>? blockInfos;
    if (json['blockInfos'] != null) {
      blockInfos = (json['blockInfos'] as List<dynamic>)
          .map((e) => IncrementalBlockInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return IncrementalAllBlockInfoResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      blockInfos: blockInfos,
    );
  }
}

/// Result for isIncrementalFile operation
class IsIncrementalResult extends FFIResult {
  final bool? isIncremental;

  IsIncrementalResult({required super.success, super.error, this.isIncremental});

  factory IsIncrementalResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return IsIncrementalResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      isIncremental: json['isIncremental'] as bool?,
    );
  }

  /// Returns isIncremental or throws an exception if failed
  bool get isIncrementalOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to check file format');
    }
    return isIncremental ?? false;
  }
}

/// Header information for incremental encrypted files
class IncrementalFileHeader {
  final String version;
  final int chunkSize;
  final int totalChunks;
  final int totalSize;
  final String encryptionAlgorithm;
  final String keyDerivationFunction;

  IncrementalFileHeader({
    required this.version,
    required this.chunkSize,
    required this.totalChunks,
    required this.totalSize,
    required this.encryptionAlgorithm,
    required this.keyDerivationFunction,
  });

  factory IncrementalFileHeader.fromJson(Map<String, dynamic> json) {
    return IncrementalFileHeader(
      version: json['version'] as String? ?? '',
      chunkSize: json['chunkSize'] as int? ?? 0,
      totalChunks: json['totalChunks'] as int? ?? 0,
      totalSize: json['totalSize'] as int? ?? 0,
      encryptionAlgorithm: json['encryptionAlgorithm'] as String? ?? '',
      keyDerivationFunction: json['keyDerivationFunction'] as String? ?? '',
    );
  }
}

/// Result for getIncrementalFileInfo operation
class IncrementalFileInfoResult extends FFIResult {
  final IncrementalFileHeader? header;

  IncrementalFileInfoResult({required super.success, super.error, this.header});

  factory IncrementalFileInfoResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    IncrementalFileHeader? header;
    if (json['header'] != null) {
      header = IncrementalFileHeader.fromJson(
        json['header'] as Map<String, dynamic>,
      );
    }
    return IncrementalFileInfoResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      header: header,
    );
  }
}

// ==================== SEC SERIES RESULTS (NEW) ====================

/// Represents an open session from sec_root_open
class SecSession {
  final int sessionID;
  final String rootPath;

  SecSession({required this.sessionID, required this.rootPath});

  factory SecSession.fromJson(Map<String, dynamic> json) {
    return SecSession(
      sessionID: json['sessionID'] as int? ?? 0,
      rootPath: json['rootPath'] as String? ?? '',
    );
  }
}

/// Result for sec_root_open operation
class SecRootOpenResult extends FFIResult {
  final SecSession? session;

  SecRootOpenResult({required super.success, super.error, this.session});

  factory SecRootOpenResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    SecSession? session;
    if (json['success'] == true) {
      session = SecSession.fromJson(json);
    }
    return SecRootOpenResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      session: session,
    );
  }

  /// Returns the session or throws an exception if failed
  SecSession get sessionOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to open session');
    }
    if (session == null) {
      throw Exception('No session returned');
    }
    return session!;
  }
}

/// Session information from sec_root_get_info
class SecSessionInfo {
  final String rootPath;
  final Map<String, dynamic>? config;

  SecSessionInfo({required this.rootPath, this.config});

  factory SecSessionInfo.fromJson(Map<String, dynamic> json) {
    return SecSessionInfo(
      rootPath: json['rootPath'] as String? ?? '',
      config: json['config'] as Map<String, dynamic>?,
    );
  }
}

/// Result for sec_root_get_info operation
class SecRootInfoResult extends FFIResult {
  final SecSessionInfo? info;

  SecRootInfoResult({required super.success, super.error, this.info});

  factory SecRootInfoResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    SecSessionInfo? info;
    if (json['success'] == true) {
      info = SecSessionInfo.fromJson(json);
    }
    return SecRootInfoResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      info: info,
    );
  }

  /// Returns the session info or throws an exception if failed
  SecSessionInfo get infoOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to get session info');
    }
    if (info == null) {
      throw Exception('No session info returned');
    }
    return info!;
  }
}

/// Result for sec_fopen operation
class SecFopenResult extends FFIResult {
  final int? fileHandle;
  final int? size;

  SecFopenResult({required super.success, super.error, this.fileHandle, this.size});

  factory SecFopenResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SecFopenResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      fileHandle: json['fileHandle'] as int?,
      size: json['size'] as int?,
    );
  }

  /// Returns the file handle or throws an exception if failed
  int get fileHandleOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to open file');
    }
    if (fileHandle == null) {
      throw Exception('No file handle returned');
    }
    return fileHandle!;
  }
}

/// Result for sec_fread operation
class SecFreadResult extends FFIResult {
  final Uint8List? data;
  final int? bytesRead;

  SecFreadResult({required super.success, super.error, this.data, this.bytesRead});

  factory SecFreadResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final success = json['success'] as bool? ?? false;

    Uint8List? data;
    if (success && json['data'] != null) {
      data = base64Decode(json['data'] as String);
    }

    return SecFreadResult(
      success: success,
      error: json['error'] as String?,
      data: data,
      bytesRead: json['bytesRead'] as int?,
    );
  }

  /// Returns the data or throws an exception if failed
  Uint8List get dataOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to read file');
    }
    if (data == null) {
      throw Exception('No data returned');
    }
    return data!;
  }
}

/// Result for sec_fwrite operation
class SecFwriteResult extends FFIResult {
  final int? bytesWritten;

  SecFwriteResult({required super.success, super.error, this.bytesWritten});

  factory SecFwriteResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SecFwriteResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      bytesWritten: json['bytesWritten'] as int?,
    );
  }
}

/// Result for sec_fstat operation
class SecFstatResult extends FFIResult {
  final int? size;

  SecFstatResult({required super.success, super.error, this.size});

  factory SecFstatResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SecFstatResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      size: json['size'] as int?,
    );
  }
}

/// Result for sec_fstat_info operation
class SecFstatInfoResult extends FFIResult {
  final bool? exists;
  final int? size;
  final bool? isChunked;
  final int? modTime;

  SecFstatInfoResult({
    required super.success,
    super.error,
    this.exists,
    this.size,
    this.isChunked,
    this.modTime,
  });

  factory SecFstatInfoResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SecFstatInfoResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      exists: json['exists'] as bool?,
      size: json['size'] as int?,
      isChunked: json['isChunked'] as bool?,
      modTime: json['modTime'] as int?,
    );
  }
}

/// Result for sec_readfile operation
class SecReadfileResult extends FFIResult {
  final Uint8List? data;

  SecReadfileResult({required super.success, super.error, this.data});

  factory SecReadfileResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final success = json['success'] as bool? ?? false;

    Uint8List? data;
    if (success && json['data'] != null) {
      data = base64Decode(json['data'] as String);
    }

    return SecReadfileResult(
      success: success,
      error: json['error'] as String?,
      data: data,
    );
  }

  /// Returns the data or throws an exception if failed
  Uint8List get dataOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to read file');
    }
    if (data == null) {
      throw Exception('No data returned');
    }
    return data!;
  }
}

/// Result for sec_dir_walk operation
class SecDirWalkResult extends FFIResult {
  final int? walkerID;
  final int? numFiles;

  SecDirWalkResult({required super.success, super.error, this.walkerID, this.numFiles});

  factory SecDirWalkResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SecDirWalkResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      walkerID: json['walkerID'] as int?,
      numFiles: json['numFiles'] as int?,
    );
  }

  /// Returns the walker ID or throws an exception if failed
  int get walkerIDOrThrow {
    if (!success) {
      throw Exception(error ?? 'Failed to start directory walk');
    }
    if (walkerID == null) {
      throw Exception('No walker ID returned');
    }
    return walkerID!;
  }
}

/// Directory entry from sec_dir_walk_next
class SecDirEntry {
  final String name;
  final bool isDir;
  final int size;
  final int modTime;

  SecDirEntry({
    required this.name,
    required this.isDir,
    required this.size,
    required this.modTime,
  });

  factory SecDirEntry.fromJson(Map<String, dynamic> json) {
    return SecDirEntry(
      name: json['name'] as String? ?? '',
      isDir: json['isDir'] as bool? ?? false,
      size: json['size'] as int? ?? 0,
      modTime: json['modTime'] as int? ?? 0,
    );
  }
}

/// Result for sec_dir_walk_next operation
class SecDirWalkNextResult extends FFIResult {
  final bool done;
  final SecDirEntry? entry;

  SecDirWalkNextResult({
    required super.success,
    super.error,
    required this.done,
    this.entry,
  });

  factory SecDirWalkNextResult.fromJson(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final done = json['done'] as bool? ?? false;

    SecDirEntry? entry;
    if (!done && json['name'] != null) {
      entry = SecDirEntry.fromJson(json);
    }

    return SecDirWalkNextResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      done: done,
      entry: entry,
    );
  }
}
