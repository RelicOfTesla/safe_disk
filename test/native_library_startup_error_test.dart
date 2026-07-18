import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/main.dart';
import 'package:safe_disk/native/bindings.dart';
import 'package:safe_disk/pages/home_page.dart';
import 'package:safe_disk/services/settings_service.dart';
import 'package:safe_disk/widgets/native_library_startup_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final loadError = NativeLibraryException(
    NativeLibraryFailureStage.load,
    StateError('password=secret /home/example/libffi_sec_fs.so'),
  );

  testWidgets('startup error hides raw diagnostics by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NativeLibraryStartupErrorPage(
          error: loadError,
          onRetry: () {},
          showDiagnostics: false,
        ),
      ),
    );

    expect(find.text('安全组件不可用'), findsOneWidget);
    expect(find.textContaining('安全组件'), findsWidgets);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.byKey(const Key('native-library-error-diagnostics')),
        findsNothing);
  });

  testWidgets('startup error sanitizes opt-in diagnostics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NativeLibraryStartupErrorPage(
          error: loadError,
          onRetry: () {},
          showDiagnostics: true,
        ),
      ),
    );

    final diagnostics = tester.widget<SelectableText>(
      find.byKey(const Key('native-library-error-diagnostics')),
    );
    expect(diagnostics.data, contains('password=[已隐藏]'));
    expect(diagnostics.data, isNot(contains('secret')));
  });

  testWidgets('retry probes again before opening the home page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var attempts = 0;
    Future<void> probe() async {
      attempts++;
      if (attempts == 1) throw loadError;
    }

    await tester.pumpWidget(
      SafeDiskApp(
        settingsService: SettingsService(),
        nativeLibraryProbe: probe,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('native-library-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('native-library-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byType(HomePage), findsOneWidget);
  });
}
