class CryptionConfig {
  final String check;
  final int iterN;
  final String version;
  final String algorithm;
  final DateTime created;
  final bool mutable;           // 是否支持修改密码
  final String? encryptedKey;   // 加密的随机密钥（mutable=true时）
  
  CryptionConfig({
    required this.check,
    required this.iterN,
    required this.version,
    required this.algorithm,
    required this.created,
    this.mutable = false,
    this.encryptedKey,
  });
  
  factory CryptionConfig.fromJson(Map<String, dynamic> json) {
    return CryptionConfig(
      check: json['check'] as String,
      iterN: json['iterN'] as int,
      version: json['version'] as String? ?? '1.0',
      algorithm: json['algorithm'] as String? ?? 'AES-256-GCM',
      created: DateTime.parse(json['created'] as String),
      mutable: json['mutable'] as bool? ?? false,
      encryptedKey: json['key'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'check': check,
      'iterN': iterN,
      'version': version,
      'algorithm': algorithm,
      'created': created.toIso8601String(),
      'mutable': mutable,
    };
    if (encryptedKey != null) {
      json['key'] = encryptedKey;
    }
    return json;
  }
}

class QuickListEntry {
  final String name;
  final String path;
  
  QuickListEntry({required this.name, required this.path});
  
  factory QuickListEntry.fromJson(Map<String, dynamic> json) {
    return QuickListEntry(
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }
  
  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}

class EncryptedDirectory {
  final String path;
  final CryptionConfig config;
  final bool isVerified;
  
  EncryptedDirectory({
    required this.path,
    required this.config,
    this.isVerified = false,
  });
}

class EncryptedFile {
  final String name;
  final String encryptedPath;
  final String? originalName;
  final int? originalSize;
  final DateTime modifiedTime;
  
  EncryptedFile({
    required this.name,
    required this.encryptedPath,
    this.originalName,
    this.originalSize,
    required this.modifiedTime,
  });
}
