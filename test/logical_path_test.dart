import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/models/logical_path.dart';

void main() {
  test('Windows 路径使用与宿主平台无关的父目录语义', () {
    expect(logicalParentPath(r'C:\vault\docs\src'), 'C:/vault/docs');
    expect(logicalParentPath('C:/vault'), 'C:/');
    expect(logicalParentPath('C:/'), isNull);
  });

  test('逻辑路径 basename 同时兼容 Windows 和 POSIX 分隔符', () {
    expect(logicalPathBasename(r'C:\safe\私密盘'), '私密盘');
    expect(logicalPathBasename('/home/user/vault'), 'vault');
  });

  test('root 边界判断不会把相似前缀视为子目录', () {
    expect(isSameOrDescendantLogicalPath(r'C:\vault\docs', 'C:/vault'), isTrue);
    expect(isSameOrDescendantLogicalPath('C:/vault-old', 'C:/vault'), isFalse);
  });
}
