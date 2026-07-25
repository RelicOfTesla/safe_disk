import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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

class WebDavOpenOptions {
  const WebDavOpenOptions({
    required this.authMode,
    required this.credentialVisibility,
    required this.sessionLifetime,
    required this.tls,
    required this.writePolicy,
  });

  final WebDavAuthMode authMode;
  final WebDavCredentialVisibility credentialVisibility;
  final WebDavSessionLifetime sessionLifetime;
  final bool tls;
  final WebDavWritePolicy writePolicy;
}

/// Keeps the security confirmation separate, but collects the three session
/// policy choices in one place so opening a session is not a dialog chain.
Future<WebDavOpenOptions?> chooseWebDavOpenOptions({
  required BuildContext context,
  required WebDavService webdavService,
}) async {
  final strings = AppLocalizations.of(context)!;
  var authMode = WebDavAuthMode.bearer;
  var credentialVisibility = WebDavCredentialVisibility.once;
  var sessionLifetime = WebDavSessionLifetime.ephemeral;
  var writePolicy = WebDavWritePolicy.readOnly;
  var tls = false;
  return showDialog<WebDavOpenOptions>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(strings.webDavOptionsTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.webDavOptionsDescription),
                const SizedBox(height: 16),
                Text(strings.webDavAuthModeTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(strings.webDavAuthModeDescription),
                RadioGroup<WebDavAuthMode>(
                  groupValue: authMode,
                  onChanged: (value) {
                    if (value != null) setState(() => authMode = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<WebDavAuthMode>(
                        value: WebDavAuthMode.bearer,
                        title: Text(strings.webDavAuthBearer),
                      ),
                      RadioListTile<WebDavAuthMode>(
                        value: WebDavAuthMode.digest,
                        title: Text(strings.webDavAuthDigest),
                      ),
                      RadioListTile<WebDavAuthMode>(
                        value: WebDavAuthMode.basic,
                        title: Text(strings.webDavAuthBasic),
                        subtitle: Text(strings.webDavBasicRiskWarning),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Text(strings.webDavCredentialVisibilityTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(strings.webDavCredentialVisibilityDescription),
                RadioGroup<WebDavCredentialVisibility>(
                  groupValue: credentialVisibility,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => credentialVisibility = value);
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<WebDavCredentialVisibility>(
                        value: WebDavCredentialVisibility.once,
                        title: Text(strings.webDavCredentialOnce),
                      ),
                      RadioListTile<WebDavCredentialVisibility>(
                        value: WebDavCredentialVisibility.persistent,
                        title: Text(strings.webDavCredentialPersistent),
                      ),
                    ],
                  ),
                ),
                if (credentialVisibility ==
                    WebDavCredentialVisibility.persistent)
                  Text(
                    strings.webDavPersistentCredentialWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Divider(),
                CheckboxListTile(
                  value: tls,
                  title: Text(strings.webDavTLS),
                  subtitle: Text(strings.webDavTLSDescription),
                  onChanged: (v) {
                    if (v != null) setState(() => tls = v);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                if (tls)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _exportCaCert(context, webdavService),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(strings.webDavExportCert),
                    ),
                  ),
                const Divider(),
                Text(strings.webDavSessionLifetimeTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(strings.webDavSessionLifetimeDescription),
                RadioGroup<WebDavSessionLifetime>(
                  groupValue: sessionLifetime,
                  onChanged: (value) {
                    if (value != null) setState(() => sessionLifetime = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<WebDavSessionLifetime>(
                        value: WebDavSessionLifetime.ephemeral,
                        title: Text(strings.webDavSessionEphemeral),
                      ),
                      RadioListTile<WebDavSessionLifetime>(
                        value: WebDavSessionLifetime.persistent,
                        title: Text(strings.webDavSessionPersistent),
                      ),
                    ],
                  ),
                ),
                if (sessionLifetime == WebDavSessionLifetime.persistent)
                  Text(
                    strings.webDavPersistentSessionWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const Divider(),
                Text(strings.webDavWritePolicyTitle,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(strings.webDavWritePolicyDescription),
                RadioGroup<WebDavWritePolicy>(
                  groupValue: writePolicy,
                  onChanged: (value) {
                    if (value != null) setState(() => writePolicy = value);
                  },
                  child: Column(
                    children: [
                      RadioListTile<WebDavWritePolicy>(
                        value: WebDavWritePolicy.readOnly,
                        title: Text(strings.webDavWritePolicyReadOnly),
                      ),
                      RadioListTile<WebDavWritePolicy>(
                        value: WebDavWritePolicy.silent,
                        title: Text(strings.webDavWritePolicySilent),
                      ),
                      RadioListTile<WebDavWritePolicy>(
                        value: WebDavWritePolicy.reviewCreate,
                        title: Text(strings.webDavWritePolicyReviewCreate),
                      ),
                    ],
                  ),
                ),
                if (writePolicy == WebDavWritePolicy.silent)
                  Text(
                    strings.webDavWritePolicySilentWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (writePolicy == WebDavWritePolicy.reviewCreate)
                  Text(
                    strings.webDavWritePolicyReviewCreateWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              WebDavOpenOptions(
                authMode: authMode,
                credentialVisibility: credentialVisibility,
                sessionLifetime: sessionLifetime,
                tls: tls,
                writePolicy: writePolicy,
              ),
            ),
            child: Text(strings.webDavAuthContinue),
          ),
        ],
      ),
    ),
  );
}

Future<WebDavAuthMode?> chooseWebDavAuthMode({
  required BuildContext context,
}) async {
  final strings = AppLocalizations.of(context)!;
  var selected = WebDavAuthMode.bearer;
  return showDialog<WebDavAuthMode>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(strings.webDavAuthModeTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.webDavAuthModeDescription),
              const SizedBox(height: 12),
              RadioGroup<WebDavAuthMode>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
                child: Column(
                  children: [
                    RadioListTile<WebDavAuthMode>(
                      value: WebDavAuthMode.bearer,
                      title: Text(strings.webDavAuthBearer),
                    ),
                    RadioListTile<WebDavAuthMode>(
                      value: WebDavAuthMode.digest,
                      title: Text(strings.webDavAuthDigest),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: Text(strings.webDavAuthContinue),
          ),
        ],
      ),
    ),
  );
}

Future<WebDavCredentialVisibility?> chooseWebDavCredentialVisibility({
  required BuildContext context,
}) async {
  final strings = AppLocalizations.of(context)!;
  var selected = WebDavCredentialVisibility.once;
  return showDialog<WebDavCredentialVisibility>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(strings.webDavCredentialVisibilityTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.webDavCredentialVisibilityDescription),
              const SizedBox(height: 12),
              RadioGroup<WebDavCredentialVisibility>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
                child: Column(
                  children: [
                    RadioListTile<WebDavCredentialVisibility>(
                      value: WebDavCredentialVisibility.once,
                      title: Text(strings.webDavCredentialOnce),
                    ),
                    RadioListTile<WebDavCredentialVisibility>(
                      value: WebDavCredentialVisibility.persistent,
                      title: Text(strings.webDavCredentialPersistent),
                    ),
                  ],
                ),
              ),
              if (selected == WebDavCredentialVisibility.persistent) ...[
                const SizedBox(height: 8),
                Text(
                  strings.webDavPersistentCredentialWarning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: Text(strings.webDavAuthContinue),
          ),
        ],
      ),
    ),
  );
}

Future<WebDavSessionLifetime?> chooseWebDavSessionLifetime({
  required BuildContext context,
}) async {
  final strings = AppLocalizations.of(context)!;
  var selected = WebDavSessionLifetime.ephemeral;
  return showDialog<WebDavSessionLifetime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(strings.webDavSessionLifetimeTitle),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.webDavSessionLifetimeDescription),
              const SizedBox(height: 12),
              RadioGroup<WebDavSessionLifetime>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) setState(() => selected = value);
                },
                child: Column(
                  children: [
                    RadioListTile<WebDavSessionLifetime>(
                      value: WebDavSessionLifetime.ephemeral,
                      title: Text(strings.webDavSessionEphemeral),
                    ),
                    RadioListTile<WebDavSessionLifetime>(
                      value: WebDavSessionLifetime.persistent,
                      title: Text(strings.webDavSessionPersistent),
                    ),
                  ],
                ),
              ),
              if (selected == WebDavSessionLifetime.persistent) ...[
                const SizedBox(height: 8),
                Text(
                  strings.webDavPersistentSessionWarning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: Text(strings.webDavAuthContinue),
          ),
        ],
      ),
    ),
  );
}

/// Lists process-local WebDAV sessions and allows explicit revocation.
Future<void> showWebDavSessionsDialog({
  required BuildContext context,
  required List<WebDavSessionStatus> sessions,
  required Future<bool> Function(WebDavSessionStatus session) onRevoke,
  required Future<bool> Function(WebDavSessionStatus session) onMount,
  required Future<bool> Function(WebDavSessionStatus session) onUnmount,
  Future<bool> Function(WebDavSessionStatus session)? onCancelMount,
  required Future<bool> Function(WebDavSessionStatus session) onReveal,
  required Future<List<WebDavSessionStatus>?> Function() onRefresh,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _WebDavSessionsDialog(
      initialSessions: sessions,
      onRevoke: onRevoke,
      onMount: onMount,
      onUnmount: onUnmount,
      onCancelMount: onCancelMount,
      onReveal: onReveal,
      onRefresh: onRefresh,
    ),
  );
}

class _WebDavSessionsDialog extends StatefulWidget {
  const _WebDavSessionsDialog({
    required this.initialSessions,
    required this.onRevoke,
    required this.onMount,
    required this.onUnmount,
    this.onCancelMount,
    required this.onReveal,
    required this.onRefresh,
  });

  final List<WebDavSessionStatus> initialSessions;
  final Future<bool> Function(WebDavSessionStatus session) onRevoke;
  final Future<bool> Function(WebDavSessionStatus session) onMount;
  final Future<bool> Function(WebDavSessionStatus session) onUnmount;
  final Future<bool> Function(WebDavSessionStatus session)? onCancelMount;
  final Future<bool> Function(WebDavSessionStatus session) onReveal;
  final Future<List<WebDavSessionStatus>?> Function() onRefresh;

  @override
  State<_WebDavSessionsDialog> createState() => _WebDavSessionsDialogState();
}

class _WebDavSessionsDialogState extends State<_WebDavSessionsDialog> {
  late final List<WebDavSessionStatus> _sessions =
      List.of(widget.initialSessions);
  String? _revokingID;
  String? _mountingID;
  bool _cancellingMount = false;
  String? _revealingID;
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
    if (_refreshing ||
        _revokingID != null ||
        _mountingID != null ||
        _revealingID != null) {
      return;
    }
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

  Future<void> _setMount(WebDavSessionStatus session) async {
    if (_mountingID != null || _revokingID != null || _revealingID != null) {
      return;
    }
    setState(() => _mountingID = session.id);
    try {
      final changed = session.mounted
          ? await widget.onUnmount(session)
          : await widget.onMount(session);
      if (changed && mounted) {
        final sessions = await widget.onRefresh();
        if (sessions != null) {
          setState(() {
            _sessions
              ..clear()
              ..addAll(sessions);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _mountingID = null;
          _cancellingMount = false;
        });
      }
    }
  }

  Future<void> _cancelMount(WebDavSessionStatus session) async {
    final cancel = widget.onCancelMount;
    if (cancel == null || _mountingID != session.id || _cancellingMount) {
      return;
    }
    setState(() => _cancellingMount = true);
    final accepted = await cancel(session);
    if (!accepted && mounted) setState(() => _cancellingMount = false);
  }

  Future<void> _reveal(WebDavSessionStatus session) async {
    if (_revealingID != null || _revokingID != null || _mountingID != null) {
      return;
    }
    setState(() => _revealingID = session.id);
    try {
      await widget.onReveal(session);
    } finally {
      if (mounted) setState(() => _revealingID = null);
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
                    final mounting = _mountingID == session.id;
                    final revealing = _revealingID == session.id;
                    return _WebDavSessionTile(
                      session: session,
                      revoking: revoking,
                      mounting: mounting,
                      cancellingMount: mounting && _cancellingMount,
                      revealing: revealing,
                      onRevoke: () => _revoke(session),
                      onMount: () => _setMount(session),
                      onCancelMount: widget.onCancelMount == null
                          ? null
                          : () => _cancelMount(session),
                      onReveal: () => _reveal(session),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _revokingID == null &&
                  _mountingID == null &&
                  _revealingID == null &&
                  !_refreshing
              ? _refresh
              : null,
          child: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.refresh),
        ),
        TextButton(
          onPressed: _revokingID == null &&
                  _mountingID == null &&
                  _revealingID == null &&
                  !_refreshing
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
    required this.mounting,
    required this.cancellingMount,
    required this.revealing,
    required this.onRevoke,
    required this.onMount,
    this.onCancelMount,
    required this.onReveal,
  });

  final WebDavSessionStatus session;
  final bool revoking;
  final bool mounting;
  final bool cancellingMount;
  final bool revealing;
  final VoidCallback onRevoke;
  final VoidCallback onMount;
  final VoidCallback? onCancelMount;
  final VoidCallback onReveal;

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
        const SizedBox(height: 4),
        Text(
          switch (session.authMode) {
            WebDavAuthMode.bearer => strings.webDavAuthModeBearer,
            WebDavAuthMode.digest => strings.webDavAuthModeDigest,
            WebDavAuthMode.basic => strings.webDavAuthModeBasic,
          },
        ),
        const SizedBox(height: 4),
        Text(
          session.sessionLifetime == WebDavSessionLifetime.persistent
              ? strings.webDavSessionPersistent
              : strings.webDavSessionEphemeral,
        ),
        if (session.mounted) ...[
          const SizedBox(height: 4),
          Text(strings.webDavMounted),
          if (session.mountPath != null)
            _CapabilityValue(
              key: const ValueKey('webdav-mount-path'),
              label: strings.webDavMountPath,
              value: session.mountPath!,
              copiedMessage: strings.webDavMountPathCopied,
            ),
        ],
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (session.credentialVisibility ==
                WebDavCredentialVisibility.persistent)
              OutlinedButton.icon(
                onPressed: revoking || mounting || revealing ? null : onReveal,
                icon: revealing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: Text(strings.webDavRevealCredentials),
              ),
            if (session.authMode != WebDavAuthMode.bearer)
              OutlinedButton.icon(
                onPressed: revoking || revealing
                    ? null
                    : mounting
                        ? (cancellingMount ? null : onCancelMount)
                        : onMount,
                icon: mounting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(session.mounted
                        ? Icons.eject_outlined
                        : Icons.folder_outlined),
                label: Text(mounting
                    ? strings.webDavCancelMount
                    : session.mounted
                        ? strings.webDavUnmount
                        : strings.webDavMount),
              ),
            OutlinedButton.icon(
              onPressed: revoking || mounting || revealing ? null : onRevoke,
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
              Text(
                switch (session.authMode) {
                  WebDavAuthMode.bearer => strings.webDavCredentialsDescription,
                  WebDavAuthMode.digest => strings.webDavDigestCredentialsDescription,
                  WebDavAuthMode.basic => strings.webDavBasicCredentialsDescription,
                },
              ),
              if (session.credentialVisibility ==
                  WebDavCredentialVisibility.persistent) ...[
                const SizedBox(height: 8),
                Text(
                  strings.webDavPersistentCredentialWarning,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              _CapabilityValue(
                label: strings.webDavUrl,
                value: session.url,
                copiedMessage: strings.webDavUrlCopied,
              ),
              const SizedBox(height: 8),
              if (session.authMode == WebDavAuthMode.bearer)
                _CapabilityValue(
                  label: strings.webDavToken,
                  value: session.token!,
                  copiedMessage: strings.webDavTokenCopied,
                )
              else ...[
                _CapabilityValue(
                  label: strings.webDavUsername,
                  value: session.username!,
                  copiedMessage: strings.webDavUsernameCopied,
                ),
                const SizedBox(height: 8),
                _CapabilityValue(
                  label: strings.webDavPassword,
                  value: session.password!,
                  copiedMessage: strings.webDavPasswordCopied,
                ),
                const SizedBox(height: 8),
                if (session.authMode == WebDavAuthMode.digest && session.realm != null)
                  _CapabilityValue(
                    label: strings.webDavRealm,
                    value: session.realm!,
                    copiedMessage: strings.webDavRealmCopied,
                  ),
              ],
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

class _CapabilityValue extends StatefulWidget {
  const _CapabilityValue({
    super.key,
    required this.label,
    required this.value,
    required this.copiedMessage,
  });

  final String label;
  final String value;
  final String copiedMessage;

  @override
  State<_CapabilityValue> createState() => _CapabilityValueState();
}

class _CapabilityValueState extends State<_CapabilityValue> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            Expanded(child: SelectableText(widget.value)),
            IconButton(
              tooltip: AppLocalizations.of(context)!.copy,
              onPressed: () {
                unawaited(
                  Clipboard.setData(ClipboardData(text: widget.value)),
                );
                if (!mounted) return;
                setState(() => _copied = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.copiedMessage)),
                );
              },
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
        if (_copied)
          Text(
            widget.copiedMessage,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}


/// Exports the CA certificate PEM to the downloads directory and shows
/// platform-specific import instructions.
Future<void> _exportCaCert(BuildContext context, WebDavService webdavService) async {
  final strings = AppLocalizations.of(context)!;
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  try {
    final pem = webdavService.exportCACertPEM();

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      throw StateError('downloads-dir-unavailable');
    }

    final file = File('${downloadsDir.path}${Platform.pathSeparator}safe-disk-ca.crt');
    await file.writeAsString(pem);
    final filePath = file.path;

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.webDavCertSaved),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.webDavCaCertNote),
                const SizedBox(height: 12),
                Text(filePath, style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(strings.webDavExportCaCertInstructions),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.close),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(strings.webDavSaveCertError)),
    );
  }
}

