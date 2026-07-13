import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/main.dart';
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
      SafeDiskApp(settingsService: SettingsService()),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark);
  });

  testWidgets('settings use two columns on wide windows and one on narrow',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(settingsService: SettingsService())),
    );
    await tester.pumpAndSettle();

    final wideAppearance =
        tester.getTopLeft(find.byKey(const Key('settings-appearance')));
    final wideBehavior =
        tester.getTopLeft(find.byKey(const Key('settings-behavior')));
    expect(wideBehavior.dx, greaterThan(wideAppearance.dx));
    expect(wideBehavior.dy, wideAppearance.dy);
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
      MaterialApp(
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
      MaterialApp(home: SettingsPage(settingsService: service)),
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

  testWidgets('detailed error reporting participates in save transaction',
      (tester) async {
    final service = SettingsService();
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(settingsService: service)),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('detailed-error-reports'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    expect(await service.getDetailedErrorReports(), isFalse);
    expect(ErrorReportingService.detailedErrorsEnabled, isFalse);
    await tester.tap(find.text('保存设置'));
    await tester.pumpAndSettle();
    expect(await service.getDetailedErrorReports(), isTrue);
    expect(ErrorReportingService.detailedErrorsEnabled, isTrue);
  });
}
