import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/error_localizations.dart';
import '../native/bindings.dart';
import '../utils/error_diagnostics.dart';

class NativeLibraryLoadingPage extends StatelessWidget {
  const NativeLibraryLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class NativeLibraryStartupErrorPage extends StatelessWidget {
  const NativeLibraryStartupErrorPage({
    required this.error,
    required this.onRetry,
    required this.showDiagnostics,
    super.key,
  });

  final NativeLibraryException error;
  final VoidCallback onRetry;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final isBindingFailure = error.stage == NativeLibraryFailureStage.bind;
    final detail = isBindingFailure
        ? strings.nativeBindingFailureDescription
        : strings.nativeLoadingFailureDescription;
    final suggestion = isBindingFailure
        ? strings.nativeBindingFailureSuggestion
        : strings.nativeLoadingFailureSuggestion;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.security_outlined, size: 44),
                const SizedBox(height: 20),
                Text(
                  strings.nativeComponentUnavailable,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(detail, key: const Key('native-library-error-message')),
                const SizedBox(height: 8),
                Text('${strings.errorSuggestionPrefix}$suggestion'),
                if (showDiagnostics) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    '${strings.initializationStage(error.operation)}\n'
                    '${strings.underlyingError(ErrorDiagnostics.sanitize(error.cause.toString(), labels: strings.errorDiagnosticsLabels()))}',
                    key: const Key('native-library-error-diagnostics'),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('native-library-retry'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(strings.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
