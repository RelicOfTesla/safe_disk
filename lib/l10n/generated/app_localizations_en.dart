// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Safe Disk';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageChinese => 'Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get saveSettings => 'Save settings';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsLoadFailed => 'Unable to load settings';

  @override
  String get settingsSaveFailed => 'Unable to save settings';

  @override
  String get settingsNotSaved => 'Settings were not saved.';

  @override
  String get settingsLoadDescription => 'Unable to read local settings.';

  @override
  String get settingsLoadSuggestion =>
      'Try again. If the problem continues, restore defaults or contact support.';

  @override
  String get settingsSaveSuggestion =>
      'Check local storage space and permissions, then try again.';

  @override
  String get appearance => 'Appearance';

  @override
  String get security => 'Security';

  @override
  String get secureNotepad => 'Secure Notepad';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themePreviewHint =>
      'The theme is previewed immediately and is kept after saving.';

  @override
  String get languagePreviewHint =>
      'The language is previewed immediately and is kept after saving.';

  @override
  String get saveChanges => 'Save settings changes?';

  @override
  String get unsavedSettings => 'Your changes have not been saved.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get saveAndReturn => 'Save and return';

  @override
  String get back => 'Back';

  @override
  String get restoreDefaults => 'Restore defaults (not saved)';

  @override
  String get loadingImage => 'Loading image';

  @override
  String get imageLoadFailed => 'Image failed to load';

  @override
  String imageEncodedSizeLimit(String limit) {
    return 'Encoded image data exceeds the $limit limit.';
  }

  @override
  String get imageContentEmpty => 'The image content is empty.';

  @override
  String get imageDimensionsInvalid => 'The image dimensions are invalid.';

  @override
  String imageDecodedPixelLimit(String limit) {
    return 'Decoded image dimensions exceed the $limit limit.';
  }

  @override
  String get imageEncryptedContentInvalid =>
      'The encrypted image data could not be read. It may be invalid.';

  @override
  String get noDisplayableImage =>
      'No displayable image. Choose another image or try again.';

  @override
  String viewingImage(String fileName) {
    return 'Viewing: $fileName';
  }

  @override
  String animatedImageFrames(int count) {
    return 'Animated ($count frames)';
  }

  @override
  String get zoomInShortcut => 'Zoom in (+)';

  @override
  String get zoomOutShortcut => 'Zoom out (-)';

  @override
  String get resetImageViewShortcut => 'Reset view (N)';

  @override
  String get rotateClockwiseShortcut => 'Rotate clockwise (R)';

  @override
  String get previousImageShortcut => 'Previous image (Left)';

  @override
  String get nextImageShortcut => 'Next image (Right)';

  @override
  String get imageDecodeFailed => 'Cannot display image';

  @override
  String get imageDecodeFailedDescription =>
      'The file may be damaged or use an unsupported image format.';

  @override
  String get errorSuggestionPrefix => 'Suggestion: ';

  @override
  String get copy => 'Copy';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get viewDetails => 'View details';

  @override
  String get technicalDetails => 'Technical details';

  @override
  String get errorDetailsCopied => 'Error details copied';

  @override
  String get errorDirectoryNotVerifiedTitle => 'Unlock directory first';

  @override
  String get errorDirectoryNotVerifiedDescription =>
      'Enter the password to unlock this encrypted directory before working with files.';

  @override
  String get errorDirectoryNotVerifiedSuggestion =>
      'Select the directory in the sidebar, then enter its password.';

  @override
  String get errorSessionExpiredTitle => 'Directory is locked';

  @override
  String get errorSessionExpiredDescription =>
      'The directory session has ended and must be unlocked again.';

  @override
  String get errorSessionExpiredSuggestion =>
      'Select the directory in the sidebar and enter the password again.';

  @override
  String get errorInvalidPasswordTitle => 'Incorrect password';

  @override
  String get errorInvalidPasswordDescription =>
      'The password cannot decrypt this directory.';

  @override
  String get errorInvalidPasswordSuggestion =>
      'Check the password, including letter case.';

  @override
  String get errorDirectoryNotExistTitle => 'Directory not found';

  @override
  String get errorDirectoryNotExistDescription =>
      'The selected directory does not exist or was deleted.';

  @override
  String get errorDirectoryNotExistSuggestion =>
      'Check the directory path or choose another directory.';

  @override
  String get errorNotEncryptedDirectoryTitle => 'Cannot open directory';

  @override
  String get errorNotEncryptedDirectoryDescription =>
      'The selected directory is not a recognized Safe Disk encrypted directory.';

  @override
  String get errorNotEncryptedDirectorySuggestion =>
      'Choose an existing encrypted directory or create a new one.';

  @override
  String get errorLoadConfigFailedTitle => 'Could not load configuration';

  @override
  String get errorLoadConfigFailedDescription =>
      'The encrypted directory configuration could not be read.';

  @override
  String get errorLoadConfigFailedSuggestion =>
      'Check that the directory is complete and was not modified by another program.';

  @override
  String get errorLoadDirectoryFailedTitle => 'Could not load directory';

  @override
  String get errorLoadDirectoryFailedDescription =>
      'The directory contents could not be read.';

  @override
  String get errorLoadDirectoryFailedSuggestion =>
      'Check directory permissions or try opening it again.';

  @override
  String get errorUnfinishedTransferStateUnavailableTitle =>
      'Cannot verify unfinished transfer state';

  @override
  String get errorUnfinishedTransferStateUnavailableDescription =>
      'Safe Disk could not safely read the unfinished import or export state, so this directory was not opened.';

  @override
  String get errorUnfinishedTransferStateUnavailableSuggestion =>
      'Check directory permissions and disk status. Keep the directory unchanged and try again.';

  @override
  String get errorCreateEncryptedDirectoryFailedTitle =>
      'Could not create encrypted directory';

  @override
  String get errorCreateEncryptedDirectoryFailedDescription =>
      'A new encrypted directory could not be created.';

  @override
  String get errorCreateEncryptedDirectoryFailedSuggestion =>
      'Check directory permissions and available disk space, then try again.';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptyTitle =>
      'Directory is not empty';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptyDescription =>
      'A new encrypted directory can only be created in a missing or empty directory.';

  @override
  String get errorCreateEncryptedDirectoryRequiresEmptySuggestion =>
      'Choose a new path or an empty directory. Use import for existing content.';

  @override
  String get errorImportFileFailedTitle => 'Could not import file';

  @override
  String get errorImportFileFailedDescription =>
      'The file could not be imported into the encrypted directory.';

  @override
  String get errorImportFileFailedSuggestion =>
      'Check that the file exists and is readable, then try again.';

  @override
  String get errorImportDirectoryFailedTitle => 'Could not import directory';

  @override
  String get errorImportDirectoryFailedDescription =>
      'The directory could not be imported into the encrypted directory.';

  @override
  String get errorImportDirectoryFailedSuggestion =>
      'Check source permissions, symbolic links, and the destination directory state, then try again.';

  @override
  String get errorImportDirectoryInsideCurrentRootTitle =>
      'Cannot import this directory';

  @override
  String get errorImportDirectoryInsideCurrentRootDescription =>
      'A subdirectory of the current encrypted directory cannot be imported into the current encrypted directory.';

  @override
  String get errorImportDirectoryInsideCurrentRootSuggestion =>
      'Choose a source directory outside the encrypted directory.';

  @override
  String get errorExportFileFailedTitle => 'Could not export file';

  @override
  String get errorExportFileFailedDescription =>
      'The file could not be exported to the selected location.';

  @override
  String get errorExportFileFailedSuggestion =>
      'Check that the destination is writable, then try again.';

  @override
  String get errorExportDirectoryFailedTitle => 'Could not export directory';

  @override
  String get errorExportDirectoryFailedDescription =>
      'The directory could not be exported to the selected location.';

  @override
  String get errorExportDirectoryFailedSuggestion =>
      'Check that the destination is writable, then try again.';

  @override
  String get errorDeleteFileFailedTitle => 'Could not delete file';

  @override
  String get errorDeleteFileFailedDescription =>
      'The file could not be deleted.';

  @override
  String get errorDeleteFileFailedSuggestion =>
      'Check whether the file is in use, then try again.';

  @override
  String get errorSaveFileFailedTitle => 'Could not save file';

  @override
  String get errorSaveFileFailedDescription =>
      'The file changes could not be saved.';

  @override
  String get errorSaveFileFailedSuggestion =>
      'Check disk space and permissions, then try again.';

  @override
  String get errorLoadFileFailedTitle => 'Could not load file';

  @override
  String get errorLoadFileFailedDescription =>
      'The file contents could not be read.';

  @override
  String get errorLoadFileFailedSuggestion =>
      'Check that the file exists and is readable.';

  @override
  String get errorNoDirectorySelectedTitle => 'No directory selected';

  @override
  String get errorNoDirectorySelectedDescription => 'Select a directory first.';

  @override
  String get errorNoFileSelectedTitle => 'No file selected';

  @override
  String get errorNoFileSelectedDescription => 'Select a file first.';

  @override
  String get errorPasswordEmptyTitle => 'Password is required';

  @override
  String get errorPasswordEmptyDescription => 'Enter a password to continue.';

  @override
  String get errorPasswordMismatchTitle => 'Passwords do not match';

  @override
  String get errorPasswordMismatchDescription =>
      'The two passwords are different.';

  @override
  String get errorPasswordMismatchSuggestion =>
      'Make sure both password entries are identical.';

  @override
  String get errorPathEmptyTitle => 'Path is required';

  @override
  String get errorPathEmptyDescription => 'Enter a directory path.';

  @override
  String get errorOperationFailedTitle => 'Operation failed';

  @override
  String get errorOperationFailedDescription =>
      'The operation did not finish. Try again later.';

  @override
  String get errorOperationFailedSuggestion =>
      'If the problem continues, contact support.';

  @override
  String get behavior => 'Behavior';

  @override
  String get openMode => 'Open items with';

  @override
  String get openModeHint => 'Choose how files and folders open';

  @override
  String get openModeSingleClick => 'Single click';

  @override
  String get openModeDoubleClick => 'Double click';

  @override
  String get confirmBeforeDelete => 'Confirm before deleting';

  @override
  String get confirmBeforeDeleteHint =>
      'Show a confirmation dialog before deleting files.';

  @override
  String get lockAfterIdle => 'Lock after inactivity';

  @override
  String get lockAfterIdleHint =>
      'Lock the current directory after its idle timeout. Directories with open file windows, unsaved changes, or active saves are not forced closed.';

  @override
  String get lockWhenHidden => 'Lock when the app is hidden';

  @override
  String get lockWhenHiddenHint =>
      'Only lock directories without open file windows, unsaved changes, or active saves. Other directories are not forced closed.';

  @override
  String get messageListSeparator => '; ';

  @override
  String autoLockSummaryLocked(int count) {
    return '$count directories were locked automatically';
  }

  @override
  String autoLockSummarySkipped(int count) {
    return '$count directories have open file windows or pending saves and were left open';
  }

  @override
  String autoLockSummaryFailed(int count) {
    return '$count directories could not be locked';
  }

  @override
  String get rootActiveWritesTitle => 'Saving content';

  @override
  String rootActiveWritesDescription(int count) {
    return '$count file save operations are still running. Wait for them to finish before ending the session.';
  }

  @override
  String get rootUnsavedContentTitle => 'Unsaved content';

  @override
  String rootUnsavedContentDescription(String documents) {
    return 'Handle these open file windows before ending the session:\n\n$documents';
  }

  @override
  String get acknowledge => 'OK';

  @override
  String get rootDirectoryDeleted => 'Encrypted directory permanently deleted';

  @override
  String get rootHistoryRemoved =>
      'Directory history removed. Files on disk were kept.';

  @override
  String get passwordChangeBlockedBySaving =>
      'This directory is saving content. Wait for the save to finish before changing its password.';

  @override
  String get passwordChangeBlockedByDocuments =>
      'Close or save this directory\'s open file windows before changing its password.';

  @override
  String get passwordChangedUnlockAgain =>
      'Password changed. Unlock the directory again with the new password.';

  @override
  String get notepadDraftInterval => 'Secure draft save interval';

  @override
  String get notepadDraftIntervalHint =>
      'Periodically save an encrypted draft beside the original file without overwriting it.';

  @override
  String get notepadDefaultReadOnly => 'Open notes read-only';

  @override
  String get notepadDefaultReadOnlyHint =>
      'New files open read-only. You can start editing manually.';

  @override
  String get notepadMonitorClipboard => 'Monitor clipboard by default';

  @override
  String get notepadMonitorClipboardHint =>
      'Only show a text preview; do not write it to files or settings.';

  @override
  String get notepadRecoveryDraftFound => 'Secure draft found';

  @override
  String get notepadBinaryContent =>
      'The file contains binary content and cannot be opened in Secure Notepad.';

  @override
  String get notepadLoadFailed =>
      'Unable to read the file. Check that it exists and is readable, then try again.';

  @override
  String get notepadRecoveryDraftDescription =>
      'An encrypted draft from an unfinished edit was found. Restore it to the editor?';

  @override
  String get notepadDiscardDraft => 'Discard draft';

  @override
  String get notepadRestoreDraft => 'Restore draft';

  @override
  String get notepadUnsavedChanges => 'Unsaved changes';

  @override
  String get notepadSaveBeforeClosing => 'Save changes before closing?';

  @override
  String get notepadDontSave => 'Don\'t save';

  @override
  String get notepadStartEditing => 'Start editing';

  @override
  String get notepadSwitchReadOnly => 'Switch to read-only';

  @override
  String get notepadUndoShortcut => 'Undo (Ctrl/Cmd+Z)';

  @override
  String get notepadRedoShortcut => 'Redo (Ctrl/Cmd+Shift+Z)';

  @override
  String get notepadFindReplace => 'Find and replace';

  @override
  String get notepadCloseFind => 'Close find';

  @override
  String get notepadStopClipboardMonitoring => 'Stop clipboard monitoring';

  @override
  String get notepadMonitorClipboardAction => 'Monitor clipboard';

  @override
  String get notepadSave => 'Save';

  @override
  String get notepadFileSaved => 'File saved';

  @override
  String get notepadSaveFailed => 'Save failed';

  @override
  String get notepadSaving => 'Saving';

  @override
  String get notepadUnsaved => 'Unsaved';

  @override
  String get notepadSaved => 'Saved';

  @override
  String get notepadReadOnly => 'Read-only';

  @override
  String get notepadEditing => 'Editing';

  @override
  String notepadCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String get notepadDraftSaveFailed => 'Could not save recovery draft';

  @override
  String get notepadDraftCleanupFailed =>
      'The original file was saved, but the old draft could not be removed.';

  @override
  String get notepadDraftReadFailed => 'Could not check the recovery draft.';

  @override
  String get notepadDraftDiscardFailed =>
      'Could not remove the recovery draft.';

  @override
  String get notepadSavingDraft => 'Saving recovery draft';

  @override
  String get notepadDraftSaved => 'Recovery draft saved';

  @override
  String get notepadClipboardMonitor => 'Clipboard monitor';

  @override
  String get notepadClipboardEmpty => 'No short text in the clipboard';

  @override
  String get notepadClipboardReadFailed =>
      'Unable to read the clipboard. Try again.';

  @override
  String get notepadClipboardClearFailed =>
      'Unable to clear the clipboard. Try again.';

  @override
  String get notepadRefreshClipboard => 'Refresh clipboard now';

  @override
  String get notepadClearClipboard => 'Clear system clipboard';

  @override
  String get notepadFindHint => 'Find (\\n means newline)';

  @override
  String notepadFindPosition(int current, int total) {
    return '$current/$total';
  }

  @override
  String get notepadFindPrevious => 'Find previous';

  @override
  String get notepadFindNext => 'Find next';

  @override
  String get notepadReplace => 'Replace';

  @override
  String get notepadReplaceAll => 'Replace all';

  @override
  String get notepadNoMatches => 'No matches found';

  @override
  String get notepadSelectMatchFirst => 'Select a match first';

  @override
  String notepadReplacedCount(int count) {
    return 'Replaced $count matches';
  }

  @override
  String get welcomeGuideWelcomeTitle => 'Welcome to Safe Disk';

  @override
  String get welcomeGuideWelcomeContent =>
      'Safe Disk helps you encrypt and manage private files.\n\nYou need the correct password to access content in an encrypted directory.';

  @override
  String get welcomeGuideEncryptedDirectoryTitle => 'Encrypted directories';

  @override
  String get welcomeGuideEncryptedDirectoryContent =>
      'Create encrypted directories to protect your files:\n\n- Open directory: Open an existing encrypted directory\n- Create directory: Create a new encrypted directory\n\nAll files in an encrypted directory are protected automatically.';

  @override
  String get welcomeGuideFeaturesTitle => 'Core features';

  @override
  String get welcomeGuideFeaturesContent =>
      '- File browser: Browse and manage files in encrypted directories\n- Secure notepad: Edit text files (.txt, .md)\n- Image viewer: View encrypted image files\n- Batch export: Export multiple files at once';

  @override
  String get welcomeGuideSecurityTitle => 'Security tips';

  @override
  String get welcomeGuideSecurityContent =>
      '- Keep your password safe. Files cannot be recovered if it is lost.\n- Use a strong password (12 or more characters with mixed character types).\n- Keys are kept only in memory and are cleared when the app closes.\n- Back up important encrypted directories regularly.';

  @override
  String get welcomeGuideDontShowAgain => 'Don\'t show this guide again';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get detailedErrors => 'Show detailed error information';

  @override
  String get detailedErrorsHint =>
      'Show redacted operation stages and underlying errors in error prompts. No disk log is written.';

  @override
  String get about => 'About';

  @override
  String get appVersionDescription => 'Version 1.0.0\nEncrypted file manager';

  @override
  String get durationNever => 'Never';

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String progressMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds sec';
  }

  @override
  String progressEstimatedRemaining(String duration) {
    return 'Estimated remaining: $duration';
  }

  @override
  String progressProcessed(int current, int total) {
    return 'Processed: $current / $total';
  }

  @override
  String progressCurrentFile(String name) {
    return 'Current: $name';
  }

  @override
  String get rerunUnfinishedTransfers =>
      'Run unfinished imports and exports again';

  @override
  String get preparing => 'Preparing...';

  @override
  String get operationNotCancellableYet =>
      'This operation cannot be cancelled yet.';

  @override
  String rerunningUnfinishedProgress(int current, int total) {
    return 'Running again: $current of $total...';
  }

  @override
  String get unfinishedTransfersRerunCompleted =>
      'Unfinished imports and exports were run again.';

  @override
  String get unfinishedTransfersRerunCancelled =>
      'Run again cancelled. The unfinished operation was kept.';

  @override
  String get preparingImport => 'Preparing import...';

  @override
  String get preparingExport => 'Preparing export...';

  @override
  String get preparingDelete => 'Preparing deletion...';

  @override
  String get preparingCannotCancel =>
      'Preparing; cancellation is unavailable...';

  @override
  String get importing => 'Importing...';

  @override
  String get exporting => 'Exporting...';

  @override
  String get deleting => 'Deleting...';

  @override
  String directoryImportCompleted(int count) {
    return 'Imported $count files.';
  }

  @override
  String get transferCancelledWithUnfinishedState =>
      'The operation was cancelled. You can clean up the unfinished import or export state the next time you open this directory.';

  @override
  String directoryExportCompleted(int count) {
    return 'Exported $count files.';
  }

  @override
  String get batchExport => 'Batch export';

  @override
  String batchExportCompleted(int success, int failed) {
    return 'Export completed: $success succeeded, $failed failed.';
  }

  @override
  String batchExportCompletedAll(int count) {
    return 'Export completed: $count files succeeded.';
  }

  @override
  String batchExportCancelled(int success, int failed) {
    return 'Export cancelled: $success succeeded, $failed failed.';
  }

  @override
  String get batchDelete => 'Batch delete';

  @override
  String batchDeleteCancelled(int success, int remaining) {
    return 'Batch deletion cancelled: $success succeeded; $remaining items remain selected.';
  }

  @override
  String batchDeleteCompleted(int count) {
    return 'Deleted $count files.';
  }

  @override
  String get unfinishedTransfersDetected =>
      'Unfinished imports or exports found';

  @override
  String unfinishedTransfersDetectedDescription(int count) {
    return '$count unfinished import or export operations were found.\n\nThese operations cannot be resumed. You can clean up the unfinished operation and run the full import or export again, or skip it for now.';
  }

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get cleanState => 'Clean unfinished operation';

  @override
  String get rerunAll => 'Run again';

  @override
  String get confirmBatchDeletion => 'Confirm batch deletion';

  @override
  String confirmBatchDeletionDescription(int count) {
    return 'Delete $count selected items? This cannot be undone. Items are deleted one at a time; items already deleted are not restored if a later deletion fails.';
  }

  @override
  String get disabled => 'Off';

  @override
  String get nativeComponentUnavailable => 'Security component unavailable';

  @override
  String get nativeBindingFailureDescription =>
      'The security component version does not match this app, so encryption cannot start.';

  @override
  String get nativeLoadingFailureDescription =>
      'Safe Disk could not load its security component, so encrypted directories cannot be accessed safely.';

  @override
  String get nativeBindingFailureSuggestion =>
      'Reinstall the matching version of Safe Disk, then try again.';

  @override
  String get nativeLoadingFailureSuggestion =>
      'Reinstall the app. If the problem continues, check whether security software quarantined application files.';

  @override
  String initializationStage(String stage) {
    return 'Initialization stage: $stage';
  }

  @override
  String underlyingError(String error) {
    return 'Underlying error: $error';
  }

  @override
  String errorDiagnosticType(String type) {
    return 'Error type: $type';
  }

  @override
  String errorDiagnosticOperation(String operation) {
    return 'Operation: $operation';
  }

  @override
  String get errorDiagnosticRedacted => '[redacted]';

  @override
  String get errorDiagnosticPathRedacted => '[path redacted]';

  @override
  String get errorDiagnosticTruncated => '[details truncated]';

  @override
  String get contentWindowUnavailable => 'Cannot connect to main window';

  @override
  String get contentWindowUnavailableDescription =>
      'The document session may have ended. To avoid editing an invalid session, close this window and open the document again from the main window.';

  @override
  String get closeWindow => 'Close window';

  @override
  String get welcomeProductTagline => 'Encrypted file manager';

  @override
  String get welcomeOpenDirectoryHint =>
      'Open or create an encrypted directory from the sidebar.';

  @override
  String selectedItems(int count) {
    return '$count selected';
  }

  @override
  String get exitSelectionMode => 'Exit selection mode';

  @override
  String get copySelected => 'Copy selected';

  @override
  String get cutSelected => 'Cut selected';

  @override
  String get moreBatchActions => 'More batch actions';

  @override
  String get selectAll => 'Select all';

  @override
  String get exportSelected => 'Export selected';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String get closeDirectory => 'Close directory';

  @override
  String get currentDirectory => 'Current directory';

  @override
  String get clipboardMovePending => 'Move pending';

  @override
  String get fileClipboard => 'File clipboard';

  @override
  String get clipboardPastePending => 'Paste pending';

  @override
  String get moveSourceDeleteFailed =>
      'The target was copied, but the source entry could not be deleted. Both entries were kept; verify the target, then remove the source manually.';

  @override
  String clipboardMultipleEntries(String name, int count) {
    return '$name and $count items';
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
  String get moveToCurrentDirectory => 'Move to current directory';

  @override
  String get pasteToCurrentDirectory => 'Paste to current directory';

  @override
  String get clearFileClipboard => 'Clear file clipboard';

  @override
  String openedDirectoriesCount(int count) {
    return '$count directories open';
  }

  @override
  String get unpinSidebar => 'Unpin sidebar';

  @override
  String get pinSidebar => 'Pin sidebar';

  @override
  String get openOrCreateEncryptedDirectory =>
      'Open or create encrypted directory';

  @override
  String get noOpenedDirectories =>
      'No directories are open yet.\n\nSelect \"Open or create encrypted directory\" to get started.';

  @override
  String get properties => 'Properties';

  @override
  String get changePassword => 'Change password';

  @override
  String get setAlias => 'Set alias';

  @override
  String get clearAlias => 'Clear alias';

  @override
  String get directoryAliasTitle => 'Set directory display alias';

  @override
  String get directoryAliasLabel => 'Alias';

  @override
  String get directoryAliasHint => 'Leave empty to restore the directory name';

  @override
  String get closeOrRemoveDirectory => 'Close or remove directory';

  @override
  String get directoryUnlocked => 'Unlocked';

  @override
  String get directoryNeedsPassword => 'Password required';

  @override
  String get moreDirectoryActions => 'More directory actions';

  @override
  String get importFile => 'Import file';

  @override
  String get importDirectory => 'Import directory';

  @override
  String get dropImportHere =>
      'Drop to import into the current encrypted directory';

  @override
  String get allFiles => 'All files';

  @override
  String get encryptedDirectoryCreated => 'Encrypted directory created';

  @override
  String encryptedRootFound(String path) {
    return 'The current path is inside an encrypted directory: $path';
  }

  @override
  String get passwordVerified => 'Password verified';

  @override
  String unfinishedStatesCleaned(int count) {
    return 'Cleaned $count unfinished import/export states';
  }

  @override
  String notepadFileTooLarge(String limit) {
    return 'The file exceeds $limit and cannot be opened in Secure Notepad.';
  }

  @override
  String get nativeContentWindowUnavailable =>
      'Separate file windows are unavailable on this platform. Opened in the main window instead.';

  @override
  String get batchMove => 'Batch move';

  @override
  String get batchPaste => 'Batch paste';

  @override
  String movedToDestination(String name) {
    return 'Moved: $name';
  }

  @override
  String pastedToDestination(String name) {
    return 'Pasted: $name';
  }

  @override
  String batchPasteCancelled(int success, int remaining) {
    return 'Batch paste cancelled: $success succeeded; $remaining items can be retried.';
  }

  @override
  String movedFiles(int count) {
    return 'Moved $count files';
  }

  @override
  String pastedFiles(int count) {
    return 'Pasted $count files';
  }

  @override
  String get noEncryptedClipboardEntries =>
      'There are no encrypted entries to paste in the file clipboard';

  @override
  String get cannotPasteDirectoryIntoItself =>
      'A directory cannot be pasted into itself or one of its subdirectories';

  @override
  String directoryCreated(String name) {
    return 'Directory created: $name';
  }

  @override
  String fileCreated(String name) {
    return 'File created: $name';
  }

  @override
  String renamedTo(String name) {
    return 'Renamed to: $name';
  }

  @override
  String get confirmDeleteFile => 'Confirm file deletion';

  @override
  String confirmDeleteFileDescription(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get fileDeleted => 'File deleted';

  @override
  String fileImportCompleted(String name) {
    return 'File imported: $name';
  }

  @override
  String fileExportCompleted(String path) {
    return 'File exported: $path';
  }

  @override
  String get confirmPlaintextExport => 'Confirm plaintext export';

  @override
  String confirmPlaintextExportDescription(String name) {
    return '\"$name\" will be written unencrypted to the selected location. The exported copy will no longer be protected by Safe Disk. Continue?';
  }

  @override
  String get continueExport => 'Continue export';

  @override
  String get copiedNameToSystemClipboard =>
      'Plaintext name copied to the system clipboard';

  @override
  String get copiedPathToSystemClipboard =>
      'Plaintext logical path copied to the system clipboard';

  @override
  String copiedForPaste(String name) {
    return 'Copied \"$name\". Select a destination directory to paste.';
  }

  @override
  String cutForMove(String name) {
    return 'Cut \"$name\". Select a destination directory to move it.';
  }

  @override
  String copiedManyForPaste(int count) {
    return 'Copied $count files. Select a destination directory to paste.';
  }

  @override
  String cutManyForMove(int count) {
    return 'Cut $count files. Select a destination directory to move them.';
  }

  @override
  String get unlockDirectoryPrompt => 'Enter the password to unlock:';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Password hint';

  @override
  String get showPasswordHint => 'Show password hint';

  @override
  String get hidePasswordHint => 'Hide password hint';

  @override
  String get passwordHintCreationNotice =>
      'Helps you remember the password. Anyone with access to this directory can see it; it cannot recover your password.';

  @override
  String get passwordHintPublicNotice =>
      'Anyone with access to this directory can see this hint. It cannot recover your password.';

  @override
  String get passwordHintTooLong => 'Password hints are limited to 256 bytes.';

  @override
  String get passwordHintNotSet => 'Not set';

  @override
  String get managePasswordHint => 'Manage password hint';

  @override
  String get passwordHintEditNotice =>
      'Enter a new hint, or leave it empty to clear it. Anyone with access to this directory can see it; it cannot recover your password.';

  @override
  String get passwordHintPasswordRequired =>
      'Enter the current password to update the password hint.';

  @override
  String get savePasswordHint => 'Save hint';

  @override
  String get passwordHintUpdated => 'Password hint updated.';

  @override
  String get unlock => 'Unlock';

  @override
  String directoryLabel(String name) {
    return 'Directory: $name';
  }

  @override
  String get passwordChangeDescription =>
      'After changing the password, reopen the directory with the new password. Existing content does not need to be re-encrypted.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get passwordChangeFieldsRequired =>
      'Enter the current password and a new password.';

  @override
  String get newPasswordsDoNotMatch => 'The new passwords do not match.';

  @override
  String get rootDirectoryActions => 'Directory actions';

  @override
  String get endSessionOnly => 'End session only';

  @override
  String endSessionDescription(String name) {
    return 'Lock \"$name\" and keep its sidebar history and disk directory.';
  }

  @override
  String get directoryAlreadyLocked => 'This directory is already locked.';

  @override
  String get endSessionAndRemoveHistory => 'End session and remove history';

  @override
  String get removeHistoryDescription =>
      'Remove only from the sidebar; keep the local disk directory unchanged.';

  @override
  String get endSessionRemoveHistoryAndDelete =>
      'End session, remove history, and delete directory';

  @override
  String get deleteDirectoryDescription =>
      'Permanently delete the local encrypted directory and all its contents. This cannot be undone.';

  @override
  String get permanentlyDeleteLocalDirectory =>
      'Permanently delete local directory';

  @override
  String get willPermanentlyDelete => 'Will permanently delete:';

  @override
  String enterDirectoryNameToConfirm(String name) {
    return 'Enter the directory name \"$name\" to confirm:';
  }

  @override
  String get permanentlyDeleteDirectory => 'Permanently delete directory';

  @override
  String get unknown => 'Unknown';

  @override
  String get rootDirectoryProperties => 'Encrypted directory properties';

  @override
  String get displayName => 'Display name';

  @override
  String get diskPath => 'Disk path';

  @override
  String get currentStatus => 'Current status';

  @override
  String get directoryLocked => 'Locked';

  @override
  String get directoryFormat => 'Directory format';

  @override
  String get dataEncryption => 'Data encryption';

  @override
  String get fileNameEncryption => 'File name encryption';

  @override
  String get nameEncryption => 'Name encryption';

  @override
  String get passwordDerivation => 'Password derivation';

  @override
  String get passwordVerification => 'Password verification';

  @override
  String versionValue(int version) {
    return 'Version $version';
  }

  @override
  String get unavailableOrLegacy => 'Unavailable or legacy format';

  @override
  String get passwordChange => 'Change password';

  @override
  String get passwordChangeDirectly => 'Can change directly';

  @override
  String get passwordChangeMigrationRequired => 'Migration required';

  @override
  String get rootPropertiesSensitiveNotice =>
      'Passwords, keys, and other sensitive information are not shown.';

  @override
  String get directory => 'Directory';

  @override
  String get status => 'Status';

  @override
  String get directoryCannotChangePassword =>
      'This directory cannot change its password directly.';

  @override
  String get reason => 'Reason';

  @override
  String get legacyPasswordChangeReason =>
      'This directory uses an older encryption format. Changing its password directly would make existing content unreadable.';

  @override
  String get safeApproach => 'Safe approach';

  @override
  String get legacyPasswordChangeApproach =>
      'Create an encrypted directory with a new password, then export and import the content you need to keep.';

  @override
  String get createEncryptedDirectory => 'Create encrypted directory';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get allowFuturePasswordChange => 'Allow password changes later';

  @override
  String get allowFuturePasswordChangeHint =>
      'Recommended: change the password without re-encrypting existing files.';

  @override
  String get advancedEncryptionParameters => 'Advanced encryption parameters';

  @override
  String get advancedEncryptionParametersHint =>
      'The default configuration is suitable for most people.';

  @override
  String get derivationStrength => 'Derivation strength';

  @override
  String get derivationStrengthUncalibratedHint =>
      'This is a preset profile and has not been calibrated for this device.';

  @override
  String get defaultNewDirectoryKdfProfile =>
      'Default derivation profile for new directories';

  @override
  String get defaultNewDirectoryKdfProfileHint =>
      'Only affects directories created later; it has not been calibrated for this device.';

  @override
  String get kdfProfileFast => 'Fast';

  @override
  String get kdfProfileBalanced => 'Balanced (recommended)';

  @override
  String get kdfProfileStrong => 'Strong';

  @override
  String get kdfProfileMaximum => 'Maximum';

  @override
  String durationMilliseconds(int count) {
    return '$count ms';
  }

  @override
  String get noEncryption => 'No encryption';

  @override
  String get unencryptedNamesWarning =>
      'Warning: with No encryption, file and directory names are not encrypted.';

  @override
  String get selectDirectory => 'Select directory';

  @override
  String get directoryPath => 'Directory path';

  @override
  String get directoryPathHint =>
      'Enter a directory path or browse to select one';

  @override
  String get browse => 'Browse';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmDirectoryRemoval => 'Confirm removal';

  @override
  String get removeEncryptedDirectoryFromSidebar =>
      'You are about to remove this encrypted directory from the sidebar:';

  @override
  String get chooseAnAction => 'Choose an action:';

  @override
  String get removeFromSidebarOnlyDescription =>
      '• Remove from sidebar only: keep the disk directory and encrypted files';

  @override
  String get deleteDirectoryFromDiskDescription =>
      '• Also delete the disk directory: permanently delete the directory and all files';

  @override
  String get removeOnly => 'Remove only';

  @override
  String get deleteDiskDirectory => 'Delete disk directory';

  @override
  String propertyLabel(String label) {
    return '$label:';
  }

  @override
  String copyPropertyValue(String label) {
    return 'Copy $label';
  }

  @override
  String get propertyValueCopied => 'Property value copied';

  @override
  String get filterCurrentDirectoryHint =>
      'Filter files and folders in the current directory...';

  @override
  String get filterLoadedItemsHint =>
      'Only loaded entries are filtered. Load more to expand the scope.';

  @override
  String get navigateUp => 'Go up';

  @override
  String directoryIncompleteSummary(int count, int folders, int files) {
    return '$count loaded ($folders folders, $files files)';
  }

  @override
  String directorySummary(int folders, int files) {
    return '$folders folders, $files files';
  }

  @override
  String get sortUnavailableUntilFullyLoaded =>
      'Sorting is unavailable until the directory finishes loading';

  @override
  String sortTooltip(String order) {
    return 'Sort: $order';
  }

  @override
  String get sortNameAscending => 'Name: A to Z';

  @override
  String get sortNameDescending => 'Name: Z to A';

  @override
  String get sortModifiedNewest => 'Modified: newest first';

  @override
  String get sortModifiedOldest => 'Modified: oldest first';

  @override
  String get sortSizeLargest => 'Size: largest first';

  @override
  String get sortSizeSmallest => 'Size: smallest first';

  @override
  String get closeCurrentDirectoryFilter => 'Close current directory filter';

  @override
  String get filterCurrentDirectory => 'Filter current directory';

  @override
  String get hideDirectoryNavigator => 'Hide directory navigator';

  @override
  String get showDirectoryNavigator => 'Show directory navigator';

  @override
  String get listView => 'List view';

  @override
  String get gridView => 'Grid view';

  @override
  String get directoryReadFailedRetry =>
      'Could not read directory. Refresh and try again.';

  @override
  String noMatchInLoadedEntries(String query) {
    return 'No loaded entries match \"$query\"';
  }

  @override
  String noMatchInCurrentDirectory(String query) {
    return 'No entries in this directory match \"$query\"';
  }

  @override
  String get unloadedEntriesMayMatch =>
      'More entries have not loaded yet. Load more, then filter again.';

  @override
  String get currentDirectoryEmpty => 'This directory is empty';

  @override
  String get loadMoreEntries => 'Load more entries';

  @override
  String get loadMoreFailedRetry =>
      'Could not load more entries. Refresh and try again.';

  @override
  String get scrollToLoadMore => 'Keep scrolling to load more entries';

  @override
  String directoryItemCount(int count) {
    return '$count items';
  }

  @override
  String get file => 'File';

  @override
  String fileSystemEntrySemantics(String name, String type) {
    return '$name, $type';
  }

  @override
  String get openDirectory => 'Open directory';

  @override
  String get viewImage => 'View image';

  @override
  String get editWithSecureNotepad => 'Edit with Secure Notepad';

  @override
  String get viewInNewWindow => 'View in new window';

  @override
  String get editInNewWindow => 'Edit in new window';

  @override
  String get select => 'Select';

  @override
  String get rename => 'Rename';

  @override
  String get cut => 'Cut';

  @override
  String get pasteIntoDirectory => 'Paste into this directory';

  @override
  String get exportDirectory => 'Export directory';

  @override
  String get exportDecryptedFile => 'Export decrypted file';

  @override
  String get copyPlaintextName => 'Copy name (plaintext)';

  @override
  String get copyPlaintextLogicalPath => 'Copy logical path (plaintext)';

  @override
  String get refresh => 'Refresh';

  @override
  String get deleteFile => 'Delete file';

  @override
  String get renameDirectory => 'Rename directory';

  @override
  String get renameFile => 'Rename file';

  @override
  String get newName => 'New name';

  @override
  String get fileNameEmpty => 'A name is required';

  @override
  String get fileNameLeadingOrTrailingWhitespace =>
      'A name cannot start or end with whitespace';

  @override
  String get fileNameReserved => 'This reserved name cannot be used';

  @override
  String get fileNameTrailingDot => 'A name cannot end with a dot';

  @override
  String get fileNamePathSeparatorOrNull =>
      'A name cannot contain a path separator or null character';

  @override
  String get fileNameUnsupportedCharacter =>
      'A name contains characters unsupported across platforms';

  @override
  String get fileNameReservedSystemName => 'This is a reserved system name';

  @override
  String get fileNameTooLong => 'A name cannot exceed 255 UTF-8 bytes';

  @override
  String get name => 'Name';

  @override
  String get type => 'Type';

  @override
  String get size => 'Size';

  @override
  String get modifiedTime => 'Modified';

  @override
  String get logicalPath => 'Logical path';

  @override
  String fileTypeWithExtension(String extension) {
    return '$extension file';
  }

  @override
  String get newFile => 'New file';

  @override
  String get newDirectory => 'New directory';

  @override
  String get newFileDefaultName => 'New file.txt';

  @override
  String get newDirectoryDefaultName => 'New directory';

  @override
  String get create => 'Create';

  @override
  String get directoryTreeReadFailed => 'Could not read directory tree';

  @override
  String get directoryTreeLoadMoreFailed => 'Could not load more directories';

  @override
  String get readingDirectories => 'Reading directories...';

  @override
  String get loadMoreDirectories => 'Load more directories';

  @override
  String retryDirectoryTreeRead(String message) {
    return '$message. Refresh and try again.';
  }

  @override
  String get importOperation => 'import';

  @override
  String get exportOperation => 'export';

  @override
  String get batchExportOperation => 'batch export';

  @override
  String get pasteOperation => 'paste';

  @override
  String get batchPasteOperation => 'batch paste';

  @override
  String get copySuffix => 'copy';

  @override
  String get conflictTargetExists => 'Destination already exists';

  @override
  String get conflictReplacementUnavailable =>
      'The source and destination types are incompatible, or they are the same entry. Choose Keep both to create a new name.';

  @override
  String get conflictDirectoryReplaceDetail =>
      'Merge and replace keeps content unique to the destination directory and replaces files with the same name.';

  @override
  String get conflictFileReplaceDetail =>
      'Replace overwrites the existing file with the new content.';

  @override
  String conflictDescription(String name, String operation, String detail) {
    return '\"$name\" already exists and cannot be directly $operation.\n\n$detail';
  }

  @override
  String get keepBoth => 'Keep both';

  @override
  String get keepBothForAll => 'Keep both for all';

  @override
  String get mergeAndReplace => 'Merge and replace';

  @override
  String get replace => 'Replace';

  @override
  String get replaceForAll => 'Replace all';

  @override
  String batchOperationCancelled(String operation) {
    return '$operation cancelled';
  }

  @override
  String batchOperationPartiallyCompleted(String operation) {
    return '$operation partially completed';
  }

  @override
  String batchOperationCompleted(String operation) {
    return '$operation completed';
  }

  @override
  String batchTotal(int count) {
    return 'Total: $count';
  }

  @override
  String batchSucceeded(int count) {
    return 'Succeeded: $count';
  }

  @override
  String batchSkipped(int count) {
    return 'Skipped: $count';
  }

  @override
  String batchFailed(int count) {
    return 'Failed: $count';
  }

  @override
  String batchUnprocessed(int count) {
    return 'Unprocessed: $count';
  }

  @override
  String batchClipboardRemaining(int count) {
    return 'Remaining in clipboard: $count';
  }

  @override
  String get failureDetails => 'Failure details';

  @override
  String batchFailureItem(String name, String reason) {
    return '\"$name\": $reason';
  }

  @override
  String additionalFailures(int count) {
    return '$count more failures';
  }
}
