import 'package:flutter/material.dart' hide MaterialApp;
import 'package:flutter/material.dart' as material show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/l10n/generated/app_localizations.dart';
import 'package:safe_disk/models/batch_operation_result.dart';
import 'package:safe_disk/widgets/batch_operation_result_dialog.dart';

class MaterialApp extends material.MaterialApp {
  const MaterialApp({super.key, super.home, Locale? locale})
      : super(
          locale: locale ?? const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
}

void main() {
  testWidgets('batch result dialog displays English partial failure details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBatchOperationResultDialog(
              context: context,
              operation: 'Paste',
              result: const BatchOperationResult(
                total: 3,
                succeeded: 1,
                skipped: 1,
                failures: [
                  BatchOperationFailure(name: 'report.txt', reason: 'exists'),
                ],
                unprocessed: 0,
                remaining: 1,
                cancelled: false,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Paste partially completed'), findsOneWidget);
    expect(find.text('Total: 3'), findsOneWidget);
    expect(find.text('Failure details'), findsOneWidget);
    expect(find.text('"report.txt": exists'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
