import 'dart:io';

const _defaultOutput = 'docs/I18N_HARDCODED_STRING_AUDIT.md';
final _cjk = RegExp(r'[\u3400-\u9fff]');
final _interpolationOnly = RegExp(
  r'^\s*(?:(?:\$\{[^}]+\})|(?:\$[A-Za-z_]\w*))+\s*$',
);
final _displayContext = RegExp(
  r'\b(Text|SelectableText|TextSpan|Tooltip|SnackBar|AlertDialog|'
  r'InputDecoration|Semantics|ListTile|AppBar|FilledButton|TextButton|'
  r'ElevatedButton|OutlinedButton|IconButton|MenuItemButton|'
  r'ScaffoldMessenger|ErrorHelper)\b|'
  r'\b(title|content|tooltip|labelText|hintText|helperText|errorText|'
  r'semanticLabel|message|description|suggestion)\s*:',
);
final _feedbackContext = RegExp(
  r'\b(throw|Exception|Error|error|failure|failed|warning|FormatException|'
  r'StateError|UnsupportedError|loadError|saveError|draftError)\b',
  caseSensitive: false,
);
final _technicalToken = RegExp(r'^[A-Za-z0-9_./:@#=+\-]+$');
final _interpolation = RegExp(r'\$\{[^}]+\}|\$[A-Za-z_]\w*');
final _nonDisplayParameter = RegExp(
  r'\b(key|debugLabel|routeName|tag|heroTag)\s*:',
);

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options.showHelp) {
    stdout.writeln('''Usage: dart run tool/audit_i18n_strings.dart [options]

Options:
  --output=<path>  Write Markdown report to this path.
  --include-test    Also scan test/**/*.dart (reported separately).
  --help            Show this help.
''');
    return;
  }

  final root = Directory.current;
  final scanDirectories = <Directory>[
    Directory('${root.path}${Platform.pathSeparator}lib'),
    if (options.includeTests)
      Directory('${root.path}${Platform.pathSeparator}test'),
  ];
  if (scanDirectories.any((directory) => !directory.existsSync())) {
    stderr.writeln('Run this command from the repository root.');
    exitCode = 2;
    return;
  }

  final findings = <_Finding>[];
  for (final directory in scanDirectories) {
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !_isExcluded(file.path, options))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    for (final file in files) {
      findings.addAll(_scanFile(root, file));
    }
  }

  final output = _resolveOutputFile(root, options.outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(_renderReport(findings, options));
  stdout.writeln(
    'Wrote ${findings.length} candidates to ${options.outputPath}',
  );
}

List<_Finding> _scanFile(Directory root, File file) {
  final source = file.readAsStringSync();
  final lines = source.split('\n');
  final relativePath = _relativePath(root, file);
  final findings = <_Finding>[];
  for (final token in _scanStrings(source)) {
    final context = _lineContext(lines, token.line);
    final containsCjk = _cjk.hasMatch(token.value);
    final userFacingAscii = !containsCjk &&
        _hasHumanReadableAscii(token.value) &&
        !_nonDisplayParameter.hasMatch(lines[token.line - 1]) &&
        (_displayContext.hasMatch(context) ||
            _feedbackContext.hasMatch(context));
    if (!containsCjk && !userFacingAscii) continue;
    if (_isLocalizationComposition(token.value)) continue;
    findings.add(
      _Finding(
        path: relativePath,
        line: token.line,
        classification: _classify(
          containsCjk: containsCjk,
          path: relativePath,
          context: context,
        ),
        value: token.value,
        source: lines[token.line - 1].trim(),
      ),
    );
  }
  return findings;
}

Iterable<_StringToken> _scanStrings(String source) sync* {
  var index = 0;
  var line = 1;
  while (index < source.length) {
    final character = source[index];
    if (character == '\n') {
      line++;
      index++;
      continue;
    }
    if (character == '/' && index + 1 < source.length) {
      final next = source[index + 1];
      if (next == '/') {
        index += 2;
        while (index < source.length && source[index] != '\n') {
          index++;
        }
        continue;
      }
      if (next == '*') {
        index += 2;
        while (index + 1 < source.length &&
            !(source[index] == '*' && source[index + 1] == '/')) {
          if (source[index] == '\n') line++;
          index++;
        }
        index = index + 1 < source.length ? index + 2 : source.length;
        continue;
      }
    }

    final raw = character == 'r' &&
        index + 1 < source.length &&
        (source[index + 1] == "'" || source[index + 1] == '"');
    final quoteIndex = raw ? index + 1 : index;
    if (quoteIndex >= source.length ||
        (source[quoteIndex] != "'" && source[quoteIndex] != '"')) {
      index++;
      continue;
    }

    final quote = source[quoteIndex];
    final triple = quoteIndex + 2 < source.length &&
        source[quoteIndex + 1] == quote &&
        source[quoteIndex + 2] == quote;
    final openingLength = triple ? 3 : 1;
    final contentStart = quoteIndex + openingLength;
    final startLine = line;
    index = contentStart;
    var closed = false;
    while (index < source.length) {
      if (source[index] == '\n') line++;
      if (!raw && source[index] == '\\') {
        index += 2;
        continue;
      }
      final closes = triple
          ? index + 2 < source.length &&
              source[index] == quote &&
              source[index + 1] == quote &&
              source[index + 2] == quote
          : source[index] == quote;
      if (closes) {
        final value = source.substring(contentStart, index);
        yield _StringToken(line: startLine, value: value);
        index += openingLength;
        closed = true;
        break;
      }
      index++;
    }
    if (!closed) return;
  }
}

String _lineContext(List<String> lines, int line) {
  final start = (line - 2).clamp(0, lines.length);
  final end = (line + 1).clamp(0, lines.length);
  return lines.sublist(start, end).join(' ');
}

bool _isExcluded(String path, _Options options) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/lib/l10n/') ||
      (!options.includeTests && normalized.contains('/lib/testing/'));
}

String _relativePath(Directory root, File file) {
  final rootPath = '${root.absolute.path}${Platform.pathSeparator}';
  return file.absolute.path.startsWith(rootPath)
      ? file.absolute.path.substring(rootPath.length).replaceAll('\\', '/')
      : file.path.replaceAll('\\', '/');
}

File _resolveOutputFile(Directory root, String outputPath) {
  final requested = File(outputPath);
  if (requested.isAbsolute) return requested;
  return File('${root.path}${Platform.pathSeparator}$outputPath');
}

bool _hasHumanReadableAscii(String value) {
  final compact =
      value.replaceAll(_interpolation, '').replaceAll(r'\n', ' ').trim();
  return RegExp(r'[A-Za-z]').hasMatch(compact) &&
      !_technicalToken.hasMatch(compact) &&
      !compact.startsWith('http://') &&
      !compact.startsWith('https://');
}

bool _isLocalizationComposition(String value) {
  return _interpolationOnly.hasMatch(value) ||
      value.contains(r'AppLocalizations') ||
      value.contains(r'strings.');
}

String _classify({
  required bool containsCjk,
  required String path,
  required String context,
}) {
  final productUi = path.startsWith('lib/widgets/') ||
      path.startsWith('lib/pages/') ||
      path.startsWith('lib/windows/');
  if (productUi ||
      _displayContext.hasMatch(context) &&
          !_feedbackContext.hasMatch(context)) {
    return containsCjk ? '直接 UI 文案' : '直接 UI 英文文案';
  }
  if (_feedbackContext.hasMatch(context)) {
    return containsCjk ? '错误/服务边界文案' : '错误/反馈英文文案';
  }
  return 'CJK 待人工复核';
}

String _renderReport(List<_Finding> findings, _Options options) {
  final byClassification = <String, int>{};
  final byFile = <String, int>{};
  for (final finding in findings) {
    byClassification.update(
      finding.classification,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    byFile.update(finding.path, (count) => count + 1, ifAbsent: () => 1);
  }
  final sortedFiles = byFile.entries.toList()
    ..sort((left, right) {
      final countOrder = right.value.compareTo(left.value);
      return countOrder != 0 ? countOrder : left.key.compareTo(right.key);
    });
  final orderedFindings = [...findings]..sort((left, right) {
      final kindOrder = left.classification.compareTo(right.classification);
      if (kindOrder != 0) return kindOrder;
      final pathOrder = left.path.compareTo(right.path);
      return pathOrder != 0 ? pathOrder : left.line.compareTo(right.line);
    });

  final buffer = StringBuffer()
    ..writeln('# 本地化未迁移文案清单')
    ..writeln()
    ..writeln('此文件由 `dart run tool/audit_i18n_strings.dart` 生成，请勿手工编辑。')
    ..writeln()
    ..writeln(
      '扫描范围：`lib/**/*.dart`${options.includeTests ? ' 与 `test/**/*.dart`' : ''}；'
      '排除生成的 `lib/l10n/`。',
    )
    ..writeln(
      '脚本采用 Dart 字符串词法扫描，覆盖单行、多行、raw 字符串，并忽略注释；'
      'CJK 字符串全量列出，同时补充 UI 与错误反馈上下文中的可见英文。',
    )
    ..writeln()
    ..writeln('分类不等同于完成结论：')
    ..writeln()
    ..writeln('- `直接 UI 文案`：应优先迁入 ARB。')
    ..writeln('- `错误/服务边界文案`：先确认是否由 UI 直接展示；若是，应改为稳定状态/错误码，再在 UI 映射 ARB。')
    ..writeln('- `CJK 待人工复核`：可能是协议、日志或测试数据，须登记理由后才可排除。')
    ..writeln('- 英文候选用于发现未本地化 fallback；技术标识、URL、协议字段不应翻译。')
    ..writeln()
    ..writeln('候选总数：${findings.length}')
    ..writeln()
    ..writeln('## 按分类统计')
    ..writeln()
    ..writeln('| 分类 | 候选数 |')
    ..writeln('| --- | ---: |');
  for (final entry in byClassification.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## 按文件统计')
    ..writeln()
    ..writeln('| 文件 | 候选数 |')
    ..writeln('| --- | ---: |');
  for (final entry in sortedFiles) {
    buffer.writeln('| `${entry.key}` | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## 逐项清单')
    ..writeln()
    ..writeln('| 分类 | 文件 | 行号 | 字符串 | 源码上下文 |')
    ..writeln('| --- | --- | ---: | --- | --- |');
  for (final finding in orderedFindings) {
    buffer
      ..write(
          '| ${finding.classification} | `${finding.path}` | ${finding.line} | ')
      ..write('${_markdown(finding.value)} | ${_markdown(finding.source)} |')
      ..writeln();
  }
  return buffer.toString();
}

String _markdown(String value) {
  final compact = value
      .replaceAll('\n', r'\n')
      .replaceAll('|', r'\|')
      .replaceAll('`', r'\`');
  return compact.length <= 160 ? compact : '${compact.substring(0, 157)}...';
}

class _Options {
  const _Options({
    required this.outputPath,
    required this.includeTests,
    required this.showHelp,
  });

  factory _Options.parse(List<String> args) {
    var outputPath = _defaultOutput;
    var includeTests = false;
    var showHelp = false;
    for (final argument in args) {
      if (argument.startsWith('--output=')) {
        outputPath = argument.substring('--output='.length);
      } else if (argument == '--include-test') {
        includeTests = true;
      } else if (argument == '--help') {
        showHelp = true;
      } else {
        stderr.writeln('Unknown option: $argument');
        showHelp = true;
      }
    }
    return _Options(
      outputPath: outputPath,
      includeTests: includeTests,
      showHelp: showHelp,
    );
  }

  final String outputPath;
  final bool includeTests;
  final bool showHelp;
}

class _StringToken {
  const _StringToken({required this.line, required this.value});

  final int line;
  final String value;
}

class _Finding {
  const _Finding({
    required this.path,
    required this.line,
    required this.classification,
    required this.value,
    required this.source,
  });

  final String path;
  final int line;
  final String classification;
  final String value;
  final String source;
}
