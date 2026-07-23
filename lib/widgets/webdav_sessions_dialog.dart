import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/webdav_service.dart';

/// Confirms that the user intends to hand a read-only plaintext capability to
/// a third-party client before the native session is created.
Future<bool> confirmWebDavReadOnlyExposure({
  required BuildContext context,
  required String displayName,
}) async {
  final strings = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.webDavExposureConfirmTitle),
          content: Text(strings.webDavExposureConfirmDescription(displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.webDavExposeReadOnly),
            ),
          ],
        ),
      ) ??
      false;
}

/// Lists process-local WebDAV sessions and allows explicit revocation.
Future<void> showWebDavSessionsDialog({
  required BuildContext context,
  required List<WebDavSessionStatus> sessions,
  required Future<bool> Function(WebDavSessionStatus session) onRevoke,
  required Future<List<WebDavSessionStatus>?> Function() onRefresh,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _WebDavSessionsDialog(
      initialSessions: sessions,
      onRevoke: onRevoke,
      onRefresh: onRefresh,
    ),
  );
}

class _WebDavSessionsDialog extends StatefulWidget {
  const _WebDavSessionsDialog({
    required this.initialSessions,
    required this.onRevoke,
    required this.onRefresh,
  });

  final List<WebDavSessionStatus> initialSessions;
  final Future<bool> Function(WebDavSessionStatus session) onRevoke;
  final Future<List<WebDavSessionStatus>?> Function() onRefresh;

  @override
  State<_WebDavSessionsDialog> createState() => _WebDavSessionsDialogState();
}

class _WebDavSessionsDialogState extends State<_WebDavSessionsDialog> {
  late final List<WebDavSessionStatus> _sessions =
      List.of(widget.initialSessions);
  String? _revokingID;
  bool _refreshing = false;

  Future<void> _revoke(WebDavSessionStatus session) async {
    if (_revokingID != null) return;
    setState(() => _revokingID = session.id);
    try {
      final revoked = await widget.onRevoke(session);
      if (revoked && mounted) {
        setState(() => _sessions.removeWhere((item) => item.id == session.id));
      }
    } finally {
      if (mounted) setState(() => _revokingID = null);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _revokingID != null) return;
    setState(() => _refreshing = true);
    try {
      final sessions = await widget.onRefresh();
      if (sessions != null && mounted) {
        setState(() {
          _sessions
            ..clear()
            ..addAll(sessions);
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.webDavSessionsTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SizedBox(
          width: 560,
          child: _sessions.isEmpty
              ? Text(strings.webDavNoActiveSessions)
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final revoking = _revokingID == session.id;
                    return _WebDavSessionTile(
                      session: session,
                      revoking: revoking,
                      onRevoke: () => _revoke(session),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _revokingID == null && !_refreshing ? _refresh : null,
          child: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.refresh),
        ),
        TextButton(
          onPressed: _revokingID == null && !_refreshing
              ? () => Navigator.pop(context)
              : null,
          child: Text(strings.close),
        ),
      ],
    );
  }
}

class _WebDavSessionTile extends StatelessWidget {
  const _WebDavSessionTile({
    required this.session,
    required this.revoking,
    required this.onRevoke,
  });

  final WebDavSessionStatus session;
  final bool revoking;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.displayName,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(strings.webDavReadOnly),
        const SizedBox(height: 8),
        _CapabilityValue(
          label: strings.webDavUrl,
          value: session.url,
          copiedMessage: strings.webDavUrlCopied,
        ),
        const SizedBox(height: 8),
        if (session.lastAccessedAt != null)
          Text(
            strings.webDavLastAccessed(
              DateFormat.yMMMd(strings.localeName)
                  .add_jm()
                  .format(session.lastAccessedAt!.toLocal()),
            ),
          ),
        if (session.activeRequests > 0)
          Text(strings.webDavActiveRequests(session.activeRequests)),
        if (session.lastAccessedAt != null || session.activeRequests > 0)
          const SizedBox(height: 8),
        Text(
          strings.webDavCapabilityWarning,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: revoking ? null : onRevoke,
          icon: revoking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_off_outlined),
          label: Text(strings.webDavRevoke),
        ),
      ],
    );
  }
}

/// Shows the URL and token once after creating a session. The session list
/// deliberately cannot recover the token from Go afterwards.
Future<void> showWebDavCredentialsDialog({
  required BuildContext context,
  required WebDavOpenedSession session,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final strings = AppLocalizations.of(dialogContext)!;
      return AlertDialog(
        title: Text(strings.webDavCredentialsTitle),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.webDavCredentialsDescription),
              const SizedBox(height: 12),
              _CapabilityValue(
                label: strings.webDavUrl,
                value: session.url,
                copiedMessage: strings.webDavUrlCopied,
              ),
              const SizedBox(height: 8),
              _CapabilityValue(
                label: strings.webDavToken,
                value: session.token,
                copiedMessage: strings.webDavTokenCopied,
              ),
              const SizedBox(height: 8),
              Text(
                strings.webDavCapabilityWarning,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.close),
          ),
        ],
      );
    },
  );
}

class _CapabilityValue extends StatelessWidget {
  const _CapabilityValue({
    required this.label,
    required this.value,
    required this.copiedMessage,
  });

  final String label;
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            Expanded(child: SelectableText(value)),
            IconButton(
              tooltip: AppLocalizations.of(context)!.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(copiedMessage)),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
