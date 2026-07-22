import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Safe Disk'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统语言'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @saveSettings.
  ///
  /// In zh, this message translates to:
  /// **'保存设置'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'设置已保存'**
  String get settingsSaved;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载设置'**
  String get settingsLoadFailed;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法保存设置'**
  String get settingsSaveFailed;

  /// No description provided for @settingsNotSaved.
  ///
  /// In zh, this message translates to:
  /// **'设置尚未保存。'**
  String get settingsNotSaved;

  /// No description provided for @settingsLoadDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法读取本机设置。'**
  String get settingsLoadDescription;

  /// No description provided for @settingsLoadSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请重试；如果问题持续，请恢复默认设置或联系支持。'**
  String get settingsLoadSuggestion;

  /// No description provided for @settingsSaveSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查本机存储空间和权限，然后重试。'**
  String get settingsSaveSuggestion;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'亮色主题'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'暗色主题'**
  String get themeDark;

  /// No description provided for @themePreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'主题会立即预览；保存后会在下次启动时保留。'**
  String get themePreviewHint;

  /// No description provided for @languagePreviewHint.
  ///
  /// In zh, this message translates to:
  /// **'语言会立即预览；保存后会在下次启动时保留。'**
  String get languagePreviewHint;

  /// No description provided for @englishPreviewNotice.
  ///
  /// In zh, this message translates to:
  /// **'英文界面仍在完善，部分页面暂时会显示中文。'**
  String get englishPreviewNotice;

  /// No description provided for @saveChanges.
  ///
  /// In zh, this message translates to:
  /// **'保存设置更改？'**
  String get saveChanges;

  /// No description provided for @unsavedSettings.
  ///
  /// In zh, this message translates to:
  /// **'当前修改尚未保存。'**
  String get unsavedSettings;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @discardChanges.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改'**
  String get discardChanges;

  /// No description provided for @saveAndReturn.
  ///
  /// In zh, this message translates to:
  /// **'保存并返回'**
  String get saveAndReturn;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @restoreDefaults.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置（未保存）'**
  String get restoreDefaults;

  /// No description provided for @loadingImage.
  ///
  /// In zh, this message translates to:
  /// **'正在加载图片'**
  String get loadingImage;

  /// No description provided for @imageLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片加载失败'**
  String get imageLoadFailed;

  /// No description provided for @imageEncodedSizeLimit.
  ///
  /// In zh, this message translates to:
  /// **'图片编码数据超过 {limit} 上限'**
  String imageEncodedSizeLimit(String limit);

  /// No description provided for @imageContentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'图片内容为空'**
  String get imageContentEmpty;

  /// No description provided for @imageDimensionsInvalid.
  ///
  /// In zh, this message translates to:
  /// **'图片尺寸无效'**
  String get imageDimensionsInvalid;

  /// No description provided for @imageDecodedPixelLimit.
  ///
  /// In zh, this message translates to:
  /// **'图片解码尺寸超过 {limit} 上限'**
  String imageDecodedPixelLimit(String limit);

  /// No description provided for @imageEncryptedContentInvalid.
  ///
  /// In zh, this message translates to:
  /// **'无法读取加密图片数据，内容可能无效。'**
  String get imageEncryptedContentInvalid;

  /// No description provided for @noDisplayableImage.
  ///
  /// In zh, this message translates to:
  /// **'没有可显示的图片。请选择其他图片或重试。'**
  String get noDisplayableImage;

  /// No description provided for @viewingImage.
  ///
  /// In zh, this message translates to:
  /// **'正在查看：{fileName}'**
  String viewingImage(String fileName);

  /// No description provided for @animatedImageFrames.
  ///
  /// In zh, this message translates to:
  /// **'动画（{count} 帧）'**
  String animatedImageFrames(int count);

  /// No description provided for @zoomInShortcut.
  ///
  /// In zh, this message translates to:
  /// **'放大（+）'**
  String get zoomInShortcut;

  /// No description provided for @zoomOutShortcut.
  ///
  /// In zh, this message translates to:
  /// **'缩小（-）'**
  String get zoomOutShortcut;

  /// No description provided for @resetImageViewShortcut.
  ///
  /// In zh, this message translates to:
  /// **'重置视图（N）'**
  String get resetImageViewShortcut;

  /// No description provided for @rotateClockwiseShortcut.
  ///
  /// In zh, this message translates to:
  /// **'顺时针旋转（R）'**
  String get rotateClockwiseShortcut;

  /// No description provided for @previousImageShortcut.
  ///
  /// In zh, this message translates to:
  /// **'上一张（←）'**
  String get previousImageShortcut;

  /// No description provided for @nextImageShortcut.
  ///
  /// In zh, this message translates to:
  /// **'下一张（→）'**
  String get nextImageShortcut;

  /// No description provided for @imageDecodeFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法显示图片'**
  String get imageDecodeFailed;

  /// No description provided for @imageDecodeFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'文件可能已损坏，或不是受支持的图片格式。'**
  String get imageDecodeFailedDescription;

  /// No description provided for @errorSuggestionPrefix.
  ///
  /// In zh, this message translates to:
  /// **'建议：'**
  String get errorSuggestionPrefix;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @viewDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get viewDetails;

  /// No description provided for @technicalDetails.
  ///
  /// In zh, this message translates to:
  /// **'技术详情'**
  String get technicalDetails;

  /// No description provided for @errorDetailsCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制错误信息'**
  String get errorDetailsCopied;

  /// No description provided for @errorDirectoryNotVerifiedTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要解锁目录'**
  String get errorDirectoryNotVerifiedTitle;

  /// No description provided for @errorDirectoryNotVerifiedDescription.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码解锁此加密目录后再操作文件。'**
  String get errorDirectoryNotVerifiedDescription;

  /// No description provided for @errorDirectoryNotVerifiedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'在侧边栏选择该目录，然后输入密码。'**
  String get errorDirectoryNotVerifiedSuggestion;

  /// No description provided for @errorSessionExpiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录已锁定'**
  String get errorSessionExpiredTitle;

  /// No description provided for @errorSessionExpiredDescription.
  ///
  /// In zh, this message translates to:
  /// **'目录会话已结束，需要重新解锁。'**
  String get errorSessionExpiredDescription;

  /// No description provided for @errorSessionExpiredSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'在侧边栏选择该目录，然后重新输入密码。'**
  String get errorSessionExpiredSuggestion;

  /// No description provided for @errorInvalidPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'密码错误'**
  String get errorInvalidPasswordTitle;

  /// No description provided for @errorInvalidPasswordDescription.
  ///
  /// In zh, this message translates to:
  /// **'您输入的密码不正确，无法解密此目录。'**
  String get errorInvalidPasswordDescription;

  /// No description provided for @errorInvalidPasswordSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查密码是否正确，注意区分大小写。'**
  String get errorInvalidPasswordSuggestion;

  /// No description provided for @errorDirectoryNotExistTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录不存在'**
  String get errorDirectoryNotExistTitle;

  /// No description provided for @errorDirectoryNotExistDescription.
  ///
  /// In zh, this message translates to:
  /// **'指定的目录路径不存在或已被删除。'**
  String get errorDirectoryNotExistDescription;

  /// No description provided for @errorDirectoryNotExistSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目录路径是否正确，或选择其他目录。'**
  String get errorDirectoryNotExistSuggestion;

  /// No description provided for @errorNotEncryptedDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法打开目录'**
  String get errorNotEncryptedDirectoryTitle;

  /// No description provided for @errorNotEncryptedDirectoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'所选目录不是可识别的 Safe Disk 加密目录。'**
  String get errorNotEncryptedDirectoryDescription;

  /// No description provided for @errorNotEncryptedDirectorySuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请选择已有加密目录，或创建新的加密目录。'**
  String get errorNotEncryptedDirectorySuggestion;

  /// No description provided for @errorLoadConfigFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'加载配置失败'**
  String get errorLoadConfigFailedTitle;

  /// No description provided for @errorLoadConfigFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法读取加密目录的配置文件。'**
  String get errorLoadConfigFailedDescription;

  /// No description provided for @errorLoadConfigFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目录是否完整且未被其他程序修改。'**
  String get errorLoadConfigFailedSuggestion;

  /// No description provided for @errorLoadDirectoryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'加载目录失败'**
  String get errorLoadDirectoryFailedTitle;

  /// No description provided for @errorLoadDirectoryFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法读取目录内容。'**
  String get errorLoadDirectoryFailedDescription;

  /// No description provided for @errorLoadDirectoryFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目录权限，或尝试重新打开目录。'**
  String get errorLoadDirectoryFailedSuggestion;

  /// No description provided for @errorUnfinishedTransferStateUnavailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法确认未完成传输状态'**
  String get errorUnfinishedTransferStateUnavailableTitle;

  /// No description provided for @errorUnfinishedTransferStateUnavailableDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法安全读取未完成的导入/导出状态，因此没有打开此加密目录。'**
  String get errorUnfinishedTransferStateUnavailableDescription;

  /// No description provided for @errorUnfinishedTransferStateUnavailableSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目录权限和磁盘状态；不要手动删除传输状态文件。'**
  String get errorUnfinishedTransferStateUnavailableSuggestion;

  /// No description provided for @errorCreateEncryptedDirectoryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建加密目录失败'**
  String get errorCreateEncryptedDirectoryFailedTitle;

  /// No description provided for @errorCreateEncryptedDirectoryFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法创建新的加密目录。'**
  String get errorCreateEncryptedDirectoryFailedDescription;

  /// No description provided for @errorCreateEncryptedDirectoryFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目录权限和磁盘空间，然后重试。'**
  String get errorCreateEncryptedDirectoryFailedSuggestion;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录不是空目录'**
  String get errorCreateEncryptedDirectoryRequiresEmptyTitle;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'新加密目录只能创建在不存在或内容为空的目录中。'**
  String get errorCreateEncryptedDirectoryRequiresEmptyDescription;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptySuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请选择新的路径或空目录；已有内容请通过导入功能加入。'**
  String get errorCreateEncryptedDirectoryRequiresEmptySuggestion;

  /// No description provided for @errorImportFileFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入文件失败'**
  String get errorImportFileFailedTitle;

  /// No description provided for @errorImportFileFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法将文件导入到加密目录。'**
  String get errorImportFileFailedDescription;

  /// No description provided for @errorImportFileFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查文件是否存在且可读，然后重试。'**
  String get errorImportFileFailedSuggestion;

  /// No description provided for @errorImportDirectoryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入目录失败'**
  String get errorImportDirectoryFailedTitle;

  /// No description provided for @errorImportDirectoryFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法将目录导入到加密目录。'**
  String get errorImportDirectoryFailedDescription;

  /// No description provided for @errorImportDirectoryFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查源目录权限、符号链接和目标目录状态，然后重试。'**
  String get errorImportDirectoryFailedSuggestion;

  /// No description provided for @errorImportDirectoryInsideCurrentRootTitle.
  ///
  /// In zh, this message translates to:
  /// **'不能导入此目录'**
  String get errorImportDirectoryInsideCurrentRootTitle;

  /// No description provided for @errorImportDirectoryInsideCurrentRootDescription.
  ///
  /// In zh, this message translates to:
  /// **'不能将当前加密目录中的目录再次导入到自身。'**
  String get errorImportDirectoryInsideCurrentRootDescription;

  /// No description provided for @errorImportDirectoryInsideCurrentRootSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请选择加密目录外的来源目录。'**
  String get errorImportDirectoryInsideCurrentRootSuggestion;

  /// No description provided for @errorExportFileFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出文件失败'**
  String get errorExportFileFailedTitle;

  /// No description provided for @errorExportFileFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法将文件导出到指定位置。'**
  String get errorExportFileFailedDescription;

  /// No description provided for @errorExportFileFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目标位置是否可写，然后重试。'**
  String get errorExportFileFailedSuggestion;

  /// No description provided for @errorExportDirectoryFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出目录失败'**
  String get errorExportDirectoryFailedTitle;

  /// No description provided for @errorExportDirectoryFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法将目录导出到指定位置。'**
  String get errorExportDirectoryFailedDescription;

  /// No description provided for @errorExportDirectoryFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查目标位置是否可写，然后重试。'**
  String get errorExportDirectoryFailedSuggestion;

  /// No description provided for @errorDeleteFileFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除文件失败'**
  String get errorDeleteFileFailedTitle;

  /// No description provided for @errorDeleteFileFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法删除此文件。'**
  String get errorDeleteFileFailedDescription;

  /// No description provided for @errorDeleteFileFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查文件是否被占用，然后重试。'**
  String get errorDeleteFileFailedSuggestion;

  /// No description provided for @errorSaveFileFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存文件失败'**
  String get errorSaveFileFailedTitle;

  /// No description provided for @errorSaveFileFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法保存文件更改。'**
  String get errorSaveFileFailedDescription;

  /// No description provided for @errorSaveFileFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查磁盘空间和权限，然后重试。'**
  String get errorSaveFileFailedSuggestion;

  /// No description provided for @errorLoadFileFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'加载文件失败'**
  String get errorLoadFileFailedTitle;

  /// No description provided for @errorLoadFileFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法读取文件内容。'**
  String get errorLoadFileFailedDescription;

  /// No description provided for @errorLoadFileFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请检查文件是否存在且可读。'**
  String get errorLoadFileFailedSuggestion;

  /// No description provided for @errorNoDirectorySelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'未选择目录'**
  String get errorNoDirectorySelectedTitle;

  /// No description provided for @errorNoDirectorySelectedDescription.
  ///
  /// In zh, this message translates to:
  /// **'请先选择一个目录。'**
  String get errorNoDirectorySelectedDescription;

  /// No description provided for @errorNoFileSelectedTitle.
  ///
  /// In zh, this message translates to:
  /// **'未选择文件'**
  String get errorNoFileSelectedTitle;

  /// No description provided for @errorNoFileSelectedDescription.
  ///
  /// In zh, this message translates to:
  /// **'请先选择一个文件。'**
  String get errorNoFileSelectedDescription;

  /// No description provided for @errorPasswordEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'密码不能为空'**
  String get errorPasswordEmptyTitle;

  /// No description provided for @errorPasswordEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码以继续操作。'**
  String get errorPasswordEmptyDescription;

  /// No description provided for @errorPasswordMismatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'密码不匹配'**
  String get errorPasswordMismatchTitle;

  /// No description provided for @errorPasswordMismatchDescription.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致。'**
  String get errorPasswordMismatchDescription;

  /// No description provided for @errorPasswordMismatchSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请确保两次输入相同的密码。'**
  String get errorPasswordMismatchSuggestion;

  /// No description provided for @errorPathEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'路径不能为空'**
  String get errorPathEmptyTitle;

  /// No description provided for @errorPathEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'请输入目录路径。'**
  String get errorPathEmptyDescription;

  /// No description provided for @errorOperationFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get errorOperationFailedTitle;

  /// No description provided for @errorOperationFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成，请稍后重试。'**
  String get errorOperationFailedDescription;

  /// No description provided for @errorOperationFailedSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'如果问题持续存在，请联系技术支持。'**
  String get errorOperationFailedSuggestion;

  /// No description provided for @behavior.
  ///
  /// In zh, this message translates to:
  /// **'行为'**
  String get behavior;

  /// No description provided for @confirmBeforeDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除前确认'**
  String get confirmBeforeDelete;

  /// No description provided for @confirmBeforeDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'删除文件前显示确认对话框'**
  String get confirmBeforeDeleteHint;

  /// No description provided for @lockAfterIdle.
  ///
  /// In zh, this message translates to:
  /// **'空闲后自动锁定'**
  String get lockAfterIdle;

  /// No description provided for @lockAfterIdleHint.
  ///
  /// In zh, this message translates to:
  /// **'当前目录空闲到期后锁定；有未保存内容或活动写入时不会强制关闭'**
  String get lockAfterIdleHint;

  /// No description provided for @lockWhenHidden.
  ///
  /// In zh, this message translates to:
  /// **'应用隐藏时自动锁定'**
  String get lockWhenHidden;

  /// No description provided for @lockWhenHiddenHint.
  ///
  /// In zh, this message translates to:
  /// **'仅锁定没有内容窗口、未保存修改或活动写入的目录；其他目录不会被强制关闭'**
  String get lockWhenHiddenHint;

  /// No description provided for @messageListSeparator.
  ///
  /// In zh, this message translates to:
  /// **'；'**
  String get messageListSeparator;

  /// No description provided for @autoLockSummaryLocked.
  ///
  /// In zh, this message translates to:
  /// **'已自动锁定 {count} 个目录'**
  String autoLockSummaryLocked(int count);

  /// No description provided for @autoLockSummarySkipped.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个目录含内容窗口或未完成保存，未强制关闭'**
  String autoLockSummarySkipped(int count);

  /// No description provided for @autoLockSummaryFailed.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个目录锁定失败'**
  String autoLockSummaryFailed(int count);

  /// No description provided for @rootActiveWritesTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在保存内容'**
  String get rootActiveWritesTitle;

  /// No description provided for @rootActiveWritesDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前有 {count} 个内容保存操作尚未完成，请等待保存结束后再关闭会话。'**
  String rootActiveWritesDescription(int count);

  /// No description provided for @rootUnsavedContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'存在未保存内容'**
  String get rootUnsavedContentTitle;

  /// No description provided for @rootUnsavedContentDescription.
  ///
  /// In zh, this message translates to:
  /// **'请先处理以下内容窗口，再结束会话：\n\n{documents}'**
  String rootUnsavedContentDescription(String documents);

  /// No description provided for @acknowledge.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get acknowledge;

  /// No description provided for @rootDirectoryDeleted.
  ///
  /// In zh, this message translates to:
  /// **'本地加密目录已永久删除'**
  String get rootDirectoryDeleted;

  /// No description provided for @rootHistoryRemoved.
  ///
  /// In zh, this message translates to:
  /// **'目录历史已移除，本地磁盘内容保持不变'**
  String get rootHistoryRemoved;

  /// No description provided for @passwordChangeBlockedBySaving.
  ///
  /// In zh, this message translates to:
  /// **'当前目录正在保存内容，请等待保存完成后再修改密码。'**
  String get passwordChangeBlockedBySaving;

  /// No description provided for @passwordChangeBlockedByDocuments.
  ///
  /// In zh, this message translates to:
  /// **'请先关闭或保存该目录中的内容窗口，再修改密码。'**
  String get passwordChangeBlockedByDocuments;

  /// No description provided for @passwordChangedUnlockAgain.
  ///
  /// In zh, this message translates to:
  /// **'密码已修改，请使用新密码重新解锁目录'**
  String get passwordChangedUnlockAgain;

  /// No description provided for @notepadDraftInterval.
  ///
  /// In zh, this message translates to:
  /// **'安全草稿保存间隔'**
  String get notepadDraftInterval;

  /// No description provided for @notepadDraftIntervalHint.
  ///
  /// In zh, this message translates to:
  /// **'定时写入同目录加密草稿，不覆盖原文件'**
  String get notepadDraftIntervalHint;

  /// No description provided for @notepadDefaultReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'记事本默认只读'**
  String get notepadDefaultReadOnly;

  /// No description provided for @notepadDefaultReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'新打开的文件先以只读方式显示，可手动开始编辑'**
  String get notepadDefaultReadOnlyHint;

  /// No description provided for @notepadMonitorClipboard.
  ///
  /// In zh, this message translates to:
  /// **'默认监视剪贴板'**
  String get notepadMonitorClipboard;

  /// No description provided for @notepadMonitorClipboardHint.
  ///
  /// In zh, this message translates to:
  /// **'仅显示短文本预览，不写入文件或设置'**
  String get notepadMonitorClipboardHint;

  /// No description provided for @notepadRecoveryDraftFound.
  ///
  /// In zh, this message translates to:
  /// **'发现安全草稿'**
  String get notepadRecoveryDraftFound;

  /// No description provided for @notepadBinaryContent.
  ///
  /// In zh, this message translates to:
  /// **'文件包含二进制内容，不能用安全记事本打开。'**
  String get notepadBinaryContent;

  /// No description provided for @notepadLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取文件内容。请检查文件是否存在且可读，然后重试。'**
  String get notepadLoadFailed;

  /// No description provided for @notepadRecoveryDraftDescription.
  ///
  /// In zh, this message translates to:
  /// **'发现上次未完成编辑的加密草稿。是否恢复到编辑器？'**
  String get notepadRecoveryDraftDescription;

  /// No description provided for @notepadDiscardDraft.
  ///
  /// In zh, this message translates to:
  /// **'放弃草稿'**
  String get notepadDiscardDraft;

  /// No description provided for @notepadRestoreDraft.
  ///
  /// In zh, this message translates to:
  /// **'恢复草稿'**
  String get notepadRestoreDraft;

  /// No description provided for @notepadUnsavedChanges.
  ///
  /// In zh, this message translates to:
  /// **'未保存的更改'**
  String get notepadUnsavedChanges;

  /// No description provided for @notepadSaveBeforeClosing.
  ///
  /// In zh, this message translates to:
  /// **'关闭前是否保存更改？'**
  String get notepadSaveBeforeClosing;

  /// No description provided for @notepadDontSave.
  ///
  /// In zh, this message translates to:
  /// **'不保存'**
  String get notepadDontSave;

  /// No description provided for @notepadStartEditing.
  ///
  /// In zh, this message translates to:
  /// **'开始编辑'**
  String get notepadStartEditing;

  /// No description provided for @notepadSwitchReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'切换为只读'**
  String get notepadSwitchReadOnly;

  /// No description provided for @notepadUndoShortcut.
  ///
  /// In zh, this message translates to:
  /// **'撤销（Ctrl/Cmd+Z）'**
  String get notepadUndoShortcut;

  /// No description provided for @notepadRedoShortcut.
  ///
  /// In zh, this message translates to:
  /// **'重做（Ctrl/Cmd+Shift+Z）'**
  String get notepadRedoShortcut;

  /// No description provided for @notepadFindReplace.
  ///
  /// In zh, this message translates to:
  /// **'查找/替换'**
  String get notepadFindReplace;

  /// No description provided for @notepadCloseFind.
  ///
  /// In zh, this message translates to:
  /// **'关闭查找'**
  String get notepadCloseFind;

  /// No description provided for @notepadStopClipboardMonitoring.
  ///
  /// In zh, this message translates to:
  /// **'停止剪贴板监视'**
  String get notepadStopClipboardMonitoring;

  /// No description provided for @notepadMonitorClipboardAction.
  ///
  /// In zh, this message translates to:
  /// **'监视剪贴板'**
  String get notepadMonitorClipboardAction;

  /// No description provided for @notepadSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get notepadSave;

  /// No description provided for @notepadFileSaved.
  ///
  /// In zh, this message translates to:
  /// **'文件已保存'**
  String get notepadFileSaved;

  /// No description provided for @notepadSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get notepadSaveFailed;

  /// No description provided for @notepadSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存'**
  String get notepadSaving;

  /// No description provided for @notepadUnsaved.
  ///
  /// In zh, this message translates to:
  /// **'未保存'**
  String get notepadUnsaved;

  /// No description provided for @notepadSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get notepadSaved;

  /// No description provided for @notepadReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'只读'**
  String get notepadReadOnly;

  /// No description provided for @notepadEditing.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get notepadEditing;

  /// No description provided for @notepadCharacterCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字符'**
  String notepadCharacterCount(int count);

  /// No description provided for @notepadDraftSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法保存恢复草稿'**
  String get notepadDraftSaveFailed;

  /// No description provided for @notepadDraftCleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'原文件已保存，但无法清理旧草稿'**
  String get notepadDraftCleanupFailed;

  /// No description provided for @notepadDraftReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法检查恢复草稿'**
  String get notepadDraftReadFailed;

  /// No description provided for @notepadDraftDiscardFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法清理恢复草稿'**
  String get notepadDraftDiscardFailed;

  /// No description provided for @notepadSavingDraft.
  ///
  /// In zh, this message translates to:
  /// **'正在保存草稿'**
  String get notepadSavingDraft;

  /// No description provided for @notepadDraftSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存恢复草稿'**
  String get notepadDraftSaved;

  /// No description provided for @notepadClipboardMonitor.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板监视'**
  String get notepadClipboardMonitor;

  /// No description provided for @notepadClipboardEmpty.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板中没有短文本'**
  String get notepadClipboardEmpty;

  /// No description provided for @notepadClipboardReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取剪贴板，请重试。'**
  String get notepadClipboardReadFailed;

  /// No description provided for @notepadClipboardClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法清空剪贴板，请重试。'**
  String get notepadClipboardClearFailed;

  /// No description provided for @notepadRefreshClipboard.
  ///
  /// In zh, this message translates to:
  /// **'立即刷新剪贴板'**
  String get notepadRefreshClipboard;

  /// No description provided for @notepadClearClipboard.
  ///
  /// In zh, this message translates to:
  /// **'快速清空系统剪贴板'**
  String get notepadClearClipboard;

  /// No description provided for @notepadFindHint.
  ///
  /// In zh, this message translates to:
  /// **'查找（\\n 表示换行）'**
  String get notepadFindHint;

  /// No description provided for @notepadFindPosition.
  ///
  /// In zh, this message translates to:
  /// **'{current}/{total}'**
  String notepadFindPosition(int current, int total);

  /// No description provided for @notepadFindPrevious.
  ///
  /// In zh, this message translates to:
  /// **'查找上一个'**
  String get notepadFindPrevious;

  /// No description provided for @notepadFindNext.
  ///
  /// In zh, this message translates to:
  /// **'查找下一个'**
  String get notepadFindNext;

  /// No description provided for @notepadReplace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get notepadReplace;

  /// No description provided for @notepadReplaceAll.
  ///
  /// In zh, this message translates to:
  /// **'全部替换'**
  String get notepadReplaceAll;

  /// No description provided for @notepadNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配项'**
  String get notepadNoMatches;

  /// No description provided for @notepadSelectMatchFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先选择匹配项'**
  String get notepadSelectMatchFirst;

  /// No description provided for @notepadReplacedCount.
  ///
  /// In zh, this message translates to:
  /// **'已替换 {count} 处'**
  String notepadReplacedCount(int count);

  /// No description provided for @welcomeGuideWelcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 Safe Disk'**
  String get welcomeGuideWelcomeTitle;

  /// No description provided for @welcomeGuideWelcomeContent.
  ///
  /// In zh, this message translates to:
  /// **'Safe Disk 是一款安全的加密文件管理器，帮助您保护私密数据。\n\n所有文件都使用 AES-256-GCM 加密算法保护，确保只有您能访问。'**
  String get welcomeGuideWelcomeContent;

  /// No description provided for @welcomeGuideEncryptedDirectoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'加密目录'**
  String get welcomeGuideEncryptedDirectoryTitle;

  /// No description provided for @welcomeGuideEncryptedDirectoryContent.
  ///
  /// In zh, this message translates to:
  /// **'创建加密目录来保护您的文件：\n\n- 打开目录：打开已有的加密目录\n- 创建目录：创建新的加密目录\n\n加密目录中的所有文件都会自动加密保护。'**
  String get welcomeGuideEncryptedDirectoryContent;

  /// No description provided for @welcomeGuideFeaturesTitle.
  ///
  /// In zh, this message translates to:
  /// **'核心功能'**
  String get welcomeGuideFeaturesTitle;

  /// No description provided for @welcomeGuideFeaturesContent.
  ///
  /// In zh, this message translates to:
  /// **'- 文件浏览：浏览和管理加密目录中的文件\n- 安全记事本：编辑文本文件（.txt, .md）\n- 图片浏览器：查看加密的图片文件\n- 批量导出：选择多个文件一次性导出'**
  String get welcomeGuideFeaturesContent;

  /// No description provided for @welcomeGuideSecurityTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全提示'**
  String get welcomeGuideSecurityTitle;

  /// No description provided for @welcomeGuideSecurityContent.
  ///
  /// In zh, this message translates to:
  /// **'- 请牢记密码！密码丢失后无法恢复文件\n- 建议使用强密码（12位以上，混合字符）\n- 密钥仅在内存中缓存，关闭应用后自动清除\n- 定期备份重要加密目录'**
  String get welcomeGuideSecurityContent;

  /// No description provided for @welcomeGuideDontShowAgain.
  ///
  /// In zh, this message translates to:
  /// **'不再显示此引导'**
  String get welcomeGuideDontShowAgain;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get getStarted;

  /// No description provided for @detailedErrors.
  ///
  /// In zh, this message translates to:
  /// **'显示详细错误信息'**
  String get detailedErrors;

  /// No description provided for @detailedErrorsHint.
  ///
  /// In zh, this message translates to:
  /// **'在错误提示中显示经脱敏的操作阶段与底层错误；不会写入磁盘日志'**
  String get detailedErrorsHint;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @appVersionDescription.
  ///
  /// In zh, this message translates to:
  /// **'版本 1.0.0\\n加密文件管理器'**
  String get appVersionDescription;

  /// No description provided for @durationNever.
  ///
  /// In zh, this message translates to:
  /// **'永不过期'**
  String get durationNever;

  /// No description provided for @durationSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String durationSeconds(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时'**
  String durationHours(int count);

  /// No description provided for @durationDays.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String durationDays(int count);

  /// No description provided for @progressMinutesSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分 {seconds} 秒'**
  String progressMinutesSeconds(int minutes, int seconds);

  /// No description provided for @progressEstimatedRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计剩余：{duration}'**
  String progressEstimatedRemaining(String duration);

  /// No description provided for @progressProcessed.
  ///
  /// In zh, this message translates to:
  /// **'已处理：{current} / {total}'**
  String progressProcessed(int current, int total);

  /// No description provided for @progressCurrentFile.
  ///
  /// In zh, this message translates to:
  /// **'当前：{name}'**
  String progressCurrentFile(String name);

  /// No description provided for @rerunUnfinishedTransfers.
  ///
  /// In zh, this message translates to:
  /// **'全量重跑导入/导出'**
  String get rerunUnfinishedTransfers;

  /// No description provided for @preparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备…'**
  String get preparing;

  /// No description provided for @operationNotCancellableYet.
  ///
  /// In zh, this message translates to:
  /// **'当前操作尚未可取消。'**
  String get operationNotCancellableYet;

  /// No description provided for @rerunningUnfinishedProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在重跑 {current}/{total}…'**
  String rerunningUnfinishedProgress(int current, int total);

  /// No description provided for @unfinishedTransfersRerunCompleted.
  ///
  /// In zh, this message translates to:
  /// **'未完成导入/导出已全量重跑。'**
  String get unfinishedTransfersRerunCompleted;

  /// No description provided for @unfinishedTransfersRerunCancelled.
  ///
  /// In zh, this message translates to:
  /// **'重跑已取消，未完成状态已保留。'**
  String get unfinishedTransfersRerunCancelled;

  /// No description provided for @preparingImport.
  ///
  /// In zh, this message translates to:
  /// **'正在准备导入…'**
  String get preparingImport;

  /// No description provided for @preparingExport.
  ///
  /// In zh, this message translates to:
  /// **'正在准备导出…'**
  String get preparingExport;

  /// No description provided for @preparingDelete.
  ///
  /// In zh, this message translates to:
  /// **'正在准备删除…'**
  String get preparingDelete;

  /// No description provided for @preparingCannotCancel.
  ///
  /// In zh, this message translates to:
  /// **'正在准备，暂时无法取消…'**
  String get preparingCannotCancel;

  /// No description provided for @importing.
  ///
  /// In zh, this message translates to:
  /// **'正在导入…'**
  String get importing;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出…'**
  String get exporting;

  /// No description provided for @deleting.
  ///
  /// In zh, this message translates to:
  /// **'正在删除…'**
  String get deleting;

  /// No description provided for @directoryImportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'目录导入完成：{count} 个文件'**
  String directoryImportCompleted(int count);

  /// No description provided for @transferCancelledWithUnfinishedState.
  ///
  /// In zh, this message translates to:
  /// **'操作已取消，可在下次打开目录时清理未完成状态。'**
  String get transferCancelledWithUnfinishedState;

  /// No description provided for @directoryExportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'导出完成：{count} 个文件'**
  String directoryExportCompleted(int count);

  /// No description provided for @batchExport.
  ///
  /// In zh, this message translates to:
  /// **'批量导出'**
  String get batchExport;

  /// No description provided for @batchExportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'导出完成：成功 {success} 个，失败 {failed} 个'**
  String batchExportCompleted(int success, int failed);

  /// No description provided for @batchExportCompletedAll.
  ///
  /// In zh, this message translates to:
  /// **'导出完成：成功 {count} 个文件'**
  String batchExportCompletedAll(int count);

  /// No description provided for @batchExportCancelled.
  ///
  /// In zh, this message translates to:
  /// **'导出已取消：成功 {success} 个，失败 {failed} 个'**
  String batchExportCancelled(int success, int failed);

  /// No description provided for @batchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchDelete;

  /// No description provided for @batchDeleteCancelled.
  ///
  /// In zh, this message translates to:
  /// **'批量删除已取消：成功 {success} 个，剩余 {remaining} 个仍保持选择'**
  String batchDeleteCancelled(int success, int remaining);

  /// No description provided for @batchDeleteCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个文件'**
  String batchDeleteCompleted(int count);

  /// No description provided for @unfinishedTransfersDetected.
  ///
  /// In zh, this message translates to:
  /// **'发现未完成的导入/导出'**
  String get unfinishedTransfersDetected;

  /// No description provided for @unfinishedTransfersDetectedDescription.
  ///
  /// In zh, this message translates to:
  /// **'检测到 {count} 个未完成的导入/导出状态。\n\n这些操作无法继续。你可以清理状态后重新执行完整的导入或导出，也可以暂时跳过。'**
  String unfinishedTransfersDetectedDescription(int count);

  /// No description provided for @skipForNow.
  ///
  /// In zh, this message translates to:
  /// **'暂时跳过'**
  String get skipForNow;

  /// No description provided for @cleanState.
  ///
  /// In zh, this message translates to:
  /// **'清理状态'**
  String get cleanState;

  /// No description provided for @rerunAll.
  ///
  /// In zh, this message translates to:
  /// **'全量重跑'**
  String get rerunAll;

  /// No description provided for @confirmBatchDeletion.
  ///
  /// In zh, this message translates to:
  /// **'确认批量删除'**
  String get confirmBatchDeletion;

  /// No description provided for @confirmBatchDeletionDescription.
  ///
  /// In zh, this message translates to:
  /// **'确定删除所选 {count} 项吗？此操作无法撤销。删除会逐项执行，发生失败时已删除的项目不会恢复。'**
  String confirmBatchDeletionDescription(int count);

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get disabled;

  /// No description provided for @nativeComponentUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'安全组件不可用'**
  String get nativeComponentUnavailable;

  /// No description provided for @nativeBindingFailureDescription.
  ///
  /// In zh, this message translates to:
  /// **'安全组件版本与应用不匹配，无法启动加密功能。'**
  String get nativeBindingFailureDescription;

  /// No description provided for @nativeLoadingFailureDescription.
  ///
  /// In zh, this message translates to:
  /// **'无法加载 Safe Disk 安全组件，无法安全访问加密目录。'**
  String get nativeLoadingFailureDescription;

  /// No description provided for @nativeBindingFailureSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请重新安装同一版本的 Safe Disk 应用后重试。'**
  String get nativeBindingFailureSuggestion;

  /// No description provided for @nativeLoadingFailureSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'请重新安装应用；若问题持续，请检查安全软件是否隔离了应用文件。'**
  String get nativeLoadingFailureSuggestion;

  /// No description provided for @initializationStage.
  ///
  /// In zh, this message translates to:
  /// **'初始化阶段：{stage}'**
  String initializationStage(String stage);

  /// No description provided for @underlyingError.
  ///
  /// In zh, this message translates to:
  /// **'底层错误：{error}'**
  String underlyingError(String error);

  /// No description provided for @errorDiagnosticType.
  ///
  /// In zh, this message translates to:
  /// **'错误类型：{type}'**
  String errorDiagnosticType(String type);

  /// No description provided for @errorDiagnosticOperation.
  ///
  /// In zh, this message translates to:
  /// **'操作阶段：{operation}'**
  String errorDiagnosticOperation(String operation);

  /// No description provided for @errorDiagnosticRedacted.
  ///
  /// In zh, this message translates to:
  /// **'[已隐藏]'**
  String get errorDiagnosticRedacted;

  /// No description provided for @errorDiagnosticPathRedacted.
  ///
  /// In zh, this message translates to:
  /// **'[路径已隐藏]'**
  String get errorDiagnosticPathRedacted;

  /// No description provided for @errorDiagnosticTruncated.
  ///
  /// In zh, this message translates to:
  /// **'[详细信息已截断]'**
  String get errorDiagnosticTruncated;

  /// No description provided for @contentWindowUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接主窗口'**
  String get contentWindowUnavailable;

  /// No description provided for @contentWindowUnavailableDescription.
  ///
  /// In zh, this message translates to:
  /// **'文档会话可能已结束。为避免在失效会话中编辑，请关闭此窗口后从主界面重新打开。'**
  String get contentWindowUnavailableDescription;

  /// No description provided for @closeWindow.
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口'**
  String get closeWindow;

  /// No description provided for @welcomeProductTagline.
  ///
  /// In zh, this message translates to:
  /// **'加密文件管理器'**
  String get welcomeProductTagline;

  /// No description provided for @welcomeOpenDirectoryHint.
  ///
  /// In zh, this message translates to:
  /// **'请从侧边栏打开或创建加密目录'**
  String get welcomeOpenDirectoryHint;

  /// No description provided for @selectedItems.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String selectedItems(int count);

  /// No description provided for @exitSelectionMode.
  ///
  /// In zh, this message translates to:
  /// **'退出选择模式'**
  String get exitSelectionMode;

  /// No description provided for @copySelected.
  ///
  /// In zh, this message translates to:
  /// **'复制所选项'**
  String get copySelected;

  /// No description provided for @cutSelected.
  ///
  /// In zh, this message translates to:
  /// **'剪切所选项'**
  String get cutSelected;

  /// No description provided for @moreBatchActions.
  ///
  /// In zh, this message translates to:
  /// **'更多批量操作'**
  String get moreBatchActions;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @exportSelected.
  ///
  /// In zh, this message translates to:
  /// **'导出所选项'**
  String get exportSelected;

  /// No description provided for @deleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除所选项'**
  String get deleteSelected;

  /// No description provided for @closeDirectory.
  ///
  /// In zh, this message translates to:
  /// **'关闭目录'**
  String get closeDirectory;

  /// No description provided for @currentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前目录'**
  String get currentDirectory;

  /// No description provided for @clipboardMovePending.
  ///
  /// In zh, this message translates to:
  /// **'待移动'**
  String get clipboardMovePending;

  /// No description provided for @fileClipboard.
  ///
  /// In zh, this message translates to:
  /// **'文件剪贴板'**
  String get fileClipboard;

  /// No description provided for @clipboardPastePending.
  ///
  /// In zh, this message translates to:
  /// **'待粘贴'**
  String get clipboardPastePending;

  /// No description provided for @moveSourceDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'目标已复制，但无法删除源项。源项和目标均已保留，请确认内容后手动删除源项。'**
  String get moveSourceDeleteFailed;

  /// No description provided for @clipboardMultipleEntries.
  ///
  /// In zh, this message translates to:
  /// **'{name} 等 {count} 项'**
  String clipboardMultipleEntries(String name, int count);

  /// No description provided for @clipboardStatusWide.
  ///
  /// In zh, this message translates to:
  /// **'{operation} · {entries} → {target}'**
  String clipboardStatusWide(String operation, String entries, String target);

  /// No description provided for @clipboardStatusNarrow.
  ///
  /// In zh, this message translates to:
  /// **'{operation} · {entries}'**
  String clipboardStatusNarrow(String operation, String entries);

  /// No description provided for @moveToCurrentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'移动到当前目录'**
  String get moveToCurrentDirectory;

  /// No description provided for @pasteToCurrentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'粘贴到当前目录'**
  String get pasteToCurrentDirectory;

  /// No description provided for @clearFileClipboard.
  ///
  /// In zh, this message translates to:
  /// **'清空文件剪贴板'**
  String get clearFileClipboard;

  /// No description provided for @openedDirectoriesCount.
  ///
  /// In zh, this message translates to:
  /// **'已打开 {count} 个目录'**
  String openedDirectoriesCount(int count);

  /// No description provided for @unpinSidebar.
  ///
  /// In zh, this message translates to:
  /// **'取消固定侧边栏'**
  String get unpinSidebar;

  /// No description provided for @pinSidebar.
  ///
  /// In zh, this message translates to:
  /// **'固定侧边栏'**
  String get pinSidebar;

  /// No description provided for @openOrCreateEncryptedDirectory.
  ///
  /// In zh, this message translates to:
  /// **'打开或创建加密目录'**
  String get openOrCreateEncryptedDirectory;

  /// No description provided for @noOpenedDirectories.
  ///
  /// In zh, this message translates to:
  /// **'还没有打开目录\\n\\n选择“打开或创建加密目录”开始使用'**
  String get noOpenedDirectories;

  /// No description provided for @properties.
  ///
  /// In zh, this message translates to:
  /// **'属性'**
  String get properties;

  /// No description provided for @changePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get changePassword;

  /// No description provided for @setAlias.
  ///
  /// In zh, this message translates to:
  /// **'设置别名'**
  String get setAlias;

  /// No description provided for @clearAlias.
  ///
  /// In zh, this message translates to:
  /// **'清除别名'**
  String get clearAlias;

  /// No description provided for @directoryAliasTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置目录显示别名'**
  String get directoryAliasTitle;

  /// No description provided for @directoryAliasLabel.
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get directoryAliasLabel;

  /// No description provided for @directoryAliasHint.
  ///
  /// In zh, this message translates to:
  /// **'留空将恢复目录名'**
  String get directoryAliasHint;

  /// No description provided for @closeOrRemoveDirectory.
  ///
  /// In zh, this message translates to:
  /// **'关闭或移除目录'**
  String get closeOrRemoveDirectory;

  /// No description provided for @directoryUnlocked.
  ///
  /// In zh, this message translates to:
  /// **'已解锁'**
  String get directoryUnlocked;

  /// No description provided for @directoryNeedsPassword.
  ///
  /// In zh, this message translates to:
  /// **'需要密码'**
  String get directoryNeedsPassword;

  /// No description provided for @moreDirectoryActions.
  ///
  /// In zh, this message translates to:
  /// **'更多目录操作'**
  String get moreDirectoryActions;

  /// No description provided for @importFile.
  ///
  /// In zh, this message translates to:
  /// **'导入文件'**
  String get importFile;

  /// No description provided for @importDirectory.
  ///
  /// In zh, this message translates to:
  /// **'导入目录'**
  String get importDirectory;

  /// No description provided for @allFiles.
  ///
  /// In zh, this message translates to:
  /// **'所有文件'**
  String get allFiles;

  /// No description provided for @encryptedDirectoryCreated.
  ///
  /// In zh, this message translates to:
  /// **'加密目录创建成功'**
  String get encryptedDirectoryCreated;

  /// No description provided for @encryptedRootFound.
  ///
  /// In zh, this message translates to:
  /// **'已找到加密根目录：{path}'**
  String encryptedRootFound(String path);

  /// No description provided for @passwordVerified.
  ///
  /// In zh, this message translates to:
  /// **'密码验证成功'**
  String get passwordVerified;

  /// No description provided for @unfinishedStatesCleaned.
  ///
  /// In zh, this message translates to:
  /// **'已清理 {count} 个未完成状态'**
  String unfinishedStatesCleaned(int count);

  /// No description provided for @notepadFileTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件超过 {limit}，暂不支持用安全记事本打开。'**
  String notepadFileTooLarge(String limit);

  /// No description provided for @nativeContentWindowUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前平台尚未启用原生内容窗口，已在主窗口打开'**
  String get nativeContentWindowUnavailable;

  /// No description provided for @batchMove.
  ///
  /// In zh, this message translates to:
  /// **'批量移动'**
  String get batchMove;

  /// No description provided for @batchPaste.
  ///
  /// In zh, this message translates to:
  /// **'批量粘贴'**
  String get batchPaste;

  /// No description provided for @movedToDestination.
  ///
  /// In zh, this message translates to:
  /// **'已移动：{name}'**
  String movedToDestination(String name);

  /// No description provided for @pastedToDestination.
  ///
  /// In zh, this message translates to:
  /// **'已粘贴：{name}'**
  String pastedToDestination(String name);

  /// No description provided for @batchPasteCancelled.
  ///
  /// In zh, this message translates to:
  /// **'批量粘贴已取消：成功 {success} 个，剩余 {remaining} 个可重试'**
  String batchPasteCancelled(int success, int remaining);

  /// No description provided for @movedFiles.
  ///
  /// In zh, this message translates to:
  /// **'已移动 {count} 个文件'**
  String movedFiles(int count);

  /// No description provided for @pastedFiles.
  ///
  /// In zh, this message translates to:
  /// **'已粘贴 {count} 个文件'**
  String pastedFiles(int count);

  /// No description provided for @noEncryptedClipboardEntries.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板中没有可粘贴的加密条目'**
  String get noEncryptedClipboardEntries;

  /// No description provided for @cannotPasteDirectoryIntoItself.
  ///
  /// In zh, this message translates to:
  /// **'目录不能粘贴到自身或其子目录'**
  String get cannotPasteDirectoryIntoItself;

  /// No description provided for @directoryCreated.
  ///
  /// In zh, this message translates to:
  /// **'目录已创建：{name}'**
  String directoryCreated(String name);

  /// No description provided for @fileCreated.
  ///
  /// In zh, this message translates to:
  /// **'文件已创建：{name}'**
  String fileCreated(String name);

  /// No description provided for @renamedTo.
  ///
  /// In zh, this message translates to:
  /// **'已重命名为：{name}'**
  String renamedTo(String name);

  /// No description provided for @confirmDeleteFile.
  ///
  /// In zh, this message translates to:
  /// **'确认删除文件'**
  String get confirmDeleteFile;

  /// No description provided for @confirmDeleteFileDescription.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除“{name}”吗？此操作无法撤销。'**
  String confirmDeleteFileDescription(String name);

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @fileDeleted.
  ///
  /// In zh, this message translates to:
  /// **'文件已删除'**
  String get fileDeleted;

  /// No description provided for @fileImportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'文件导入成功：{name}'**
  String fileImportCompleted(String name);

  /// No description provided for @fileExportCompleted.
  ///
  /// In zh, this message translates to:
  /// **'文件导出成功：{path}'**
  String fileExportCompleted(String path);

  /// No description provided for @confirmPlaintextExport.
  ///
  /// In zh, this message translates to:
  /// **'确认导出明文'**
  String get confirmPlaintextExport;

  /// No description provided for @confirmPlaintextExportDescription.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”将以未加密形式写入你选择的位置。导出后的副本不再受 Safe Disk 保护，是否继续？'**
  String confirmPlaintextExportDescription(String name);

  /// No description provided for @continueExport.
  ///
  /// In zh, this message translates to:
  /// **'继续导出'**
  String get continueExport;

  /// No description provided for @copiedNameToSystemClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已将明文名称复制到系统剪贴板'**
  String get copiedNameToSystemClipboard;

  /// No description provided for @copiedPathToSystemClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已将明文逻辑路径复制到系统剪贴板'**
  String get copiedPathToSystemClipboard;

  /// No description provided for @copiedForPaste.
  ///
  /// In zh, this message translates to:
  /// **'已复制“{name}”，请选择目标目录粘贴'**
  String copiedForPaste(String name);

  /// No description provided for @cutForMove.
  ///
  /// In zh, this message translates to:
  /// **'已剪切“{name}”，请选择目标目录移动'**
  String cutForMove(String name);

  /// No description provided for @copiedManyForPaste.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {count} 个文件，请选择目标目录粘贴'**
  String copiedManyForPaste(int count);

  /// No description provided for @cutManyForMove.
  ///
  /// In zh, this message translates to:
  /// **'已剪切 {count} 个文件，请选择目标目录移动'**
  String cutManyForMove(int count);

  /// No description provided for @unlockDirectoryPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码以解锁：'**
  String get unlockDirectoryPrompt;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @directoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'目录：{name}'**
  String directoryLabel(String name);

  /// No description provided for @passwordChangeDescription.
  ///
  /// In zh, this message translates to:
  /// **'修改后需要用新密码重新打开目录。已有内容无需重新加密。'**
  String get passwordChangeDescription;

  /// No description provided for @currentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPassword;

  /// No description provided for @passwordChangeFieldsRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码和新密码'**
  String get passwordChangeFieldsRequired;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @rootDirectoryActions.
  ///
  /// In zh, this message translates to:
  /// **'目录操作'**
  String get rootDirectoryActions;

  /// No description provided for @endSessionOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅结束会话'**
  String get endSessionOnly;

  /// No description provided for @endSessionDescription.
  ///
  /// In zh, this message translates to:
  /// **'锁定“{name}”，保留侧边栏历史和磁盘目录'**
  String endSessionDescription(String name);

  /// No description provided for @directoryAlreadyLocked.
  ///
  /// In zh, this message translates to:
  /// **'当前目录已经锁定'**
  String get directoryAlreadyLocked;

  /// No description provided for @endSessionAndRemoveHistory.
  ///
  /// In zh, this message translates to:
  /// **'结束会话并移除历史'**
  String get endSessionAndRemoveHistory;

  /// No description provided for @removeHistoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'只从侧边栏移除，本地磁盘目录保持不变'**
  String get removeHistoryDescription;

  /// No description provided for @endSessionRemoveHistoryAndDelete.
  ///
  /// In zh, this message translates to:
  /// **'结束会话、移除历史并删除目录'**
  String get endSessionRemoveHistoryAndDelete;

  /// No description provided for @deleteDirectoryDescription.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本地加密目录及全部内容，无法撤销'**
  String get deleteDirectoryDescription;

  /// No description provided for @permanentlyDeleteLocalDirectory.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本地目录'**
  String get permanentlyDeleteLocalDirectory;

  /// No description provided for @willPermanentlyDelete.
  ///
  /// In zh, this message translates to:
  /// **'将永久删除：'**
  String get willPermanentlyDelete;

  /// No description provided for @enterDirectoryNameToConfirm.
  ///
  /// In zh, this message translates to:
  /// **'请输入目录名“{name}”确认：'**
  String enterDirectoryNameToConfirm(String name);

  /// No description provided for @permanentlyDeleteDirectory.
  ///
  /// In zh, this message translates to:
  /// **'永久删除目录'**
  String get permanentlyDeleteDirectory;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @rootDirectoryProperties.
  ///
  /// In zh, this message translates to:
  /// **'加密目录属性'**
  String get rootDirectoryProperties;

  /// No description provided for @displayName.
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get displayName;

  /// No description provided for @diskPath.
  ///
  /// In zh, this message translates to:
  /// **'磁盘路径'**
  String get diskPath;

  /// No description provided for @currentStatus.
  ///
  /// In zh, this message translates to:
  /// **'当前状态'**
  String get currentStatus;

  /// No description provided for @directoryLocked.
  ///
  /// In zh, this message translates to:
  /// **'已锁定'**
  String get directoryLocked;

  /// No description provided for @directoryFormat.
  ///
  /// In zh, this message translates to:
  /// **'目录格式'**
  String get directoryFormat;

  /// No description provided for @dataEncryption.
  ///
  /// In zh, this message translates to:
  /// **'数据加密'**
  String get dataEncryption;

  /// No description provided for @fileNameEncryption.
  ///
  /// In zh, this message translates to:
  /// **'文件名加密'**
  String get fileNameEncryption;

  /// No description provided for @nameEncryption.
  ///
  /// In zh, this message translates to:
  /// **'名称加密'**
  String get nameEncryption;

  /// No description provided for @passwordDerivation.
  ///
  /// In zh, this message translates to:
  /// **'密码派生'**
  String get passwordDerivation;

  /// No description provided for @passwordVerification.
  ///
  /// In zh, this message translates to:
  /// **'密码验证'**
  String get passwordVerification;

  /// No description provided for @versionValue.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String versionValue(int version);

  /// No description provided for @unavailableOrLegacy.
  ///
  /// In zh, this message translates to:
  /// **'不可用或旧格式'**
  String get unavailableOrLegacy;

  /// No description provided for @passwordChange.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get passwordChange;

  /// No description provided for @passwordChangeDirectly.
  ///
  /// In zh, this message translates to:
  /// **'可直接修改'**
  String get passwordChangeDirectly;

  /// No description provided for @passwordChangeMigrationRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要迁移'**
  String get passwordChangeMigrationRequired;

  /// No description provided for @rootPropertiesSensitiveNotice.
  ///
  /// In zh, this message translates to:
  /// **'不会显示密码、密钥或其他敏感信息。'**
  String get rootPropertiesSensitiveNotice;

  /// No description provided for @directory.
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get directory;

  /// No description provided for @status.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get status;

  /// No description provided for @directoryCannotChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'此目录不能直接修改密码'**
  String get directoryCannotChangePassword;

  /// No description provided for @reason.
  ///
  /// In zh, this message translates to:
  /// **'原因'**
  String get reason;

  /// No description provided for @legacyPasswordChangeReason.
  ///
  /// In zh, this message translates to:
  /// **'此目录使用较早的加密格式。直接修改密码会导致已有内容无法读取。'**
  String get legacyPasswordChangeReason;

  /// No description provided for @safeApproach.
  ///
  /// In zh, this message translates to:
  /// **'安全做法'**
  String get safeApproach;

  /// No description provided for @legacyPasswordChangeApproach.
  ///
  /// In zh, this message translates to:
  /// **'使用新密码创建一个加密目录，再导出并导入需要保留的内容。'**
  String get legacyPasswordChangeApproach;

  /// No description provided for @createEncryptedDirectory.
  ///
  /// In zh, this message translates to:
  /// **'创建加密目录'**
  String get createEncryptedDirectory;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get confirmPassword;

  /// No description provided for @showPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get hidePassword;

  /// No description provided for @allowFuturePasswordChange.
  ///
  /// In zh, this message translates to:
  /// **'允许以后修改密码'**
  String get allowFuturePasswordChange;

  /// No description provided for @allowFuturePasswordChangeHint.
  ///
  /// In zh, this message translates to:
  /// **'推荐：不重加密已有文件即可修改密码'**
  String get allowFuturePasswordChangeHint;

  /// No description provided for @advancedEncryptionParameters.
  ///
  /// In zh, this message translates to:
  /// **'高级加密参数'**
  String get advancedEncryptionParameters;

  /// No description provided for @advancedEncryptionParametersHint.
  ///
  /// In zh, this message translates to:
  /// **'默认配置适合大多数用户'**
  String get advancedEncryptionParametersHint;

  /// No description provided for @derivationStrength.
  ///
  /// In zh, this message translates to:
  /// **'派生强度'**
  String get derivationStrength;

  /// No description provided for @durationMilliseconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 毫秒'**
  String durationMilliseconds(int count);

  /// No description provided for @noEncryption.
  ///
  /// In zh, this message translates to:
  /// **'不加密（None）'**
  String get noEncryption;

  /// No description provided for @unencryptedNamesWarning.
  ///
  /// In zh, this message translates to:
  /// **'注意：选择“不加密（None）”后，文件名和目录名不会加密。'**
  String get unencryptedNamesWarning;

  /// No description provided for @selectDirectory.
  ///
  /// In zh, this message translates to:
  /// **'选择目录'**
  String get selectDirectory;

  /// No description provided for @directoryPath.
  ///
  /// In zh, this message translates to:
  /// **'目录路径'**
  String get directoryPath;

  /// No description provided for @directoryPathHint.
  ///
  /// In zh, this message translates to:
  /// **'输入目录路径或浏览选择'**
  String get directoryPathHint;

  /// No description provided for @browse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get browse;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @confirmDirectoryRemoval.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDirectoryRemoval;

  /// No description provided for @removeEncryptedDirectoryFromSidebar.
  ///
  /// In zh, this message translates to:
  /// **'您即将从侧边栏移除加密目录：'**
  String get removeEncryptedDirectoryFromSidebar;

  /// No description provided for @chooseAnAction.
  ///
  /// In zh, this message translates to:
  /// **'请选择操作：'**
  String get chooseAnAction;

  /// No description provided for @removeFromSidebarOnlyDescription.
  ///
  /// In zh, this message translates to:
  /// **'• 仅从侧边栏移除：保留磁盘目录和加密文件'**
  String get removeFromSidebarOnlyDescription;

  /// No description provided for @deleteDirectoryFromDiskDescription.
  ///
  /// In zh, this message translates to:
  /// **'• 同时删除磁盘目录：永久删除目录及所有文件'**
  String get deleteDirectoryFromDiskDescription;

  /// No description provided for @removeOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅移除'**
  String get removeOnly;

  /// No description provided for @deleteDiskDirectory.
  ///
  /// In zh, this message translates to:
  /// **'删除磁盘目录'**
  String get deleteDiskDirectory;

  /// No description provided for @argon2TimeCost.
  ///
  /// In zh, this message translates to:
  /// **'Argon2 时间成本'**
  String get argon2TimeCost;

  /// No description provided for @argon2MemoryCost.
  ///
  /// In zh, this message translates to:
  /// **'Argon2 内存成本'**
  String get argon2MemoryCost;

  /// No description provided for @argon2Parallelism.
  ///
  /// In zh, this message translates to:
  /// **'Argon2 并行度'**
  String get argon2Parallelism;

  /// No description provided for @argon2KeyLength.
  ///
  /// In zh, this message translates to:
  /// **'Argon2 密钥长度'**
  String get argon2KeyLength;

  /// No description provided for @pbkdf2Iterations.
  ///
  /// In zh, this message translates to:
  /// **'PBKDF2 迭代次数'**
  String get pbkdf2Iterations;

  /// No description provided for @pbkdf2KeyLength.
  ///
  /// In zh, this message translates to:
  /// **'PBKDF2 密钥长度'**
  String get pbkdf2KeyLength;

  /// No description provided for @scryptN.
  ///
  /// In zh, this message translates to:
  /// **'scrypt N'**
  String get scryptN;

  /// No description provided for @scryptR.
  ///
  /// In zh, this message translates to:
  /// **'scrypt r'**
  String get scryptR;

  /// No description provided for @scryptP.
  ///
  /// In zh, this message translates to:
  /// **'scrypt p'**
  String get scryptP;

  /// No description provided for @scryptKeyLength.
  ///
  /// In zh, this message translates to:
  /// **'scrypt 密钥长度'**
  String get scryptKeyLength;

  /// No description provided for @propertyLabel.
  ///
  /// In zh, this message translates to:
  /// **'{label}：'**
  String propertyLabel(String label);

  /// No description provided for @copyPropertyValue.
  ///
  /// In zh, this message translates to:
  /// **'复制{label}'**
  String copyPropertyValue(String label);

  /// No description provided for @propertyValueCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制属性值'**
  String get propertyValueCopied;

  /// No description provided for @filterCurrentDirectoryHint.
  ///
  /// In zh, this message translates to:
  /// **'筛选当前目录的文件和文件夹…'**
  String get filterCurrentDirectoryHint;

  /// No description provided for @filterLoadedItemsHint.
  ///
  /// In zh, this message translates to:
  /// **'仅筛选已加载条目；继续加载可扩大范围'**
  String get filterLoadedItemsHint;

  /// No description provided for @navigateUp.
  ///
  /// In zh, this message translates to:
  /// **'返回上级目录'**
  String get navigateUp;

  /// No description provided for @directoryIncompleteSummary.
  ///
  /// In zh, this message translates to:
  /// **'已加载 {count} 项（{folders} 个文件夹，{files} 个文件）'**
  String directoryIncompleteSummary(int count, int folders, int files);

  /// No description provided for @directorySummary.
  ///
  /// In zh, this message translates to:
  /// **'{folders} 个文件夹，{files} 个文件'**
  String directorySummary(int folders, int files);

  /// No description provided for @sortUnavailableUntilFullyLoaded.
  ///
  /// In zh, this message translates to:
  /// **'目录尚未完整加载，暂不可排序'**
  String get sortUnavailableUntilFullyLoaded;

  /// No description provided for @sortTooltip.
  ///
  /// In zh, this message translates to:
  /// **'排序：{order}'**
  String sortTooltip(String order);

  /// No description provided for @sortNameAscending.
  ///
  /// In zh, this message translates to:
  /// **'名称：A 到 Z'**
  String get sortNameAscending;

  /// No description provided for @sortNameDescending.
  ///
  /// In zh, this message translates to:
  /// **'名称：Z 到 A'**
  String get sortNameDescending;

  /// No description provided for @sortModifiedNewest.
  ///
  /// In zh, this message translates to:
  /// **'修改时间：最新优先'**
  String get sortModifiedNewest;

  /// No description provided for @sortModifiedOldest.
  ///
  /// In zh, this message translates to:
  /// **'修改时间：最早优先'**
  String get sortModifiedOldest;

  /// No description provided for @sortSizeLargest.
  ///
  /// In zh, this message translates to:
  /// **'大小：最大优先'**
  String get sortSizeLargest;

  /// No description provided for @sortSizeSmallest.
  ///
  /// In zh, this message translates to:
  /// **'大小：最小优先'**
  String get sortSizeSmallest;

  /// No description provided for @closeCurrentDirectoryFilter.
  ///
  /// In zh, this message translates to:
  /// **'关闭当前目录筛选'**
  String get closeCurrentDirectoryFilter;

  /// No description provided for @filterCurrentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'筛选当前目录'**
  String get filterCurrentDirectory;

  /// No description provided for @hideDirectoryNavigator.
  ///
  /// In zh, this message translates to:
  /// **'隐藏目录导航'**
  String get hideDirectoryNavigator;

  /// No description provided for @showDirectoryNavigator.
  ///
  /// In zh, this message translates to:
  /// **'显示目录导航'**
  String get showDirectoryNavigator;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// No description provided for @gridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// No description provided for @directoryReadFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'读取目录失败，刷新后重试'**
  String get directoryReadFailedRetry;

  /// No description provided for @noMatchInLoadedEntries.
  ///
  /// In zh, this message translates to:
  /// **'已加载条目中没有匹配“{query}”的内容'**
  String noMatchInLoadedEntries(String query);

  /// No description provided for @noMatchInCurrentDirectory.
  ///
  /// In zh, this message translates to:
  /// **'当前目录没有匹配“{query}”的条目'**
  String noMatchInCurrentDirectory(String query);

  /// No description provided for @unloadedEntriesMayMatch.
  ///
  /// In zh, this message translates to:
  /// **'仍有未加载条目，可继续加载后再筛选'**
  String get unloadedEntriesMayMatch;

  /// No description provided for @currentDirectoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前目录为空'**
  String get currentDirectoryEmpty;

  /// No description provided for @loadMoreEntries.
  ///
  /// In zh, this message translates to:
  /// **'加载更多条目'**
  String get loadMoreEntries;

  /// No description provided for @loadMoreFailedRetry.
  ///
  /// In zh, this message translates to:
  /// **'加载更多失败，刷新后重试'**
  String get loadMoreFailedRetry;

  /// No description provided for @scrollToLoadMore.
  ///
  /// In zh, this message translates to:
  /// **'继续滚动以加载更多条目'**
  String get scrollToLoadMore;

  /// No description provided for @directoryItemCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个项目'**
  String directoryItemCount(int count);

  /// No description provided for @file.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get file;

  /// No description provided for @fileSystemEntrySemantics.
  ///
  /// In zh, this message translates to:
  /// **'{name}，{type}'**
  String fileSystemEntrySemantics(String name, String type);

  /// No description provided for @openDirectory.
  ///
  /// In zh, this message translates to:
  /// **'打开目录'**
  String get openDirectory;

  /// No description provided for @viewImage.
  ///
  /// In zh, this message translates to:
  /// **'查看图片'**
  String get viewImage;

  /// No description provided for @editWithSecureNotepad.
  ///
  /// In zh, this message translates to:
  /// **'使用安全记事本编辑'**
  String get editWithSecureNotepad;

  /// No description provided for @viewInNewWindow.
  ///
  /// In zh, this message translates to:
  /// **'在新窗口中查看'**
  String get viewInNewWindow;

  /// No description provided for @editInNewWindow.
  ///
  /// In zh, this message translates to:
  /// **'在新窗口中编辑'**
  String get editInNewWindow;

  /// No description provided for @select.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get select;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @cut.
  ///
  /// In zh, this message translates to:
  /// **'剪切'**
  String get cut;

  /// No description provided for @pasteIntoDirectory.
  ///
  /// In zh, this message translates to:
  /// **'粘贴到此目录'**
  String get pasteIntoDirectory;

  /// No description provided for @exportDirectory.
  ///
  /// In zh, this message translates to:
  /// **'导出目录'**
  String get exportDirectory;

  /// No description provided for @exportDecryptedFile.
  ///
  /// In zh, this message translates to:
  /// **'导出解密文件'**
  String get exportDecryptedFile;

  /// No description provided for @copyPlaintextName.
  ///
  /// In zh, this message translates to:
  /// **'复制名称（明文）'**
  String get copyPlaintextName;

  /// No description provided for @copyPlaintextLogicalPath.
  ///
  /// In zh, this message translates to:
  /// **'复制逻辑路径（明文）'**
  String get copyPlaintextLogicalPath;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @deleteFile.
  ///
  /// In zh, this message translates to:
  /// **'删除文件'**
  String get deleteFile;

  /// No description provided for @renameDirectory.
  ///
  /// In zh, this message translates to:
  /// **'重命名目录'**
  String get renameDirectory;

  /// No description provided for @renameFile.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件'**
  String get renameFile;

  /// No description provided for @newName.
  ///
  /// In zh, this message translates to:
  /// **'新名称'**
  String get newName;

  /// No description provided for @fileNameEmpty.
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空'**
  String get fileNameEmpty;

  /// No description provided for @fileNameLeadingOrTrailingWhitespace.
  ///
  /// In zh, this message translates to:
  /// **'名称不能以空格开头或结尾'**
  String get fileNameLeadingOrTrailingWhitespace;

  /// No description provided for @fileNameReserved.
  ///
  /// In zh, this message translates to:
  /// **'不能使用保留名称'**
  String get fileNameReserved;

  /// No description provided for @fileNameTrailingDot.
  ///
  /// In zh, this message translates to:
  /// **'名称不能以点结尾'**
  String get fileNameTrailingDot;

  /// No description provided for @fileNamePathSeparatorOrNull.
  ///
  /// In zh, this message translates to:
  /// **'名称不能包含路径分隔符或空字符'**
  String get fileNamePathSeparatorOrNull;

  /// No description provided for @fileNameUnsupportedCharacter.
  ///
  /// In zh, this message translates to:
  /// **'名称包含跨平台不支持的字符'**
  String get fileNameUnsupportedCharacter;

  /// No description provided for @fileNameReservedSystemName.
  ///
  /// In zh, this message translates to:
  /// **'该名称是系统保留名称'**
  String get fileNameReservedSystemName;

  /// No description provided for @fileNameTooLong.
  ///
  /// In zh, this message translates to:
  /// **'名称不能超过 255 个 UTF-8 字节'**
  String get fileNameTooLong;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// No description provided for @type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get type;

  /// No description provided for @size.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get size;

  /// No description provided for @modifiedTime.
  ///
  /// In zh, this message translates to:
  /// **'修改时间'**
  String get modifiedTime;

  /// No description provided for @logicalPath.
  ///
  /// In zh, this message translates to:
  /// **'逻辑路径'**
  String get logicalPath;

  /// No description provided for @fileTypeWithExtension.
  ///
  /// In zh, this message translates to:
  /// **'{extension} 文件'**
  String fileTypeWithExtension(String extension);

  /// No description provided for @newFile.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get newFile;

  /// No description provided for @newDirectory.
  ///
  /// In zh, this message translates to:
  /// **'新建目录'**
  String get newDirectory;

  /// No description provided for @newFileDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'新建文件.txt'**
  String get newFileDefaultName;

  /// No description provided for @newDirectoryDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'新建目录'**
  String get newDirectoryDefaultName;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @directoryTreeReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取目录树'**
  String get directoryTreeReadFailed;

  /// No description provided for @directoryTreeLoadMoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'继续读取失败'**
  String get directoryTreeLoadMoreFailed;

  /// No description provided for @readingDirectories.
  ///
  /// In zh, this message translates to:
  /// **'正在读取…'**
  String get readingDirectories;

  /// No description provided for @loadMoreDirectories.
  ///
  /// In zh, this message translates to:
  /// **'读取更多目录'**
  String get loadMoreDirectories;

  /// No description provided for @retryDirectoryTreeRead.
  ///
  /// In zh, this message translates to:
  /// **'{message}，刷新重试'**
  String retryDirectoryTreeRead(String message);

  /// No description provided for @importOperation.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importOperation;

  /// No description provided for @exportOperation.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get exportOperation;

  /// No description provided for @batchExportOperation.
  ///
  /// In zh, this message translates to:
  /// **'批量导出'**
  String get batchExportOperation;

  /// No description provided for @pasteOperation.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get pasteOperation;

  /// No description provided for @batchPasteOperation.
  ///
  /// In zh, this message translates to:
  /// **'批量粘贴'**
  String get batchPasteOperation;

  /// No description provided for @copySuffix.
  ///
  /// In zh, this message translates to:
  /// **'副本'**
  String get copySuffix;

  /// No description provided for @conflictTargetExists.
  ///
  /// In zh, this message translates to:
  /// **'目标已存在'**
  String get conflictTargetExists;

  /// No description provided for @conflictReplacementUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'源和目标类型不兼容，或源与目标是同一条目。请选择“保留两者”生成新名称。'**
  String get conflictReplacementUnavailable;

  /// No description provided for @conflictDirectoryReplaceDetail.
  ///
  /// In zh, this message translates to:
  /// **'选择“合并并替换”会保留目标目录独有的内容，并替换其中的同名文件。'**
  String get conflictDirectoryReplaceDetail;

  /// No description provided for @conflictFileReplaceDetail.
  ///
  /// In zh, this message translates to:
  /// **'选择“替换”会用新内容替换现有文件。'**
  String get conflictFileReplaceDetail;

  /// No description provided for @conflictDescription.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”已存在，无法直接{operation}。\n\n{detail}'**
  String conflictDescription(String name, String operation, String detail);

  /// No description provided for @keepBoth.
  ///
  /// In zh, this message translates to:
  /// **'保留两者'**
  String get keepBoth;

  /// No description provided for @keepBothForAll.
  ///
  /// In zh, this message translates to:
  /// **'全部保留两者'**
  String get keepBothForAll;

  /// No description provided for @mergeAndReplace.
  ///
  /// In zh, this message translates to:
  /// **'合并并替换'**
  String get mergeAndReplace;

  /// No description provided for @replace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get replace;

  /// No description provided for @replaceForAll.
  ///
  /// In zh, this message translates to:
  /// **'全部替换'**
  String get replaceForAll;

  /// No description provided for @batchOperationCancelled.
  ///
  /// In zh, this message translates to:
  /// **'{operation}已取消'**
  String batchOperationCancelled(String operation);

  /// No description provided for @batchOperationPartiallyCompleted.
  ///
  /// In zh, this message translates to:
  /// **'{operation}部分完成'**
  String batchOperationPartiallyCompleted(String operation);

  /// No description provided for @batchOperationCompleted.
  ///
  /// In zh, this message translates to:
  /// **'{operation}完成'**
  String batchOperationCompleted(String operation);

  /// No description provided for @batchTotal.
  ///
  /// In zh, this message translates to:
  /// **'总数：{count}'**
  String batchTotal(int count);

  /// No description provided for @batchSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'成功：{count}'**
  String batchSucceeded(int count);

  /// No description provided for @batchSkipped.
  ///
  /// In zh, this message translates to:
  /// **'跳过：{count}'**
  String batchSkipped(int count);

  /// No description provided for @batchFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败：{count}'**
  String batchFailed(int count);

  /// No description provided for @batchUnprocessed.
  ///
  /// In zh, this message translates to:
  /// **'未处理：{count}'**
  String batchUnprocessed(int count);

  /// No description provided for @batchClipboardRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板剩余：{count}'**
  String batchClipboardRemaining(int count);

  /// No description provided for @failureDetails.
  ///
  /// In zh, this message translates to:
  /// **'失败详情'**
  String get failureDetails;

  /// No description provided for @batchFailureItem.
  ///
  /// In zh, this message translates to:
  /// **'“{name}”：{reason}'**
  String batchFailureItem(String name, String reason);

  /// No description provided for @additionalFailures.
  ///
  /// In zh, this message translates to:
  /// **'另有 {count} 项失败'**
  String additionalFailures(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
