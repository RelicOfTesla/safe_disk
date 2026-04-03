import 'dart:async';
import '../native/native_lib.dart';
import '../models/ffi_results.dart';

/// Callback for progress updates
typedef ProgressCallback = void Function(JobProgress progress);

/// Service for async directory encryption and decryption operations
class DirectoryService {
  final NativeLib _native = NativeLib.instance;

  /// Default polling interval for progress updates (in milliseconds)
  static const int defaultPollIntervalMs = 200;

  /// Starts an async directory encryption job and returns the job ID
  /// 
  /// Parameters:
  /// - srcDir: source directory path (plaintext files)
  /// - dstDir: destination directory path (encrypted files)
  /// - tempKeyID: temporary key ID (from CryptoService.createSession)
  /// 
  /// Returns: job ID that can be used to track progress
  String startEncryptDirectory(String srcDir, String dstDir, String tempKeyID) {
    final resultStr = _native.encryptDirectoryAsync(srcDir, dstDir, tempKeyID);
    final result = JobResult.fromJson(resultStr);
    return result.jobIDOrThrow;
  }

  /// Starts an async directory decryption job and returns the job ID
  /// 
  /// Parameters:
  /// - srcDir: source directory path (encrypted files)
  /// - dstDir: destination directory path (decrypted files)
  /// - tempKeyID: temporary key ID (from CryptoService.createSession)
  /// 
  /// Returns: job ID that can be used to track progress
  String startDecryptDirectory(String srcDir, String dstDir, String tempKeyID) {
    final resultStr = _native.decryptDirectoryAsync(srcDir, dstDir, tempKeyID);
    final result = JobResult.fromJson(resultStr);
    return result.jobIDOrThrow;
  }

  /// Gets the current progress of a job
  /// 
  /// Parameters:
  /// - jobID: job ID from startEncryptDirectory or startDecryptDirectory
  /// 
  /// Returns: JobProgress with current status
  JobProgress getProgress(String jobID) {
    final resultStr = _native.getJobProgress(jobID);
    final result = JobProgressResult.fromJson(resultStr);
    if (!result.success || result.progress == null) {
      return JobProgress(status: 'failed', error: result.error ?? 'Unknown error');
    }
    return result.progress!;
  }

  /// Gets the current status of a job
  /// 
  /// Parameters:
  /// - jobID: job ID
  /// 
  /// Returns: JobStatus enum value
  JobStatus getStatus(String jobID) {
    final resultStr = _native.getJobStatus(jobID);
    final result = JobStatusResult.fromJson(resultStr);
    return result.status ?? JobStatus.unknown;
  }

  /// Cancels a running job
  /// 
  /// Parameters:
  /// - jobID: job ID
  /// 
  /// Returns: true if cancellation was successful
  bool cancel(String jobID) {
    final resultStr = _native.cancelJob(jobID);
    final result = FFIResult.fromJson(resultStr);
    return result.success;
  }

  /// Deletes a job from the job manager
  /// 
  /// Parameters:
  /// - jobID: job ID
  void deleteJob(String jobID) {
    _native.deleteJob(jobID);
  }

  /// Encrypts a directory asynchronously with progress tracking
  /// 
  /// This method starts the encryption job, polls for progress,
  /// and calls the onProgress callback with updates.
  /// 
  /// Parameters:
  /// - srcDir: source directory path (plaintext files)
  /// - dstDir: destination directory path (encrypted files)
  /// - tempKeyID: temporary key ID
  /// - onProgress: optional callback for progress updates
  /// - pollIntervalMs: polling interval in milliseconds (default 200ms)
  /// 
  /// Returns: JobProgress with final status
  /// Throws: Exception if encryption fails
  Future<JobProgress> encryptDirectory(
    String srcDir,
    String dstDir,
    String tempKeyID, {
    ProgressCallback? onProgress,
    int pollIntervalMs = defaultPollIntervalMs,
  }) async {
    final jobID = startEncryptDirectory(srcDir, dstDir, tempKeyID);
    return _waitForJob(jobID, onProgress, pollIntervalMs);
  }

  /// Decrypts a directory asynchronously with progress tracking
  /// 
  /// This method starts the decryption job, polls for progress,
  /// and calls the onProgress callback with updates.
  /// 
  /// Parameters:
  /// - srcDir: source directory path (encrypted files)
  /// - dstDir: destination directory path (decrypted files)
  /// - tempKeyID: temporary key ID
  /// - onProgress: optional callback for progress updates
  /// - pollIntervalMs: polling interval in milliseconds (default 200ms)
  /// 
  /// Returns: JobProgress with final status
  /// Throws: Exception if decryption fails
  Future<JobProgress> decryptDirectory(
    String srcDir,
    String dstDir,
    String tempKeyID, {
    ProgressCallback? onProgress,
    int pollIntervalMs = defaultPollIntervalMs,
  }) async {
    final jobID = startDecryptDirectory(srcDir, dstDir, tempKeyID);
    return _waitForJob(jobID, onProgress, pollIntervalMs);
  }

  /// Waits for a job to complete, polling for progress
  Future<JobProgress> _waitForJob(
    String jobID,
    ProgressCallback? onProgress,
    int pollIntervalMs,
  ) async {
    while (true) {
      final progress = getProgress(jobID);
      
      // Call progress callback
      onProgress?.call(progress);
      
      // Check if job is complete
      if (progress.isComplete) {
        // Clean up job
        deleteJob(jobID);
        
        // Throw if failed
        if (progress.isFailed) {
          throw Exception(progress.error ?? 'Operation failed');
        }
        
        return progress;
      }
      
      // Wait before next poll
      await Future.delayed(Duration(milliseconds: pollIntervalMs));
    }
  }

  /// Creates a cancellable directory encryption operation
  /// 
  /// Returns a CancellableOperation that can be used to track progress
  /// and cancel the operation.
  CancellableDirectoryOperation encryptDirectoryCancellable(
    String srcDir,
    String dstDir,
    String tempKeyID,
  ) {
    final jobID = startEncryptDirectory(srcDir, dstDir, tempKeyID);
    return CancellableDirectoryOperation(this, jobID);
  }

  /// Creates a cancellable directory decryption operation
  /// 
  /// Returns a CancellableOperation that can be used to track progress
  /// and cancel the operation.
  CancellableDirectoryOperation decryptDirectoryCancellable(
    String srcDir,
    String dstDir,
    String tempKeyID,
  ) {
    final jobID = startDecryptDirectory(srcDir, dstDir, tempKeyID);
    return CancellableDirectoryOperation(this, jobID);
  }
}

/// A cancellable directory operation
/// 
/// Use this to track progress and cancel long-running operations.
class CancellableDirectoryOperation {
  final DirectoryService _service;
  final String _jobID;
  bool _cancelled = false;
  bool _completed = false;

  CancellableDirectoryOperation(this._service, this._jobID);

  /// The job ID
  String get jobID => _jobID;

  /// Whether the operation has been cancelled
  bool get isCancelled => _cancelled;

  /// Whether the operation has completed (successfully or not)
  bool get isCompleted => _completed;

  /// Gets the current progress
  JobProgress get progress => _service.getProgress(_jobID);

  /// Cancels the operation
  /// 
  /// Returns true if cancellation was successful
  bool cancel() {
    if (_completed || _cancelled) {
      return false;
    }
    _cancelled = _service.cancel(_jobID);
    return _cancelled;
  }

  /// Waits for the operation to complete
  /// 
  /// Parameters:
  /// - onProgress: optional callback for progress updates
  /// - pollIntervalMs: polling interval in milliseconds
  /// 
  /// Returns: JobProgress with final status
  /// Throws: Exception if operation fails
  Future<JobProgress> waitForCompletion({
    ProgressCallback? onProgress,
    int pollIntervalMs = DirectoryService.defaultPollIntervalMs,
  }) async {
    while (!_completed && !_cancelled) {
      final progress = _service.getProgress(_jobID);
      
      // Call progress callback
      onProgress?.call(progress);
      
      // Check if job is complete
      if (progress.isComplete) {
        _completed = true;
        _service.deleteJob(_jobID);
        
        // Throw if failed
        if (progress.isFailed && !_cancelled) {
          throw Exception(progress.error ?? 'Operation failed');
        }
        
        return progress;
      }
      
      // Wait before next poll
      await Future.delayed(Duration(milliseconds: pollIntervalMs));
    }
    
    // Return current progress if cancelled
    return _service.getProgress(_jobID);
  }
}
