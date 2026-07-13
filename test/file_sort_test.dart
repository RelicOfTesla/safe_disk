import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/services/file_sort.dart';

void main() {
  test('keeps directories first and sorts names deterministically', () {
    final nodes = [
      _node('b.txt', '/b.txt'),
      _node('资料', '/资料', directory: true),
      _node('A.txt', '/A.txt'),
      _node('a.txt', '/a.txt'),
    ];

    expect(
      sortFileSystemNodes(nodes, FileSortOrder.nameAscending)
          .map((node) => node.name),
      ['资料', 'A.txt', 'a.txt', 'b.txt'],
    );
    expect(
      sortFileSystemNodes(nodes, FileSortOrder.nameDescending)
          .map((node) => node.name),
      ['资料', 'b.txt', 'a.txt', 'A.txt'],
    );
    expect(nodes.first.name, 'b.txt');
  });

  test('sorts known time and size values while leaving unknown values last',
      () {
    final nodes = [
      _node('unknown.txt', '/unknown.txt'),
      _node('small.txt', '/small.txt', size: 1, day: 1),
      _node('large.txt', '/large.txt', size: 100, day: 3),
      _node('medium.txt', '/medium.txt', size: 10, day: 2),
    ];

    expect(
      sortFileSystemNodes(nodes, FileSortOrder.sizeLargest)
          .map((node) => node.name),
      ['large.txt', 'medium.txt', 'small.txt', 'unknown.txt'],
    );
    expect(
      sortFileSystemNodes(nodes, FileSortOrder.modifiedOldest)
          .map((node) => node.name),
      ['small.txt', 'medium.txt', 'large.txt', 'unknown.txt'],
    );
  });
}

FileSystemNode _node(
  String name,
  String path, {
  bool directory = false,
  int? size,
  int? day,
}) {
  return FileSystemNode(
    name: name,
    path: path,
    isDirectory: directory,
    size: size,
    modifiedTime: day == null ? null : DateTime(2026, 1, day),
  );
}
