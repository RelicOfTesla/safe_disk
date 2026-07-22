import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/services/drag_drop_controller.dart';

void main() {
  test('accepts ordinary external files and directories in source order',
      () async {
    final sandbox = await Directory.systemTemp.createTemp('safe-disk-drop-');
    addTearDown(() => sandbox.delete(recursive: true));
    final root = Directory('${sandbox.path}${Platform.pathSeparator}root')
      ..createSync();
    final file = File('${sandbox.path}${Platform.pathSeparator}note.txt')
      ..writeAsStringSync('x');
    final directory =
        Directory('${sandbox.path}${Platform.pathSeparator}source')
          ..createSync();

    final requests = const DragDropController().importRequests(
      rootPath: root.path,
      candidates: [
        DragDropCandidate(path: file.path),
        DragDropCandidate(path: directory.path),
      ],
    );

    expect(
        requests.map((request) => request.path), [file.path, directory.path]);
    expect(requests.map((request) => request.kind), [
      DragDropImportKind.file,
      DragDropImportKind.directory,
    ]);
  });

  test(
      'rejects promises, inline bytes, links, missing paths and root internals',
      () async {
    final sandbox = await Directory.systemTemp.createTemp('safe-disk-drop-');
    addTearDown(() => sandbox.delete(recursive: true));
    final root = Directory('${sandbox.path}${Platform.pathSeparator}root')
      ..createSync();
    final inside = File('${root.path}${Platform.pathSeparator}inside.txt')
      ..writeAsStringSync('x');
    final external = File('${sandbox.path}${Platform.pathSeparator}outside.txt')
      ..writeAsStringSync('x');
    final link = Link('${sandbox.path}${Platform.pathSeparator}outside-link')
      ..createSync(external.path);

    final requests = const DragDropController().importRequests(
      rootPath: root.path,
      candidates: [
        DragDropCandidate(path: external.path, fromPromise: true),
        DragDropCandidate(path: external.path, hasInlineBytes: true),
        DragDropCandidate(path: inside.path),
        DragDropCandidate(path: link.path),
        const DragDropCandidate(path: 'relative.txt'),
        DragDropCandidate(
            path: '${sandbox.path}${Platform.pathSeparator}missing'),
        DragDropCandidate(path: external.path),
        DragDropCandidate(path: external.path),
      ],
    );

    expect(requests, hasLength(1));
    expect(requests.single.path, external.path);
  });
}
