import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Welcome screen shown when no encrypted directory is opened.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            strings.appTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(strings.welcomeProductTagline),
          const SizedBox(height: 32),
          Text(
            strings.welcomeOpenDirectoryHint,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
