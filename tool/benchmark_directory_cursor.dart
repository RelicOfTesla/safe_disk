import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:safe_disk/native/native_lib.dart';
import 'package:safe_disk/services/crypto_service.dart';
import 'package:safe_disk/services/directory_page_session.dart';

/// Measures the real FFI cursor path without making a 100k-entry test part of
/// the normal Flutter suite. Run with SAFE_DISK_FFI_LIBRARY set explicitly.
Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    stdout.writeln(_Options.usage);
    return;
  }

  Directory? workspace;
  DirectoryPageSession? session;
  CryptoService? crypto;
  int? rootID;
  try {
    NativeLib.ensureAvailable();
    workspace =
        await Directory.systemTemp.createTemp('safe-disk-cursor-bench-');
    final rootPath = '${workspace.path}${Platform.pathSeparator}root';
    final password = _newBenchmarkPassword();
    final native = NativeLib.instance;

    native.secCreateRootConfig(
      rootPath,
      password,
      jsonEncode(const {
        'dataFactory': 'AES-CTR',
        'nameFactory': 'AES-256-GCM',
        'keyStrengthMs': 1,
      }),
    );
    crypto = CryptoService();
    rootID = crypto.openRoot(rootPath, password, '');

    final creationWatch = Stopwatch()..start();
    for (var index = 0; index < options.entryCount; index++) {
      native.secQuickWriteFile(rootID, _entryName(index), const []);
      if ((index + 1) % 10000 == 0) {
        stderr.writeln('已创建 ${index + 1}/${options.entryCount} 个条目');
      }
    }
    creationWatch.stop();

    session = DirectoryPageSession(
      gateway: _CryptoCursorGateway(crypto),
      rootID: rootID,
      relativePath: '',
    );
    final totalWatch = Stopwatch()..start();
    final firstPageWatch = Stopwatch()..start();
    await session.loadNext(limit: options.pageSize);
    firstPageWatch.stop();

    var pageCount = 1;
    var maxPageMilliseconds = firstPageWatch.elapsedMilliseconds;
    final firstPageSampledRssBytes = _sampleRssBytes();
    var maxSampledRssBytes = firstPageSampledRssBytes;
    final firstPageEntryCount = session.entries.length;
    while (!session.done) {
      final pageWatch = Stopwatch()..start();
      await session.loadNext(limit: options.pageSize);
      pageWatch.stop();
      pageCount++;
      maxPageMilliseconds =
          _max(maxPageMilliseconds, pageWatch.elapsedMilliseconds);
      maxSampledRssBytes = _max(maxSampledRssBytes, _sampleRssBytes());
    }
    totalWatch.stop();

    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'schema_version': 1,
      'entry_count': options.entryCount,
      'page_size': options.pageSize,
      'name_factory': 'AES-256-GCM',
      'creation_ms': creationWatch.elapsedMilliseconds,
      'first_page': {
        'entry_count': firstPageEntryCount,
        'response_ms': firstPageWatch.elapsedMilliseconds,
        'sampled_rss_bytes': firstPageSampledRssBytes,
      },
      'full_enumeration': {
        'page_count': pageCount,
        'entry_count': session.entries.length,
        'elapsed_ms': totalWatch.elapsedMilliseconds,
        'max_page_response_ms': maxPageMilliseconds,
        'max_sampled_rss_bytes': maxSampledRssBytes,
      },
      'rss_note': '每页返回后采样进程 RSS，不是语言运行时堆峰值。',
      'workspace': workspace.path,
      'workspace_retained': options.keepWorkspace,
    }));
  } finally {
    await session?.dispose();
    if (crypto != null && rootID != null) crypto.closeRoot(rootID);
    if (workspace != null && !options.keepWorkspace) {
      await workspace.delete(recursive: true);
    }
  }
}

String _entryName(int index) => 'entry-${index.toString().padLeft(6, '0')}.txt';

String _newBenchmarkPassword() {
  final random = Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
}

int _sampleRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } on UnsupportedError {
    return 0;
  }
}

int _max(int first, int second) => first > second ? first : second;

class _CryptoCursorGateway implements DirectoryCursorGateway {
  const _CryptoCursorGateway(this.crypto);

  final CryptoService crypto;

  @override
  Future<void> close(int cursorID) => crypto.closeDirCursor(cursorID);

  @override
  Future<int> open(int rootID, String relativePath) =>
      crypto.openDirCursor(rootID, relativePath);

  @override
  Future<DirectoryCursorPageData> readPage(int cursorID, int limit) async {
    final page = await crypto.readDirCursorPage(cursorID, limit);
    return DirectoryCursorPageData(
      entries: page.entries.map(DirEntry.fromJson).toList(),
      done: page.done,
    );
  }
}

class _Options {
  const _Options({
    required this.entryCount,
    required this.pageSize,
    required this.keepWorkspace,
    required this.showHelp,
  });

  static const usage = '''用法：
  SAFE_DISK_FFI_LIBRARY=/path/to/libffi_sec_fs.so \\
    dart run tool/benchmark_directory_cursor.dart [options]

选项：
  --entries=<n>    创建的直系文件数（默认：100000）。
  --page-size=<n>  Cursor 页大小，1..1000（默认：200）。
  --keep           保留临时基准 root 供检查。
  --help           显示此帮助。
''';

  final int entryCount;
  final int pageSize;
  final bool keepWorkspace;
  final bool showHelp;

  static _Options parse(List<String> arguments) {
    var entryCount = 100000;
    var pageSize = 200;
    var keepWorkspace = false;
    var showHelp = false;
    for (final argument in arguments) {
      if (argument == '--help') {
        showHelp = true;
      } else if (argument == '--keep') {
        keepWorkspace = true;
      } else if (argument.startsWith('--entries=')) {
        entryCount = _positiveValue(argument, '--entries');
      } else if (argument.startsWith('--page-size=')) {
        pageSize = _positiveValue(argument, '--page-size');
      } else {
        throw ArgumentError('Unknown option: $argument');
      }
    }
    if (pageSize > 1000) {
      throw ArgumentError('--page-size must be between 1 and 1000');
    }
    return _Options(
      entryCount: entryCount,
      pageSize: pageSize,
      keepWorkspace: keepWorkspace,
      showHelp: showHelp,
    );
  }

  static int _positiveValue(String argument, String option) {
    final value = int.tryParse(argument.substring(option.length + 1));
    if (value == null || value < 1) {
      throw ArgumentError('$option must be a positive integer');
    }
    return value;
  }
}
