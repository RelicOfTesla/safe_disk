import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_disk/services/directory_persistence_service.dart';

void main() {
  test('目录别名独立持久化且不修改目录历史路径', () async {
    SharedPreferences.setMockInitialValues({
      'opened_directories': [r'C:\safe\root'],
    });
    final service = DirectoryPersistenceService();

    await service.saveDirectoryAlias(r'C:\safe\root', '工作资料');
    expect(await service.loadDirectoryAliases(), {
      r'C:\safe\root': '工作资料',
    });
    expect(await service.loadOpenedDirectories(), [r'C:\safe\root']);

    await service.saveDirectoryAlias(r'C:\safe\root', null);
    expect(await service.loadDirectoryAliases(), isEmpty);
  });
}
