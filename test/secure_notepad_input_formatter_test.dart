import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_disk/widgets/secure_notepad_sections.dart';

void main() {
  test('limits ASCII input by UTF-8 bytes', () {
    const formatter = Utf8ByteLengthLimitingTextInputFormatter(4);
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
          text: 'abcde', selection: TextSelection.collapsed(offset: 5)),
    );

    expect(value.text, 'abcd');
    expect(value.selection, const TextSelection.collapsed(offset: 4));
  });

  test('limits multibyte input without splitting a code point', () {
    const formatter = Utf8ByteLengthLimitingTextInputFormatter(6);
    final value = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
          text: '你好啊', selection: TextSelection.collapsed(offset: 3)),
    );

    expect(value.text, '你好');
    expect(value.text.codeUnits, hasLength(2));
    expect(value.selection, const TextSelection.collapsed(offset: 2));
  });

  test('keeps edits within the byte limit unchanged', () {
    const formatter = Utf8ByteLengthLimitingTextInputFormatter(8);
    const value = TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(formatter.formatEditUpdate(const TextEditingValue(), value), value);
  });
}
