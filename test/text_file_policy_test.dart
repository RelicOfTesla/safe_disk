import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/text_file_policy.dart';

void main() {
  test('脚本和源码后缀是已知文本类型', () {
    for (final name in ['run.bat', 'main.dart', 'server.go', 'build.sh']) {
      expect(isKnownTextFilename(name), isTrue, reason: name);
      expect(shouldOpenFallbackTextReadOnly(name), isFalse, reason: name);
    }
  });

  test('未知后缀和无后缀文件首次使用只读回退', () {
    expect(shouldOpenFallbackTextReadOnly('README'), isTrue);
    expect(shouldOpenFallbackTextReadOnly('sample.unknown'), isTrue);
  });
}
