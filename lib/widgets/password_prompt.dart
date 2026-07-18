import 'package:flutter/material.dart';

/// Password verification prompt for unlocking an encrypted directory.
///
/// Manages its own [TextEditingController] and [FocusNode].
/// Calls [onUnlock] with the entered password.
class PasswordPrompt extends StatefulWidget {
  const PasswordPrompt({
    super.key,
    required this.directoryPath,
    required this.onUnlock,
  });

  /// Path of the directory to unlock (display only).
  final String directoryPath;

  /// Called when the user submits a password.
  /// The parent should verify the password and update state.
  /// If verification fails, the prompt will clear and refocus automatically.
  final Future<void> Function(String password) onUnlock;

  @override
  State<PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<PasswordPrompt> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus after first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
              '请输入密码以解锁：',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.directoryPath,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              obscureText: true,
              enableInteractiveSelection: true,
              enabled: !_isVerifying,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
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
                  : const Text('解锁'),
            ),
          ],
        ),
      ),
    );
  }
}
