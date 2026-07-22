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
}
