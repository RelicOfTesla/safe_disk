import 'dart:io';

enum DragDropImportKind { file, directory }

class DragDropCandidate {
  const DragDropCandidate({
    required this.path,
    this.fromPromise = false,
    this.hasInlineBytes = false,
  });

  final String path;
  final bool fromPromise;
  final bool hasInlineBytes;
}

class DragDropImportRequest {
  const DragDropImportRequest({required this.path, required this.kind});

  final String path;
  final DragDropImportKind kind;
}

/// Converts platform drop candidates into safe, ordinary filesystem imports.
/// It deliberately does not know root IDs, credentials, or Transfer details.
class DragDropController {
  const DragDropController({this.windowsStyle});

  /// Overrides the host platform in tests so Windows path rules are covered
  /// without requiring a Windows runner.
  final bool? windowsStyle;

  List<DragDropImportRequest> importRequests({
    required Iterable<DragDropCandidate> candidates,
    required String rootPath,
  }) {
    final requests = <DragDropImportRequest>[];
    final seenPaths = <String>{};
    for (final candidate in candidates) {
      if (candidate.fromPromise || candidate.hasInlineBytes) continue;
      final path = candidate.path;
      if (path.isEmpty ||
          !File(path).isAbsolute ||
          !_isOutsideRoot(path, rootPath)) {
        continue;
      }
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      final kind = switch (type) {
        FileSystemEntityType.file => DragDropImportKind.file,
        FileSystemEntityType.directory => DragDropImportKind.directory,
        _ => null,
      };
      if (kind == null || !seenPaths.add(path)) continue;
      requests.add(DragDropImportRequest(path: path, kind: kind));
    }
    return requests;
  }

  bool _isOutsideRoot(String path, String rootPath) {
    final candidate = _normalizeForComparison(path);
    final root = _normalizeForComparison(rootPath);
    final normalizedRoot = _withTrailingSeparator(root);
    return candidate != root && !candidate.startsWith(normalizedRoot);
  }

  String _normalizeForComparison(String path) {
    if (!(windowsStyle ?? Platform.isWindows)) return path;
    return path.replaceAll('\\', '/').toLowerCase();
  }

  String _withTrailingSeparator(String path) {
    final separator =
        (windowsStyle ?? Platform.isWindows) ? '/' : Platform.pathSeparator;
    return path.endsWith(separator) ? path : '$path$separator';
  }
}
