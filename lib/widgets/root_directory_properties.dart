import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/cryption_config.dart';
import '../models/logical_path.dart';
import 'property_overlay.dart';

Future<void> showRootDirectoryProperties({
  required BuildContext context,
  required EncryptedDirectory directory,
  Future<void> Function()? onManagePasswordHint,
}) {
  final strings = AppLocalizations.of(context)!;
  final config = directory.config.toJson();
  final displayName = directory.displayAlias?.trim().isNotEmpty == true
      ? directory.displayAlias!
      : logicalPathBasename(directory.path);
  final values = <PropertyValue>[
    PropertyValue(strings.displayName, displayName),
    PropertyValue(strings.diskPath, directory.path),
    PropertyValue(
      strings.currentStatus,
      directory.isVerified
          ? strings.directoryUnlocked
          : strings.directoryLocked,
    ),
    PropertyValue(strings.directoryFormat, directory.config.version),
    PropertyValue(
      strings.dataEncryption,
      _configString(config, 'sec_fs_factory', strings.unknown),
    ),
    PropertyValue(
      strings.nameEncryption,
      _configString(config, 'sec_name_factory', strings.unknown),
    ),
    PropertyValue(
      strings.passwordDerivation,
      _configString(config, 'sec_deriver_factory', strings.unknown),
    ),
    PropertyValue(
      strings.passwordVerification,
      config['sec_password_verifier_version'] is int
          ? strings.versionValue(config['sec_password_verifier_version'] as int)
          : strings.unavailableOrLegacy,
    ),
    PropertyValue(
      strings.passwordChange,
      rootSupportsPasswordChange(directory)
          ? strings.passwordChangeDirectly
          : strings.passwordChangeMigrationRequired,
    ),
    if (directory.isVerified)
      PropertyValue(
        strings.passwordHint,
        directory.config.passwordHint.isEmpty
            ? strings.passwordHintNotSet
            : directory.config.passwordHint,
        copyable: false,
      ),
  ];
  return showPropertyOverlay(
    context: context,
    title: strings.rootDirectoryProperties,
    values: values,
    notice: Text(strings.rootPropertiesSensitiveNotice),
    actionsBuilder: onManagePasswordHint == null
        ? null
        : (context, close) => Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  close();
                  unawaited(onManagePasswordHint());
                },
                child: Text(strings.managePasswordHint),
              ),
            ),
  );
}

bool rootSupportsPasswordChange(EncryptedDirectory directory) {
  return directory.config.toJson()['sec_key_envelope_version'] == 1;
}

Future<void> showUnsupportedRootPasswordChange({
  required BuildContext context,
  required EncryptedDirectory directory,
}) {
  final strings = AppLocalizations.of(context)!;
  return showPropertyOverlay(
    context: context,
    title: strings.passwordChange,
    values: [
      PropertyValue(
          strings.directory, directory.displayAlias ?? directory.path),
      PropertyValue(strings.status, strings.directoryCannotChangePassword),
      PropertyValue(
        strings.reason,
        strings.legacyPasswordChangeReason,
      ),
      PropertyValue(
        strings.safeApproach,
        strings.legacyPasswordChangeApproach,
      ),
    ],
  );
}

String _configString(Map<String, dynamic> config, String key, String unknown) {
  final value = config[key];
  return value is String && value.isNotEmpty ? value : unknown;
}
