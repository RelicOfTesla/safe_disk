import 'dart:convert';

class CreateRootRequest {
  const CreateRootRequest({
    required this.password,
    this.dataFactory = 'AES-CTR',
    this.nameFactory = 'AES-256-GCM',
    this.deriverFactory = 'Argon2id',
    this.keyStrengthMs = 1000,
  });

  // Secure interactive subset of native/sec_fs/crypto_all. RC4 and the
  // password-unsuitable HKDF factory stay registered for legacy roots only.
  static const dataFactories = ['AES-CTR', 'AES-XTS', 'ChaCha20'];
  static const nameFactories = ['AES-256-GCM', 'None'];
  static const deriverFactories = ['Argon2id', 'scrypt', 'PBKDF2'];
  static const keyStrengthOptions = [500, 1000, 2000, 5000];

  final String password;
  final String dataFactory;
  final String nameFactory;
  final String deriverFactory;
  final int keyStrengthMs;

  String get optionsJSON => jsonEncode({
        'dataFactory': dataFactory,
        'nameFactory': nameFactory,
        'deriverFactory': deriverFactory,
        'keyStrengthMs': keyStrengthMs,
      });
}
