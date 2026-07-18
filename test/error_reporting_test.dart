import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('technical details are shown only after explicit opt-in',
      (tester) async {
    Future<void> pumpError() async {
      await tester.pumpWidget(
        MaterialApp(
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
