import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'ime_safe_password_field.dart';

class RootPasswordHintRequest {
  const RootPasswordHintRequest({
    required this.password,
    required this.hint,
  });

  final String password;
  final String hint;
}

Future<RootPasswordHintRequest?> showRootPasswordHintDialog({
  required BuildContext context,
  required String directoryName,
  required String currentHint,
}) {
  return showDialog<RootPasswordHintRequest>(
    context: context,
    builder: (_) => _RootPasswordHintDialog(
      directoryName: directoryName,
      currentHint: currentHint,
    ),
  );
}

class _RootPasswordHintDialog extends StatefulWidget {
  const _RootPasswordHintDialog({
    required this.directoryName,
    required this.currentHint,
  });

  final String directoryName;
  final String currentHint;

  @override
  State<_RootPasswordHintDialog> createState() =>
      _RootPasswordHintDialogState();
}

class _RootPasswordHintDialogState extends State<_RootPasswordHintDialog> {
  late final TextEditingController _hintController;
  final _passwordController = TextEditingController();
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _hintController = TextEditingController(text: widget.currentHint);
  }

  @override
  void dispose() {
    _hintController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final strings = AppLocalizations.of(context)!;
    if (_passwordController.text.isEmpty) {
      setState(() => _validationMessage = strings.passwordHintPasswordRequired);
      return;
    }
    if (utf8.encode(_hintController.text).length > 256) {
      setState(() => _validationMessage = strings.passwordHintTooLong);
      return;
    }
    Navigator.pop(
      context,
      RootPasswordHintRequest(
        password: _passwordController.text,
        hint: _hintController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.managePasswordHint),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.directoryLabel(widget.directoryName)),
            const SizedBox(height: 12),
            Text(strings.passwordHintEditNotice),
            const SizedBox(height: 16),
            TextField(
              key: const Key('root-password-hint'),
              controller: _hintController,
              minLines: 2,
              maxLines: 3,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: strings.passwordHint),
            ),
            const SizedBox(height: 12),
            ImeSafePasswordField(
              textFieldKey: const Key('root-password-hint-current-password'),
              controller: _passwordController,
              labelText: strings.currentPassword,
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
        FilledButton(
          onPressed: _submit,
          child: Text(strings.savePasswordHint),
        ),
      ],
    );
  }
}
