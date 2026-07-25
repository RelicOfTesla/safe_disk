import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'ime_safe_password_field.dart';

class RootPasswordChangeRequest {
  const RootPasswordChangeRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  final String oldPassword;
  final String newPassword;
}

Future<RootPasswordChangeRequest?> showRootPasswordChangeDialog({
  required BuildContext context,
  required String directoryName,
}) {
  return showDialog<RootPasswordChangeRequest>(
    context: context,
    builder: (_) => _RootPasswordChangeDialog(directoryName: directoryName),
  );
}

class _RootPasswordChangeDialog extends StatefulWidget {
  const _RootPasswordChangeDialog({required this.directoryName});

  final String directoryName;

  @override
  State<_RootPasswordChangeDialog> createState() =>
      _RootPasswordChangeDialogState();
}

class _RootPasswordChangeDialogState extends State<_RootPasswordChangeDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final strings = AppLocalizations.of(context)!;
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (oldPassword.isEmpty || newPassword.isEmpty) {
      setState(() => _validationMessage = strings.passwordChangeFieldsRequired);
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      setState(() => _validationMessage = strings.newPasswordsDoNotMatch);
      return;
    }
    Navigator.pop(
      context,
      RootPasswordChangeRequest(
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.changePassword),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.directoryLabel(widget.directoryName)),
            const SizedBox(height: 12),
            Text(strings.passwordChangeDescription),
            const SizedBox(height: 16),
            ImeSafePasswordField(
              textFieldKey: const Key('root-password-current'),
              controller: _oldPasswordController,
              labelText: strings.currentPassword,
              onSubmitted: (_) => _submit(),
            ),
            ImeSafePasswordField(
              textFieldKey: const Key('root-password-new'),
              controller: _newPasswordController,
              labelText: strings.newPassword,
              onSubmitted: (_) => _submit(),
            ),
            ImeSafePasswordField(
              textFieldKey: const Key('root-password-confirm'),
              controller: _confirmPasswordController,
              labelText: strings.confirmNewPassword,
              onSubmitted: (_) => _submit(),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(strings.changePassword)),
      ],
    );
  }
}
