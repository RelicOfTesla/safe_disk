import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists the secure notepad auto-save interval', () async {
    final service = SettingsService();

    expect(
      await service.getNotepadAutoSaveSeconds(),
      SettingsService.defaultNotepadAutoSaveSeconds,
    );

    await service.setNotepadAutoSaveSeconds(60);

    expect(await service.getNotepadAutoSaveSeconds(), 60);
  });

  test('rejects unsupported secure notepad auto-save intervals', () async {
    final service = SettingsService();

    await expectLater(
      service.setNotepadAutoSaveSeconds(17),
      throwsArgumentError,
    );
  });

  test('persists secure notepad read-only and clipboard defaults', () async {
    final service = SettingsService();

    expect(await service.getNotepadDefaultReadOnly(), isFalse);
    expect(await service.getNotepadDefaultMonitorClipboard(), isFalse);

    await service.setNotepadDefaultReadOnly(true);
    await service.setNotepadDefaultMonitorClipboard(true);

    expect(await service.getNotepadDefaultReadOnly(), isTrue);
    expect(await service.getNotepadDefaultMonitorClipboard(), isTrue);
  });

  test('detailed error reporting is opt-in and persisted', () async {
    final service = SettingsService();

    expect(await service.getDetailedErrorReports(), isFalse);
    await service.setDetailedErrorReports(true);
    expect(await service.getDetailedErrorReports(), isTrue);
  });

  test('persists the item open mode', () async {
    final service = SettingsService();

    expect(
      await service.getOpenOnDoubleClick(),
      SettingsService.defaultOpenOnDoubleClick,
    );

    await service.setOpenOnDoubleClick(true);

    expect(await service.getOpenOnDoubleClick(), isTrue);
  });

  test('WebDAV sharing switch defaults on and persists', () async {
    final service = SettingsService();

    expect(await service.getWebDavEnabled(), isTrue);
    await service.setWebDavEnabled(false);
    expect(await service.getWebDavEnabled(), isFalse);
  });

  test('locale preference defaults safely and rejects unsupported values',
      () async {
    final service = SettingsService();

    expect(await service.getLocale(), SettingsService.defaultLocale);
    await service.setLocale('en');
    expect(await service.getLocale(), 'en');
    await expectLater(service.setLocale('fr'), throwsArgumentError);

    SharedPreferences.setMockInitialValues({'locale': 'fr'});
    expect(await SettingsService().getLocale(), SettingsService.defaultLocale);
  });

  test('theme preference defaults safely and rejects unsupported values',
      () async {
    final service = SettingsService();

    expect(await service.getThemeMode(), SettingsService.defaultThemeMode);
    await service.setThemeMode('dark');
    expect(await service.getThemeMode(), 'dark');
    await expectLater(service.setThemeMode('sepia'), throwsArgumentError);

    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    expect(
      await SettingsService().getThemeMode(),
      SettingsService.defaultThemeMode,
    );
  });

  test('session TTL preference rejects unsupported values', () async {
    final service = SettingsService();

    await service.setSessionTTL(SettingsService.sessionTTLOptions['30min']!);
    expect(await service.getSessionTTL(), 1800);
    await expectLater(service.setSessionTTL(17), throwsArgumentError);

    SharedPreferences.setMockInitialValues({'session_ttl': 17});
    expect(
      await SettingsService().getSessionTTL(),
      SettingsService.defaultSessionTTL,
    );
  });

  test('new-directory derivation profile is constrained and recovers safely',
      () async {
    final service = SettingsService();

    await service.setKeyStrengthMs(2000);
    expect(await service.getKeyStrengthMs(), 2000);
    await expectLater(service.setKeyStrengthMs(1234), throwsArgumentError);

    SharedPreferences.setMockInitialValues({'key_strength_ms': 1234});
    expect(
      await SettingsService().getKeyStrengthMs(),
      SettingsService.defaultKeyStrengthMs,
    );
  });
}
