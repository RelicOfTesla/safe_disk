import 'package:flutter/services.dart';

abstract interface class SystemTextClipboard {
  Future<String?> readText();

  Future<void> clear();
}

class FlutterSystemTextClipboard implements SystemTextClipboard {
  const FlutterSystemTextClipboard();

  @override
  Future<String?> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  @override
  Future<void> clear() {
    return Clipboard.setData(const ClipboardData(text: ''));
  }
}
