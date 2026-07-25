import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:flutter_ime/flutter_ime.dart';

/// Password verification prompt for unlocking an encrypted directory.
///
/// Manages its own [TextEditingController] and [FocusNode].
/// Calls [onUnlock] with the entered password.
class PasswordPrompt extends StatefulWidget {
  const PasswordPrompt({
    super.key,
    required this.directoryPath,
    required this.onUnlock,
    this.passwordHint = '',
  });

  /// Path of the directory to unlock (display only).
  final String directoryPath;

  /// Called when the user submits a password.
  /// The parent should verify the password and update state.
  /// If verification fails, the prompt will clear and refocus automatically.
  final Future<void> Function(String password) onUnlock;

  /// Public metadata. It is intentionally hidden until the user requests it.
  final String passwordHint;

  @override
  State<PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<PasswordPrompt> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;
  bool _showPasswordHint = false;

  @override
  void initState() {
    super.initState();
    // Disable IME on focus to prevent CJK composition window freeze
    // (Windows: detaches IME context; other platforms: no-op).
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        disableIME();
      } else {
        enableIME();
      }
    });
    // Auto-focus after first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Restore IME before disposing.
    enableIME();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      await widget.onUnlock(_controller.text);
      // If still mounted and verification likely failed
      // (parent would have rebuilt if successful), refocus.
      if (mounted) {
        _controller.clear();
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 48),
            const SizedBox(height: 16),
            Text(
              strings.unlockDirectoryPrompt,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.directoryPath,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (widget.passwordHint.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() => _showPasswordHint = !_showPasswordHint);
                },
                icon: Icon(_showPasswordHint
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                label: Text(_showPasswordHint
                    ? strings.hidePasswordHint
                    : strings.showPasswordHint),
              ),
              if (_showPasswordHint) ...[
                const SizedBox(height: 4),
                Text(
                  widget.passwordHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  strings.passwordHintPublicNotice,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              // Restrict to ASCII printable to prevent IME composition window
              // from opening (ibus/fcitx can cause UI freeze on Linux).
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
              ],
              keyboardType: TextInputType.visiblePassword,
              enableInteractiveSelection: true,
              enabled: !_isVerifying,
              decoration: InputDecoration(
                labelText: strings.password,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying ? null : _handleSubmit,
              child: _isVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(strings.unlock),
            ),
          ],
        ),
      ),
    );
  }
}
