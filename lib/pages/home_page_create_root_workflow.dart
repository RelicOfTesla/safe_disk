import 'dart:io';

import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../models/create_root_options.dart';
import '../services/crypto_service.dart';
import '../services/settings_service.dart';
import '../utils/error_messages.dart';
import '../widgets/copyable_snackbar.dart';
import 'dialogs.dart';

class EncryptedDirectoryCreationResult {
  const EncryptedDirectoryCreationResult({
    required this.directory,
    required this.rootID,
  });

  final EncryptedDirectory directory;
  final int rootID;
}

/// Runs the create-root dialog and crypto operations, but leaves page state
/// updates to HomePage.
class HomePageCreateRootWorkflow {
  const HomePageCreateRootWorkflow({
    required this.cryptoService,
    required this.settingsService,
  });

  final CryptoService cryptoService;
  final SettingsService settingsService;

  Future<EncryptedDirectoryCreationResult?> run(
    BuildContext context,
    String selectedPath, {
    required bool Function() isMounted,
    required Future<void> Function(int rootID) revokeWebDavSessions,
    required void Function(bool loading) onLoadingChanged,
  }) async {
    final directory = Directory(selectedPath);
    try {
      final isNonEmpty = await directory.exists() &&
          !await directory.list(followLinks: false).isEmpty;
      if (isNonEmpty) {
        if (isMounted()) {
          ErrorHelper.showError(
            context,
            errorType: ErrorType.createEncryptedDirectoryRequiresEmpty,
            originalError: 'The selected directory is not empty: $selectedPath',
            operation: 'validate-create-root-path',
          );
        }
        return null;
      }
    } catch (error) {
      if (isMounted()) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.createEncryptedDirectoryFailed,
          originalError: error.toString(),
          operation: 'validate-create-root-path',
        );
      }
      return null;
    }

    final initialKeyStrengthMs = await settingsService.getKeyStrengthMs();
    if (!isMounted()) return null;
    final result = await showDialog<CreateRootRequest>(
      context: context,
      builder: (context) => CreateEncryptedDirectoryDialog(
        initialKeyStrengthMs: initialKeyStrengthMs,
      ),
    );
    if (result == null) return null;

    onLoadingChanged(true);
    var operation = 'create-root-config';
    try {
      cryptoService.createRootConfig(
        selectedPath,
        result.password,
        result.optionsJSON,
      );
      operation = 'open-created-root';
      final rootID = cryptoService.openRoot(selectedPath, result.password, '');
      await revokeWebDavSessions(rootID);
      operation = 'load-created-root-config';
      final config = cryptoService.loadConfig(selectedPath);
      return EncryptedDirectoryCreationResult(
        directory: EncryptedDirectory(
          path: selectedPath,
          config: config,
          isVerified: true,
          tempKeyID: rootID.toString(),
        ),
        rootID: rootID,
      );
    } catch (error) {
      if (isMounted()) {
        ErrorHelper.showError(
          context,
          errorType: ErrorType.createEncryptedDirectoryFailed,
          originalError: error.toString(),
          operation: operation,
        );
      }
      return null;
    } finally {
      onLoadingChanged(false);
    }
  }
}
