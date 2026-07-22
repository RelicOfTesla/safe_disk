import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';

class PropertyValue {
  const PropertyValue(this.label, this.value, {this.copyable = true});

  final String label;
  final String value;
  final bool copyable;
}

Future<void> showPropertyOverlay({
  required BuildContext context,
  required String title,
  required List<PropertyValue> values,
  Widget? notice,
  Widget Function(BuildContext context, VoidCallback close)? actionsBuilder,
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
      actionsBuilder: actionsBuilder,
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
    this.actionsBuilder,
  });

  final String title;
  final List<PropertyValue> values;
  final Widget? notice;
  final Widget Function(BuildContext context, VoidCallback close)?
      actionsBuilder;
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
                              if (actionsBuilder != null) ...[
                                const SizedBox(height: 8),
                                actionsBuilder!(context, onClose),
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
    final displayValue = value.value.isEmpty ? strings.unknown : value.value;
    final canCopy = value.copyable && value.value.isNotEmpty;
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
            child: SelectableText(
              displayValue,
              key: Key('property-value-${value.label}'),
            ),
          ),
          if (canCopy)
            Semantics(
              button: true,
              label: strings.copyPropertyValue(value.label),
              child: IconButton(
                key: Key('copy-property-${value.label}'),
                tooltip: strings.copyPropertyValue(value.label),
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _copyValue(context),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyValue(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value.value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.propertyValueCopied)),
    );
  }
}
