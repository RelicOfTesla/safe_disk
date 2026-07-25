// 错误语义和呈现元数据。
//
// 此文件故意不保存任何用户可见文案。错误文字必须在持有 BuildContext 的
// 呈现层通过 ARB 解析，避免 service/controller 与界面语言耦合。

/// 错误提示类型。
///
/// 该枚举是领域层与 UI 层之间的稳定语义标识，不随界面语言变化。
enum ErrorType {
  directoryNotVerified,
  sessionExpired,
  invalidPassword,
  directoryNotExist,
  notEncryptedDirectory,
  loadConfigFailed,
  loadDirectoryFailed,
  loadSettingsFailed,
  saveSettingsFailed,
  unfinishedTransferStateUnavailable,
  createEncryptedDirectoryFailed,
  createEncryptedDirectoryRequiresEmpty,
  importFileFailed,
  importDirectoryFailed,
  importDirectoryInsideCurrentRoot,
  exportFileFailed,
  exportDirectoryFailed,
  deleteFileFailed,
  saveFileFailed,
  loadFileFailed,
  noDirectorySelected,
  noFileSelected,
  passwordEmpty,
  passwordMismatch,
  pathEmpty,
  dataCorrupted,
  operationFailed,
}

/// 与语言无关的错误呈现元数据。
class ErrorDescriptor {
  final ErrorType type;
  final bool isCritical;

  const ErrorDescriptor({required this.type, this.isCritical = false});
}

/// 已解析的错误文字，仅供持有当前 locale 的 UI 使用。
class ErrorMessage {
  final String title;
  final String description;
  final String? suggestion;
  final bool isCritical;

  const ErrorMessage({
    required this.title,
    required this.description,
    this.suggestion,
    this.isCritical = false,
  });
}

/// 错误描述符入口。
class ErrorMessages {
  ErrorMessages._();

  static const _criticalTypes = <ErrorType>{
    ErrorType.invalidPassword,
    ErrorType.loadConfigFailed,
    ErrorType.unfinishedTransferStateUnavailable,
  };

  static ErrorDescriptor descriptor(ErrorType type) {
    return ErrorDescriptor(
      type: type,
      isCritical: _criticalTypes.contains(type),
    );
  }

  static bool isCritical(ErrorType type) => descriptor(type).isCritical;
}
