import 'dart:convert';

/// CryptionConfig - JSON container for encryption configuration
///
/// This class does NOT parse specific fields. It stores the raw JSON
/// and passes it directly to FFI. This avoids compatibility issues
/// when the config format changes.
class CryptionConfig {
  // Directly store raw JSON, do not parse specific fields
  final Map<String, dynamic> _json;

  CryptionConfig(this._json);

  factory CryptionConfig.fromJson(Map<String, dynamic> json) {
    return CryptionConfig(json);
  }

  Map<String, dynamic> toJson() => _json;

  // Optional: provide common field getters for display purposes
  // These are safe to access and won't break if fields are missing

  String get version => _json['version'] as String? ?? '1.0';
  String get algorithm => _json['algorithm'] as String? ?? 'AES-256-GCM';
  bool get mutable => _json['mutable'] as bool? ?? false;

  /// Public password-reminder metadata. Invalid stored values are not shown.
  String get passwordHint {
    final value = _json['sec_password_hint'];
    if (value is! String || value.isEmpty || utf8.encode(value).length > 256) {
      return '';
    }
    return value;
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
  final String? tempKeyID; // Temporary key ID for session (managed externally)
  final String? displayAlias;

  EncryptedDirectory({
    required this.path,
    required this.config,
    this.isVerified = false,
    this.tempKeyID,
    this.displayAlias,
  });

  /// Creates a copy with updated fields
  EncryptedDirectory copyWith({
    String? path,
    CryptionConfig? config,
    bool? isVerified,
    String? tempKeyID,
    String? displayAlias,
    bool clearDisplayAlias = false,
  }) {
    return EncryptedDirectory(
      path: path ?? this.path,
      config: config ?? this.config,
      isVerified: isVerified ?? this.isVerified,
      tempKeyID: tempKeyID ?? this.tempKeyID,
      displayAlias:
          clearDisplayAlias ? null : (displayAlias ?? this.displayAlias),
    );
  }
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
