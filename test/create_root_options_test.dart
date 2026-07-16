import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/create_root_options.dart';

void main() {
  test('推荐 root 参数使用名称加密和 Argon2id', () {
    const request = CreateRootRequest(password: 'secret');
    final options = jsonDecode(request.optionsJSON) as Map<String, dynamic>;

    expect(options['dataFactory'], 'AES-CTR');
    expect(options['nameFactory'], 'AES-256-GCM');
    expect(options['deriverFactory'], 'Argon2id');
    expect(options['keyStrengthMs'], 1000);
    expect(options.containsKey('password'), isFalse);
    expect(options.containsKey('mutable'), isFalse);
  });

  test('公开选项只包含 sec 已注册且适合交互密码的算法', () {
    expect(CreateRootRequest.dataFactories, ['AES-CTR', 'AES-XTS', 'ChaCha20']);
    expect(CreateRootRequest.nameFactories, ['AES-256-GCM', 'None']);
    expect(
        CreateRootRequest.deriverFactories, ['Argon2id', 'scrypt', 'PBKDF2']);
    expect(CreateRootRequest.dataFactories, isNot(contains('RC4')));
    expect(CreateRootRequest.deriverFactories, isNot(contains('HKDF-SHA-256')));
  });
}
