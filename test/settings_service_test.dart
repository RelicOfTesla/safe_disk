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
    expect(service.getNotepadAutoSaveDisplayName(60), '1 分钟');
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
}
