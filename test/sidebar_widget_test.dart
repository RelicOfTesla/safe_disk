import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/widgets/sidebar.dart';

void main() {
  testWidgets('Sidebar shows directory basename instead of config JSON',
      (tester) async {
    final directory = EncryptedDirectory(
      path: '/tmp/safe-disk-ui/root-name',
      config: CryptionConfig({
        'version': '1.0',
        'dataFactory': 'aes-ctr',
        'nameFactory': 'none',
      }),
      isVerified: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SidebarWidget(
          openedDirs: [directory],
          currentDir: directory,
          drawerPinned: false,
          onOpenDirectory: () {},
          onCloseDirectory: (_) {},
          onSwitchDirectory: (_) {},
          onTogglePin: (_) async {},
        ),
      ),
    ));

    expect(find.text('root-name'), findsOneWidget);
    expect(find.textContaining('dataFactory'), findsNothing);
    expect(find.textContaining('nameFactory'), findsNothing);
  });
}
