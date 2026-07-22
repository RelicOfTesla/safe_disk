import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/services/error_reporting_service.dart';
import 'package:safe_disk/utils/error_diagnostics.dart';
import 'package:safe_disk/utils/error_messages.dart';
import 'package:safe_disk/widgets/copyable_snackbar.dart';

void main() {
  tearDown(() {
    ErrorReportingService.configure(detailedErrorsEnabled: false);
  });

  test('diagnostics redact secrets and absolute paths', () {
    final details = ErrorDiagnostics.build(
      type: ErrorType.createEncryptedDirectoryFailed,
      operation: 'create-root-config',
      originalError: 'password=hunter2 SAFE_DISK_PASSWORD=secret '
          r'C:\vault /tmp/safe-disk/libffi_sec_fs.so access denied',
    );

    expect(details, contains('create-root-config'));
    expect(details, contains('[路径已隐藏]'));
    expect(details, isNot(contains(r'C:\vault')));
    expect(details, isNot(contains('/tmp/safe-disk/libffi_sec_fs.so')));
    expect(details, isNot(contains('hunter2')));
    expect(details, isNot(contains('=secret')));
  });

  test('error descriptor contains stable metadata but no display text', () {
    final descriptor = ErrorMessages.descriptor(ErrorType.invalidPassword);

    expect(descriptor.type, ErrorType.invalidPassword);
    expect(descriptor.isCritical, isTrue);
    expect(ErrorMessages.isCritical(ErrorType.loadDirectoryFailed), isFalse);
  });

  testWidgets('error messages follow the active locale', (tester) async {
    Future<void> pumpError(Locale locale, String triggerLabel) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ErrorHelper.showError(
                  context,
                  errorType: ErrorType.importDirectoryInsideCurrentRoot,
                ),
                child: Text(triggerLabel),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(triggerLabel));
      await tester.pump();
    }

    await pumpError(const Locale('zh'), 'show-zh');
    expect(find.text('不能导入此目录'), findsOneWidget);
    expect(find.text('不能将当前加密目录中的目录再次导入到自身。'), findsOneWidget);
    expect(find.textContaining('建议：请选择加密目录外的来源目录。'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpError(const Locale('en'), 'show-en');
    expect(find.text('Cannot import this directory'), findsOneWidget);
    expect(
      find.text(
          'A directory inside the current encrypted directory cannot be imported back into itself.'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
          'Suggestion: Choose a source directory outside the encrypted directory.'),
      findsOneWidget,
    );
  });

  testWidgets('technical details are shown only after explicit opt-in',
      (tester) async {
    Future<void> pumpError() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ErrorHelper.showError(
                  context,
                  errorType: ErrorType.createEncryptedDirectoryFailed,
                  originalError: 'CreateFile C:\\vault: access denied',
                  operation: 'create-root-config',
                ),
                child: const Text('触发错误'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('触发错误'));
      await tester.pump();
    }

    await pumpError();
    expect(find.byKey(const Key('error-technical-details')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    ErrorReportingService.configure(detailedErrorsEnabled: true);
    await pumpError();
    expect(find.byKey(const Key('error-technical-details')), findsOneWidget);
    expect(find.textContaining('create-root-config'), findsOneWidget);
  });
}
