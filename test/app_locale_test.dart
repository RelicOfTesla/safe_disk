import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/app_locale.dart';
import 'package:safe_disk/services/settings_service.dart';

void main() {
  const supported = [Locale('zh'), Locale('en')];

  test('Chinese is the persisted default and explicit preferences resolve', () {
    expect(SettingsService.defaultLocale, appLocaleChinese);
    expect(appLocaleFromPreference(appLocaleChinese), const Locale('zh'));
    expect(appLocaleFromPreference(appLocaleEnglish), const Locale('en'));
    expect(appLocaleFromPreference(appLocaleSystem), isNull);
  });

  test(
      'system locale resolves only supported languages and falls back to Chinese',
      () {
    expect(resolveSafeDiskLocale(const Locale('en', 'US'), supported),
        const Locale('en'));
    expect(resolveSafeDiskLocale(const Locale('ja', 'JP'), supported),
        const Locale('zh'));
    expect(resolveSafeDiskLocale(null, supported), const Locale('zh'));
  });
}
