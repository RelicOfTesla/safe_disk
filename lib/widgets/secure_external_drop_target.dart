import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/drag_drop_controller.dart';

class SecureExternalDropTarget extends StatefulWidget {
  const SecureExternalDropTarget({
    super.key,
    required this.rootPath,
    required this.child,
    required this.onDrop,
    this.enabled = true,
  });

  final String rootPath;
  final Widget child;
  final ValueChanged<List<DragDropCandidate>> onDrop;
  final bool enabled;

  @override
  State<SecureExternalDropTarget> createState() =>
      _SecureExternalDropTargetState();
}

class _SecureExternalDropTargetState extends State<SecureExternalDropTarget> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        widget.onDrop([
          for (final item in details.files)
            DragDropCandidate(
              path: item.path,
              fromPromise: item.fromPromise,
            ),
        ]);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_dragging)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.72),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      AppLocalizations.of(context)!.dropImportHere,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
