import 'package:flutter/widgets.dart';

const appLocaleSystem = 'system';
const appLocaleChinese = 'zh';
const appLocaleEnglish = 'en';
const defaultAppLocalePreference = appLocaleChinese;

const supportedAppLocalePreferences = <String>[
  appLocaleSystem,
  appLocaleChinese,
  appLocaleEnglish,
];

Locale? appLocaleFromPreference(String preference) => switch (preference) {
      appLocaleChinese => const Locale(appLocaleChinese),
      appLocaleEnglish => const Locale(appLocaleEnglish),
      _ => null,
    };

Locale resolveSafeDiskLocale(
  Locale? deviceLocale,
  Iterable<Locale> supportedLocales,
) {
  for (final locale in supportedLocales) {
    if (locale.languageCode == deviceLocale?.languageCode) return locale;
  }
  return supportedLocales.firstWhere(
    (locale) => locale.languageCode == appLocaleChinese,
    orElse: () => supportedLocales.first,
  );
}
