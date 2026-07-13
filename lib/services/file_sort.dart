import 'file_service.dart';

enum FileSortOrder {
  nameAscending,
  nameDescending,
  modifiedNewest,
  modifiedOldest,
  sizeLargest,
  sizeSmallest,
}

String fileSortOrderLabel(FileSortOrder order) => switch (order) {
      FileSortOrder.nameAscending => '名称：A 到 Z',
      FileSortOrder.nameDescending => '名称：Z 到 A',
      FileSortOrder.modifiedNewest => '修改时间：最新优先',
      FileSortOrder.modifiedOldest => '修改时间：最早优先',
      FileSortOrder.sizeLargest => '大小：最大优先',
      FileSortOrder.sizeSmallest => '大小：最小优先',
    };

List<FileSystemNode> sortFileSystemNodes(
  Iterable<FileSystemNode> nodes,
  FileSortOrder order,
) {
  final result = nodes.toList();
  result.sort((left, right) {
    if (left.isDirectory != right.isDirectory) {
      return left.isDirectory ? -1 : 1;
    }
    final comparison = switch (order) {
      FileSortOrder.nameAscending => _compareName(left, right),
      FileSortOrder.nameDescending => -_compareName(left, right),
      FileSortOrder.modifiedNewest => _compareNullable(
          left.modifiedTime,
          right.modifiedTime,
          descending: true,
        ),
      FileSortOrder.modifiedOldest => _compareNullable(
          left.modifiedTime,
          right.modifiedTime,
          descending: false,
        ),
      FileSortOrder.sizeLargest => _compareNullable(
          left.size,
          right.size,
          descending: true,
        ),
      FileSortOrder.sizeSmallest => _compareNullable(
          left.size,
          right.size,
          descending: false,
        ),
    };
    if (comparison != 0) return comparison;
    return _compareName(left, right);
  });
  return result;
}

int _compareName(FileSystemNode left, FileSystemNode right) {
  final folded = left.name.toLowerCase().compareTo(right.name.toLowerCase());
  if (folded != 0) return folded;
  final exact = left.name.compareTo(right.name);
  if (exact != 0) return exact;
  return left.path.compareTo(right.path);
}

int _compareNullable<T extends Comparable<Object?>>(T? left, T? right,
    {required bool descending}) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  final comparison = left.compareTo(right);
  return descending ? -comparison : comparison;
}
