import 'dart:io';

const _defaultOutput = 'docs/I18N_HARDCODED_STRING_AUDIT.md';
final _cjk = RegExp(r'[\u3400-\u9fff]');
final _stringLiteral = RegExp(r'''(?:r)?'([^']*)'|(?:r)?"([^"]*)"''');
final _uiContext = RegExp(
  r'\b(Text|SelectableText|Tooltip|SnackBar|AlertDialog|InputDecoration|'
  r'Semantics|ListTile|AppBar|FilledButton|TextButton|ElevatedButton|'
  r'IconButton|MenuItemButton)\b|'
  r'\b(title|content|tooltip|labelText|hintText|helperText|semanticLabel)\s*:',
);

void main(List<String> args) {
  String? outputPath;
  for (final argument in args) {
    if (argument.startsWith('--output=')) {
      outputPath = argument.substring('--output='.length);
    }
  }
  if (args.any((argument) => argument == '--help')) {
    stdout.writeln(
      'Usage: dart run tool/audit_i18n_strings.dart '
      '[--output=docs/I18N_HARDCODED_STRING_AUDIT.md]',
    );
    return;
  }

  final root = Directory.current;
  final libDirectory = Directory('${root.path}${Platform.pathSeparator}lib');
  if (!libDirectory.existsSync()) {
    stderr.writeln('Run this command from the repository root.');
    exitCode = 2;
    return;
  }

  final findings = <_Finding>[];
  final files = libDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !_isExcluded(file.path))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final relativePath = _relativePath(root, file);
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final source = _stripLineComment(lines[index]);
      if (source.trim().isEmpty) continue;
      final uiContext = _uiContext.hasMatch(source);
      for (final match in _stringLiteral.allMatches(source)) {
        final value = match.group(1) ?? match.group(2) ?? '';
        if (value.isEmpty) continue;
        final containsCjk = _cjk.hasMatch(value);
        if (!containsCjk && !uiContext) continue;
        if (!containsCjk && !_hasDisplayText(value)) continue;
        findings.add(_Finding(
          path: relativePath,
          line: index + 1,
          kind: containsCjk ? 'CJK 字符串' : 'UI ASCII 字符串',
          value: value,
          source: lines[index].trim(),
        ));
      }
    }
  }

  final output = File(
    '${root.path}${Platform.pathSeparator}${outputPath ?? _defaultOutput}',
  );
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(_renderReport(findings));
  stdout.writeln(
    'Wrote ${findings.length} candidates to ${outputPath ?? _defaultOutput}',
  );
}

bool _isExcluded(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/lib/l10n/') ||
      normalized.contains('/lib/testing/');
}

String _relativePath(Directory root, File file) {
  final rootPath = '${root.absolute.path}${Platform.pathSeparator}';
  return file.absolute.path.startsWith(rootPath)
      ? file.absolute.path.substring(rootPath.length).replaceAll('\\', '/')
      : file.path.replaceAll('\\', '/');
}

String _stripLineComment(String source) {
  var quote = '';
  var escaped = false;
  for (var index = 0; index < source.length - 1; index++) {
    final character = source[index];
    if (quote.isNotEmpty) {
      if (!escaped && character == quote) quote = '';
      escaped = !escaped && character == '\\';
      continue;
    }
    if (character == "'" || character == '"') {
      quote = character;
      continue;
    }
    if (character == '/' && source[index + 1] == '/') {
      return source.substring(0, index);
    }
  }
  return source;
}

bool _hasDisplayText(String value) {
  return RegExp(r'[A-Za-z]').hasMatch(value) &&
      !RegExp(r'^[A-Za-z0-9_./:-]+$').hasMatch(value);
}

String _renderReport(List<_Finding> findings) {
  final counts = <String, int>{};
  for (final finding in findings) {
    counts.update(finding.path, (count) => count + 1, ifAbsent: () => 1);
  }
  final summary = counts.entries.toList()
    ..sort((left, right) {
      final countOrder = right.value.compareTo(left.value);
      return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
    });
  final buffer = StringBuffer()
    ..writeln('# 本地化硬编码候选清单')
    ..writeln()
    ..writeln('此文件由 `dart run tool/audit_i18n_strings.dart` 生成，请勿手工编辑。')
    ..writeln()
    ..writeln('扫描范围为 `lib/**/*.dart`，排除生成的 `lib/l10n/` 和 `lib/testing/`。')
    ..writeln('它列出所有 CJK 字符串，以及常见 UI 构造位置的 ASCII 字符串。')
    ..writeln('候选项需要人工分类：领域操作标识、技术诊断和仅供开发者使用的文本不应直接迁入 ARB。')
    ..writeln()
    ..writeln('候选总数：${findings.length}')
    ..writeln()
    ..writeln('## 按文件统计')
    ..writeln()
    ..writeln('| 文件 | 候选数 |')
    ..writeln('| --- | ---: |');
  for (final entry in summary) {
    buffer.writeln('| `${entry.key}` | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## 逐项候选')
    ..writeln()
    ..writeln('| 文件 | 行号 | 类型 | 字符串 | 源码上下文 |')
    ..writeln('| --- | ---: | --- | --- | --- |');
  for (final finding in findings) {
    buffer
      ..write('| `${finding.path}` | ${finding.line} | ${finding.kind} | ')
      ..write('${_markdown(finding.value)} | ${_markdown(finding.source)} |')
      ..writeln();
  }
  return buffer.toString();
}

String _markdown(String value) {
  final compact = value.replaceAll('\n', r'\n').replaceAll('|', r'\|');
  return compact.length <= 160 ? compact : '${compact.substring(0, 157)}...';
}

class _Finding {
  const _Finding({
    required this.path,
    required this.line,
    required this.kind,
    required this.value,
    required this.source,
  });

  final String path;
  final int line;
  final String kind;
  final String value;
  final String source;
}
