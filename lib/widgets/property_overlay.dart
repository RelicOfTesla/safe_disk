import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

class PropertyValue {
  const PropertyValue(this.label, this.value);

  final String label;
  final String value;
}

Future<void> showPropertyOverlay({
  required BuildContext context,
  required String title,
  required List<PropertyValue> values,
  Widget? notice,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completed = Completer<void>();
  late final OverlayEntry entry;
  var closed = false;

  void close() {
    if (closed) return;
    closed = true;
    entry.remove();
    completed.complete();
  }

  entry = OverlayEntry(
    builder: (_) => _PropertyOverlay(
      title: title,
      values: values,
      notice: notice,
      onClose: close,
    ),
  );
  overlay.insert(entry);
  return completed.future;
}

class _PropertyOverlay extends StatelessWidget {
  const _PropertyOverlay({
    required this.title,
    required this.values,
    required this.onClose,
    this.notice,
  });

  final String title;
  final List<PropertyValue> values;
  final Widget? notice;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('property-overlay-barrier'),
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
              ),
            ),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: title,
                  child: Material(
                    key: const Key('property-overlay'),
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        maxHeight: MediaQuery.sizeOf(context).height - 48,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 20),
                              for (final value in values)
                                _PropertyRow(value: value),
                              if (notice != null) ...[
                                const SizedBox(height: 4),
                                notice!,
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: onClose,
                                  child: Text(strings.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.value});

  final PropertyValue value;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              strings.propertyLabel(value.label),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value.value.isEmpty ? strings.unknown : value.value),
          ),
        ],
      ),
    );
  }
}
