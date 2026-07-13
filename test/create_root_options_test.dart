import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/create_root_options.dart';

void main() {
  test('推荐 root 参数使用名称加密和 Argon2id', () {
    const request = CreateRootRequest(password: 'secret');
    final options = jsonDecode(request.optionsJSON) as Map<String, dynamic>;

    expect(options['dataFactory'], 'aes-ctr');
    expect(options['nameFactory'], 'aes-gcm-name');
    expect(options['deriverFactory'], 'argon2id');
    expect(options['keyStrengthMs'], 1000);
    expect(options.containsKey('password'), isFalse);
    expect(options.containsKey('mutable'), isFalse);
  });

  test('公开选项只包含 sec 已注册且适合交互密码的算法', () {
    expect(CreateRootRequest.dataFactories, ['aes-ctr', 'aes-xts', 'chacha20']);
    expect(CreateRootRequest.nameFactories, ['aes-gcm-name', 'none']);
    expect(
        CreateRootRequest.deriverFactories, ['argon2id', 'scrypt', 'pbkdf2']);
    expect(CreateRootRequest.dataFactories, isNot(contains('rc4')));
    expect(CreateRootRequest.deriverFactories, isNot(contains('hkdf')));
  });
}
