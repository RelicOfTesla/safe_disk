// 错误提示常量和工具函数
//
// 统一管理所有错误提示，确保：
// 1. 文案清晰易懂
// 2. 包含建议操作
// 3. 显示方式友好

/// 错误提示类型
enum ErrorType {
  /// 目录未验证
  directoryNotVerified,

  /// 会话已过期
  sessionExpired,

  /// 密码错误
  invalidPassword,

  /// 目录不存在
  directoryNotExist,

  /// 不是加密目录
  notEncryptedDirectory,

  /// 加载配置失败
  loadConfigFailed,

  /// 加载目录失败
  loadDirectoryFailed,

  /// 创建加密目录失败
  createEncryptedDirectoryFailed,

  /// 导入文件失败
  importFileFailed,

  /// 导入目录失败
  importDirectoryFailed,

  /// 导出文件失败
  exportFileFailed,

  /// 导出目录失败
  exportDirectoryFailed,

  /// 删除文件失败
  deleteFileFailed,

  /// 保存文件失败
  saveFileFailed,

  /// 加载文件失败
  loadFileFailed,

  /// 未选择目录
  noDirectorySelected,

  /// 未选择文件
  noFileSelected,

  /// 密码为空
  passwordEmpty,

  /// 密码不匹配
  passwordMismatch,

  /// 路径为空
  pathEmpty,

  /// 操作失败（通用）
  operationFailed,
}

/// 错误提示信息
class ErrorMessage {
  /// 错误标题（简短）
  final String title;

  /// 错误描述（详细）
  final String description;

  /// 建议操作（如何解决）
  final String? suggestion;

  /// 是否为严重错误
  final bool isCritical;

  const ErrorMessage({
    required this.title,
    required this.description,
    this.suggestion,
    this.isCritical = false,
  });
}

/// 错误提示常量
class ErrorMessages {
  // 私有构造函数，防止实例化
  ErrorMessages._();

  /// 错误提示映射表
  static const Map<ErrorType, ErrorMessage> _messages = {
    // 目录验证相关
    ErrorType.directoryNotVerified: ErrorMessage(
      title: '需要验证目录',
      description: '请先验证此加密目录的身份，然后才能操作文件。',
      suggestion: '点击侧边栏的"验证"按钮，输入密码验证目录。',
    ),
    ErrorType.sessionExpired: ErrorMessage(
      title: '会话已过期',
      description: '您的登录会话已过期，出于安全考虑，需要重新验证。',
      suggestion: '点击侧边栏的"验证"按钮，重新输入密码。',
    ),
    ErrorType.invalidPassword: ErrorMessage(
      title: '密码错误',
      description: '您输入的密码不正确，无法解密此目录。',
      suggestion: '请检查密码是否正确，注意区分大小写。',
      isCritical: true,
    ),

    // 目录操作相关
    ErrorType.directoryNotExist: ErrorMessage(
      title: '目录不存在',
      description: '指定的目录路径不存在或已被删除。',
      suggestion: '请检查目录路径是否正确，或选择其他目录。',
    ),
    ErrorType.notEncryptedDirectory: ErrorMessage(
      title: '非加密目录',
      description: '此目录不是 Safe Disk 加密目录，无法打开。',
      suggestion: '请选择包含 "_cryption.json" 文件的加密目录。',
    ),
    ErrorType.loadConfigFailed: ErrorMessage(
      title: '加载配置失败',
      description: '无法读取加密目录的配置文件。',
      suggestion: '请检查 "_cryption.json" 文件是否存在且格式正确。',
      isCritical: true,
    ),
    ErrorType.loadDirectoryFailed: ErrorMessage(
      title: '加载目录失败',
      description: '无法读取目录内容。',
      suggestion: '请检查目录权限，或尝试重新打开目录。',
    ),
    ErrorType.createEncryptedDirectoryFailed: ErrorMessage(
      title: '创建加密目录失败',
      description: '无法创建新的加密目录。',
      suggestion: '请检查目录权限和磁盘空间，然后重试。',
    ),

    // 文件操作相关
    ErrorType.importFileFailed: ErrorMessage(
      title: '导入文件失败',
      description: '无法将文件导入到加密目录。',
      suggestion: '请检查文件是否存在且可读，然后重试。',
    ),
    ErrorType.importDirectoryFailed: ErrorMessage(
      title: '导入目录失败',
      description: '无法将目录导入到加密目录。',
      suggestion: '请检查源目录权限、符号链接和目标目录状态，然后重试。',
    ),
    ErrorType.exportFileFailed: ErrorMessage(
      title: '导出文件失败',
      description: '无法将文件导出到指定位置。',
      suggestion: '请检查目标位置是否可写，然后重试。',
    ),
    ErrorType.exportDirectoryFailed: ErrorMessage(
      title: '导出目录失败',
      description: '无法将目录导出到指定位置。',
      suggestion: '请检查目标位置是否可写，然后重试。',
    ),
    ErrorType.deleteFileFailed: ErrorMessage(
      title: '删除文件失败',
      description: '无法删除此文件。',
      suggestion: '请检查文件是否被占用，然后重试。',
    ),
    ErrorType.saveFileFailed: ErrorMessage(
      title: '保存文件失败',
      description: '无法保存文件更改。',
      suggestion: '请检查磁盘空间和权限，然后重试。',
    ),
    ErrorType.loadFileFailed: ErrorMessage(
      title: '加载文件失败',
      description: '无法读取文件内容。',
      suggestion: '请检查文件是否存在且可读。',
    ),

    // 用户输入相关
    ErrorType.noDirectorySelected: ErrorMessage(
      title: '未选择目录',
      description: '请先选择一个目录。',
    ),
    ErrorType.noFileSelected: ErrorMessage(
      title: '未选择文件',
      description: '请先选择一个文件。',
    ),
    ErrorType.passwordEmpty: ErrorMessage(
      title: '密码不能为空',
      description: '请输入密码以继续操作。',
    ),
    ErrorType.passwordMismatch: ErrorMessage(
      title: '密码不匹配',
      description: '两次输入的密码不一致。',
      suggestion: '请确保两次输入相同的密码。',
    ),
    ErrorType.pathEmpty: ErrorMessage(
      title: '路径不能为空',
      description: '请输入目录路径。',
    ),

    // 通用错误
    ErrorType.operationFailed: ErrorMessage(
      title: '操作失败',
      description: '操作未完成，请稍后重试。',
      suggestion: '如果问题持续存在，请联系技术支持。',
    ),
  };

  /// 获取错误提示
  static ErrorMessage getError(ErrorType type) {
    return _messages[type] ?? _messages[ErrorType.operationFailed]!;
  }

  /// 获取错误标题
  static String getTitle(ErrorType type) {
    return getError(type).title;
  }

  /// 获取完整错误信息（用于 SnackBar）
  static String getFullMessage(ErrorType type) {
    final error = getError(type);
    if (error.suggestion != null) {
      return '${error.description}\n\n建议：${error.suggestion}';
    }
    return error.description;
  }

  /// 获取带有原始错误的完整错误信息
  static String getFullMessageWithError(ErrorType type, String? originalError) {
    final error = getError(type);
    var message = error.description;

    if (originalError != null && originalError.isNotEmpty) {
      // 只在调试模式下显示原始错误
      // message += '\n\n详细信息：$originalError';
      // 生产环境下不显示技术细节
    }

    if (error.suggestion != null) {
      message += '\n\n建议：${error.suggestion}';
    }

    return message;
  }

  /// 判断是否为严重错误
  static bool isCritical(ErrorType type) {
    return getError(type).isCritical;
  }
}
