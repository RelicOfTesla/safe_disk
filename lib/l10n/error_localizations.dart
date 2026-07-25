import '../utils/error_messages.dart';
import '../utils/error_diagnostics.dart';
import 'generated/app_localizations.dart';

/// 把稳定错误语义解析为当前 locale 的用户可见文本。
extension ErrorLocalizations on AppLocalizations {
  ErrorDiagnosticsLabels errorDiagnosticsLabels() {
    return ErrorDiagnosticsLabels(
      errorType: errorDiagnosticType,
      operation: errorDiagnosticOperation,
      underlyingError: underlyingError,
      redacted: errorDiagnosticRedacted,
      pathRedacted: errorDiagnosticPathRedacted,
      truncated: errorDiagnosticTruncated,
    );
  }

  ErrorMessage errorMessage(ErrorType type) {
    final descriptor = ErrorMessages.descriptor(type);
    final (title, description, suggestion) = switch (type) {
      ErrorType.directoryNotVerified => (
          errorDirectoryNotVerifiedTitle,
          errorDirectoryNotVerifiedDescription,
          errorDirectoryNotVerifiedSuggestion,
        ),
      ErrorType.sessionExpired => (
          errorSessionExpiredTitle,
          errorSessionExpiredDescription,
          errorSessionExpiredSuggestion,
        ),
      ErrorType.invalidPassword => (
          errorInvalidPasswordTitle,
          errorInvalidPasswordDescription,
          errorInvalidPasswordSuggestion,
        ),
      ErrorType.directoryNotExist => (
          errorDirectoryNotExistTitle,
          errorDirectoryNotExistDescription,
          errorDirectoryNotExistSuggestion,
        ),
      ErrorType.notEncryptedDirectory => (
          errorNotEncryptedDirectoryTitle,
          errorNotEncryptedDirectoryDescription,
          errorNotEncryptedDirectorySuggestion,
        ),
      ErrorType.loadConfigFailed => (
          errorLoadConfigFailedTitle,
          errorLoadConfigFailedDescription,
          errorLoadConfigFailedSuggestion,
        ),
      ErrorType.loadDirectoryFailed => (
          errorLoadDirectoryFailedTitle,
          errorLoadDirectoryFailedDescription,
          errorLoadDirectoryFailedSuggestion,
        ),
      ErrorType.loadSettingsFailed => (
          settingsLoadFailed,
          settingsLoadDescription,
          settingsLoadSuggestion,
        ),
      ErrorType.saveSettingsFailed => (
          settingsSaveFailed,
          settingsNotSaved,
          settingsSaveSuggestion,
        ),
      ErrorType.unfinishedTransferStateUnavailable => (
          errorUnfinishedTransferStateUnavailableTitle,
          errorUnfinishedTransferStateUnavailableDescription,
          errorUnfinishedTransferStateUnavailableSuggestion,
        ),
      ErrorType.createEncryptedDirectoryFailed => (
          errorCreateEncryptedDirectoryFailedTitle,
          errorCreateEncryptedDirectoryFailedDescription,
          errorCreateEncryptedDirectoryFailedSuggestion,
        ),
      ErrorType.createEncryptedDirectoryRequiresEmpty => (
          errorCreateEncryptedDirectoryRequiresEmptyTitle,
          errorCreateEncryptedDirectoryRequiresEmptyDescription,
          errorCreateEncryptedDirectoryRequiresEmptySuggestion,
        ),
      ErrorType.importFileFailed => (
          errorImportFileFailedTitle,
          errorImportFileFailedDescription,
          errorImportFileFailedSuggestion,
        ),
      ErrorType.importDirectoryFailed => (
          errorImportDirectoryFailedTitle,
          errorImportDirectoryFailedDescription,
          errorImportDirectoryFailedSuggestion,
        ),
      ErrorType.importDirectoryInsideCurrentRoot => (
          errorImportDirectoryInsideCurrentRootTitle,
          errorImportDirectoryInsideCurrentRootDescription,
          errorImportDirectoryInsideCurrentRootSuggestion,
        ),
      ErrorType.exportFileFailed => (
          errorExportFileFailedTitle,
          errorExportFileFailedDescription,
          errorExportFileFailedSuggestion,
        ),
      ErrorType.exportDirectoryFailed => (
          errorExportDirectoryFailedTitle,
          errorExportDirectoryFailedDescription,
          errorExportDirectoryFailedSuggestion,
        ),
      ErrorType.deleteFileFailed => (
          errorDeleteFileFailedTitle,
          errorDeleteFileFailedDescription,
          errorDeleteFileFailedSuggestion,
        ),
      ErrorType.saveFileFailed => (
          errorSaveFileFailedTitle,
          errorSaveFileFailedDescription,
          errorSaveFileFailedSuggestion,
        ),
      ErrorType.loadFileFailed => (
          errorLoadFileFailedTitle,
          errorLoadFileFailedDescription,
          errorLoadFileFailedSuggestion,
        ),
      ErrorType.noDirectorySelected => (
          errorNoDirectorySelectedTitle,
          errorNoDirectorySelectedDescription,
          null,
        ),
      ErrorType.noFileSelected => (
          errorNoFileSelectedTitle,
          errorNoFileSelectedDescription,
          null,
        ),
      ErrorType.passwordEmpty => (
          errorPasswordEmptyTitle,
          errorPasswordEmptyDescription,
          null,
        ),
      ErrorType.passwordMismatch => (
          errorPasswordMismatchTitle,
          errorPasswordMismatchDescription,
          errorPasswordMismatchSuggestion,
        ),
      ErrorType.pathEmpty => (
          errorPathEmptyTitle,
          errorPathEmptyDescription,
          null,
        ),
      ErrorType.dataCorrupted => (
          errorDataCorruptedTitle,
          errorDataCorruptedDescription,
          errorDataCorruptedSuggestion,
        ),
      ErrorType.operationFailed => (
          errorOperationFailedTitle,
          errorOperationFailedDescription,
          errorOperationFailedSuggestion,
        ),
    };

    return ErrorMessage(
      title: title,
      description: description,
      suggestion: suggestion,
      isCritical: descriptor.isCritical,
    );
  }

  String errorFullMessage(ErrorType type) {
    final error = errorMessage(type);
    if (error.suggestion == null) return error.description;
    return '${error.description}\n\n$errorSuggestionPrefix${error.suggestion}';
  }
}
