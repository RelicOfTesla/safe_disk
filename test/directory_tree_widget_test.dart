import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_page_session.dart';
import 'package:safe_disk/services/file_service.dart';
import 'package:safe_disk/widgets/directory_tree.dart';

void main() {
  testWidgets('tree skips file-only cursor pages before showing directories',
      (tester) async {
    final service = _PagedTreeFileService({
      '/root': [
        _page([_entry('plain.txt', isDirectory: false)], done: false),
        _page([_entry('folder', isDirectory: true)], done: true),
      ],
      '/root/folder': [
        _page([_entry('child.txt', isDirectory: false)], done: false),
        _page([_entry('nested', isDirectory: true)], done: true),
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectoryTreeWidget(
            rootPath: '/root',
            fileService: service,
            pageSize: 1,
            onPathSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('plain.txt'), findsNothing);
    expect(find.text('folder'), findsOneWidget);
    expect(service.reads['/root'], 2);

    final folderRow = find.ancestor(
      of: find.text('folder'),
      matching: find.byType(InkWell),
    );
    await tester
        .tap(find.descendant(of: folderRow, matching: find.byType(IconButton)));
    await tester.pumpAndSettle();

    expect(find.text('child.txt'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
    expect(service.reads['/root/folder'], 2);
  });
}

DirectoryCursorPageData _page(List<DirEntry> entries, {required bool done}) =>
    DirectoryCursorPageData(entries: entries, done: done);

DirEntry _entry(String name, {required bool isDirectory}) => DirEntry(
      name: name,
      isDir: isDirectory,
      size: 0,
      modTime: 0,
      mode: 0,
      path: name,
    );

class _PagedTreeFileService extends FileService {
  _PagedTreeFileService(this.pages);

  final Map<String, List<DirectoryCursorPageData>> pages;
  final Map<String, int> reads = {};

  @override
  DirectoryPageSession? openCurrentDirectorySession(
    String path, {
    bool retainEntries = true,
  }) {
    return DirectoryPageSession(
      gateway: _TreeGateway(
        List<DirectoryCursorPageData>.from(pages[path] ?? const []),
        onRead: () =>
            reads.update(path, (count) => count + 1, ifAbsent: () => 1),
      ),
      rootID: 1,
      relativePath: path,
      retainEntries: retainEntries,
    );
  }

  @override
  List<FileSystemNode> nodesForDirectoryPage(
    DirectoryPageSession session,
    Iterable<DirEntry> entries,
  ) {
    return entries
        .map(
          (entry) => FileSystemNode(
            name: entry.name,
            path: '${session.relativePath}/${entry.name}',
            isDirectory: entry.isDir,
          ),
        )
        .toList();
  }
}

class _TreeGateway implements DirectoryCursorGateway {
  _TreeGateway(this.pages, {required this.onRead});

  final List<DirectoryCursorPageData> pages;
  final VoidCallback onRead;

  @override
  Future<void> close(int cursorID) async {}

  @override
  Future<int> open(int rootID, String relativePath) async => 1;

  @override
  Future<DirectoryCursorPageData> readPage(int cursorID, int limit) async {
    onRead();
    if (pages.isEmpty) {
      return const DirectoryCursorPageData(entries: [], done: true);
    }
    return pages.removeAt(0);
  }
}
