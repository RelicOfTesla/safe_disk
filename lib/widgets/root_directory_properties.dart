import 'package:flutter/material.dart';

import '../models/cryption_config.dart';
import '../models/logical_path.dart';
import 'property_overlay.dart';

Future<void> showRootDirectoryProperties({
  required BuildContext context,
  required EncryptedDirectory directory,
}) {
  final config = directory.config.toJson();
  final displayName = directory.displayAlias?.trim().isNotEmpty == true
      ? directory.displayAlias!
      : logicalPathBasename(directory.path);
  final values = <PropertyValue>[
    PropertyValue('显示名称', displayName),
    PropertyValue('磁盘路径', directory.path),
    PropertyValue('会话状态', directory.isVerified ? '已解锁' : '已锁定'),
    PropertyValue('配置版本', directory.config.version),
    PropertyValue('数据加密', _configString(config, 'sec_fs_factory')),
    PropertyValue('名称加密', _configString(config, 'sec_name_factory')),
    PropertyValue('密码派生', _configString(config, 'sec_deriver_factory')),
    PropertyValue(
      '密码认证',
      config['sec_password_verifier_version'] is int
          ? '版本 ${config['sec_password_verifier_version']}'
          : '不可用或旧格式',
    ),
    ..._safeKdfProperties(config),
    const PropertyValue('安全改密', '当前格式不支持'),
  ];
  return showPropertyOverlay(
    context: context,
    title: '加密目录属性',
    values: values,
    notice: const Text(
      '属性不会显示 salt、密码 verifier 内容、密钥或其他密码材料。',
    ),
  );
}

Future<void> showUnsupportedRootPasswordChange({
  required BuildContext context,
  required EncryptedDirectory directory,
}) {
  return showPropertyOverlay(
    context: context,
    title: '修改密码',
    values: [
      PropertyValue('目录', directory.displayAlias ?? directory.path),
      const PropertyValue('状态', '当前加密格式不支持安全原地改密'),
      const PropertyValue(
        '原因',
        '数据密钥由密码直接派生，没有可用新密码重新封装的独立 root 主密钥。',
      ),
      const PropertyValue(
        '安全做法',
        '使用新密码创建新 root，再通过全量导出/导入或后续 convert 功能迁移。',
      ),
    ],
  );
}

String _configString(Map<String, dynamic> config, String key) {
  final value = config[key];
  return value is String && value.isNotEmpty ? value : '未知';
}

List<PropertyValue> _safeKdfProperties(Map<String, dynamic> config) {
  const safeKeys = <String, String>{
    'argon2_time': 'Argon2 时间成本',
    'argon2_memory': 'Argon2 内存成本',
    'argon2_threads': 'Argon2 并行度',
    'argon2_key_length': 'Argon2 密钥长度',
    'pbkdf2_iterations': 'PBKDF2 迭代次数',
    'pbkdf2_key_length': 'PBKDF2 密钥长度',
    'scrypt_n': 'scrypt N',
    'scrypt_r': 'scrypt r',
    'scrypt_p': 'scrypt p',
    'scrypt_key_length': 'scrypt 密钥长度',
  };
  return [
    for (final entry in safeKeys.entries)
      if (config[entry.key] is int)
        PropertyValue(entry.value, '${config[entry.key]}'),
  ];
}
