import 'dart:io';
import 'dart:convert';

/// Represents an item in the clipboard
class ClipboardItem {
  final String path;
  final bool isDirectory;

  ClipboardItem({
    required this.path,
    required this.isDirectory,
  });

  Map<String, dynamic> toMap() => {
        'path': path,
        'isDirectory': isDirectory,
      };

  factory ClipboardItem.fromMap(Map<String, dynamic> map) => ClipboardItem(
        path: map['path'] as String,
        isDirectory: map['isDirectory'] as bool,
      );
}

/// Result of a clipboard operation
class ClipboardResult {
  final bool success;
  final String? error;
  final List<ClipboardItem>? items;

  ClipboardResult({
    required this.success,
    this.error,
    this.items,
  });

  factory ClipboardResult.success(List<ClipboardItem> items) =>
      ClipboardResult(success: true, items: items);

  factory ClipboardResult.failure(String error) =>
      ClipboardResult(success: false, error: error);
}

/// Cross-platform clipboard service for file operations.
///
/// This service provides clipboard operations for copying and pasting files.
/// Platform-specific implementations are handled internally.
///
/// Usage:
/// ```dart
/// final clipboardService = ClipboardService();
///
/// // Copy files to clipboard
/// await clipboardService.copyFiles([
///   ClipboardItem(path: '/path/to/file1.txt', isDirectory: false),
///   ClipboardItem(path: '/path/to/folder', isDirectory: true),
/// ]);
///
/// // Check if clipboard has files
/// final hasFiles = await clipboardService.hasFiles();
///
/// // Paste files from clipboard
/// final items = await clipboardService.pasteFiles();
/// ```
class ClipboardService {
  static ClipboardService? _instance;

  static ClipboardService get instance {
    _instance ??= ClipboardService._();
    return _instance!;
  }

  ClipboardService._();

  /// Custom MIME type for Safe Disk clipboard data
  // Note: MIME type support varies across platforms, so we use temp files instead
  // static const String _mimeType = 'application/x-safe-disk-file-list';

  /// Copies a list of files to the system clipboard.
  ///
  /// [items] - List of files/directories to copy
  ///
  /// Returns: ClipboardResult indicating success or failure
  Future<ClipboardResult> copyFiles(List<ClipboardItem> items) async {
    if (items.isEmpty) {
      return ClipboardResult.failure('No items to copy');
    }

    // Validate all paths exist
    for (final item in items) {
      if (item.isDirectory) {
        if (!await Directory(item.path).exists()) {
          return ClipboardResult.failure('Directory not found: ${item.path}');
        }
      } else {
        if (!await File(item.path).exists()) {
          return ClipboardResult.failure('File not found: ${item.path}');
        }
      }
    }

    try {
      if (Platform.isLinux) {
        return await _copyFilesLinux(items);
      } else if (Platform.isWindows) {
        return await _copyFilesWindows(items);
      } else {
        return ClipboardResult.failure('Unsupported platform');
      }
    } catch (e) {
      return ClipboardResult.failure('Failed to copy: $e');
    }
  }

  /// Checks if the clipboard contains files.
  ///
  /// Returns: true if clipboard has files that can be pasted
  Future<bool> hasFiles() async {
    try {
      if (Platform.isLinux) {
        return await _hasFilesLinux();
      } else if (Platform.isWindows) {
        return await _hasFilesWindows();
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the list of files from the clipboard.
  ///
  /// Returns: ClipboardResult with list of ClipboardItem
  Future<ClipboardResult> pasteFiles() async {
    try {
      if (Platform.isLinux) {
        return await _pasteFilesLinux();
      } else if (Platform.isWindows) {
        return await _pasteFilesWindows();
      }
      return ClipboardResult.failure('Unsupported platform');
    } catch (e) {
      return ClipboardResult.failure('Failed to paste: $e');
    }
  }

  // ==================== Linux Implementation ====================

  /// Linux: Copy files using xclip
  Future<ClipboardResult> _copyFilesLinux(List<ClipboardItem> items) async {
    // Create JSON data for our custom format
    final jsonData = jsonEncode({
      'version': 1,
      'items': items.map((i) => i.toMap()).toList(),
    });

    // Also prepare text/uri-list format for compatibility with other apps
    final uriList = items.map((i) {
      final uri = Uri.file(i.path).toString();
      return uri;
    }).join('\n');

    // Try xclip first, then xsel
    final xclipAvailable = await _commandExists('xclip');
    final xselAvailable = await _commandExists('xsel');

    if (!xclipAvailable && !xselAvailable) {
      // Fallback: store in temp file and provide instructions
      return await _copyFilesLinuxFallback(items, jsonData);
    }

    ProcessResult result;

    if (xclipAvailable) {
      // Store the JSON data to a temp file
      final tempFile = File('/tmp/safe_disk_clipboard.json');
      await tempFile.writeAsString(jsonData);

      // Set clipboard using xclip with the temp file
      result = await Process.run(
        'xclip',
        ['-selection', 'clipboard', '-i', tempFile.path],
      );

      if (result.exitCode == 0) {
        // Also set the URI list for external app compatibility
        final uriTempFile = File('/tmp/safe_disk_clipboard_uris.txt');
        await uriTempFile.writeAsString(uriList);

        // Set primary selection as well (middle-click paste)
        await Process.run(
          'xclip',
          ['-selection', 'primary', '-i', uriTempFile.path],
        );

        return ClipboardResult.success(items);
      }
    }

    if (xselAvailable) {
      // Use xsel as fallback
      final tempFile = File('/tmp/safe_disk_clipboard.json');
      await tempFile.writeAsString(jsonData);

      // Use cat to pipe the file content to xsel
      result = await Process.run(
        'sh',
        ['-c', 'cat "${tempFile.path}" | xsel --clipboard --input'],
      );

      if (result.exitCode == 0) {
        return ClipboardResult.success(items);
      }
    }

    return ClipboardResult.failure('Failed to set clipboard data');
  }

  /// Linux: Fallback method when xclip/xsel are not available
  Future<ClipboardResult> _copyFilesLinuxFallback(
      List<ClipboardItem> items, String jsonData) async {
    // Store clipboard data in a well-known temp location
    final clipboardFile = File('/tmp/safe_disk_clipboard.json');
    await clipboardFile.writeAsString(jsonData);

    // Return success but indicate limited functionality
    return ClipboardResult.success(items);
  }

  /// Linux: Check if clipboard has files
  Future<bool> _hasFilesLinux() async {
    // Check our temp file first
    final clipboardFile = File('/tmp/safe_disk_clipboard.json');
    if (await clipboardFile.exists()) {
      try {
        final content = await clipboardFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        return data['items'] != null && (data['items'] as List).isNotEmpty;
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Check xclip for text/uri-list
    final xclipAvailable = await _commandExists('xclip');
    if (xclipAvailable) {
      try {
        final result = await Process.run(
          'xclip',
          ['-selection', 'clipboard', '-o', '-t', 'text/uri-list'],
        );

        if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
          // Check if it contains file:// URIs
          final output = result.stdout.toString();
          if (output.contains('file://')) {
            return true;
          }
        }
      } catch (_) {
        // Ignore errors
      }
    }

    return false;
  }

  /// Linux: Get files from clipboard
  Future<ClipboardResult> _pasteFilesLinux() async {
    // Check our temp file first (for internal copy)
    final clipboardFile = File('/tmp/safe_disk_clipboard.json');
    if (await clipboardFile.exists()) {
      try {
        final content = await clipboardFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        if (data['items'] != null) {
          final items = (data['items'] as List)
              .map((i) => ClipboardItem.fromMap(i as Map<String, dynamic>))
              .toList();

          // Verify items still exist
          final validItems = <ClipboardItem>[];
          for (final item in items) {
            if (item.isDirectory) {
              if (await Directory(item.path).exists()) {
                validItems.add(item);
              }
            } else {
              if (await File(item.path).exists()) {
                validItems.add(item);
              }
            }
          }

          if (validItems.isNotEmpty) {
            return ClipboardResult.success(validItems);
          }
        }
      } catch (_) {
        // Ignore parse errors, fall through to external clipboard check
      }
    }

    // Check xclip for text/uri-list (for external copy)
    final xclipAvailable = await _commandExists('xclip');
    if (xclipAvailable) {
      try {
        final result = await Process.run(
          'xclip',
          ['-selection', 'clipboard', '-o', '-t', 'text/uri-list'],
        );

        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final items = await _parseUriList(output);
          if (items.isNotEmpty) {
            return ClipboardResult.success(items);
          }
        }
      } catch (_) {
        // Try without MIME type
        try {
          final result = await Process.run(
            'xclip',
            ['-selection', 'clipboard', '-o'],
          );

          if (result.exitCode == 0) {
            final output = result.stdout.toString();
            final items = await _parseUriList(output);
            if (items.isNotEmpty) {
              return ClipboardResult.success(items);
            }
          }
        } catch (_) {
          // Ignore errors
        }
      }
    }

    // Try xsel as fallback
    final xselAvailable = await _commandExists('xsel');
    if (xselAvailable) {
      try {
        final result = await Process.run(
          'xsel',
          ['--clipboard', '--output'],
        );

        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final items = await _parseUriList(output);
          if (items.isNotEmpty) {
            return ClipboardResult.success(items);
          }
        }
      } catch (_) {
        // Ignore errors
      }
    }

    return ClipboardResult.failure('No files in clipboard');
  }

  // ==================== Windows Implementation ====================

  /// Windows: Copy files using PowerShell
  Future<ClipboardResult> _copyFilesWindows(List<ClipboardItem> items) async {
    // Create JSON data for internal use
    final jsonData = jsonEncode({
      'version': 1,
      'items': items.map((i) => i.toMap()).toList(),
    });

    // Store to temp file for internal paste
    final tempDir = Directory.systemTemp;
    final clipboardFile = File('${tempDir.path}\\safe_disk_clipboard.json');
    await clipboardFile.writeAsString(jsonData);

    // Use PowerShell to set clipboard with file paths
    // This allows other apps to recognize the files
    final paths = items.map((i) => i.path).join("','");
    final psScript = '''
      Add-Type -AssemblyName System.Windows.Forms
      \$files = @('$paths')
      \$fileObjects = \$files | ForEach-Object { Get-Item -LiteralPath \$_ }
      [System.Windows.Forms.Clipboard]::SetFileDropList(\$fileObjects)
    ''';

    try {
      final result = await Process.run(
        'powershell',
        ['-Command', psScript],
      );

      if (result.exitCode == 0) {
        return ClipboardResult.success(items);
      }

      // Fallback: just store to temp file
      return ClipboardResult.success(items);
    } catch (e) {
      // Still return success since we stored to temp file
      return ClipboardResult.success(items);
    }
  }

  /// Windows: Check if clipboard has files
  Future<bool> _hasFilesWindows() async {
    // Check our temp file first
    final tempDir = Directory.systemTemp;
    final clipboardFile = File('${tempDir.path}\\safe_disk_clipboard.json');

    if (await clipboardFile.exists()) {
      try {
        final content = await clipboardFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        return data['items'] != null && (data['items'] as List).isNotEmpty;
      } catch (_) {
        // Ignore parse errors
      }
    }

    // Check Windows clipboard via PowerShell
    try {
      const psScript = '''
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::ContainsFileDropList()
      ''';

      final result = await Process.run(
        'powershell',
        ['-Command', psScript],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim().toLowerCase();
        return output == 'true';
      }
    } catch (_) {
      // Ignore errors
    }

    return false;
  }

  /// Windows: Get files from clipboard
  Future<ClipboardResult> _pasteFilesWindows() async {
    // Check our temp file first (for internal copy)
    final tempDir = Directory.systemTemp;
    final clipboardFile = File('${tempDir.path}\\safe_disk_clipboard.json');

    if (await clipboardFile.exists()) {
      try {
        final content = await clipboardFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        if (data['items'] != null) {
          final items = (data['items'] as List)
              .map((i) => ClipboardItem.fromMap(i as Map<String, dynamic>))
              .toList();

          // Verify items still exist
          final validItems = <ClipboardItem>[];
          for (final item in items) {
            if (item.isDirectory) {
              if (await Directory(item.path).exists()) {
                validItems.add(item);
              }
            } else {
              if (await File(item.path).exists()) {
                validItems.add(item);
              }
            }
          }

          if (validItems.isNotEmpty) {
            return ClipboardResult.success(validItems);
          }
        }
      } catch (_) {
        // Ignore parse errors, fall through to external clipboard check
      }
    }

    // Check Windows clipboard via PowerShell
    try {
      const psScript = '''
        Add-Type -AssemblyName System.Windows.Forms
        \$files = [System.Windows.Forms.Clipboard]::GetFileDropList()
        \$files -join '|'
      ''';

      final result = await Process.run(
        'powershell',
        ['-Command', psScript],
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final paths = output.split('|');
          final items = <ClipboardItem>[];

          for (final path in paths) {
            if (path.isEmpty) continue;

            final file = File(path);
            final dir = Directory(path);

            if (await file.exists()) {
              items.add(ClipboardItem(path: path, isDirectory: false));
            } else if (await dir.exists()) {
              items.add(ClipboardItem(path: path, isDirectory: true));
            }
          }

          if (items.isNotEmpty) {
            return ClipboardResult.success(items);
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }

    return ClipboardResult.failure('No files in clipboard');
  }

  // ==================== Utility Methods ====================

  /// Checks if a command exists on the system
  Future<bool> _commandExists(String command) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('where', [command]);
        return result.exitCode == 0;
      } else {
        final result = await Process.run('which', [command]);
        return result.exitCode == 0;
      }
    } catch (_) {
      return false;
    }
  }

  /// Parses a text/uri-list string into ClipboardItems
  Future<List<ClipboardItem>> _parseUriList(String uriList) async {
    final items = <ClipboardItem>[];

    for (final line in uriList.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      try {
        final uri = Uri.parse(trimmed);
        if (uri.scheme == 'file') {
          final path = uri.toFilePath();
          final file = File(path);
          final dir = Directory(path);

          if (await file.exists()) {
            items.add(ClipboardItem(path: path, isDirectory: false));
          } else if (await dir.exists()) {
            items.add(ClipboardItem(path: path, isDirectory: true));
          }
        }
      } catch (_) {
        // Try as plain path
        final file = File(trimmed);
        final dir = Directory(trimmed);

        if (await file.exists()) {
          items.add(ClipboardItem(path: trimmed, isDirectory: false));
        } else if (await dir.exists()) {
          items.add(ClipboardItem(path: trimmed, isDirectory: true));
        }
      }
    }

    return items;
  }

  /// Clears the clipboard
  Future<void> clear() async {
    try {
      if (Platform.isLinux) {
        final tempFile = File('/tmp/safe_disk_clipboard.json');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final uriFile = File('/tmp/safe_disk_clipboard_uris.txt');
        if (await uriFile.exists()) {
          await uriFile.delete();
        }

        final xclipAvailable = await _commandExists('xclip');
        if (xclipAvailable) {
          await Process.run(
              'xclip', ['-selection', 'clipboard', '-i', '/dev/null']);
        }
      } else if (Platform.isWindows) {
        final tempDir = Directory.systemTemp;
        final clipboardFile = File('${tempDir.path}\\safe_disk_clipboard.json');
        if (await clipboardFile.exists()) {
          await clipboardFile.delete();
        }

        const psScript = '''
          Add-Type -AssemblyName System.Windows.Forms
          [System.Windows.Forms.Clipboard]::Clear()
        ''';

        await Process.run('powershell', ['-Command', psScript]);
      }
    } catch (_) {
      // Ignore errors when clearing
    }
  }
}
