import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';

/// Detects the text encoding of raw bytes and decodes them.
///
/// Tries encodings in descending likelihood order. The first encoding that
/// decodes without error wins.  On save, content is always normalized to UTF-8.
class EncodingDetector {
  const EncodingDetector._();

  /// Encodings tried in priority order (after BOM and UTF-8).
  ///
  /// Covered: Chinese (GB18030, Big5), Japanese (Shift_JIS, EUC-JP),
  /// Korean (EUC-KR), Western/Central European (windows-1250/1252),
  /// Cyrillic (windows-1251), Arabic (windows-1256).
  static const _candidates = [
    'gb18030',       // GBK superset — most common legacy Chinese
    'big5',          // Traditional Chinese
    'shift_jis',     // Japanese
    'euc-jp',        // Japanese (Unix)
    'euc-kr',        // Korean
    'windows-1252',  // Western European
    'windows-1250',  // Central European
    'windows-1251',  // Cyrillic
    'windows-1256',  // Arabic
  ];

  /// Decode [bytes] using the best-guess encoding.
  ///
  /// Returns the decoded string and the name of the encoding used.
  static Future<({String text, String encoding})> decode(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return (text: '', encoding: 'utf-8');
    }

    // 1. BOM (if present, trust it exclusively).
    final bomResult = _tryBOM(bytes);
    if (bomResult != null) return bomResult;

    // 2. UTF-8 — fast path for the majority of modern text.
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      return (text: text, encoding: 'utf-8');
    } catch (_) {
      // Not valid UTF-8.
    }

    // 3. Try candidate legacy encodings.
    for (final name in _candidates) {
      try {
        final text = await CharsetConverter.decode(name, bytes);
        return (text: text, encoding: name);
      } catch (_) {
        // Not valid for this encoding — try the next.
      }
    }

    // 4. Latin-1 fallback (every byte maps to a valid codepoint).
    final text = latin1.decode(bytes);
    return (text: text, encoding: 'latin1');
  }

  static ({String text, String encoding})? _tryBOM(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return (
        text: utf8.decode(bytes.sublist(3), allowMalformed: false),
        encoding: 'utf-8-bom',
      );
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return (text: _utf16leDecode(bytes.sublist(2)), encoding: 'utf-16-le');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return (text: _utf16beDecode(bytes.sublist(2)), encoding: 'utf-16-be');
    }
    return null;
  }
}

/// Minimal UTF-16 LE decoder for BOM-stripped data.
String _utf16leDecode(Uint8List bytes) {
  final codes = <int>[];
  for (var i = 0; i < bytes.length - 1; i += 2) {
    codes.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(codes);
}

/// Minimal UTF-16 BE decoder for BOM-stripped data.
String _utf16beDecode(Uint8List bytes) {
  final codes = <int>[];
  for (var i = 0; i < bytes.length - 1; i += 2) {
    codes.add((bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(codes);
}
