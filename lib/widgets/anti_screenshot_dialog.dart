import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

/// Step 1: Informational dialog explaining anti-screenshot before enabling.
///
/// Returns true if the user chooses to enable, false otherwise.
class AntiScreenshotInfoDialog extends StatelessWidget {
  final AppLocalizations strings;

  const AntiScreenshotInfoDialog({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(s.antiScreenshotInfoTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.antiScreenshotInfoDescription),
            const SizedBox(height: 12),
            Text(
              s.antiScreenshotEnvVarHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(s.antiScreenshotInfoEnable),
        ),
      ],
    );
  }
}

/// Step 2: Countdown confirmation dialog shown *after* anti-screenshot has
/// been enabled.  The setting is already active; if the user does not confirm
/// within [countdownSeconds] the dialog auto-closes with null and the caller
/// should revert the setting.
class AntiScreenshotCountdownDialog extends StatefulWidget {
  final AppLocalizations strings;
  final int countdownSeconds;

  const AntiScreenshotCountdownDialog({
    super.key,
    required this.strings,
    this.countdownSeconds = 15,
  });

  @override
  State<AntiScreenshotCountdownDialog> createState() =>
      _AntiScreenshotCountdownDialogState();
}

class _AntiScreenshotCountdownDialogState
    extends State<AntiScreenshotCountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.countdownSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _timer?.cancel();
          Navigator.of(context).pop(null); // timeout → revert
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(s.antiScreenshotCountdownTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.antiScreenshotCountdownHint(widget.countdownSeconds)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _remaining / widget.countdownSeconds,
            backgroundColor: cs.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          Text(
            '${_remaining}s',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(false);
          },
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context).pop(true);
          },
          child: Text(s.antiScreenshotCountdownConfirm),
        ),
      ],
    );
  }
}
