import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/main.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/pages/settings_page.dart';
import 'package:safe_disk/services/settings_service.dart';
import 'package:safe_disk/services/error_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });
  tearDown(() {
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });

  testWidgets('persisted dark theme is applied to the whole application',
      (tester) async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

    await tester.pumpWidget(
      SafeDiskApp(
        settingsService: SettingsService(),
        nativeLibraryProbe: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
  });

  testWidgets('persisted locale is applied to the whole application',
      (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});

    await tester.pumpWidget(
      SafeDiskApp(
        settingsService: SettingsService(),
        nativeLibraryProbe: () async {},
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(app.supportedLocales, contains(const Locale('zh')));
    expect(app.localizationsDelegates, isNotEmpty);
  });

  testWidgets('settings core controls render in English for the English locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(settingsService: SettingsService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Secure Notepad'), findsOneWidget);
    expect(find.text('Confirm before deleting'), findsOneWidget);
    expect(find.text('Open items with'), findsOneWidget);
    expect(find.text('Single click'), findsOneWidget);
    expect(find.text('Lock after inactivity'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    expect(find.text('Secure draft save interval'), findsOneWidget);
    expect(find.text('Open notes read-only'), findsOneWidget);
    expect(find.text('Monitor clipboard by default'), findsOneWidget);
    expect(find.text('Show detailed error information'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(
      find.text('Version 1.0.0\nEncrypted file manager'),
      findsOneWidget,
    );
    expect(find.textContaining('Version 1.0.0'), findsOneWidget);
    expect(find.textContaining('Encrypted file manager'), findsOneWidget);
    expect(find.text('删除前确认'), findsNothing);
    expect(
      find.text(
          'English is still being translated. Some screens may remain in Chinese.'),
      findsNothing,
    );
  });

  testWidgets('settings use two columns on wide windows and one on narrow',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: SettingsService())),
    );
    await tester.pumpAndSettle();

    final wideAppearance =
        tester.getTopLeft(find.byKey(const Key('settings-appearance')));
    final wideBehavior =
        tester.getTopLeft(find.byKey(const Key('settings-behavior')));
    final wideSecurity =
        tester.getTopLeft(find.byKey(const Key('settings-security')));
    final wideNotepad =
        tester.getTopLeft(find.byKey(const Key('settings-notepad')));
    expect(wideBehavior.dx, greaterThan(wideAppearance.dx));
    expect(wideBehavior.dy, wideAppearance.dy);
    expect(wideSecurity.dx, wideAppearance.dx);
    expect(wideSecurity.dy, greaterThan(wideAppearance.dy));
    expect(wideNotepad.dx, greaterThan(wideSecurity.dx));
    expect(wideNotepad.dy, wideSecurity.dy);
    expect(
      tester.getSize(find.byKey(const Key('settings-content'))).width,
      lessThanOrEqualTo(1080),
    );

    await tester.binding.setSurfaceSize(const Size(600, 800));
    await tester.pumpAndSettle();
    final narrowAppearance =
        tester.getTopLeft(find.byKey(const Key('settings-appearance')));
    final narrowBehavior =
        tester.getTopLeft(find.byKey(const Key('settings-behavior')));
    expect(narrowBehavior.dy, greaterThan(narrowAppearance.dy));
  });

  testWidgets('unsaved settings can cancel, discard, or save on return',
      (tester) async {
    final previews = <ThemeMode>[];
    final service = SettingsService();

    await tester.pumpWidget(
      _settingsTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    settingsService: service,
                    onThemeModeChanged: previews.add,
                  ),
                ),
              ),
              child: const Text('打开设置'),
            ),
          ),
        ),
      ),
    );

    Future<void> openSettings() async {
      await tester.tap(find.text('打开设置'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsOneWidget);
    }

    await openSettings();
    await tester.tap(find.text('暗色主题'));
    await tester.pumpAndSettle();
    expect(previews.last, ThemeMode.dark);
    expect(await service.getThemeMode(), SettingsService.defaultThemeMode);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('保存设置更改？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.text('打开设置'), findsOneWidget);
    expect(previews.last, ThemeMode.system);
    expect(await service.getThemeMode(), SettingsService.defaultThemeMode);

    await openSettings();
    await tester.tap(find.text('暗色主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();
    expect(find.text('打开设置'), findsOneWidget);
    expect(await service.getThemeMode(), 'dark');
  });

  testWidgets('notepad defaults participate in the settings save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final readOnly = find.byKey(const Key('notepad-default-read-only'));
    final monitor = find.byKey(const Key('notepad-default-monitor-clipboard'));
    await tester.ensureVisible(readOnly);
    await tester.tap(readOnly);
    await tester.ensureVisible(monitor);
    await tester.tap(monitor);
    await tester.pump();
    expect(find.text('保存设置'), findsOneWidget);

    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(await service.getNotepadDefaultReadOnly(), isTrue);
    expect(await service.getNotepadDefaultMonitorClipboard(), isTrue);
  });

  testWidgets('item open mode participates in the settings save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    expect(await service.getOpenOnDoubleClick(), isFalse);
    await tester.tap(find.byType(DropdownButton<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('双击打开').last);
    await tester.pump();

    expect(await service.getOpenOnDoubleClick(), isFalse);
    await tester.ensureVisible(find.text('保存设置'));
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(await service.getOpenOnDoubleClick(), isTrue);
  });

  testWidgets(
      'background auto-lock participates in the settings save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('auto-lock-on-background'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(await service.getAutoCloseSession(), isFalse);

    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(await service.getAutoCloseSession(), isTrue);
  });

  testWidgets('session TTL participates in the settings save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final ttl = find.byKey(const Key('session-ttl'));
    await tester.ensureVisible(ttl);
    await tester.tap(
        find.descendant(of: ttl, matching: find.byType(DropdownButton<int>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 分钟').last);
    await tester.pump();

    expect(await service.getSessionTTL(), SettingsService.defaultSessionTTL);
    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(await service.getSessionTTL(), 900);
  });

  testWidgets(
      'default new-directory derivation profile is saved transactionally',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final profile = find.byKey(const Key('default-key-strength'));
    await tester.ensureVisible(profile);
    await tester.tap(
      find.descendant(of: profile, matching: find.byType(DropdownButton<int>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('增强').last);
    await tester.pump();

    expect(
        await service.getKeyStrengthMs(), SettingsService.defaultKeyStrengthMs);
    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(await service.getKeyStrengthMs(), 2000);
  });

  testWidgets('restoring settings defaults resets the new-directory profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'key_strength_ms': 2000,
      'auto_close_session': true,
      'session_ttl': 900,
    });
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('恢复默认设置（未保存）'));
    await tester.pump();
    final profile = find.byKey(const Key('default-key-strength'));
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.descendant(
                of: profile, matching: find.byType(DropdownButton<int>)),
          )
          .value,
      SettingsService.defaultKeyStrengthMs,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('auto-lock-on-background')),
          )
          .value,
      SettingsService.defaultAutoCloseSession,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('session-ttl'))).trailing,
      isA<DropdownButton<int>>().having(
        (dropdown) => dropdown.value,
        'value',
        SettingsService.defaultSessionTTL,
      ),
    );

    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      await service.getKeyStrengthMs(),
      SettingsService.defaultKeyStrengthMs,
    );
    expect(
      await service.getAutoCloseSession(),
      SettingsService.defaultAutoCloseSession,
    );
    expect(
      await service.getSessionTTL(),
      SettingsService.defaultSessionTTL,
    );
  });

  testWidgets('invalid persisted session TTL falls back to the safe default',
      (tester) async {
    SharedPreferences.setMockInitialValues({'session_ttl': 1});
    final service = SettingsService();

    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    expect(await service.getSessionTTL(), SettingsService.defaultSessionTTL);
    final ttl = find.byKey(const Key('session-ttl'));
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.descendant(
                of: ttl, matching: find.byType(DropdownButton<int>)),
          )
          .value,
      SettingsService.defaultSessionTTL,
    );
  });

  testWidgets('detailed error reporting participates in save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('detailed-error-reports'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    expect(await service.getDetailedErrorReports(), isFalse);
    expect(ErrorReportingService.detailedErrorsEnabled, isFalse);
    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(await service.getDetailedErrorReports(), isTrue);
    expect(ErrorReportingService.detailedErrorsEnabled, isTrue);
  });

  testWidgets('language choice previews immediately and persists on save',
      (tester) async {
    final previews = <Locale?>[];
    final service = SettingsService();
    await tester.pumpWidget(
      _settingsTestApp(
        home: SettingsPage(
          settingsService: service,
          onLocaleChanged: previews.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final locale = find.byKey(const Key('app-locale'));
    await tester.ensureVisible(locale);
    await tester.tap(
      find.descendant(
          of: locale, matching: find.byType(DropdownButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pump();

    expect(previews.last, const Locale('en'));
    expect(await service.getLocale(), SettingsService.defaultLocale);
    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(await service.getLocale(), 'en');
  });

  testWidgets('settings failures hide raw diagnostics by default',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(settingsService: _FailingLoadSettings()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法加载设置'), findsOneWidget);
    expect(find.text('无法读取本机设置。'), findsOneWidget);
    expect(find.textContaining('private-settings-path'), findsNothing);
    expect(find.byKey(const Key('error-technical-details')), findsNothing);
  });

  testWidgets('opted-in settings failures show sanitized diagnostics',
      (tester) async {
    ErrorReportingService.configure(detailedErrorsEnabled: true);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(settingsService: _FailingLoadSettings()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('error-technical-details')), findsOneWidget);
    expect(find.textContaining('private-settings-path'), findsNothing);
    expect(find.textContaining('[路径已隐藏]'), findsOneWidget);
  });

  testWidgets('save failure uses the same protected error presentation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(settingsService: _FailingSaveSettings()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('暗色主题'));
    await tester.pump();
    final save = find.text('保存设置');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('无法保存设置'), findsOneWidget);
    expect(find.text('设置尚未保存。'), findsOneWidget);
    expect(find.textContaining('private-settings-path'), findsNothing);
  });
}

Widget _settingsTestApp(
    {required Widget home, Locale locale = const Locale('zh')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

class _FailingLoadSettings extends SettingsService {
  @override
  Future<String> getThemeMode() =>
      Future<String>.error(StateError('read /private-settings-path/theme'));
}

class _FailingSaveSettings extends SettingsService {
  @override
  Future<void> setThemeMode(String mode) =>
      Future<void>.error(StateError('write /private-settings-path/theme'));
}
