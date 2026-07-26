import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/directory_persistence_service.dart';
import '../services/settings_service.dart';
import '../widgets/anti_screenshot_dialog.dart';
import 'dialogs.dart';

/// Coordinates first-run dialogs without owning HomePage state.
class HomePageStartupCoordinator {
  const HomePageStartupCoordinator({
    required this.settingsService,
    required this.persistenceService,
  });

  final SettingsService settingsService;
  final DirectoryPersistenceService persistenceService;

  Future<void> checkFirstLaunchAntiScreenshot(
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    try {
      final enabled = await settingsService.getAntiScreenshot();
      if (!enabled) return;
      final confirmed =
          await settingsService.getAntiScreenshotFirstConfirmed();
      if (confirmed || !isMounted()) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!isMounted()) return;
        final strings = AppLocalizations.of(context)!;
        final enable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AntiScreenshotInfoDialog(strings: strings),
        );
        if (!isMounted() || enable != true) {
          await settingsService.setAntiScreenshot(false);
          await settingsService.applyAntiScreenshot();
          if (isMounted()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.antiScreenshotHint)),
            );
          }
          return;
        }

        final saved = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AntiScreenshotCountdownDialog(strings: strings),
        );
        if (saved == true) {
          await settingsService.setAntiScreenshotFirstConfirmed(true);
        } else {
          await settingsService.setAntiScreenshot(false);
          await settingsService.applyAntiScreenshot();
          if (isMounted()) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.antiScreenshotHint)),
            );
          }
        }
      });
    } catch (_) {
      // First-run protection must not prevent the main page from opening.
    }
  }

  Future<void> checkFirstTimeUser(
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    final isFirstTime = await persistenceService.isFirstTimeUser();
    if (isFirstTime && isMounted()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isMounted()) _showWelcomeGuide(context);
      });
    }
  }

  Future<void> _showWelcomeGuide(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeGuideDialog(
        onComplete: (neverShowAgain) async {
          if (neverShowAgain) {
            await persistenceService.setNeverShowWelcome(true);
          } else {
            await persistenceService.markWelcomeShown();
          }
        },
      ),
    );
  }
}
