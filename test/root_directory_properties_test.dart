import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/cryption_config.dart';
import 'package:safe_disk/widgets/root_directory_properties.dart';

void main() {
  final directory = EncryptedDirectory(
    path: '/safe/root',
    displayAlias: '工作盘',
    isVerified: true,
    config: CryptionConfig({
      'version': '2',
      'sec_fs_factory': 'AES-256-CTR',
      'sec_name_factory': 'AES-256-GCM',
      'sec_deriver_factory': 'Argon2id',
      'sec_password_verifier_version': 1,
      'sec_password_verifier_challenge': 'secret-challenge',
      'sec_password_verifier_tag': 'secret-tag',
      'argon2_salt': 'secret-salt',
      'argon2_time': 3,
      'argon2_memory': 65536,
    }),
  );

  testWidgets('root 属性只显示安全配置字段', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRootDirectoryProperties(
            context: context,
            directory: directory,
          ),
          child: const Text('打开'),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pump();

    expect(find.text('加密目录属性'), findsOneWidget);
    expect(find.text('工作盘'), findsOneWidget);
    expect(find.text('AES-256-CTR'), findsOneWidget);
    expect(find.text('Argon2id'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('secret-challenge'), findsNothing);
    expect(find.text('secret-tag'), findsNothing);
    expect(find.text('secret-salt'), findsNothing);
  });

  testWidgets('当前格式明确拒绝伪原地改密', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showUnsupportedRootPasswordChange(
            context: context,
            directory: directory,
          ),
          child: const Text('修改'),
        ),
      ),
    ));
    await tester.tap(find.text('修改'));
    await tester.pump();

    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('当前加密格式不支持在原目录中安全修改密码'), findsOneWidget);
    expect(find.textContaining('数据密钥由密码直接派生'), findsOneWidget);
    expect(find.textContaining('完整导出和导入迁移数据'), findsOneWidget);
  });
}
