// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Safe Disk';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get saveSettings => '保存设置';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get settingsLoadFailed => '无法加载设置';

  @override
  String get settingsSaveFailed => '无法保存设置';

  @override
  String get settingsNotSaved => '设置尚未保存。';

  @override
  String get settingsLoadDescription => '无法读取本机设置。';

  @override
  String get settingsLoadSuggestion => '请重试；如果问题持续，请恢复默认设置或联系支持。';

  @override
  String get settingsSaveSuggestion => '请检查本机存储空间和权限，然后重试。';

  @override
  String get appearance => '外观';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '亮色主题';

  @override
  String get themeDark => '暗色主题';

  @override
  String get themePreviewHint => '主题会立即预览；保存后会在下次启动时保留。';

  @override
  String get languagePreviewHint => '语言会立即预览；保存后会在下次启动时保留。';

  @override
  String get englishPreviewNotice => '英文界面仍在完善，部分页面暂时会显示中文。';

  @override
  String get saveChanges => '保存设置更改？';

  @override
  String get unsavedSettings => '当前修改尚未保存。';

  @override
  String get cancel => '取消';

  @override
  String get discardChanges => '放弃修改';

  @override
  String get saveAndReturn => '保存并返回';

  @override
  String get back => '返回';

  @override
  String get restoreDefaults => '恢复默认设置（未保存）';

  @override
  String get loadingImage => '正在加载图片';

  @override
  String get imageLoadFailed => '图片加载失败';

  @override
  String get noDisplayableImage => '没有可显示的图片。请选择其他图片或重试。';

  @override
  String viewingImage(String fileName) {
    return '正在查看：$fileName';
  }

  @override
  String get errorSuggestionPrefix => '建议：';

  @override
  String get copy => '复制';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get viewDetails => '查看详情';

  @override
  String get technicalDetails => '技术详情';

  @override
  String get errorDetailsCopied => '已复制错误信息';

  @override
  String get errorDirectoryNotVerifiedTitle => '需要解锁目录';

  @override
  String get errorDirectoryNotVerifiedDescription => '请输入密码解锁此加密目录后再操作文件。';

  @override
  String get errorDirectoryNotVerifiedSuggestion => '在侧边栏选择该目录，然后输入密码。';

  @override
  String get errorSessionExpiredTitle => '目录已锁定';

  @override
  String get errorSessionExpiredDescription => '目录会话已结束，需要重新解锁。';

  @override
  String get errorSessionExpiredSuggestion => '在侧边栏选择该目录，然后重新输入密码。';

  @override
  String get errorInvalidPasswordTitle => '密码错误';

  @override
  String get errorInvalidPasswordDescription => '您输入的密码不正确，无法解密此目录。';

  @override
  String get errorInvalidPasswordSuggestion => '请检查密码是否正确，注意区分大小写。';

  @override
  String get errorDirectoryNotExistTitle => '目录不存在';

  @override
  String get errorDirectoryNotExistDescription => '指定的目录路径不存在或已被删除。';

  @override
  String get errorDirectoryNotExistSuggestion => '请检查目录路径是否正确，或选择其他目录。';

  @override
  String get errorNotEncryptedDirectoryTitle => '无法打开目录';

  @override
  String get errorNotEncryptedDirectoryDescription =>
      '所选目录不是可识别的 Safe Disk 加密目录。';

  @override
  String get errorNotEncryptedDirectorySuggestion => '请选择已有加密目录，或创建新的加密目录。';

  @override
  String get errorLoadConfigFailedTitle => '加载配置失败';

  @override
  String get errorLoadConfigFailedDescription => '无法读取加密目录的配置文件。';

  @override
  String get errorLoadConfigFailedSuggestion => '请检查目录是否完整且未被其他程序修改。';

  @override
  String get errorLoadDirectoryFailedTitle => '加载目录失败';

  @override
  String get errorLoadDirectoryFailedDescription => '无法读取目录内容。';

  @override
  String get errorLoadDirectoryFailedSuggestion => '请检查目录权限，或尝试重新打开目录。';

  @override
  String get errorUnfinishedTransferStateUnavailableTitle => '无法确认未完成传输状态';

  @override
  String get errorUnfinishedTransferStateUnavailableDescription =>
      '无法安全读取未完成的导入/导出状态，因此没有打开此加密目录。';

  @override
  String get errorUnfinishedTransferStateUnavailableSuggestion =>
      '请检查目录权限和磁盘状态；不要手动删除传输状态文件。';

  @override
  String get errorCreateEncryptedDirectoryFailedTitle => '创建加密目录失败';

  @override
  String get errorCreateEncryptedDirectoryFailedDescription => '无法创建新的加密目录。';

  @override
  String get errorCreateEncryptedDirectoryFailedSuggestion =>
      '请检查目录权限和磁盘空间，然后重试。';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptyTitle => '目录不是空目录';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptyDescription =>
      '新加密目录只能创建在不存在或内容为空的目录中。';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptySuggestion =>
      '请选择新的路径或空目录；已有内容请通过导入功能加入。';

  @override
  String get errorImportFileFailedTitle => '导入文件失败';

  @override
  String get errorImportFileFailedDescription => '无法将文件导入到加密目录。';

  @override
  String get errorImportFileFailedSuggestion => '请检查文件是否存在且可读，然后重试。';

  @override
  String get errorImportDirectoryFailedTitle => '导入目录失败';

  @override
  String get errorImportDirectoryFailedDescription => '无法将目录导入到加密目录。';

  @override
  String get errorImportDirectoryFailedSuggestion =>
      '请检查源目录权限、符号链接和目标目录状态，然后重试。';

  @override
  String get errorImportDirectoryInsideCurrentRootTitle => '不能导入此目录';

  @override
  String get errorImportDirectoryInsideCurrentRootDescription =>
      '不能将当前加密目录中的目录再次导入到自身。';

  @override
  String get errorImportDirectoryInsideCurrentRootSuggestion =>
      '请选择加密目录外的来源目录。';

  @override
  String get errorExportFileFailedTitle => '导出文件失败';

  @override
  String get errorExportFileFailedDescription => '无法将文件导出到指定位置。';

  @override
  String get errorExportFileFailedSuggestion => '请检查目标位置是否可写，然后重试。';

  @override
  String get errorExportDirectoryFailedTitle => '导出目录失败';

  @override
  String get errorExportDirectoryFailedDescription => '无法将目录导出到指定位置。';

  @override
  String get errorExportDirectoryFailedSuggestion => '请检查目标位置是否可写，然后重试。';

  @override
  String get errorDeleteFileFailedTitle => '删除文件失败';

  @override
  String get errorDeleteFileFailedDescription => '无法删除此文件。';

  @override
  String get errorDeleteFileFailedSuggestion => '请检查文件是否被占用，然后重试。';

  @override
  String get errorSaveFileFailedTitle => '保存文件失败';

  @override
  String get errorSaveFileFailedDescription => '无法保存文件更改。';

  @override
  String get errorSaveFileFailedSuggestion => '请检查磁盘空间和权限，然后重试。';

  @override
  String get errorLoadFileFailedTitle => '加载文件失败';

  @override
  String get errorLoadFileFailedDescription => '无法读取文件内容。';

  @override
  String get errorLoadFileFailedSuggestion => '请检查文件是否存在且可读。';

  @override
  String get errorNoDirectorySelectedTitle => '未选择目录';

  @override
  String get errorNoDirectorySelectedDescription => '请先选择一个目录。';

  @override
  String get errorNoFileSelectedTitle => '未选择文件';

  @override
  String get errorNoFileSelectedDescription => '请先选择一个文件。';

  @override
  String get errorPasswordEmptyTitle => '密码不能为空';

  @override
  String get errorPasswordEmptyDescription => '请输入密码以继续操作。';

  @override
  String get errorPasswordMismatchTitle => '密码不匹配';

  @override
  String get errorPasswordMismatchDescription => '两次输入的密码不一致。';

  @override
  String get errorPasswordMismatchSuggestion => '请确保两次输入相同的密码。';

  @override
  String get errorPathEmptyTitle => '路径不能为空';

  @override
  String get errorPathEmptyDescription => '请输入目录路径。';

  @override
  String get errorOperationFailedTitle => '操作失败';

  @override
  String get errorOperationFailedDescription => '操作未完成，请稍后重试。';

  @override
  String get errorOperationFailedSuggestion => '如果问题持续存在，请联系技术支持。';

  @override
  String get behavior => '行为';

  @override
  String get confirmBeforeDelete => '删除前确认';

  @override
  String get confirmBeforeDeleteHint => '删除文件前显示确认对话框';

  @override
  String get lockAfterIdle => '空闲后自动锁定';

  @override
  String get lockAfterIdleHint => '当前目录空闲到期后锁定；有未保存内容或活动写入时不会强制关闭';

  @override
  String get lockWhenHidden => '应用隐藏时自动锁定';

  @override
  String get lockWhenHiddenHint => '仅锁定没有内容窗口、未保存修改或活动写入的目录；其他目录不会被强制关闭';

  @override
  String get notepadDraftInterval => '安全草稿保存间隔';

  @override
  String get notepadDraftIntervalHint => '定时写入同目录加密草稿，不覆盖原文件';

  @override
  String get notepadDefaultReadOnly => '记事本默认只读';

  @override
  String get notepadDefaultReadOnlyHint => '新打开的文件先以只读方式显示，可手动开始编辑';

  @override
  String get notepadMonitorClipboard => '默认监视剪贴板';

  @override
  String get notepadMonitorClipboardHint => '仅显示短文本预览，不写入文件或设置';

  @override
  String get detailedErrors => '显示详细错误信息';

  @override
  String get detailedErrorsHint => '在错误提示中显示经脱敏的操作阶段与底层错误；不会写入磁盘日志';

  @override
  String get about => '关于';

  @override
  String get appVersionDescription => '版本 1.0.0\\n加密文件管理器';

  @override
  String get durationNever => '永不过期';

  @override
  String durationSeconds(int count) {
    return '$count 秒';
  }

  @override
  String durationMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String durationHours(int count) {
    return '$count 小时';
  }

  @override
  String durationDays(int count) {
    return '$count 天';
  }

  @override
  String progressMinutesSeconds(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒';
  }

  @override
  String progressEstimatedRemaining(String duration) {
    return '预计剩余：$duration';
  }

  @override
  String progressProcessed(int current, int total) {
    return '已处理：$current / $total';
  }

  @override
  String progressCurrentFile(String name) {
    return '当前：$name';
  }

  @override
  String get rerunUnfinishedTransfers => '全量重跑导入/导出';

  @override
  String get preparing => '正在准备…';

  @override
  String get operationNotCancellableYet => '当前操作尚未可取消。';

  @override
  String rerunningUnfinishedProgress(int current, int total) {
    return '正在重跑 $current/$total…';
  }

  @override
  String get unfinishedTransfersRerunCompleted => '未完成导入/导出已全量重跑。';

  @override
  String get unfinishedTransfersRerunCancelled => '重跑已取消，未完成状态已保留。';

  @override
  String get preparingImport => '正在准备导入…';

  @override
  String get preparingExport => '正在准备导出…';

  @override
  String get preparingDelete => '正在准备删除…';

  @override
  String get preparingCannotCancel => '正在准备，暂时无法取消…';

  @override
  String get importing => '正在导入…';

  @override
  String get exporting => '正在导出…';

  @override
  String get deleting => '正在删除…';

  @override
  String directoryImportCompleted(int count) {
    return '目录导入完成：$count 个文件';
  }

  @override
  String get transferCancelledWithUnfinishedState => '操作已取消，可在下次打开目录时清理未完成状态。';

  @override
  String directoryExportCompleted(int count) {
    return '导出完成：$count 个文件';
  }

  @override
  String get batchExport => '批量导出';

  @override
  String batchExportCompleted(int success, int failed) {
    return '导出完成：成功 $success 个，失败 $failed 个';
  }

  @override
  String batchExportCompletedAll(int count) {
    return '导出完成：成功 $count 个文件';
  }

  @override
  String batchExportCancelled(int success, int failed) {
    return '导出已取消：成功 $success 个，失败 $failed 个';
  }

  @override
  String get batchDelete => '批量删除';

  @override
  String batchDeleteCancelled(int success, int remaining) {
    return '批量删除已取消：成功 $success 个，剩余 $remaining 个仍保持选择';
  }

  @override
  String batchDeleteCompleted(int count) {
    return '已删除 $count 个文件';
  }

  @override
  String get disabled => '关闭';

  @override
  String get nativeComponentUnavailable => '安全组件不可用';

  @override
  String get nativeBindingFailureDescription => '安全组件版本与应用不匹配，无法启动加密功能。';

  @override
  String get nativeLoadingFailureDescription =>
      '无法加载 Safe Disk 安全组件，无法安全访问加密目录。';

  @override
  String get nativeBindingFailureSuggestion => '请重新安装同一版本的 Safe Disk 应用后重试。';

  @override
  String get nativeLoadingFailureSuggestion =>
      '请重新安装应用；若问题持续，请检查安全软件是否隔离了应用文件。';

  @override
  String initializationStage(String stage) {
    return '初始化阶段：$stage';
  }

  @override
  String underlyingError(String error) {
    return '底层错误：$error';
  }

  @override
  String get contentWindowUnavailable => '无法连接主窗口';

  @override
  String get contentWindowUnavailableDescription =>
      '文档会话可能已结束。为避免在失效会话中编辑，请关闭此窗口后从主界面重新打开。';

  @override
  String get closeWindow => '关闭窗口';

  @override
  String get welcomeProductTagline => '加密文件管理器';

  @override
  String get welcomeOpenDirectoryHint => '请从侧边栏打开或创建加密目录';

  @override
  String selectedItems(int count) {
    return '已选择 $count 项';
  }

  @override
  String get exitSelectionMode => '退出选择模式';

  @override
  String get copySelected => '复制所选项';

  @override
  String get cutSelected => '剪切所选项';

  @override
  String get moreBatchActions => '更多批量操作';

  @override
  String get selectAll => '全选';

  @override
  String get exportSelected => '导出所选项';

  @override
  String get deleteSelected => '删除所选项';

  @override
  String get closeDirectory => '关闭目录';

  @override
  String get currentDirectory => '当前目录';

  @override
  String get clipboardMovePending => '待移动';

  @override
  String get fileClipboard => '文件剪贴板';

  @override
  String get clipboardPastePending => '待粘贴';

  @override
  String clipboardMultipleEntries(String name, int count) {
    return '$name 等 $count 项';
  }

  @override
  String clipboardStatusWide(String operation, String entries, String target) {
    return '$operation · $entries → $target';
  }

  @override
  String clipboardStatusNarrow(String operation, String entries) {
    return '$operation · $entries';
  }

  @override
  String get moveToCurrentDirectory => '移动到当前目录';

  @override
  String get pasteToCurrentDirectory => '粘贴到当前目录';

  @override
  String get clearFileClipboard => '清空文件剪贴板';

  @override
  String openedDirectoriesCount(int count) {
    return '已打开 $count 个目录';
  }

  @override
  String get unpinSidebar => '取消固定侧边栏';

  @override
  String get pinSidebar => '固定侧边栏';

  @override
  String get openOrCreateEncryptedDirectory => '打开或创建加密目录';

  @override
  String get noOpenedDirectories => '还没有打开目录\\n\\n选择“打开或创建加密目录”开始使用';

  @override
  String get properties => '属性';

  @override
  String get changePassword => '修改密码';

  @override
  String get setAlias => '设置别名';

  @override
  String get clearAlias => '清除别名';

  @override
  String get closeOrRemoveDirectory => '关闭或移除目录';

  @override
  String get directoryUnlocked => '已解锁';

  @override
  String get directoryNeedsPassword => '需要密码';

  @override
  String get moreDirectoryActions => '更多目录操作';

  @override
  String get importFile => '导入文件';

  @override
  String get importDirectory => '导入目录';

  @override
  String get unlockDirectoryPrompt => '请输入密码以解锁：';

  @override
  String get password => '密码';

  @override
  String get unlock => '解锁';

  @override
  String directoryLabel(String name) {
    return '目录：$name';
  }

  @override
  String get passwordChangeDescription => '修改后需要用新密码重新打开目录。已有内容无需重新加密。';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get passwordChangeFieldsRequired => '请输入当前密码和新密码';

  @override
  String get newPasswordsDoNotMatch => '两次输入的新密码不一致';

  @override
  String get rootDirectoryActions => '目录操作';

  @override
  String get endSessionOnly => '仅结束会话';

  @override
  String endSessionDescription(String name) {
    return '锁定“$name”，保留侧边栏历史和磁盘目录';
  }

  @override
  String get directoryAlreadyLocked => '当前目录已经锁定';

  @override
  String get endSessionAndRemoveHistory => '结束会话并移除历史';

  @override
  String get removeHistoryDescription => '只从侧边栏移除，本地磁盘目录保持不变';

  @override
  String get endSessionRemoveHistoryAndDelete => '结束会话、移除历史并删除目录';

  @override
  String get deleteDirectoryDescription => '永久删除本地加密目录及全部内容，无法撤销';

  @override
  String get permanentlyDeleteLocalDirectory => '永久删除本地目录';

  @override
  String get willPermanentlyDelete => '将永久删除：';

  @override
  String enterDirectoryNameToConfirm(String name) {
    return '请输入目录名“$name”确认：';
  }

  @override
  String get permanentlyDeleteDirectory => '永久删除目录';

  @override
  String get unknown => '未知';

  @override
  String get rootDirectoryProperties => '加密目录属性';

  @override
  String get displayName => '显示名称';

  @override
  String get diskPath => '磁盘路径';

  @override
  String get currentStatus => '当前状态';

  @override
  String get directoryLocked => '已锁定';

  @override
  String get directoryFormat => '目录格式';

  @override
  String get dataEncryption => '数据加密';

  @override
  String get fileNameEncryption => '文件名加密';

  @override
  String get nameEncryption => '名称加密';

  @override
  String get passwordDerivation => '密码派生';

  @override
  String get passwordVerification => '密码验证';

  @override
  String versionValue(int version) {
    return '版本 $version';
  }

  @override
  String get unavailableOrLegacy => '不可用或旧格式';

  @override
  String get passwordChange => '修改密码';

  @override
  String get passwordChangeDirectly => '可直接修改';

  @override
  String get passwordChangeMigrationRequired => '需要迁移';

  @override
  String get rootPropertiesSensitiveNotice => '不会显示密码、密钥或其他敏感信息。';

  @override
  String get directory => '目录';

  @override
  String get status => '状态';

  @override
  String get directoryCannotChangePassword => '此目录不能直接修改密码';

  @override
  String get reason => '原因';

  @override
  String get legacyPasswordChangeReason => '此目录使用较早的加密格式。直接修改密码会导致已有内容无法读取。';

  @override
  String get safeApproach => '安全做法';

  @override
  String get legacyPasswordChangeApproach => '使用新密码创建一个加密目录，再导出并导入需要保留的内容。';

  @override
  String get createEncryptedDirectory => '创建加密目录';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get allowFuturePasswordChange => '允许以后修改密码';

  @override
  String get allowFuturePasswordChangeHint => '推荐：不重加密已有文件即可修改密码';

  @override
  String get advancedEncryptionParameters => '高级加密参数';

  @override
  String get advancedEncryptionParametersHint => '默认配置适合大多数用户';

  @override
  String get derivationStrength => '派生强度';

  @override
  String durationMilliseconds(int count) {
    return '$count 毫秒';
  }

  @override
  String get noEncryption => '不加密（None）';

  @override
  String get unencryptedNamesWarning => '注意：选择“不加密（None）”后，文件名和目录名不会加密。';

  @override
  String get selectDirectory => '选择目录';

  @override
  String get directoryPath => '目录路径';

  @override
  String get directoryPathHint => '输入目录路径或浏览选择';

  @override
  String get browse => '浏览';

  @override
  String get confirm => '确定';

  @override
  String get confirmDirectoryRemoval => '确认删除';

  @override
  String get removeEncryptedDirectoryFromSidebar => '您即将从侧边栏移除加密目录：';

  @override
  String get chooseAnAction => '请选择操作：';

  @override
  String get removeFromSidebarOnlyDescription => '• 仅从侧边栏移除：保留磁盘目录和加密文件';

  @override
  String get deleteDirectoryFromDiskDescription => '• 同时删除磁盘目录：永久删除目录及所有文件';

  @override
  String get removeOnly => '仅移除';

  @override
  String get deleteDiskDirectory => '删除磁盘目录';

  @override
  String get argon2TimeCost => 'Argon2 时间成本';

  @override
  String get argon2MemoryCost => 'Argon2 内存成本';

  @override
  String get argon2Parallelism => 'Argon2 并行度';

  @override
  String get argon2KeyLength => 'Argon2 密钥长度';

  @override
  String get pbkdf2Iterations => 'PBKDF2 迭代次数';

  @override
  String get pbkdf2KeyLength => 'PBKDF2 密钥长度';

  @override
  String get scryptN => 'scrypt N';

  @override
  String get scryptR => 'scrypt r';

  @override
  String get scryptP => 'scrypt p';

  @override
  String get scryptKeyLength => 'scrypt 密钥长度';

  @override
  String propertyLabel(String label) {
    return '$label：';
  }

  @override
  String get filterCurrentDirectoryHint => '筛选当前目录的文件和文件夹…';

  @override
  String get filterLoadedItemsHint => '仅筛选已加载条目；继续加载可扩大范围';

  @override
  String get navigateUp => '返回上级目录';

  @override
  String directoryIncompleteSummary(int count, int folders, int files) {
    return '已加载 $count 项（$folders 个文件夹，$files 个文件）';
  }

  @override
  String directorySummary(int folders, int files) {
    return '$folders 个文件夹，$files 个文件';
  }

  @override
  String get sortUnavailableUntilFullyLoaded => '目录尚未完整加载，暂不可排序';

  @override
  String sortTooltip(String order) {
    return '排序：$order';
  }

  @override
  String get sortNameAscending => '名称：A 到 Z';

  @override
  String get sortNameDescending => '名称：Z 到 A';

  @override
  String get sortModifiedNewest => '修改时间：最新优先';

  @override
  String get sortModifiedOldest => '修改时间：最早优先';

  @override
  String get sortSizeLargest => '大小：最大优先';

  @override
  String get sortSizeSmallest => '大小：最小优先';

  @override
  String get closeCurrentDirectoryFilter => '关闭当前目录筛选';

  @override
  String get filterCurrentDirectory => '筛选当前目录';

  @override
  String get hideDirectoryNavigator => '隐藏目录导航';

  @override
  String get showDirectoryNavigator => '显示目录导航';

  @override
  String get listView => '列表视图';

  @override
  String get gridView => '网格视图';

  @override
  String get directoryReadFailedRetry => '读取目录失败，刷新后重试';

  @override
  String noMatchInLoadedEntries(String query) {
    return '已加载条目中没有匹配“$query”的内容';
  }

  @override
  String noMatchInCurrentDirectory(String query) {
    return '当前目录没有匹配“$query”的条目';
  }

  @override
  String get unloadedEntriesMayMatch => '仍有未加载条目，可继续加载后再筛选';

  @override
  String get currentDirectoryEmpty => '当前目录为空';

  @override
  String get loadMoreEntries => '加载更多条目';

  @override
  String get loadMoreFailedRetry => '加载更多失败，刷新后重试';

  @override
  String get scrollToLoadMore => '继续滚动以加载更多条目';

  @override
  String directoryItemCount(int count) {
    return '$count 个项目';
  }

  @override
  String get file => '文件';

  @override
  String fileSystemEntrySemantics(String name, String type) {
    return '$name，$type';
  }

  @override
  String get openDirectory => '打开目录';

  @override
  String get viewImage => '查看图片';

  @override
  String get editWithSecureNotepad => '使用安全记事本编辑';

  @override
  String get viewInNewWindow => '在新窗口中查看';

  @override
  String get editInNewWindow => '在新窗口中编辑';

  @override
  String get select => '选择';

  @override
  String get rename => '重命名';

  @override
  String get cut => '剪切';

  @override
  String get pasteIntoDirectory => '粘贴到此目录';

  @override
  String get exportDirectory => '导出目录';

  @override
  String get exportDecryptedFile => '导出解密文件';

  @override
  String get copyPlaintextName => '复制名称（明文）';

  @override
  String get copyPlaintextLogicalPath => '复制逻辑路径（明文）';

  @override
  String get refresh => '刷新';

  @override
  String get deleteFile => '删除文件';

  @override
  String get renameDirectory => '重命名目录';

  @override
  String get renameFile => '重命名文件';

  @override
  String get newName => '新名称';

  @override
  String get fileNameEmpty => '名称不能为空';

  @override
  String get fileNameLeadingOrTrailingWhitespace => '名称不能以空格开头或结尾';

  @override
  String get fileNameReserved => '不能使用保留名称';

  @override
  String get fileNameTrailingDot => '名称不能以点结尾';

  @override
  String get fileNamePathSeparatorOrNull => '名称不能包含路径分隔符或空字符';

  @override
  String get fileNameUnsupportedCharacter => '名称包含跨平台不支持的字符';

  @override
  String get fileNameReservedSystemName => '该名称是系统保留名称';

  @override
  String get fileNameTooLong => '名称不能超过 255 个 UTF-8 字节';

  @override
  String get name => '名称';

  @override
  String get type => '类型';

  @override
  String get size => '大小';

  @override
  String get modifiedTime => '修改时间';

  @override
  String get logicalPath => '逻辑路径';

  @override
  String fileTypeWithExtension(String extension) {
    return '$extension 文件';
  }

  @override
  String get newFile => '新建文件';

  @override
  String get newDirectory => '新建目录';

  @override
  String get newFileDefaultName => '新建文件.txt';

  @override
  String get newDirectoryDefaultName => '新建目录';

  @override
  String get create => '创建';

  @override
  String get directoryTreeReadFailed => '无法读取目录树';

  @override
  String get directoryTreeLoadMoreFailed => '继续读取失败';

  @override
  String get readingDirectories => '正在读取…';

  @override
  String get loadMoreDirectories => '读取更多目录';

  @override
  String retryDirectoryTreeRead(String message) {
    return '$message，刷新重试';
  }

  @override
  String get importOperation => '导入';

  @override
  String get exportOperation => '导出';

  @override
  String get batchExportOperation => '批量导出';

  @override
  String get pasteOperation => '粘贴';

  @override
  String get batchPasteOperation => '批量粘贴';

  @override
  String get copySuffix => '副本';

  @override
  String get conflictTargetExists => '目标已存在';

  @override
  String get conflictReplacementUnavailable =>
      '源和目标类型不兼容，或源与目标是同一条目。请选择“保留两者”生成新名称。';

  @override
  String get conflictDirectoryReplaceDetail =>
      '选择“合并并替换”会保留目标目录独有的内容，并替换其中的同名文件。';

  @override
  String get conflictFileReplaceDetail => '选择“替换”会用新内容替换现有文件。';

  @override
  String conflictDescription(String name, String operation, String detail) {
    return '“$name”已存在，无法直接$operation。\n\n$detail';
  }

  @override
  String get keepBoth => '保留两者';

  @override
  String get keepBothForAll => '全部保留两者';

  @override
  String get mergeAndReplace => '合并并替换';

  @override
  String get replace => '替换';

  @override
  String get replaceForAll => '全部替换';

  @override
  String batchOperationCancelled(String operation) {
    return '$operation已取消';
  }

  @override
  String batchOperationPartiallyCompleted(String operation) {
    return '$operation部分完成';
  }

  @override
  String batchOperationCompleted(String operation) {
    return '$operation完成';
  }

  @override
  String batchTotal(int count) {
    return '总数：$count';
  }

  @override
  String batchSucceeded(int count) {
    return '成功：$count';
  }

  @override
  String batchSkipped(int count) {
    return '跳过：$count';
  }

  @override
  String batchFailed(int count) {
    return '失败：$count';
  }

  @override
  String batchUnprocessed(int count) {
    return '未处理：$count';
  }

  @override
  String batchClipboardRemaining(int count) {
    return '剪贴板剩余：$count';
  }

  @override
  String get failureDetails => '失败详情';

  @override
  String batchFailureItem(String name, String reason) {
    return '“$name”：$reason';
  }

  @override
  String additionalFailures(int count) {
    return '另有 $count 项失败';
  }
}
