// ignore: unused_import
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
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @acknowledge.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get acknowledge;

  /// No description provided for @additionalFailures.
  ///
  /// In en, this message translates to:
  /// **'{count} more failures'**
  String additionalFailures(int count);

  /// No description provided for @advancedEncryptionParameters.
  ///
  /// In en, this message translates to:
  /// **'Advanced encryption parameters'**
  String get advancedEncryptionParameters;

  /// No description provided for @advancedEncryptionParametersHint.
  ///
  /// In en, this message translates to:
  /// **'The default configuration is suitable for most people.'**
  String get advancedEncryptionParametersHint;

  /// No description provided for @allFiles.
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get allFiles;

  /// No description provided for @allowFuturePasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Allow password changes later'**
  String get allowFuturePasswordChange;

  /// No description provided for @allowFuturePasswordChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended: change the password without re-encrypting existing files.'**
  String get allowFuturePasswordChangeHint;

  /// No description provided for @animatedImageFrames.
  ///
  /// In en, this message translates to:
  /// **'Animated ({count} frames)'**
  String animatedImageFrames(int count);

  /// No description provided for @antiScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Anti-screenshot'**
  String get antiScreenshot;

  /// No description provided for @antiScreenshotCountdownConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Save'**
  String get antiScreenshotCountdownConfirm;

  /// No description provided for @antiScreenshotCountdownHint.
  ///
  /// In en, this message translates to:
  /// **'The setting has been applied. If the screen becomes unusable, do nothing — it wi...'**
  String antiScreenshotCountdownHint(int countdown);

  /// No description provided for @antiScreenshotCountdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Anti-Screenshot Enabled'**
  String get antiScreenshotCountdownTitle;

  /// No description provided for @antiScreenshotEnvVarHint.
  ///
  /// In en, this message translates to:
  /// **'If anti-screenshot makes the app unusable, launch with environment variable SAFE...'**
  String get antiScreenshotEnvVarHint;

  /// No description provided for @antiScreenshotHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, screenshot tools and screen recording software cannot capture this...'**
  String get antiScreenshotHint;

  /// No description provided for @antiScreenshotInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'Anti-screenshot prevents system tools (PrintScreen, Snipping Tool, etc.) and rec...'**
  String get antiScreenshotInfoDescription;

  /// No description provided for @antiScreenshotInfoEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get antiScreenshotInfoEnable;

  /// No description provided for @antiScreenshotInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Anti-Screenshot?'**
  String get antiScreenshotInfoTitle;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe Disk'**
  String get appTitle;

  /// No description provided for @appVersionDescription.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0\nEncrypted file manager'**
  String get appVersionDescription;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @autoLockSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} directories could not be locked'**
  String autoLockSummaryFailed(int count);

  /// No description provided for @autoLockSummaryLocked.
  ///
  /// In en, this message translates to:
  /// **'{count} directories were locked automatically'**
  String autoLockSummaryLocked(int count);

  /// No description provided for @autoLockSummarySkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} directories have open file windows or pending saves and were left open'**
  String autoLockSummarySkipped(int count);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @batchClipboardRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining in clipboard: {count}'**
  String batchClipboardRemaining(int count);

  /// No description provided for @batchDelete.
  ///
  /// In en, this message translates to:
  /// **'Batch delete'**
  String get batchDelete;

  /// No description provided for @batchDeleteCancelled.
  ///
  /// In en, this message translates to:
  /// **'Batch deletion cancelled: {success} succeeded; {remaining} items remain selected...'**
  String batchDeleteCancelled(int success, int remaining);

  /// No description provided for @batchDeleteCompleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} files.'**
  String batchDeleteCompleted(int count);

  /// No description provided for @batchExport.
  ///
  /// In en, this message translates to:
  /// **'Batch export'**
  String get batchExport;

  /// No description provided for @batchExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled: {success} succeeded, {failed} failed.'**
  String batchExportCancelled(int success, int failed);

  /// No description provided for @batchExportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Export completed: {success} succeeded, {failed} failed.'**
  String batchExportCompleted(int success, int failed);

  /// No description provided for @batchExportCompletedAll.
  ///
  /// In en, this message translates to:
  /// **'Export completed: {count} files succeeded.'**
  String batchExportCompletedAll(int count);

  /// No description provided for @batchExportOperation.
  ///
  /// In en, this message translates to:
  /// **'batch export'**
  String get batchExportOperation;

  /// No description provided for @batchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {count}'**
  String batchFailed(int count);

  /// No description provided for @batchFailureItem.
  ///
  /// In en, this message translates to:
  /// **'"{name}": {reason}'**
  String batchFailureItem(String name, String reason);

  /// No description provided for @batchMove.
  ///
  /// In en, this message translates to:
  /// **'Batch move'**
  String get batchMove;

  /// No description provided for @batchOperationCancelled.
  ///
  /// In en, this message translates to:
  /// **'{operation} cancelled'**
  String batchOperationCancelled(String operation);

  /// No description provided for @batchOperationCompleted.
  ///
  /// In en, this message translates to:
  /// **'{operation} completed'**
  String batchOperationCompleted(String operation);

  /// No description provided for @batchOperationPartiallyCompleted.
  ///
  /// In en, this message translates to:
  /// **'{operation} partially completed'**
  String batchOperationPartiallyCompleted(String operation);

  /// No description provided for @batchPaste.
  ///
  /// In en, this message translates to:
  /// **'Batch paste'**
  String get batchPaste;

  /// No description provided for @batchPasteCancelled.
  ///
  /// In en, this message translates to:
  /// **'Batch paste cancelled: {success} succeeded; {remaining} items can be retried.'**
  String batchPasteCancelled(int success, int remaining);

  /// No description provided for @batchPasteOperation.
  ///
  /// In en, this message translates to:
  /// **'batch paste'**
  String get batchPasteOperation;

  /// No description provided for @batchSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped: {count}'**
  String batchSkipped(int count);

  /// No description provided for @batchSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded: {count}'**
  String batchSucceeded(int count);

  /// No description provided for @batchTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {count}'**
  String batchTotal(int count);

  /// No description provided for @batchUnprocessed.
  ///
  /// In en, this message translates to:
  /// **'Unprocessed: {count}'**
  String batchUnprocessed(int count);

  /// No description provided for @behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get behavior;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cannotPasteDirectoryIntoItself.
  ///
  /// In en, this message translates to:
  /// **'A directory cannot be pasted into itself or one of its subdirectories'**
  String get cannotPasteDirectoryIntoItself;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @chooseAnAction.
  ///
  /// In en, this message translates to:
  /// **'Choose an action:'**
  String get chooseAnAction;

  /// No description provided for @cleanState.
  ///
  /// In en, this message translates to:
  /// **'Clean unfinished operation'**
  String get cleanState;

  /// No description provided for @clearAlias.
  ///
  /// In en, this message translates to:
  /// **'Clear alias'**
  String get clearAlias;

  /// No description provided for @clearFileClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clear file clipboard'**
  String get clearFileClipboard;

  /// No description provided for @clipboardMovePending.
  ///
  /// In en, this message translates to:
  /// **'Move pending'**
  String get clipboardMovePending;

  /// No description provided for @clipboardMultipleEntries.
  ///
  /// In en, this message translates to:
  /// **'{name} and {count} items'**
  String clipboardMultipleEntries(String name, int count);

  /// No description provided for @clipboardPastePending.
  ///
  /// In en, this message translates to:
  /// **'Paste pending'**
  String get clipboardPastePending;

  /// No description provided for @clipboardStatusNarrow.
  ///
  /// In en, this message translates to:
  /// **'{operation} · {entries}'**
  String clipboardStatusNarrow(String operation, String entries);

  /// No description provided for @clipboardStatusWide.
  ///
  /// In en, this message translates to:
  /// **'{operation} · {entries} → {target}'**
  String clipboardStatusWide(String operation, String entries, String target);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeCurrentDirectoryFilter.
  ///
  /// In en, this message translates to:
  /// **'Close current directory filter'**
  String get closeCurrentDirectoryFilter;

  /// No description provided for @closeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Close directory'**
  String get closeDirectory;

  /// No description provided for @closeOrRemoveDirectory.
  ///
  /// In en, this message translates to:
  /// **'Close or remove directory'**
  String get closeOrRemoveDirectory;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get closeWindow;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmBatchDeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm batch deletion'**
  String get confirmBatchDeletion;

  /// No description provided for @confirmBatchDeletionDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} selected items? This cannot be undone. Items are deleted one at a...'**
  String confirmBatchDeletionDescription(int count);

  /// No description provided for @confirmBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm before deleting'**
  String get confirmBeforeDelete;

  /// No description provided for @confirmBeforeDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Show a confirmation dialog before deleting files.'**
  String get confirmBeforeDeleteHint;

  /// No description provided for @confirmDeleteFile.
  ///
  /// In en, this message translates to:
  /// **'Confirm file deletion'**
  String get confirmDeleteFile;

  /// No description provided for @confirmDeleteFileDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete "{name}"? This cannot be undone.'**
  String confirmDeleteFileDescription(String name);

  /// No description provided for @confirmDirectoryRemoval.
  ///
  /// In en, this message translates to:
  /// **'Confirm removal'**
  String get confirmDirectoryRemoval;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @confirmPlaintextExport.
  ///
  /// In en, this message translates to:
  /// **'Confirm plaintext export'**
  String get confirmPlaintextExport;

  /// No description provided for @confirmPlaintextExportDescription.
  ///
  /// In en, this message translates to:
  /// **'"{name}" will be written unencrypted to the selected location. The exported copy...'**
  String confirmPlaintextExportDescription(String name);

  /// No description provided for @conflictDescription.
  ///
  /// In en, this message translates to:
  /// **'"{name}" already exists and cannot be directly {operation}.\n\n{detail}'**
  String conflictDescription(String name, String operation, String detail);

  /// No description provided for @conflictDirectoryReplaceDetail.
  ///
  /// In en, this message translates to:
  /// **'Merge and replace keeps content unique to the destination directory and replaces...'**
  String get conflictDirectoryReplaceDetail;

  /// No description provided for @conflictFileReplaceDetail.
  ///
  /// In en, this message translates to:
  /// **'Replace overwrites the existing file with the new content.'**
  String get conflictFileReplaceDetail;

  /// No description provided for @conflictReplacementUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The source and destination types are incompatible, or they are the same entry. C...'**
  String get conflictReplacementUnavailable;

  /// No description provided for @conflictTargetExists.
  ///
  /// In en, this message translates to:
  /// **'Destination already exists'**
  String get conflictTargetExists;

  /// No description provided for @contentFileSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'The file size cannot be determined, so it cannot be opened safely.'**
  String get contentFileSizeUnknown;

  /// No description provided for @contentWindowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to main window'**
  String get contentWindowUnavailable;

  /// No description provided for @contentWindowUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The document session may have ended. To avoid editing an invalid session, close ...'**
  String get contentWindowUnavailableDescription;

  /// No description provided for @continueExport.
  ///
  /// In en, this message translates to:
  /// **'Continue export'**
  String get continueExport;

  /// No description provided for @copiedForPaste.
  ///
  /// In en, this message translates to:
  /// **'Copied "{name}". Select a destination directory to paste.'**
  String copiedForPaste(String name);

  /// No description provided for @copiedManyForPaste.
  ///
  /// In en, this message translates to:
  /// **'Copied {count} files. Select a destination directory to paste.'**
  String copiedManyForPaste(int count);

  /// No description provided for @copiedNameToSystemClipboard.
  ///
  /// In en, this message translates to:
  /// **'Plaintext name copied to the system clipboard'**
  String get copiedNameToSystemClipboard;

  /// No description provided for @copiedPathToSystemClipboard.
  ///
  /// In en, this message translates to:
  /// **'Plaintext logical path copied to the system clipboard'**
  String get copiedPathToSystemClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyPlaintextLogicalPath.
  ///
  /// In en, this message translates to:
  /// **'Copy logical path (plaintext)'**
  String get copyPlaintextLogicalPath;

  /// No description provided for @copyPlaintextName.
  ///
  /// In en, this message translates to:
  /// **'Copy name (plaintext)'**
  String get copyPlaintextName;

  /// No description provided for @copyPropertyValue.
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String copyPropertyValue(String label);

  /// No description provided for @copySelected.
  ///
  /// In en, this message translates to:
  /// **'Copy selected'**
  String get copySelected;

  /// No description provided for @copySuffix.
  ///
  /// In en, this message translates to:
  /// **'copy'**
  String get copySuffix;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createEncryptedDirectory.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted directory'**
  String get createEncryptedDirectory;

  /// No description provided for @currentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Current directory'**
  String get currentDirectory;

  /// No description provided for @currentDirectoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'This directory is empty'**
  String get currentDirectoryEmpty;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @currentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get currentStatus;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @cutForMove.
  ///
  /// In en, this message translates to:
  /// **'Cut "{name}". Select a destination directory to move it.'**
  String cutForMove(String name);

  /// No description provided for @cutManyForMove.
  ///
  /// In en, this message translates to:
  /// **'Cut {count} files. Select a destination directory to move them.'**
  String cutManyForMove(int count);

  /// No description provided for @cutSelected.
  ///
  /// In en, this message translates to:
  /// **'Cut selected'**
  String get cutSelected;

  /// No description provided for @dataEncryption.
  ///
  /// In en, this message translates to:
  /// **'Data encryption'**
  String get dataEncryption;

  /// No description provided for @defaultNewDirectoryKdfProfile.
  ///
  /// In en, this message translates to:
  /// **'Default derivation profile for new directories'**
  String get defaultNewDirectoryKdfProfile;

  /// No description provided for @defaultNewDirectoryKdfProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Only affects directories created later; it has not been calibrated for this devi...'**
  String get defaultNewDirectoryKdfProfileHint;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete the local encrypted directory and all its contents. This cann...'**
  String get deleteDirectoryDescription;

  /// No description provided for @deleteDirectoryFromDiskDescription.
  ///
  /// In en, this message translates to:
  /// **'• Also delete the disk directory: permanently delete the directory and all files'**
  String get deleteDirectoryFromDiskDescription;

  /// No description provided for @deleteDiskDirectory.
  ///
  /// In en, this message translates to:
  /// **'Delete disk directory'**
  String get deleteDiskDirectory;

  /// No description provided for @deleteFile.
  ///
  /// In en, this message translates to:
  /// **'Delete file'**
  String get deleteFile;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @derivationStrength.
  ///
  /// In en, this message translates to:
  /// **'Derivation strength'**
  String get derivationStrength;

  /// No description provided for @derivationStrengthUncalibratedHint.
  ///
  /// In en, this message translates to:
  /// **'This is a preset profile and has not been calibrated for this device.'**
  String get derivationStrengthUncalibratedHint;

  /// No description provided for @detailedErrors.
  ///
  /// In en, this message translates to:
  /// **'Show detailed error information'**
  String get detailedErrors;

  /// No description provided for @detailedErrorsHint.
  ///
  /// In en, this message translates to:
  /// **'Show redacted operation stages and underlying errors in error prompts. No disk l...'**
  String get detailedErrorsHint;

  /// No description provided for @directory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get directory;

  /// No description provided for @directoryAliasHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to restore the directory name'**
  String get directoryAliasHint;

  /// No description provided for @directoryAliasLabel.
  ///
  /// In en, this message translates to:
  /// **'Alias'**
  String get directoryAliasLabel;

  /// No description provided for @directoryAliasTitle.
  ///
  /// In en, this message translates to:
  /// **'Set directory display alias'**
  String get directoryAliasTitle;

  /// No description provided for @directoryAlreadyLocked.
  ///
  /// In en, this message translates to:
  /// **'This directory is already locked.'**
  String get directoryAlreadyLocked;

  /// No description provided for @directoryCannotChangePassword.
  ///
  /// In en, this message translates to:
  /// **'This directory cannot change its password directly.'**
  String get directoryCannotChangePassword;

  /// No description provided for @directoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Directory created: {name}'**
  String directoryCreated(String name);

  /// No description provided for @directoryExportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} files.'**
  String directoryExportCompleted(int count);

  /// No description provided for @directoryFormat.
  ///
  /// In en, this message translates to:
  /// **'Directory format'**
  String get directoryFormat;

  /// No description provided for @directoryImportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} files.'**
  String directoryImportCompleted(int count);

  /// No description provided for @directoryIncompleteSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} loaded ({folders} folders, {files} files)'**
  String directoryIncompleteSummary(int count, int folders, int files);

  /// No description provided for @directoryItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String directoryItemCount(int count);

  /// No description provided for @directoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Directory: {name}'**
  String directoryLabel(String name);

  /// No description provided for @directoryLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get directoryLocked;

  /// No description provided for @directoryNeedsPassword.
  ///
  /// In en, this message translates to:
  /// **'Password required'**
  String get directoryNeedsPassword;

  /// No description provided for @directoryPath.
  ///
  /// In en, this message translates to:
  /// **'Directory path'**
  String get directoryPath;

  /// No description provided for @directoryPathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a directory path or browse to select one'**
  String get directoryPathHint;

  /// No description provided for @directoryReadFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not read directory. Refresh and try again.'**
  String get directoryReadFailedRetry;

  /// No description provided for @directorySummary.
  ///
  /// In en, this message translates to:
  /// **'{folders} folders, {files} files'**
  String directorySummary(int folders, int files);

  /// No description provided for @directoryTreeLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more directories'**
  String get directoryTreeLoadMoreFailed;

  /// No description provided for @directoryTreeReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read directory tree'**
  String get directoryTreeReadFailed;

  /// No description provided for @directoryUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get directoryUnlocked;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get disabled;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @diskPath.
  ///
  /// In en, this message translates to:
  /// **'Disk path'**
  String get diskPath;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @dropImportHere.
  ///
  /// In en, this message translates to:
  /// **'Drop to import into the current encrypted directory'**
  String get dropImportHere;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day} other{{count} days}}'**
  String durationDays(int count);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 hour} other{{count} hours}}'**
  String durationHours(int count);

  /// No description provided for @durationMilliseconds.
  ///
  /// In en, this message translates to:
  /// **'{count} ms'**
  String durationMilliseconds(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 minute} other{{count} minutes}}'**
  String durationMinutes(int count);

  /// No description provided for @durationNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get durationNever;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 second} other{{count} seconds}}'**
  String durationSeconds(int count);

  /// No description provided for @editInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'Edit in new window'**
  String get editInNewWindow;

  /// No description provided for @editWithSecureNotepad.
  ///
  /// In en, this message translates to:
  /// **'Edit with Secure Notepad'**
  String get editWithSecureNotepad;

  /// No description provided for @encryptedDirectoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Encrypted directory created'**
  String get encryptedDirectoryCreated;

  /// No description provided for @encryptedRootFound.
  ///
  /// In en, this message translates to:
  /// **'The current path is inside an encrypted directory: {path}'**
  String encryptedRootFound(String path);

  /// No description provided for @endSessionAndRemoveHistory.
  ///
  /// In en, this message translates to:
  /// **'End session and remove history'**
  String get endSessionAndRemoveHistory;

  /// No description provided for @endSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'Lock "{name}" and keep its sidebar history and disk directory.'**
  String endSessionDescription(String name);

  /// No description provided for @endSessionOnly.
  ///
  /// In en, this message translates to:
  /// **'End session only'**
  String get endSessionOnly;

  /// No description provided for @endSessionRemoveHistoryAndDelete.
  ///
  /// In en, this message translates to:
  /// **'End session, remove history, and delete directory'**
  String get endSessionRemoveHistoryAndDelete;

  /// No description provided for @enterDirectoryNameToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter the directory name "{name}" to confirm:'**
  String enterDirectoryNameToConfirm(String name);

  /// No description provided for @errorCreateEncryptedDirectoryFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'A new encrypted directory could not be created.'**
  String get errorCreateEncryptedDirectoryFailedDescription;

  /// No description provided for @errorCreateEncryptedDirectoryFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check directory permissions and available disk space, then try again.'**
  String get errorCreateEncryptedDirectoryFailedSuggestion;

  /// No description provided for @errorCreateEncryptedDirectoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not create encrypted directory'**
  String get errorCreateEncryptedDirectoryFailedTitle;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'A new encrypted directory can only be created in a missing or empty directory.'**
  String get errorCreateEncryptedDirectoryRequiresEmptyDescription;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Choose a new path or an empty directory. Use import for existing content.'**
  String get errorCreateEncryptedDirectoryRequiresEmptySuggestion;

  /// No description provided for @errorCreateEncryptedDirectoryRequiresEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Directory is not empty'**
  String get errorCreateEncryptedDirectoryRequiresEmptyTitle;

  /// No description provided for @errorDeleteFileFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file could not be deleted.'**
  String get errorDeleteFileFailedDescription;

  /// No description provided for @errorDeleteFileFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check whether the file is in use, then try again.'**
  String get errorDeleteFileFailedSuggestion;

  /// No description provided for @errorDeleteFileFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not delete file'**
  String get errorDeleteFileFailedTitle;

  /// No description provided for @errorDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Error details copied'**
  String get errorDetailsCopied;

  /// No description provided for @errorDiagnosticOperation.
  ///
  /// In en, this message translates to:
  /// **'Operation: {operation}'**
  String errorDiagnosticOperation(String operation);

  /// No description provided for @errorDiagnosticPathRedacted.
  ///
  /// In en, this message translates to:
  /// **'[path redacted]'**
  String get errorDiagnosticPathRedacted;

  /// No description provided for @errorDiagnosticRedacted.
  ///
  /// In en, this message translates to:
  /// **'[redacted]'**
  String get errorDiagnosticRedacted;

  /// No description provided for @errorDiagnosticTruncated.
  ///
  /// In en, this message translates to:
  /// **'[details truncated]'**
  String get errorDiagnosticTruncated;

  /// No description provided for @errorDiagnosticType.
  ///
  /// In en, this message translates to:
  /// **'Error type: {type}'**
  String errorDiagnosticType(String type);

  /// No description provided for @errorDirectoryNotExistDescription.
  ///
  /// In en, this message translates to:
  /// **'The selected directory does not exist or was deleted.'**
  String get errorDirectoryNotExistDescription;

  /// No description provided for @errorDirectoryNotExistSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check the directory path or choose another directory.'**
  String get errorDirectoryNotExistSuggestion;

  /// No description provided for @errorDirectoryNotExistTitle.
  ///
  /// In en, this message translates to:
  /// **'Directory not found'**
  String get errorDirectoryNotExistTitle;

  /// No description provided for @errorDirectoryNotVerifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the password to unlock this encrypted directory before working with files.'**
  String get errorDirectoryNotVerifiedDescription;

  /// No description provided for @errorDirectoryNotVerifiedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Select the directory in the sidebar, then enter its password.'**
  String get errorDirectoryNotVerifiedSuggestion;

  /// No description provided for @errorDirectoryNotVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock directory first'**
  String get errorDirectoryNotVerifiedTitle;

  /// No description provided for @errorExportDirectoryFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The directory could not be exported to the selected location.'**
  String get errorExportDirectoryFailedDescription;

  /// No description provided for @errorExportDirectoryFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check that the destination is writable, then try again.'**
  String get errorExportDirectoryFailedSuggestion;

  /// No description provided for @errorExportDirectoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not export directory'**
  String get errorExportDirectoryFailedTitle;

  /// No description provided for @errorExportFileFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file could not be exported to the selected location.'**
  String get errorExportFileFailedDescription;

  /// No description provided for @errorExportFileFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check that the destination is writable, then try again.'**
  String get errorExportFileFailedSuggestion;

  /// No description provided for @errorExportFileFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not export file'**
  String get errorExportFileFailedTitle;

  /// No description provided for @errorImportDirectoryFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The directory could not be imported into the encrypted directory.'**
  String get errorImportDirectoryFailedDescription;

  /// No description provided for @errorImportDirectoryFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check source permissions, symbolic links, and the destination directory state, t...'**
  String get errorImportDirectoryFailedSuggestion;

  /// No description provided for @errorImportDirectoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not import directory'**
  String get errorImportDirectoryFailedTitle;

  /// No description provided for @errorImportDirectoryInsideCurrentRootDescription.
  ///
  /// In en, this message translates to:
  /// **'A subdirectory of the current encrypted directory cannot be imported into the cu...'**
  String get errorImportDirectoryInsideCurrentRootDescription;

  /// No description provided for @errorImportDirectoryInsideCurrentRootSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Choose a source directory outside the encrypted directory.'**
  String get errorImportDirectoryInsideCurrentRootSuggestion;

  /// No description provided for @errorImportDirectoryInsideCurrentRootTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot import this directory'**
  String get errorImportDirectoryInsideCurrentRootTitle;

  /// No description provided for @errorImportFileFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file could not be imported into the encrypted directory.'**
  String get errorImportFileFailedDescription;

  /// No description provided for @errorImportFileFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check that the file exists and is readable, then try again.'**
  String get errorImportFileFailedSuggestion;

  /// No description provided for @errorImportFileFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not import file'**
  String get errorImportFileFailedTitle;

  /// No description provided for @errorInvalidPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'The password cannot decrypt this directory.'**
  String get errorInvalidPasswordDescription;

  /// No description provided for @errorInvalidPasswordSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check the password, including letter case.'**
  String get errorInvalidPasswordSuggestion;

  /// No description provided for @errorInvalidPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get errorInvalidPasswordTitle;

  /// No description provided for @errorLoadConfigFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The encrypted directory configuration could not be read.'**
  String get errorLoadConfigFailedDescription;

  /// No description provided for @errorLoadConfigFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check that the directory is complete and was not modified by another program.'**
  String get errorLoadConfigFailedSuggestion;

  /// No description provided for @errorLoadConfigFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load configuration'**
  String get errorLoadConfigFailedTitle;

  /// No description provided for @errorLoadDirectoryFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The directory contents could not be read.'**
  String get errorLoadDirectoryFailedDescription;

  /// No description provided for @errorLoadDirectoryFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check directory permissions or try opening it again.'**
  String get errorLoadDirectoryFailedSuggestion;

  /// No description provided for @errorLoadDirectoryFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load directory'**
  String get errorLoadDirectoryFailedTitle;

  /// No description provided for @errorLoadFileFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file contents could not be read.'**
  String get errorLoadFileFailedDescription;

  /// No description provided for @errorLoadFileFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check that the file exists and is readable.'**
  String get errorLoadFileFailedSuggestion;

  /// No description provided for @errorLoadFileFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load file'**
  String get errorLoadFileFailedTitle;

  /// No description provided for @errorNoDirectorySelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a directory first.'**
  String get errorNoDirectorySelectedDescription;

  /// No description provided for @errorNoDirectorySelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No directory selected'**
  String get errorNoDirectorySelectedTitle;

  /// No description provided for @errorNoFileSelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Select a file first.'**
  String get errorNoFileSelectedDescription;

  /// No description provided for @errorNoFileSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get errorNoFileSelectedTitle;

  /// No description provided for @errorNotEncryptedDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'The selected directory is not a recognized Safe Disk encrypted directory.'**
  String get errorNotEncryptedDirectoryDescription;

  /// No description provided for @errorNotEncryptedDirectorySuggestion.
  ///
  /// In en, this message translates to:
  /// **'Choose an existing encrypted directory or create a new one.'**
  String get errorNotEncryptedDirectorySuggestion;

  /// No description provided for @errorNotEncryptedDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot open directory'**
  String get errorNotEncryptedDirectoryTitle;

  /// No description provided for @errorOperationFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The operation did not finish. Try again later.'**
  String get errorOperationFailedDescription;

  /// No description provided for @errorOperationFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'If the problem continues, contact support.'**
  String get errorOperationFailedSuggestion;

  /// No description provided for @errorOperationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get errorOperationFailedTitle;

  /// No description provided for @errorPasswordEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a password to continue.'**
  String get errorPasswordEmptyDescription;

  /// No description provided for @errorPasswordEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get errorPasswordEmptyTitle;

  /// No description provided for @errorPasswordMismatchDescription.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are different.'**
  String get errorPasswordMismatchDescription;

  /// No description provided for @errorPasswordMismatchSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Make sure both password entries are identical.'**
  String get errorPasswordMismatchSuggestion;

  /// No description provided for @errorPasswordMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorPasswordMismatchTitle;

  /// No description provided for @errorPathEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a directory path.'**
  String get errorPathEmptyDescription;

  /// No description provided for @errorPathEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Path is required'**
  String get errorPathEmptyTitle;

  /// No description provided for @errorSaveFileFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file changes could not be saved.'**
  String get errorSaveFileFailedDescription;

  /// No description provided for @errorSaveFileFailedSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check disk space and permissions, then try again.'**
  String get errorSaveFileFailedSuggestion;

  /// No description provided for @errorSaveFileFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not save file'**
  String get errorSaveFileFailedTitle;

  /// No description provided for @errorSessionExpiredDescription.
  ///
  /// In en, this message translates to:
  /// **'The directory session has ended and must be unlocked again.'**
  String get errorSessionExpiredDescription;

  /// No description provided for @errorSessionExpiredSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Select the directory in the sidebar and enter the password again.'**
  String get errorSessionExpiredSuggestion;

  /// No description provided for @errorSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Directory is locked'**
  String get errorSessionExpiredTitle;

  /// No description provided for @errorSuggestionPrefix.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: '**
  String get errorSuggestionPrefix;

  /// No description provided for @errorUnfinishedTransferStateUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'Safe Disk could not safely read the unfinished import or export state, so this d...'**
  String get errorUnfinishedTransferStateUnavailableDescription;

  /// No description provided for @errorUnfinishedTransferStateUnavailableSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check directory permissions and disk status. Keep the directory unchanged and tr...'**
  String get errorUnfinishedTransferStateUnavailableSuggestion;

  /// No description provided for @errorUnfinishedTransferStateUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot verify unfinished transfer state'**
  String get errorUnfinishedTransferStateUnavailableTitle;

  /// No description provided for @exitSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Exit selection mode'**
  String get exitSelectionMode;

  /// No description provided for @exportDecryptedFile.
  ///
  /// In en, this message translates to:
  /// **'Export decrypted file'**
  String get exportDecryptedFile;

  /// No description provided for @exportDirectory.
  ///
  /// In en, this message translates to:
  /// **'Export directory'**
  String get exportDirectory;

  /// No description provided for @exportOperation.
  ///
  /// In en, this message translates to:
  /// **'export'**
  String get exportOperation;

  /// No description provided for @exportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export selected'**
  String get exportSelected;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get exporting;

  /// No description provided for @exposeToThirdParty.
  ///
  /// In en, this message translates to:
  /// **'Expose to third-party tool'**
  String get exposeToThirdParty;

  /// No description provided for @failureDetails.
  ///
  /// In en, this message translates to:
  /// **'Failure details'**
  String get failureDetails;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @fileClipboard.
  ///
  /// In en, this message translates to:
  /// **'File clipboard'**
  String get fileClipboard;

  /// No description provided for @fileCreated.
  ///
  /// In en, this message translates to:
  /// **'File created: {name}'**
  String fileCreated(String name);

  /// No description provided for @fileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get fileDeleted;

  /// No description provided for @fileExportCompleted.
  ///
  /// In en, this message translates to:
  /// **'File exported: {path}'**
  String fileExportCompleted(String path);

  /// No description provided for @fileImportCompleted.
  ///
  /// In en, this message translates to:
  /// **'File imported: {name}'**
  String fileImportCompleted(String name);

  /// No description provided for @fileNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'A name is required'**
  String get fileNameEmpty;

  /// No description provided for @fileNameEncryption.
  ///
  /// In en, this message translates to:
  /// **'File name encryption'**
  String get fileNameEncryption;

  /// No description provided for @fileNameLeadingOrTrailingWhitespace.
  ///
  /// In en, this message translates to:
  /// **'A name cannot start or end with whitespace'**
  String get fileNameLeadingOrTrailingWhitespace;

  /// No description provided for @fileNamePathSeparatorOrNull.
  ///
  /// In en, this message translates to:
  /// **'A name cannot contain a path separator or null character'**
  String get fileNamePathSeparatorOrNull;

  /// No description provided for @fileNameReserved.
  ///
  /// In en, this message translates to:
  /// **'This reserved name cannot be used'**
  String get fileNameReserved;

  /// No description provided for @fileNameReservedSystemName.
  ///
  /// In en, this message translates to:
  /// **'This is a reserved system name'**
  String get fileNameReservedSystemName;

  /// No description provided for @fileNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'A name cannot exceed 255 UTF-8 bytes'**
  String get fileNameTooLong;

  /// No description provided for @fileNameTrailingDot.
  ///
  /// In en, this message translates to:
  /// **'A name cannot end with a dot'**
  String get fileNameTrailingDot;

  /// No description provided for @fileNameUnsupportedCharacter.
  ///
  /// In en, this message translates to:
  /// **'A name contains characters unsupported across platforms'**
  String get fileNameUnsupportedCharacter;

  /// No description provided for @fileSystemEntrySemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type}'**
  String fileSystemEntrySemantics(String name, String type);

  /// No description provided for @fileTypeWithExtension.
  ///
  /// In en, this message translates to:
  /// **'{extension} file'**
  String fileTypeWithExtension(String extension);

  /// No description provided for @filterCurrentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Filter current directory'**
  String get filterCurrentDirectory;

  /// No description provided for @filterCurrentDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Filter files and folders in the current directory...'**
  String get filterCurrentDirectoryHint;

  /// No description provided for @filterLoadedItemsHint.
  ///
  /// In en, this message translates to:
  /// **'Only loaded entries are filtered. Load more to expand the scope.'**
  String get filterLoadedItemsHint;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @hideDirectoryNavigator.
  ///
  /// In en, this message translates to:
  /// **'Hide directory navigator'**
  String get hideDirectoryNavigator;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @hidePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Hide password hint'**
  String get hidePasswordHint;

  /// No description provided for @imageContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'The image content is empty.'**
  String get imageContentEmpty;

  /// No description provided for @imageDecodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot display image'**
  String get imageDecodeFailed;

  /// No description provided for @imageDecodeFailedDescription.
  ///
  /// In en, this message translates to:
  /// **'The file may be damaged or use an unsupported image format.'**
  String get imageDecodeFailedDescription;

  /// No description provided for @imageDecodedPixelLimit.
  ///
  /// In en, this message translates to:
  /// **'Decoded image dimensions exceed the {limit} limit.'**
  String imageDecodedPixelLimit(String limit);

  /// No description provided for @imageDimensionsInvalid.
  ///
  /// In en, this message translates to:
  /// **'The image dimensions are invalid.'**
  String get imageDimensionsInvalid;

  /// No description provided for @imageEncodedSizeLimit.
  ///
  /// In en, this message translates to:
  /// **'Encoded image data exceeds the {limit} limit.'**
  String imageEncodedSizeLimit(String limit);

  /// No description provided for @imageEncryptedContentInvalid.
  ///
  /// In en, this message translates to:
  /// **'The encrypted image data could not be read. It may be invalid.'**
  String get imageEncryptedContentInvalid;

  /// No description provided for @imageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get imageLoadFailed;

  /// No description provided for @importDirectory.
  ///
  /// In en, this message translates to:
  /// **'Import directory'**
  String get importDirectory;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get importFile;

  /// No description provided for @importOperation.
  ///
  /// In en, this message translates to:
  /// **'import'**
  String get importOperation;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importing;

  /// No description provided for @initializationStage.
  ///
  /// In en, this message translates to:
  /// **'Initialization stage: {stage}'**
  String initializationStage(String stage);

  /// No description provided for @kdfProfileBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced (recommended)'**
  String get kdfProfileBalanced;

  /// No description provided for @kdfProfileFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get kdfProfileFast;

  /// No description provided for @kdfProfileMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get kdfProfileMaximum;

  /// No description provided for @kdfProfileStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get kdfProfileStrong;

  /// No description provided for @keepBoth.
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// No description provided for @keepBothForAll.
  ///
  /// In en, this message translates to:
  /// **'Keep both for all'**
  String get keepBothForAll;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'The language is previewed immediately and is kept after saving.'**
  String get languagePreviewHint;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @legacyPasswordChangeApproach.
  ///
  /// In en, this message translates to:
  /// **'Create an encrypted directory with a new password, then export and import the co...'**
  String get legacyPasswordChangeApproach;

  /// No description provided for @legacyPasswordChangeReason.
  ///
  /// In en, this message translates to:
  /// **'This directory uses an older encryption format. Changing its password directly w...'**
  String get legacyPasswordChangeReason;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @loadMoreDirectories.
  ///
  /// In en, this message translates to:
  /// **'Load more directories'**
  String get loadMoreDirectories;

  /// No description provided for @loadMoreEntries.
  ///
  /// In en, this message translates to:
  /// **'Load more entries'**
  String get loadMoreEntries;

  /// No description provided for @loadMoreFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load more entries. Refresh and try again.'**
  String get loadMoreFailedRetry;

  /// No description provided for @loadingImage.
  ///
  /// In en, this message translates to:
  /// **'Loading image'**
  String get loadingImage;

  /// No description provided for @lockAfterIdle.
  ///
  /// In en, this message translates to:
  /// **'Lock after inactivity'**
  String get lockAfterIdle;

  /// No description provided for @lockAfterIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Lock the current directory after its idle timeout. Directories with open file wi...'**
  String get lockAfterIdleHint;

  /// No description provided for @lockWhenHidden.
  ///
  /// In en, this message translates to:
  /// **'Lock when the app is hidden'**
  String get lockWhenHidden;

  /// No description provided for @lockWhenHiddenHint.
  ///
  /// In en, this message translates to:
  /// **'Only lock directories without open file windows, unsaved changes, or active save...'**
  String get lockWhenHiddenHint;

  /// No description provided for @logicalPath.
  ///
  /// In en, this message translates to:
  /// **'Logical path'**
  String get logicalPath;

  /// No description provided for @managePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Manage password hint'**
  String get managePasswordHint;

  /// No description provided for @mergeAndReplace.
  ///
  /// In en, this message translates to:
  /// **'Merge and replace'**
  String get mergeAndReplace;

  /// No description provided for @messageListSeparator.
  ///
  /// In en, this message translates to:
  /// **'; '**
  String get messageListSeparator;

  /// No description provided for @modifiedTime.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get modifiedTime;

  /// No description provided for @moreBatchActions.
  ///
  /// In en, this message translates to:
  /// **'More batch actions'**
  String get moreBatchActions;

  /// No description provided for @moreDirectoryActions.
  ///
  /// In en, this message translates to:
  /// **'More directory actions'**
  String get moreDirectoryActions;

  /// No description provided for @moveDirectoryDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDirectoryDown;

  /// No description provided for @moveDirectoryUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveDirectoryUp;

  /// No description provided for @moveSourceDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The target was copied, but the source entry could not be deleted. Both entries w...'**
  String get moveSourceDeleteFailed;

  /// No description provided for @moveToCurrentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Move to current directory'**
  String get moveToCurrentDirectory;

  /// No description provided for @movedFiles.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} files'**
  String movedFiles(int count);

  /// No description provided for @movedToDestination.
  ///
  /// In en, this message translates to:
  /// **'Moved: {name}'**
  String movedToDestination(String name);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameEncryption.
  ///
  /// In en, this message translates to:
  /// **'Name encryption'**
  String get nameEncryption;

  /// No description provided for @nativeBindingFailureDescription.
  ///
  /// In en, this message translates to:
  /// **'The security component version does not match this app, so encryption cannot sta...'**
  String get nativeBindingFailureDescription;

  /// No description provided for @nativeBindingFailureSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Reinstall the matching version of Safe Disk, then try again.'**
  String get nativeBindingFailureSuggestion;

  /// No description provided for @nativeComponentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Security component unavailable'**
  String get nativeComponentUnavailable;

  /// No description provided for @nativeContentWindowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Separate file windows are unavailable on this platform. Opened in the main windo...'**
  String get nativeContentWindowUnavailable;

  /// No description provided for @nativeLoadingFailureDescription.
  ///
  /// In en, this message translates to:
  /// **'Safe Disk could not load its security component, so encrypted directories cannot...'**
  String get nativeLoadingFailureDescription;

  /// No description provided for @nativeLoadingFailureSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Reinstall the app. If the problem continues, check whether security software qua...'**
  String get nativeLoadingFailureSuggestion;

  /// No description provided for @navigateUp.
  ///
  /// In en, this message translates to:
  /// **'Go up'**
  String get navigateUp;

  /// No description provided for @newDirectory.
  ///
  /// In en, this message translates to:
  /// **'New directory'**
  String get newDirectory;

  /// No description provided for @newDirectoryDefaultName.
  ///
  /// In en, this message translates to:
  /// **'New directory'**
  String get newDirectoryDefaultName;

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFile;

  /// No description provided for @newFileDefaultName.
  ///
  /// In en, this message translates to:
  /// **'New file.txt'**
  String get newFileDefaultName;

  /// No description provided for @newName.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get newName;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The new passwords do not match.'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @nextImageShortcut.
  ///
  /// In en, this message translates to:
  /// **'Next image (Right)'**
  String get nextImageShortcut;

  /// No description provided for @noDisplayableImage.
  ///
  /// In en, this message translates to:
  /// **'No displayable image. Choose another image or try again.'**
  String get noDisplayableImage;

  /// No description provided for @noEncryptedClipboardEntries.
  ///
  /// In en, this message translates to:
  /// **'There are no encrypted entries to paste in the file clipboard'**
  String get noEncryptedClipboardEntries;

  /// No description provided for @noEncryption.
  ///
  /// In en, this message translates to:
  /// **'No encryption'**
  String get noEncryption;

  /// No description provided for @noMatchInCurrentDirectory.
  ///
  /// In en, this message translates to:
  /// **'No entries in this directory match "{query}"'**
  String noMatchInCurrentDirectory(String query);

  /// No description provided for @noMatchInLoadedEntries.
  ///
  /// In en, this message translates to:
  /// **'No loaded entries match "{query}"'**
  String noMatchInLoadedEntries(String query);

  /// No description provided for @noOpenedDirectories.
  ///
  /// In en, this message translates to:
  /// **'No directories are open yet.\n\nSelect "Open or create encrypted directory" to g...'**
  String get noOpenedDirectories;

  /// No description provided for @notepadBinaryContent.
  ///
  /// In en, this message translates to:
  /// **'The file contains binary content and cannot be opened in Secure Notepad.'**
  String get notepadBinaryContent;

  /// No description provided for @notepadCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String notepadCharacterCount(int count);

  /// No description provided for @notepadClearClipboard.
  ///
  /// In en, this message translates to:
  /// **'Clear system clipboard'**
  String get notepadClearClipboard;

  /// No description provided for @notepadClipboardClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to clear the clipboard. Try again.'**
  String get notepadClipboardClearFailed;

  /// No description provided for @notepadClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No short text in the clipboard'**
  String get notepadClipboardEmpty;

  /// No description provided for @notepadClipboardMonitor.
  ///
  /// In en, this message translates to:
  /// **'Clipboard monitor'**
  String get notepadClipboardMonitor;

  /// No description provided for @notepadClipboardReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the clipboard. Try again.'**
  String get notepadClipboardReadFailed;

  /// No description provided for @notepadCloseFind.
  ///
  /// In en, this message translates to:
  /// **'Close find'**
  String get notepadCloseFind;

  /// No description provided for @notepadDefaultReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Open notes read-only'**
  String get notepadDefaultReadOnly;

  /// No description provided for @notepadDefaultReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'New files open read-only. You can start editing manually.'**
  String get notepadDefaultReadOnlyHint;

  /// No description provided for @notepadDiscardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get notepadDiscardDraft;

  /// No description provided for @notepadDontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get notepadDontSave;

  /// No description provided for @notepadDraftCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'The original file was saved, but the old draft could not be removed.'**
  String get notepadDraftCleanupFailed;

  /// No description provided for @notepadDraftDiscardFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the recovery draft.'**
  String get notepadDraftDiscardFailed;

  /// No description provided for @notepadDraftInterval.
  ///
  /// In en, this message translates to:
  /// **'Secure draft save interval'**
  String get notepadDraftInterval;

  /// No description provided for @notepadDraftIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Periodically save an encrypted draft beside the original file without overwritin...'**
  String get notepadDraftIntervalHint;

  /// No description provided for @notepadDraftReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check the recovery draft.'**
  String get notepadDraftReadFailed;

  /// No description provided for @notepadDraftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save recovery draft'**
  String get notepadDraftSaveFailed;

  /// No description provided for @notepadDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Recovery draft saved'**
  String get notepadDraftSaved;

  /// No description provided for @notepadEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get notepadEditing;

  /// No description provided for @notepadFileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get notepadFileSaved;

  /// No description provided for @notepadFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file exceeds {limit} and cannot be opened in Secure Notepad.'**
  String notepadFileTooLarge(String limit);

  /// No description provided for @notepadFindHint.
  ///
  /// In en, this message translates to:
  /// **'Find (\\n means newline)'**
  String get notepadFindHint;

  /// No description provided for @notepadFindNext.
  ///
  /// In en, this message translates to:
  /// **'Find next'**
  String get notepadFindNext;

  /// No description provided for @notepadFindPosition.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total}'**
  String notepadFindPosition(int current, int total);

  /// No description provided for @notepadFindPrevious.
  ///
  /// In en, this message translates to:
  /// **'Find previous'**
  String get notepadFindPrevious;

  /// No description provided for @notepadFindReplace.
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get notepadFindReplace;

  /// No description provided for @notepadLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the file. Check that it exists and is readable, then try again.'**
  String get notepadLoadFailed;

  /// No description provided for @notepadMonitorClipboard.
  ///
  /// In en, this message translates to:
  /// **'Monitor clipboard by default'**
  String get notepadMonitorClipboard;

  /// No description provided for @notepadMonitorClipboardAction.
  ///
  /// In en, this message translates to:
  /// **'Monitor clipboard'**
  String get notepadMonitorClipboardAction;

  /// No description provided for @notepadMonitorClipboardHint.
  ///
  /// In en, this message translates to:
  /// **'Only show a text preview; do not write it to files or settings.'**
  String get notepadMonitorClipboardHint;

  /// No description provided for @notepadNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches found'**
  String get notepadNoMatches;

  /// No description provided for @notepadReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get notepadReadOnly;

  /// No description provided for @notepadRecoveryDraftDescription.
  ///
  /// In en, this message translates to:
  /// **'An encrypted draft from an unfinished edit was found. Restore it to the editor?'**
  String get notepadRecoveryDraftDescription;

  /// No description provided for @notepadRecoveryDraftFound.
  ///
  /// In en, this message translates to:
  /// **'Secure draft found'**
  String get notepadRecoveryDraftFound;

  /// No description provided for @notepadRedoShortcut.
  ///
  /// In en, this message translates to:
  /// **'Redo (Ctrl/Cmd+Shift+Z)'**
  String get notepadRedoShortcut;

  /// No description provided for @notepadRefreshClipboard.
  ///
  /// In en, this message translates to:
  /// **'Refresh clipboard now'**
  String get notepadRefreshClipboard;

  /// No description provided for @notepadReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get notepadReplace;

  /// No description provided for @notepadReplaceAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get notepadReplaceAll;

  /// No description provided for @notepadReplacedCount.
  ///
  /// In en, this message translates to:
  /// **'Replaced {count} matches'**
  String notepadReplacedCount(int count);

  /// No description provided for @notepadRestoreDraft.
  ///
  /// In en, this message translates to:
  /// **'Restore draft'**
  String get notepadRestoreDraft;

  /// No description provided for @notepadSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get notepadSave;

  /// No description provided for @notepadSaveBeforeClosing.
  ///
  /// In en, this message translates to:
  /// **'Save changes before closing?'**
  String get notepadSaveBeforeClosing;

  /// No description provided for @notepadSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get notepadSaveFailed;

  /// No description provided for @notepadSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get notepadSaved;

  /// No description provided for @notepadSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get notepadSaving;

  /// No description provided for @notepadSavingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving recovery draft'**
  String get notepadSavingDraft;

  /// No description provided for @notepadSelectMatchFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a match first'**
  String get notepadSelectMatchFirst;

  /// No description provided for @notepadStartEditing.
  ///
  /// In en, this message translates to:
  /// **'Start editing'**
  String get notepadStartEditing;

  /// No description provided for @notepadStopClipboardMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Stop clipboard monitoring'**
  String get notepadStopClipboardMonitoring;

  /// No description provided for @notepadSwitchReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Switch to read-only'**
  String get notepadSwitchReadOnly;

  /// No description provided for @notepadUndoShortcut.
  ///
  /// In en, this message translates to:
  /// **'Undo (Ctrl/Cmd+Z)'**
  String get notepadUndoShortcut;

  /// No description provided for @notepadUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get notepadUnsaved;

  /// No description provided for @notepadUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get notepadUnsavedChanges;

  /// No description provided for @openDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open directory'**
  String get openDirectory;

  /// No description provided for @openMode.
  ///
  /// In en, this message translates to:
  /// **'Open items with'**
  String get openMode;

  /// No description provided for @openModeDoubleClick.
  ///
  /// In en, this message translates to:
  /// **'Double click'**
  String get openModeDoubleClick;

  /// No description provided for @openModeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how files and folders open'**
  String get openModeHint;

  /// No description provided for @openModeSingleClick.
  ///
  /// In en, this message translates to:
  /// **'Single click'**
  String get openModeSingleClick;

  /// No description provided for @openOrCreateEncryptedDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open or create encrypted directory'**
  String get openOrCreateEncryptedDirectory;

  /// No description provided for @openedDirectoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} directories open'**
  String openedDirectoriesCount(int count);

  /// No description provided for @operationNotCancellableYet.
  ///
  /// In en, this message translates to:
  /// **'This operation cannot be cancelled yet.'**
  String get operationNotCancellableYet;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordChange.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get passwordChange;

  /// No description provided for @passwordChangeBlockedByDocuments.
  ///
  /// In en, this message translates to:
  /// **'Close or save this directory\'s open file windows before changing its password.'**
  String get passwordChangeBlockedByDocuments;

  /// No description provided for @passwordChangeBlockedBySaving.
  ///
  /// In en, this message translates to:
  /// **'This directory is saving content. Wait for the save to finish before changing it...'**
  String get passwordChangeBlockedBySaving;

  /// No description provided for @passwordChangeDescription.
  ///
  /// In en, this message translates to:
  /// **'After changing the password, reopen the directory with the new password. Existin...'**
  String get passwordChangeDescription;

  /// No description provided for @passwordChangeDirectly.
  ///
  /// In en, this message translates to:
  /// **'Can change directly'**
  String get passwordChangeDirectly;

  /// No description provided for @passwordChangeFieldsRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the current password and a new password.'**
  String get passwordChangeFieldsRequired;

  /// No description provided for @passwordChangeMigrationRequired.
  ///
  /// In en, this message translates to:
  /// **'Migration required'**
  String get passwordChangeMigrationRequired;

  /// No description provided for @passwordChangedUnlockAgain.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Unlock the directory again with the new password.'**
  String get passwordChangedUnlockAgain;

  /// No description provided for @passwordDerivation.
  ///
  /// In en, this message translates to:
  /// **'Password derivation'**
  String get passwordDerivation;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password hint'**
  String get passwordHint;

  /// No description provided for @passwordHintCreationNotice.
  ///
  /// In en, this message translates to:
  /// **'Helps you remember the password. Anyone with access to this directory can see it...'**
  String get passwordHintCreationNotice;

  /// No description provided for @passwordHintEditNotice.
  ///
  /// In en, this message translates to:
  /// **'Enter a new hint, or leave it empty to clear it. Anyone with access to this dire...'**
  String get passwordHintEditNotice;

  /// No description provided for @passwordHintNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get passwordHintNotSet;

  /// No description provided for @passwordHintPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the current password to update the password hint.'**
  String get passwordHintPasswordRequired;

  /// No description provided for @passwordHintPublicNotice.
  ///
  /// In en, this message translates to:
  /// **'Anyone with access to this directory can see this hint. It cannot recover your p...'**
  String get passwordHintPublicNotice;

  /// No description provided for @passwordHintTooLong.
  ///
  /// In en, this message translates to:
  /// **'Password hints are limited to 256 bytes.'**
  String get passwordHintTooLong;

  /// No description provided for @passwordHintUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password hint updated.'**
  String get passwordHintUpdated;

  /// No description provided for @passwordVerification.
  ///
  /// In en, this message translates to:
  /// **'Password verification'**
  String get passwordVerification;

  /// No description provided for @passwordVerified.
  ///
  /// In en, this message translates to:
  /// **'Password verified'**
  String get passwordVerified;

  /// No description provided for @pasteIntoDirectory.
  ///
  /// In en, this message translates to:
  /// **'Paste into this directory'**
  String get pasteIntoDirectory;

  /// No description provided for @pasteOperation.
  ///
  /// In en, this message translates to:
  /// **'paste'**
  String get pasteOperation;

  /// No description provided for @pasteToCurrentDirectory.
  ///
  /// In en, this message translates to:
  /// **'Paste to current directory'**
  String get pasteToCurrentDirectory;

  /// No description provided for @pastedFiles.
  ///
  /// In en, this message translates to:
  /// **'Pasted {count} files'**
  String pastedFiles(int count);

  /// No description provided for @pastedToDestination.
  ///
  /// In en, this message translates to:
  /// **'Pasted: {name}'**
  String pastedToDestination(String name);

  /// No description provided for @permanentlyDeleteDirectory.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete directory'**
  String get permanentlyDeleteDirectory;

  /// No description provided for @permanentlyDeleteLocalDirectory.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete local directory'**
  String get permanentlyDeleteLocalDirectory;

  /// No description provided for @pinSidebar.
  ///
  /// In en, this message translates to:
  /// **'Pin sidebar'**
  String get pinSidebar;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get preparing;

  /// No description provided for @preparingCannotCancel.
  ///
  /// In en, this message translates to:
  /// **'Preparing; cancellation is unavailable...'**
  String get preparingCannotCancel;

  /// No description provided for @preparingDelete.
  ///
  /// In en, this message translates to:
  /// **'Preparing deletion...'**
  String get preparingDelete;

  /// No description provided for @preparingExport.
  ///
  /// In en, this message translates to:
  /// **'Preparing export...'**
  String get preparingExport;

  /// No description provided for @preparingImport.
  ///
  /// In en, this message translates to:
  /// **'Preparing import...'**
  String get preparingImport;

  /// No description provided for @previousImageShortcut.
  ///
  /// In en, this message translates to:
  /// **'Previous image (Left)'**
  String get previousImageShortcut;

  /// No description provided for @progressCurrentFile.
  ///
  /// In en, this message translates to:
  /// **'Current: {name}'**
  String progressCurrentFile(String name);

  /// No description provided for @progressEstimatedRemaining.
  ///
  /// In en, this message translates to:
  /// **'Estimated remaining: {duration}'**
  String progressEstimatedRemaining(String duration);

  /// No description provided for @progressMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} sec'**
  String progressMinutesSeconds(int minutes, int seconds);

  /// No description provided for @progressProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed: {current} / {total}'**
  String progressProcessed(int current, int total);

  /// No description provided for @properties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// No description provided for @propertyLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}:'**
  String propertyLabel(String label);

  /// No description provided for @propertyValueCopied.
  ///
  /// In en, this message translates to:
  /// **'Property value copied'**
  String get propertyValueCopied;

  /// No description provided for @readingDirectories.
  ///
  /// In en, this message translates to:
  /// **'Reading directories...'**
  String get readingDirectories;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @removeEncryptedDirectoryFromSidebar.
  ///
  /// In en, this message translates to:
  /// **'You are about to remove this encrypted directory from the sidebar:'**
  String get removeEncryptedDirectoryFromSidebar;

  /// No description provided for @removeFromSidebarOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'• Remove from sidebar only: keep the disk directory and encrypted files'**
  String get removeFromSidebarOnlyDescription;

  /// No description provided for @removeHistoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove only from the sidebar; keep the local disk directory unchanged.'**
  String get removeHistoryDescription;

  /// No description provided for @removeOnly.
  ///
  /// In en, this message translates to:
  /// **'Remove only'**
  String get removeOnly;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Rename directory'**
  String get renameDirectory;

  /// No description provided for @renameFile.
  ///
  /// In en, this message translates to:
  /// **'Rename file'**
  String get renameFile;

  /// No description provided for @renamedTo.
  ///
  /// In en, this message translates to:
  /// **'Renamed to: {name}'**
  String renamedTo(String name);

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @replaceForAll.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get replaceForAll;

  /// No description provided for @rerunAll.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get rerunAll;

  /// No description provided for @rerunUnfinishedTransfers.
  ///
  /// In en, this message translates to:
  /// **'Run unfinished imports and exports again'**
  String get rerunUnfinishedTransfers;

  /// No description provided for @rerunningUnfinishedProgress.
  ///
  /// In en, this message translates to:
  /// **'Running again: {current} of {total}...'**
  String rerunningUnfinishedProgress(int current, int total);

  /// No description provided for @resetImageViewShortcut.
  ///
  /// In en, this message translates to:
  /// **'Reset view (N)'**
  String get resetImageViewShortcut;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore defaults (not saved)'**
  String get restoreDefaults;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @retryDirectoryTreeRead.
  ///
  /// In en, this message translates to:
  /// **'{message}. Refresh and try again.'**
  String retryDirectoryTreeRead(String message);

  /// No description provided for @rootActiveWritesDescription.
  ///
  /// In en, this message translates to:
  /// **'{count} file save operations are still running. Wait for them to finish before e...'**
  String rootActiveWritesDescription(int count);

  /// No description provided for @rootActiveWritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving content'**
  String get rootActiveWritesTitle;

  /// No description provided for @rootDirectoryActions.
  ///
  /// In en, this message translates to:
  /// **'Directory actions'**
  String get rootDirectoryActions;

  /// No description provided for @rootDirectoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Encrypted directory permanently deleted'**
  String get rootDirectoryDeleted;

  /// No description provided for @rootDirectoryProperties.
  ///
  /// In en, this message translates to:
  /// **'Encrypted directory properties'**
  String get rootDirectoryProperties;

  /// No description provided for @rootHistoryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Directory history removed. Files on disk were kept.'**
  String get rootHistoryRemoved;

  /// No description provided for @rootPropertiesSensitiveNotice.
  ///
  /// In en, this message translates to:
  /// **'Passwords, keys, and other sensitive information are not shown.'**
  String get rootPropertiesSensitiveNotice;

  /// No description provided for @rootUnsavedContentDescription.
  ///
  /// In en, this message translates to:
  /// **'Handle these open file windows before ending the session:\n\n{documents}'**
  String rootUnsavedContentDescription(String documents);

  /// No description provided for @rootUnsavedContentTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved content'**
  String get rootUnsavedContentTitle;

  /// No description provided for @rotateClockwiseShortcut.
  ///
  /// In en, this message translates to:
  /// **'Rotate clockwise (R)'**
  String get rotateClockwiseShortcut;

  /// No description provided for @safeApproach.
  ///
  /// In en, this message translates to:
  /// **'Safe approach'**
  String get safeApproach;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndReturn.
  ///
  /// In en, this message translates to:
  /// **'Save and return'**
  String get saveAndReturn;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save settings changes?'**
  String get saveChanges;

  /// No description provided for @savePasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Save hint'**
  String get savePasswordHint;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get saveSettings;

  /// No description provided for @scrollToLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Keep scrolling to load more entries'**
  String get scrollToLoadMore;

  /// No description provided for @secureNotepad.
  ///
  /// In en, this message translates to:
  /// **'Secure Notepad'**
  String get secureNotepad;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @selectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select directory'**
  String get selectDirectory;

  /// No description provided for @selectedItems.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedItems(int count);

  /// No description provided for @setAlias.
  ///
  /// In en, this message translates to:
  /// **'Set alias'**
  String get setAlias;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsLoadDescription.
  ///
  /// In en, this message translates to:
  /// **'Unable to read local settings.'**
  String get settingsLoadDescription;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load settings'**
  String get settingsLoadFailed;

  /// No description provided for @settingsLoadSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Try again. If the problem continues, restore defaults or contact support.'**
  String get settingsLoadSuggestion;

  /// No description provided for @settingsNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings were not saved.'**
  String get settingsNotSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save settings'**
  String get settingsSaveFailed;

  /// No description provided for @settingsSaveSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Check local storage space and permissions, then try again.'**
  String get settingsSaveSuggestion;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @showDirectoryNavigator.
  ///
  /// In en, this message translates to:
  /// **'Show directory navigator'**
  String get showDirectoryNavigator;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @showPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Show password hint'**
  String get showPasswordHint;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @sortModifiedNewest.
  ///
  /// In en, this message translates to:
  /// **'Modified: newest first'**
  String get sortModifiedNewest;

  /// No description provided for @sortModifiedOldest.
  ///
  /// In en, this message translates to:
  /// **'Modified: oldest first'**
  String get sortModifiedOldest;

  /// No description provided for @sortNameAscending.
  ///
  /// In en, this message translates to:
  /// **'Name: A to Z'**
  String get sortNameAscending;

  /// No description provided for @sortNameDescending.
  ///
  /// In en, this message translates to:
  /// **'Name: Z to A'**
  String get sortNameDescending;

  /// No description provided for @sortSizeLargest.
  ///
  /// In en, this message translates to:
  /// **'Size: largest first'**
  String get sortSizeLargest;

  /// No description provided for @sortSizeSmallest.
  ///
  /// In en, this message translates to:
  /// **'Size: smallest first'**
  String get sortSizeSmallest;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort: {order}'**
  String sortTooltip(String order);

  /// No description provided for @sortUnavailableUntilFullyLoaded.
  ///
  /// In en, this message translates to:
  /// **'Sorting is unavailable until the directory finishes loading'**
  String get sortUnavailableUntilFullyLoaded;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themePreviewHint.
  ///
  /// In en, this message translates to:
  /// **'The theme is previewed immediately and is kept after saving.'**
  String get themePreviewHint;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @transferCancelledWithUnfinishedState.
  ///
  /// In en, this message translates to:
  /// **'The operation was cancelled. You can clean up the unfinished import or export st...'**
  String get transferCancelledWithUnfinishedState;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @unavailableOrLegacy.
  ///
  /// In en, this message translates to:
  /// **'Unavailable or legacy format'**
  String get unavailableOrLegacy;

  /// No description provided for @underlyingError.
  ///
  /// In en, this message translates to:
  /// **'Underlying error: {error}'**
  String underlyingError(String error);

  /// No description provided for @unencryptedNamesWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: with No encryption, file and directory names are not encrypted.'**
  String get unencryptedNamesWarning;

  /// No description provided for @unfinishedStatesCleaned.
  ///
  /// In en, this message translates to:
  /// **'Cleaned {count} unfinished import/export states'**
  String unfinishedStatesCleaned(int count);

  /// No description provided for @unfinishedTransfersDetected.
  ///
  /// In en, this message translates to:
  /// **'Unfinished imports or exports found'**
  String get unfinishedTransfersDetected;

  /// No description provided for @unfinishedTransfersDetectedDescription.
  ///
  /// In en, this message translates to:
  /// **'{count} unfinished import or export operations were found.\n\nThese operations c...'**
  String unfinishedTransfersDetectedDescription(int count);

  /// No description provided for @unfinishedTransfersRerunCancelled.
  ///
  /// In en, this message translates to:
  /// **'Run again cancelled. The unfinished operation was kept.'**
  String get unfinishedTransfersRerunCancelled;

  /// No description provided for @unfinishedTransfersRerunCompleted.
  ///
  /// In en, this message translates to:
  /// **'Unfinished imports and exports were run again.'**
  String get unfinishedTransfersRerunCompleted;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unloadedEntriesMayMatch.
  ///
  /// In en, this message translates to:
  /// **'More entries have not loaded yet. Load more, then filter again.'**
  String get unloadedEntriesMayMatch;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockDirectoryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the password to unlock:'**
  String get unlockDirectoryPrompt;

  /// No description provided for @unpinSidebar.
  ///
  /// In en, this message translates to:
  /// **'Unpin sidebar'**
  String get unpinSidebar;

  /// No description provided for @unsavedSettings.
  ///
  /// In en, this message translates to:
  /// **'Your changes have not been saved.'**
  String get unsavedSettings;

  /// No description provided for @versionValue.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionValue(int version);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @viewImage.
  ///
  /// In en, this message translates to:
  /// **'View image'**
  String get viewImage;

  /// No description provided for @viewInNewWindow.
  ///
  /// In en, this message translates to:
  /// **'View in new window'**
  String get viewInNewWindow;

  /// No description provided for @viewingImage.
  ///
  /// In en, this message translates to:
  /// **'Viewing: {fileName}'**
  String viewingImage(String fileName);

  /// No description provided for @webDavActiveRequests.
  ///
  /// In en, this message translates to:
  /// **'Active requests: {count}'**
  String webDavActiveRequests(int count);

  /// No description provided for @webDavAuthBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic (username and password, loopback only)'**
  String get webDavAuthBasic;

  /// No description provided for @webDavAuthBearer.
  ///
  /// In en, this message translates to:
  /// **'Bearer (token)'**
  String get webDavAuthBearer;

  /// No description provided for @webDavAuthContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get webDavAuthContinue;

  /// No description provided for @webDavAuthDigest.
  ///
  /// In en, this message translates to:
  /// **'Digest (username and password)'**
  String get webDavAuthDigest;

  /// No description provided for @webDavAuthModeBasic.
  ///
  /// In en, this message translates to:
  /// **'Authentication: Basic'**
  String get webDavAuthModeBasic;

  /// No description provided for @webDavAuthModeBearer.
  ///
  /// In en, this message translates to:
  /// **'Authentication: Bearer'**
  String get webDavAuthModeBearer;

  /// No description provided for @webDavAuthModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Different tools support different authentication methods. Credentials are shown ...'**
  String get webDavAuthModeDescription;

  /// No description provided for @webDavAuthModeDigest.
  ///
  /// In en, this message translates to:
  /// **'Authentication: Digest'**
  String get webDavAuthModeDigest;

  /// No description provided for @webDavAuthModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose authentication'**
  String get webDavAuthModeTitle;

  /// No description provided for @webDavBasicCredentialsDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide the URL, username, and password to the selected trusted tool. Basic auth...'**
  String get webDavBasicCredentialsDescription;

  /// No description provided for @webDavBasicRiskWarning.
  ///
  /// In en, this message translates to:
  /// **'Basic authentication transmits credentials in a form that other local processes ...'**
  String get webDavBasicRiskWarning;

  /// No description provided for @webDavCaCertNote.
  ///
  /// In en, this message translates to:
  /// **'This certificate is for local loopback trust only. Do not distribute it to other...'**
  String get webDavCaCertNote;

  /// No description provided for @webDavCancelMount.
  ///
  /// In en, this message translates to:
  /// **'Cancel mount operation'**
  String get webDavCancelMount;

  /// No description provided for @webDavCapabilityWarning.
  ///
  /// In en, this message translates to:
  /// **'Both the URL and token can access the exposed content. Share them only with trus...'**
  String get webDavCapabilityWarning;

  /// No description provided for @webDavCertSaved.
  ///
  /// In en, this message translates to:
  /// **'CA certificate saved'**
  String get webDavCertSaved;

  /// No description provided for @webDavCredentialOnce.
  ///
  /// In en, this message translates to:
  /// **'Show once (recommended)'**
  String get webDavCredentialOnce;

  /// No description provided for @webDavCredentialPersistent.
  ///
  /// In en, this message translates to:
  /// **'Allow showing again'**
  String get webDavCredentialPersistent;

  /// No description provided for @webDavCredentialVisibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Showing credentials once is safer. Persistent display allows the credentials to ...'**
  String get webDavCredentialVisibilityDescription;

  /// No description provided for @webDavCredentialVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Credential display'**
  String get webDavCredentialVisibilityTitle;

  /// No description provided for @webDavCredentialsDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide the URL and token to the selected trusted tool. The token is not shown a...'**
  String get webDavCredentialsDescription;

  /// No description provided for @webDavCredentialsRevealed.
  ///
  /// In en, this message translates to:
  /// **'Credentials shown'**
  String get webDavCredentialsRevealed;

  /// No description provided for @webDavCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party tool credentials'**
  String get webDavCredentialsTitle;

  /// No description provided for @webDavDigestCredentialsDescription.
  ///
  /// In en, this message translates to:
  /// **'Provide the URL, username, password, and realm to the selected trusted tool. The...'**
  String get webDavDigestCredentialsDescription;

  /// No description provided for @webDavDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'WebDAV sharing is disabled. Re-enable it in Settings to create a share.'**
  String get webDavDisabledMessage;

  /// No description provided for @webDavExportCaCertInstructions.
  ///
  /// In en, this message translates to:
  /// **'To trust WebDAV connections without warnings, install the exported CA certificat...'**
  String get webDavExportCaCertInstructions;

  /// No description provided for @webDavExportCert.
  ///
  /// In en, this message translates to:
  /// **'Export CA Certificate'**
  String get webDavExportCert;

  /// No description provided for @webDavExportCertDescription.
  ///
  /// In en, this message translates to:
  /// **'Save the CA certificate to a file. Install this certificate in your system trust...'**
  String get webDavExportCertDescription;

  /// No description provided for @webDavExposeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Create read-only access'**
  String get webDavExposeReadOnly;

  /// No description provided for @webDavExposureConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'{name} will be exposed through a loopback, read-only WebDAV session. Third-party...'**
  String webDavExposureConfirmDescription(String name);

  /// No description provided for @webDavExposureConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Expose content to a third-party tool?'**
  String get webDavExposureConfirmTitle;

  /// No description provided for @webDavGlobalSwitch.
  ///
  /// In en, this message translates to:
  /// **'Allow WebDAV sharing'**
  String get webDavGlobalSwitch;

  /// No description provided for @webDavGlobalSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'When disabled, new shares are blocked and WebDAV access for open roots is revoke...'**
  String get webDavGlobalSwitchHint;

  /// No description provided for @webDavLastAccessed.
  ///
  /// In en, this message translates to:
  /// **'Last accessed: {time}'**
  String webDavLastAccessed(String time);

  /// No description provided for @webDavMount.
  ///
  /// In en, this message translates to:
  /// **'Mount in the operating system'**
  String get webDavMount;

  /// No description provided for @webDavMountPath.
  ///
  /// In en, this message translates to:
  /// **'System mount path'**
  String get webDavMountPath;

  /// No description provided for @webDavMountPathCopied.
  ///
  /// In en, this message translates to:
  /// **'System mount path copied'**
  String get webDavMountPathCopied;

  /// No description provided for @webDavMounted.
  ///
  /// In en, this message translates to:
  /// **'Mounted in the operating system'**
  String get webDavMounted;

  /// No description provided for @webDavMountedAt.
  ///
  /// In en, this message translates to:
  /// **'Mounted at: {path}'**
  String webDavMountedAt(String path);

  /// No description provided for @webDavNoActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'There is no active third-party access.'**
  String get webDavNoActiveSessions;

  /// No description provided for @webDavOptionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose authentication, credential display, and session lifetime. You can mount o...'**
  String get webDavOptionsDescription;

  /// No description provided for @webDavOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV access'**
  String get webDavOptionsTitle;

  /// No description provided for @webDavPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get webDavPassword;

  /// No description provided for @webDavPasswordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get webDavPasswordCopied;

  /// No description provided for @webDavPersistentCredentialWarning.
  ///
  /// In en, this message translates to:
  /// **'Persistent display increases the risk of credential exposure. Use it only when t...'**
  String get webDavPersistentCredentialWarning;

  /// No description provided for @webDavPersistentSessionWarning.
  ///
  /// In en, this message translates to:
  /// **'Persistent sessions retain their port and credentials until explicitly revoked. ...'**
  String get webDavPersistentSessionWarning;

  /// No description provided for @webDavReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Permission: read-only'**
  String get webDavReadOnly;

  /// No description provided for @webDavRealm.
  ///
  /// In en, this message translates to:
  /// **'Realm'**
  String get webDavRealm;

  /// No description provided for @webDavRealmCopied.
  ///
  /// In en, this message translates to:
  /// **'Realm copied'**
  String get webDavRealmCopied;

  /// No description provided for @webDavRevealCredentials.
  ///
  /// In en, this message translates to:
  /// **'Show credentials'**
  String get webDavRevealCredentials;

  /// No description provided for @webDavRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get webDavRevoke;

  /// No description provided for @webDavSaveCertError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save CA certificate'**
  String get webDavSaveCertError;

  /// No description provided for @webDavSessionEphemeral.
  ///
  /// In en, this message translates to:
  /// **'Ephemeral session (recommended)'**
  String get webDavSessionEphemeral;

  /// No description provided for @webDavSessionLifetimeDescription.
  ///
  /// In en, this message translates to:
  /// **'An ephemeral session ends when the root is closed. A persistent session is resto...'**
  String get webDavSessionLifetimeDescription;

  /// No description provided for @webDavSessionLifetimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Session lifetime'**
  String get webDavSessionLifetimeTitle;

  /// No description provided for @webDavSessionPersistent.
  ///
  /// In en, this message translates to:
  /// **'Persistent session'**
  String get webDavSessionPersistent;

  /// No description provided for @webDavSessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'Third-party access revoked'**
  String get webDavSessionRevoked;

  /// No description provided for @webDavSessions.
  ///
  /// In en, this message translates to:
  /// **'Third-party access'**
  String get webDavSessions;

  /// No description provided for @webDavSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Third-party tool access'**
  String get webDavSessionsTitle;

  /// No description provided for @webDavTLS.
  ///
  /// In en, this message translates to:
  /// **'Enable HTTPS/TLS'**
  String get webDavTLS;

  /// No description provided for @webDavTLSDescription.
  ///
  /// In en, this message translates to:
  /// **'Use HTTPS with a self-signed certificate for loopback connections. Required by s...'**
  String get webDavTLSDescription;

  /// No description provided for @webDavToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get webDavToken;

  /// No description provided for @webDavTokenCopied.
  ///
  /// In en, this message translates to:
  /// **'Access token copied'**
  String get webDavTokenCopied;

  /// No description provided for @webDavUnmount.
  ///
  /// In en, this message translates to:
  /// **'Unmount'**
  String get webDavUnmount;

  /// No description provided for @webDavUnmounted.
  ///
  /// In en, this message translates to:
  /// **'Unmounted'**
  String get webDavUnmounted;

  /// No description provided for @webDavUrl.
  ///
  /// In en, this message translates to:
  /// **'WebDAV URL'**
  String get webDavUrl;

  /// No description provided for @webDavUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'WebDAV URL copied'**
  String get webDavUrlCopied;

  /// No description provided for @webDavUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get webDavUsername;

  /// No description provided for @webDavUsernameCopied.
  ///
  /// In en, this message translates to:
  /// **'Username copied'**
  String get webDavUsernameCopied;

  /// No description provided for @welcomeGuideDontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this guide again'**
  String get welcomeGuideDontShowAgain;

  /// No description provided for @welcomeGuideEncryptedDirectoryContent.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted directories to protect your files:\n\n- Open directory: Open an...'**
  String get welcomeGuideEncryptedDirectoryContent;

  /// No description provided for @welcomeGuideEncryptedDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted directories'**
  String get welcomeGuideEncryptedDirectoryTitle;

  /// No description provided for @welcomeGuideFeaturesContent.
  ///
  /// In en, this message translates to:
  /// **'- File browser: Browse and manage files in encrypted directories\n- Secure notep...'**
  String get welcomeGuideFeaturesContent;

  /// No description provided for @welcomeGuideFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Core features'**
  String get welcomeGuideFeaturesTitle;

  /// No description provided for @welcomeGuideSecurityContent.
  ///
  /// In en, this message translates to:
  /// **'- Keep your password safe. Files cannot be recovered if it is lost.\n- Use a str...'**
  String get welcomeGuideSecurityContent;

  /// No description provided for @welcomeGuideSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security tips'**
  String get welcomeGuideSecurityTitle;

  /// No description provided for @welcomeGuideWelcomeContent.
  ///
  /// In en, this message translates to:
  /// **'Safe Disk helps you encrypt and manage private files.\n\nYou need the correct pa...'**
  String get welcomeGuideWelcomeContent;

  /// No description provided for @welcomeGuideWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Safe Disk'**
  String get welcomeGuideWelcomeTitle;

  /// No description provided for @welcomeOpenDirectoryHint.
  ///
  /// In en, this message translates to:
  /// **'Open or create an encrypted directory from the sidebar.'**
  String get welcomeOpenDirectoryHint;

  /// No description provided for @welcomeProductTagline.
  ///
  /// In en, this message translates to:
  /// **'Encrypted file manager'**
  String get welcomeProductTagline;

  /// No description provided for @willPermanentlyDelete.
  ///
  /// In en, this message translates to:
  /// **'Will permanently delete:'**
  String get willPermanentlyDelete;

  /// No description provided for @zoomInShortcut.
  ///
  /// In en, this message translates to:
  /// **'Zoom in (+)'**
  String get zoomInShortcut;

  /// No description provided for @zoomOutShortcut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out (-)'**
  String get zoomOutShortcut;

}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError('AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely an issue with the localizations generation tool. Please file an issue.');
}