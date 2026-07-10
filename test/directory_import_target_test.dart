import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/directory_service.dart';

void main() {
  group('directory import target', () {
    test('places the selected directory under the current secure directory',
        () {
      expect(
        buildDirectoryImportDestination(
          rootPath: '/vault',
          currentPath: '/vault/docs',
          sourcePath: '/plain/photos/',
        ),
        'docs/photos',
      );
      expect(
        buildDirectoryImportDestination(
          rootPath: '/vault',
          currentPath: '/vault',
          sourcePath: '/plain/photos',
        ),
        'photos',
      );
    });

    test('normalizes Windows separators and rejects paths outside root', () {
      expect(
        buildDirectoryImportDestination(
          rootPath: r'C:\vault',
          currentPath: r'C:\vault\docs',
          sourcePath: r'D:\plain\photos',
        ),
        'docs/photos',
      );
      expect(
        () => buildDirectoryImportDestination(
          rootPath: '/vault',
          currentPath: '/other',
          sourcePath: '/plain/photos',
        ),
        throwsStateError,
      );
    });

    test('detects the root itself and descendants', () {
      expect(isPathInsideDirectory('/vault', '/vault'), isTrue);
      expect(isPathInsideDirectory('/vault/nested', '/vault'), isTrue);
      expect(isPathInsideDirectory('/vault-other', '/vault'), isFalse);
    });
  });
}
