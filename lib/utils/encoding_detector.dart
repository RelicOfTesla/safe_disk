import 'dart:convert';

import 'package:charset_converter/charset_converter.dart';

/// Detects the text encoding of raw bytes and decodes them.
///
/// Tries encodings in order of likelihood for Chinese text files:
/// 1. BOM-based detection (UTF-8, UTF-16 LE/BE)
/// 2. UTF-8 (validated — no replacement characters)
/// 3. GB18030 / GBK (most common legacy Chinese encoding)
/// 4. Big5 (traditional Chinese)
/// 5. Latin-1 (universal fallback — never fails)
class EncodingDetector {
  const EncodingDetector._();

  /// Decode [bytes] using the best-guess encoding.
  ///
  /// Returns the decoded string and the name of the encoding used.
  static Future<({String text, String encoding})> decode(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return (text: '', encoding: 'utf-8');
    }

    // 1. Check BOM.
    final bomResult = _tryBOM(bytes);
    if (bomResult != null) return bomResult;

    // 2. Try UTF-8 (strict — allowMalformed: false throws on bad bytes).
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      return (text: text, encoding: 'utf-8');
    } catch (_) {
      // Not valid UTF-8.
    }

    // 3. Try GB18030 (superset of GBK).
    try {
      final text = await CharsetConverter.decode('gb18030', bytes);
      return (text: text, encoding: 'gb18030');
    } catch (_) {
      // Not valid GB18030.
    }

    // 4. Try Big5.
    try {
      final text = await CharsetConverter.decode('big5', bytes);
      return (text: text, encoding: 'big5');
    } catch (_) {
      // Not valid Big5.
    }

    // 5. Latin-1 fallback (every byte maps to a valid codepoint).
    final text = latin1.decode(bytes);
    return (text: text, encoding: 'latin1');
  }

  static ({String text, String encoding})? _tryBOM(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return (
        text: utf8.decode(bytes.sublist(3)),
        encoding: 'utf-8-bom',
      );
    }
    if (bytes.length >= 2 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xFE) {
      final text = utf16le.decode(bytes.sublist(2));
      return (text: text, encoding: 'utf-16-le');
    }
    if (bytes.length >= 2 &&
        bytes[0] == 0xFE &&
        bytes[1] == 0xFF) {
      final text = utf16be.decode(bytes.sublist(2));
      return (text: text, encoding: 'utf-16-be');
    }
    return null;
  }

  static const utf16le = _Utf16leCodec();
  static const utf16be = _Utf16beCodec();
}

/// Minimal UTF-16 LE decoder for BOM-stripped data.
class _Utf16leCodec extends Encoding {
  const _Utf16leCodec();

  @override
  String get name => 'utf-16-le';

  @override
  Converter<List<int>, String> get decoder => const _Utf16leDecoder();
}

class _Utf16leDecoder extends Converter<List<int>, String> {
  const _Utf16leDecoder();

  @override
  String convert(List<int> input) {
    final codes = <int>[];
    for (var i = 0; i < input.length - 1; i += 2) {
      codes.add(input[i] | (input[i + 1] << 8));
    }
    return String.fromCharCodes(codes);
  }
}

/// Minimal UTF-16 BE decoder for BOM-stripped data.
class _Utf16beCodec extends Encoding {
  const _Utf16beCodec();

  @override
  String get name => 'utf-16-be';

  @override
  Converter<List<int>, String> get decoder => const _Utf16beDecoder();
}

class _Utf16beDecoder extends Converter<List<int>, String> {
  const _Utf16beDecoder();

  @override
  String convert(List<int> input) {
    final codes = <int>[];
    for (var i = 0; i < input.length - 1; i += 2) {
      codes.add((input[i] << 8) | input[i + 1]);
    }
    return String.fromCharCodes(codes);
  }
}
